# ==================================================
# project:       Get inventory of LIS data
# Author:        Andres Castaneda
# Dependencies:  The World Bank
# ----------------------------------------------------
# Creation Date:    2020-12-16
# Modification Date:
# Script version:    01
# References:
#
#
# Output:             Data frame to be loaded in Stata
# ==================================================

#----------------------------------------------------------
#   Load libraries
#----------------------------------------------------------

library("data.table")

#----------------------------------------------------------
#   Set up
#----------------------------------------------------------

pt <- "//wbntpcifs/povcalnet/01.PovcalNet/03.QA/06.LIS/03.Vintage_control/"
fls <-
  fs::dir_ls(pt,
             recurse = TRUE,
             type = "file",
             regexp = ".*BIN\\.dta$")

fls <- as.character(fls)

#--------- create data frame ---------
dt <- data.table(orig = fls)

# create variables for merging
cnames <-
  c(
    "country_code",
    "surveyid_year",
    "survey_acronym",
    "vermast",
    "M",
    "veralt",
    "A",
    "collection",
    "module"
  )

dt[,
   id := gsub("(.*[Dd]ata/)(.*)(\\.dta)", "\\2", orig)
   ][,
     (cnames) := tstrsplit(id, "_", fixed = TRUE)
     ][,
       c("M", "A", "collection", "module") := NULL
       ]


