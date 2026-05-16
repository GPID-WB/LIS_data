##' Compare R and Stata 1000-bin Lorenz outputs
##'
##' Loads the CSV produced by 01.LIS_1000bins_test.R and the DTA produced by
##' LIS_1000bins_test.do and checks whether they agree, column by column.
##'
##' Outputs:
##'   - Console summary of row counts, key-column match, and per-column stats.
##'   - `compare_detail` data.table with absolute/relative differences for each
##'     numeric column, one row per (survey, bin).

library(data.table)
library(haven)

# -------------------------------------------------------------------------
# 0. Locate files
# -------------------------------------------------------------------------

path <- "C:/WBG/Git repos/Packages/GPID/PIP/LIS_data/01.programs/SampleData"

# Accept an explicit date-stamp argument, otherwise pick the most-recent file
pick_latest <- function(pattern) {
  files <- list.files(path, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) stop("No file matching '", pattern, "' in ", path)
  files[which.max(file.mtime(files))]
}

dta_file <- pick_latest("^wb_1000bin_append_.*\\.dta$")
csv_file <- pick_latest("^wb_1000bin_append_.*\\.csv$")

message("Stata output : ", basename(dta_file))
message("R output     : ", basename(csv_file))

# -------------------------------------------------------------------------
# 1. Load both files
# -------------------------------------------------------------------------

stata <- as.data.table(haven::read_dta(dta_file))
r_out <- fread(csv_file)

message("\nRow counts  —  Stata: ", nrow(stata), "  |  R: ", nrow(r_out))

# -------------------------------------------------------------------------
# 2. Harmonise and sort by key variables
# -------------------------------------------------------------------------

key_cols <- c("country_code", "surveyid_year", "reporting_level", "bin")

# Strip haven attributes so waldo only reports data differences
stata <- haven::zap_formats(haven::zap_labels(stata))

# Coerce join keys to consistent types
for (col in c("country_code", "reporting_level")) {
  set(stata, j = col, value = trimws(as.character(stata[[col]])))
  set(r_out,  j = col, value = trimws(as.character(r_out[[col]])))
}
for (col in c("surveyid_year", "bin")) {
  set(stata, j = col, value = as.integer(stata[[col]]))
  set(r_out,  j = col, value = as.integer(r_out[[col]]))
}

setkeyv(stata, key_cols)
setkeyv(r_out,  key_cols)

# -------------------------------------------------------------------------
# 3. Compare
# -------------------------------------------------------------------------

waldo::compare(stata, r_out, tolerance = 1e-13)
# Only differences in the labels for stata.