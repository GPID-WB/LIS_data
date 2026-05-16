clear all
set more off

// Change the path below to match your local setup
do "C:/WBG/Git repos/Packages/GPID/PIP/LIS_data/01.programs/lorenz_table_defs.do"
cd "C:/WBG/Git repos/Packages/GPID/PIP/LIS_data/01.programs/SampleData"

use us14ih, clear

// Survey-level metadata
local country_code  = upper(iso3[1])
local surveyid_year = year[1]
local wave          = wave[1]

// Currency: second "-" segment of label (e.g. "USD-USD-A" -> "USD")
decode currency, gen(curr_str)
split curr_str, parse(-)
local currency = strtrim(curr_str2[1])
if ("`currency'" == "") local currency = strtrim(curr_str1[1])
drop curr_str*

// Welfare and weight
keep hid dhi hpopwgt nhhmem
gen double weight  = hpopwgt * nhhmem
gen double welfare = dhi / nhhmem

// Drop negatives and missing
drop if welfare < 0 | missing(welfare) | missing(weight)

// Min/max before binning
quietly summarize welfare, meanonly
local min_welfare = r(min)
local max_welfare = r(max)

// Reporting level is always national for LIS household data
gen str8 reporting_level = "national"

// Compute 1000-bin Lorenz table
lorenz_table welfare, wvar(weight) reporting(reporting_level) nq(1000)

// Attach survey metadata (same types and order as LIS_1000bins.do)
gen str3   country_code  = "`country_code'"
gen int    surveyid_year = `surveyid_year'
gen int    wave          = `wave'
gen str20  currency      = "`currency'"
gen double min_welfare   = `min_welfare'
gen double max_welfare   = `max_welfare'

order reporting_level bin avg_welfare pop_share welfare_share ///
      quantile pop country_code surveyid_year wave            ///
      min_welfare max_welfare currency

list in 1/10
