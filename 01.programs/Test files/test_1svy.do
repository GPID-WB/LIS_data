clear all
set more off

do "C:/WBG/Git repos/Packages/GPID/PIP/LIS_data/01.programs/lorenz_table_defs.do"
cd "C:/WBG/Git repos/Packages/GPID/PIP/LIS_data/01.programs/SampleData"

use us14ih, clear

local country_code  = upper(iso3[1])
local surveyid_year = year[1]
local wave          = wave[1]

decode currency, gen(curr_str)
split curr_str, parse(-)
local currency = curr_str2[1]
if ("`currency'" == "") local currency = curr_str1[1]
drop curr_str*

keep hid dhi hpopwgt nhhmem
gen double weight  = hpopwgt * nhhmem
gen double welfare = dhi / nhhmem

drop if welfare < 0 | missing(welfare) | missing(weight)

quietly summarize welfare, meanonly
local min_welfare = r(min)
local max_welfare = r(max)

gen str8 reporting_level = "national"

lorenz_table welfare, wvar(weight) reporting(reporting_level) nq(1000)

gen str3   country_code  = "`country_code'"
gen int    surveyid_year = `surveyid_year'
gen str4   wave          = "`wave'"
gen str10  currency      = "`currency'"
gen double min_welfare   = `min_welfare'
gen double max_welfare   = `max_welfare'

order reporting_level bin avg_welfare pop_share welfare_share ///
      quantile pop country_code surveyid_year wave            ///
      currency min_welfare max_welfare

list in 1/10
