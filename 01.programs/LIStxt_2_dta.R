# ==================================================
# project:       Convert txt files from LIS to dta
# Author:        Andres Castaneda
# Dependencies:  The World Bank
# ----------------------------------------------------
# Creation Date:    2020-12-16
# Modification Date:
# Script version:    01
# References:
#
#
# Output:             Data frame
# ==================================================

#----------------------------------------------------------
#   Load libraries
#----------------------------------------------------------

library(stringr)
library(purrr)
library(data.table)

#----------------------------------------------------------
#   subfunctions
#----------------------------------------------------------
txt2dta <- function(x, y, id, cr, df) {

  dt <- data.table(orig = df[x:y])
  cnames <- c("nq", "P", "weight", "welfare", "min", "max")

  #--------- Create welfare vectors ---------

  dt[,
     (cnames) := tstrsplit(orig, split = "[ \t]")
  ][,
    c("nq", "orig", "P") := NULL
  ]

  #--------- add id and currency info ---------
  idnames <- c("n", "country_code", "surveyid_year", "wave")
  dt[,
     idor := df[id]
  ][,
    (idnames) := tstrsplit(idor, split = "[ \t]")
  ][,
    c("idor", "n") := NULL]

  crnames <- c("nn", "currency")
  dt[,
     crr := df[cr]
  ][,
    (crnames) := tstrsplit(crr, split = "[\\-]")
  ][,
    c("crr", "nn") := NULL
  ][,
    currency := str_trim(currency)]

  return(dt)
}

#----------------------------------------------------------
#   get data as a single data frame
#----------------------------------------------------------


frames_in_txt <- function(fl) {

  df   <- str_squish(readLines(fl, warn=FALSE))     # read text file and remove spaces
  df   <- str_trim(df)         # remove leading and trail spaces
  ids  <- grep("^##1", df)     # get ID
  crs  <- grep("^##2", df)     # Get currency
  str  <- grep("^1 \\|", df)   # Starting point
  end  <- grep("^400 \\|", df) # ending point

  # rows with info
  ls_rows <-
    list(
        x  = str,
        y  = end,
        id = ids,
        cr = crs
    )

  # list with data frames
  ls_dta <- pmap(ls_rows, txt2dta, df = df)

  dt <- rbindlist(ls_dta,
                use.names = TRUE,
                fill = TRUE)
  return(dt)
}


find_txt <- function(path, pattern) {
  fls <- fs::dir_ls(path    = path,
             type    = "file",
             recurse = TRUE,
             regexp  = pattern)
  fls <- as.character(fls)
  return(fls)
}


#----------------------------------------------------------
#
#----------------------------------------------------------


#
# fl <- "c:/Users/wb384996/OneDrive - WBG/WorldBank/DECDG/PovcalNet Team/LIS_data/00.LIS_output/LISSY_Dec2020_9.txt"
#
# fl <- 'C:/Users/wb384996/OneDrive - WBG/WorldBank/DECDG/PovcalNet Team/LIS_data/00.LIS_output/LISSY_Dec2020_2.txt'
