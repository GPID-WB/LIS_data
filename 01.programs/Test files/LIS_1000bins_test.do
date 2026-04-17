/*===========================================================================
Project:     Weighted Lorenz bins for LIS data
Created:     Apr 08 2026
Author:      GitHub Copilot (Diana Garcia testing and edits)
Purpose:     Stata implementation of the R functions lorenz_table() and
             new_bins() from 01.LIS_1000bins.R

Usage:

    do "01.programs/LIS_1000bins_test.do"

    * Dataset in memory must contain welfare, weight, reporting_level
    lorenz_table welfare, wvar(weight) reporting(reporting_level) nq(1000)

Result:
    The dataset in memory is replaced with a Lorenz-style table containing:
    reporting_level, bin, avg_welfare, pop_share, welfare_share, quantile, pop

Notes:
    - new_bins splits observations across bins when a weight spans multiple bins.
    - lorenz_table adds a synthetic national reporting level when the input
      contains more than one reporting level.
    - reporting() must be a string variable because the synthetic level is
      stored as the literal value "national".
===========================================================================*/
clear all
set more off

do "C:/WBG/Git repos/Packages/GPID/PIP/LIS_data/01.programs/lorenz_table_defs.do"

cd "C://WBG//Git repos//Packages//GPID//PIP//LIS_data//01.programs//SampleData//"

/*===========================================================================
  2: LIS caller
  Mirrors LIS_bins_data() and the survey loop in 01.LIS_1000bins.R.
  Programs are loaded via lorenz_table_defs.do above.

  Output columns added beyond lorenz_table():
    country_code   - ISO 3-letter code (uppercase)
    surveyid_year  - survey reference year
    wave           - LIS wave number
    currency       - ISO currency code (2nd "-" segment of LIS label)
    min_welfare    - min per-capita welfare after dropping negatives
    max_welfare    - max per-capita welfare
===========================================================================*/

/*---------- 2a. Survey list (modify as needed) ----------------------------*/

//-- Full run
/* local silc   "at be bg cz dk ee fi fr de gr hu is ie it lt lu nl no pl ro rs sk si es se ch uk"
local nosilc "au br ca cl cn co do ge gt in il ci jp ml mx ps pa py pe ru za kr tw us uy vn" */

//-- Testing only: uncomment and override the lists above:
// local silc   ""
// local nosilc "us in"

/* local countries "`silc' `nosilc'" */


// Build two-digit year suffixes "63" "64" .. "09" "10" .. "24" (zero-padded)
/* numlist "1963/2024"
local yrs_full `r(numlist)'
local ys ""
foreach year of local yrs_full {
	local y = substr("`year'", 3, 2)
	local ys "`ys' `y'"
}

local surveys ""
foreach c of local countries {
	foreach y of local ys {
		local surveys "`surveys' `c'`y'h"
	}
} */


local surveys "us14ih us16ih mx14ih mx16ih it14ih it16ih"
// local y = substr("`surveys'", 3,.)
// local year "20`y'"
// local surveys: subinstr local surveys " " "ih", all
// local surveys "`surveys'h"
display "`surveys'"
pwd

/*---------- 2b. Loop over surveys -----------------------------------------*/

local i = 1

foreach x of local surveys {

	cap {
		use "`x'", clear

		// Survey-level metadata
		local country_code  = upper(iso3[1])
		local surveyid_year = year[1]
		local wave          = wave[1]

		// Currency: second "-" segment of label (e.g. "USD-USD-A" -> "USD")
		// mirrors R: tstrsplit(..., "-", keep=1:2)[[2]]
		decode currency, gen(curr_str)
		split curr_str, parse(-)
		local currency = strtrim(curr_str2[1])
		if ("`currency'" == "") local currency = strtrim(curr_str1[1])
		drop curr_str*

		// Welfare and weight (matching R: welfare=dhi/nhhmem, weight=hpopwgt*nhhmem)
		keep hid dhi hpopwgt nhhmem
		gen double weight  = hpopwgt * nhhmem
		gen double welfare = dhi / nhhmem

		// Drop negatives and missing (R: fsubset(welfare >= 0 & !is.na(...)))
		drop if welfare < 0 | missing(welfare) | missing(weight)

		// Min/max before binning (added as metadata columns after lorenz_table)
		quietly sum welfare, meanonly
		local min_welfare = r(min)
		local max_welfare = r(max)

		// Reporting level is always national for LIS household data
		gen str8 reporting_level = "national"

		// Compute 1000-bin Lorenz table (replaces dataset in memory)
		lorenz_table welfare, wvar(weight) reporting(reporting_level) nq(1000)

		// Attach survey metadata
		gen str3   country_code  = "`country_code'"
		gen int    surveyid_year = `surveyid_year'
		gen int    wave          = `wave'
		gen str20  currency      = "`currency'"
		gen double min_welfare   = `min_welfare'
		gen double max_welfare   = `max_welfare'

		order reporting_level bin avg_welfare pop_share welfare_share ///
		      quantile pop country_code surveyid_year wave            ///
		      min_welfare max_welfare currency
	}
	if (_rc) {
		noi di as txt "  Skipping `x' (rc=`_rc')"
		continue
	}

	noi mata: printf("## `country_code' `surveyid_year' wave `wave'\n")

	if `i' == 1 {
		tempfile datasofar
		save `datasofar'
	}
	else {
		append using "`datasofar'"
		save `datasofar', replace
	}

	local ++i
}


/*---------- 2c. Save result -----------------------------------------------*/

if `i' > 1 {
	use `datasofar', clear

	local today = c(current_date)
	local today: subinstr local today " " "_", all

	// Save as dta
	save "wb_1000bin_append_`today'.dta", replace

	// Save as CSV (equivalent to readr::write_csv in R):
// 	export delimited using "wb_1000bin_append_`today'.csv", replace
}
else {
	di as err "No surveys were successfully processed."
}

exit
/* End of do-file */

// ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
// Notes:
// 1. lorenz_table and _lorenz_table_new_bins are defined in lorenz_table_defs.do.
//    The wvar() option is used instead of weight() to avoid Stata's reserved
//    option name conflict in program syntax declarations.
// 2. The LIS caller mirrors 01.LIS_1000bins.R exactly:
//    - welfare  = dhi / nhhmem  (same as R: dhi/nhhmem)
//    - weight   = hpopwgt * nhhmem  (same as R: hpopwgt*nhhmem)
//    - nq       = 1000
//    - Only welfare >= 0 observations retained.
// Version Control: