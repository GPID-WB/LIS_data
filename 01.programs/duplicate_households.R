# library(ggplot2)
library(data.table)
library(collapse)

##' Compute weighted Lorenz table by reporting level
##'
##' This function computes a Lorenz-like table for a dataset containing
##' household welfare and sampling weights. It assigns observations to
##' weighted bins (percentiles) using `new_bins()` and then aggregates
##' key statistics by `reporting_level` and bin. The output contains
##' average welfare per bin, population and welfare shares, quantiles,
##' and total population per bin. If multiple reporting levels are
##' present, the function also adds a synthetic `national` reporting
##' level by duplicating the full dataset.
##'
##' @param df A data.frame or data.table containing at least the columns
##'   `welfare`, `weight`, and `reporting_level`.
##' @param nq Integer number of bins to create (default 100). For a
##'   typical Lorenz/percentile decomposition use `nq = 100`.
##' @param tolerance Numeric tolerance used when filling bins in
##'   `new_bins()` (passed through; default `1e-6`).
##'
##' @return A `data.table` aggregated by `reporting_level` and `bin` with
##'   columns: `reporting_level`, `bin`, `avg_welfare`, `pop_share`,
##'   `welfare_share`, `quantile`, and `pop`.
##'
##' @details The function sorts the data by `welfare`, assigns each
##' observation (or split portion of an observation) to a bin so that
##' each bin has approximately the same total weight, and computes
##' weighted summaries. Large weights may be split across bins via
##' `new_bins()`.
##'
##' @examples
##' 
##' 
##' # Example (small synthetic dataset)
##' # dt <- data.table::data.table(
##' #   reporting_level = rep("national", 5),
##' #   welfare = c(1,2,3,4,5),
##' #   weight = c(1,1,1,1,1)
##' # )
##' # lorenz_table(dt, nq = 5)
##'
##' @export
lorenz_table <- \(df, nq = 100, tolerance = 1e-6) {
  # number of data labels
  no_dl <- funique(df$reporting_level) |>
    length()


  if (no_dl > 1) {
## Bins at national level ----
    df2 <-  copy(df)
    df2[, reporting_level := "national"]
    df <- rowbind(df, df2)
  }

  ## Bins at reporting level -------
  # sort according to bins calculation method
  setorder(df, reporting_level, welfare)
  df[, id := .I]

  dt <-
    df[, new_bins(welfare = welfare,
                  weight = weight,
                  id = id,
                  nbins = nq,
                  tolerance = tolerance),
       by = reporting_level]  |>
    ftransform(wt_welfare = welfare*weight) |>
    fgroup_by(reporting_level) |>
  ## totals by reporting level
    fmutate(tot_pop = fsum(weight),
            tot_wlf = fsum(wt_welfare)) |>
    fungroup() |>
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Main measures --------
  ## shares at the observation level ---------
  ftransform(pop_share = weight/tot_pop,
             welfare_share = (wt_welfare)/tot_wlf) |>
    ## aggregate
    fgroup_by(reporting_level, bin) |>
    fsummarise(avg_welfare    = fmean(welfare, w = weight),
               pop_share      = fsum(pop_share),
               welfare_share  = fsum(welfare_share),
               quantile       = fmax(welfare),
               pop            = fsum(weight)) |>
    fungroup() |>
    setorder(reporting_level, bin)

  dt

}

#' Assign households to weighted bins (percentiles)
#'
#' This function assigns each household to a percentile bin using a weighted distribution,
#' ensuring that each bin has approximately the same total weight. Households with large
#' weights may be duplicated and split across bins to preserve monotonicity of welfare shares.
#'
#' @param welfare Numeric vector of household welfare (e.g., income).
#' @param weight  Numeric vector of sampling weights (same length as welfare).
#' @param nbins   Number of bins to divide the population into (default = 100).
#' @param id      Optional ID vector for each observation. If NULL, it will be generated.
#'
#' @return A `data.table` with columns: `id`, `welfare`, `weight`, and `bin`.
#'   The output may have more rows than the input due to household splitting.
#'
#' @export
new_bins <- function(welfare, weight, nbins = 100, tolerance = 1e-6, id = NULL) {
  stopifnot(length(welfare) == length(weight))

  # Handle NAs
  if (anyNA(welfare) || anyNA(weight)) {
    valid <- !is.na(welfare) & !is.na(weight)
    welfare <- welfare[valid]
    weight  <- weight[valid]
    if (!is.null(id)) id <- id[valid]
  } else {
    id <- if (is.null(id)) seq_along(welfare) else id
  }

  # Sort by welfare
  o <- order(welfare)
  welfare <- welfare[o]
  weight  <- weight[o]
  id      <- id[o]

  total_weight <- fsum(weight)
  bin_size     <- total_weight / nbins

  # Preallocate result vectors
  out_id      <- integer(2 * length(welfare))
  out_welfare <- numeric(2 * length(welfare))
  out_weight  <- numeric(2 * length(welfare))
  out_bin     <- integer(2 * length(welfare))

  cur_bin    <- 1
  cur_weight <- 0 # current among ot people in a bin
  out_index  <- 1 # index of the new vectors

  # loop over each row of the original data.
  for (i in seq_along(welfare)) {
    w  <- welfare[i]
    wt <- weight[i]
    id_i <- id[i]

    # as long as the weight to allocate is positive and
    # the value of the current bin is smaller or equal to
    # the number of bins proceed
    while (wt > 0 && cur_bin <= nbins) {
      # room in the bin available after subtracting
      # the people that is already in there.
      room <- bin_size - cur_weight

      # Move to next bin if very close to full
      if (abs(room) < tolerance) {
        cur_bin <- cur_bin + 1
        cur_weight <- 0
        next
      }

      #
      take <- min(wt, room)

      out_id[out_index]      <- id_i
      out_welfare[out_index] <- w
      out_weight[out_index]  <- take
      out_bin[out_index]     <- cur_bin
      out_index <- out_index + 1

      wt <- wt - take
      cur_weight <- cur_weight + take

      if (cur_weight >= bin_size - tolerance) {
        cur_bin <- cur_bin + 1
        cur_weight <- 0 # reset and go to the next bin
      }
    }
  }

  # Handle any leftover weight that couldn't be assigned due to tolerance
  if (cur_bin > nbins && wt > 0) {
    # Add remaining weight to the last bin
    out_id[out_index]      <- id_i
    out_welfare[out_index] <- w
    out_weight[out_index]  <- wt
    out_bin[out_index]     <- nbins
    out_index <- out_index + 1
  }

  # Return result
  data.table::data.table(
    id      = out_id[1:(out_index - 1)],
    bin     = out_bin[1:(out_index - 1)],
    weight  = out_weight[1:(out_index - 1)],
    welfare = out_welfare[1:(out_index - 1)]
  )
}
