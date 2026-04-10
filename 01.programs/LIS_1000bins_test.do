/*===========================================================================
Project:     Weighted Lorenz bins for LIS data
Created:     Apr 08 2026
Author:      GitHub Copilot (Diana Garcia testing and edits)
Purpose:     Stata implementation of the R functions lorenz_table() and
             new_bins() from 01.LIS_1000bins.R

Usage:

    do "01.programs/LIS_1000bins.do"

    * Dataset in memory must contain welfare, weight, reporting_level
    lorenz_table welfare, weight(weight) reporting(reporting_level) nq(1000)

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


cd "C://WBG//Git repos//Packages//GPID//PIP//LIS_data//01.programs//SampleData//"

version 16.1

cap program drop new_bins
program define new_bins, rclass
    version 16.1

    syntax varname(numeric) [if] [in], Weight(varname) ///
        [ID(varname) NBINS(integer 100) Tolerance(real 1e-6) Reporting(varname)]

    marksample touse, novarlist

    if (`nbins' <= 0) {
        di as err "nbins() must be a positive integer"
        exit 198
    }

    if (`tolerance' < 0) {
        di as err "tolerance() must be nonnegative"
        exit 198
    }

    tempvar welfare_var weight_var id_var grp_var
    tempfile group_map

    quietly keep if `touse'

    local keepvars `varlist' `weight'
    if ("`id'" != "") {
        local keepvars `keepvars' `id'
    }
    if ("`reporting'" != "") {
        local keepvars `keepvars' `reporting'
    }
    keep `keepvars'

    quietly drop if missing(`varlist') | missing(`weight')

    quietly count
    if (r(N) == 0) {
        di as err "no nonmissing observations remain after filtering"
        exit 2000
    }

    quietly count if `weight' < 0
    if (r(N) > 0) {
        di as err "weight() must be nonnegative"
        exit 459
    }

    generate double `welfare_var' = `varlist'
    generate double `weight_var' = `weight'

    if ("`id'" == "") {
        generate double `id_var' = _n
    }
    else {
        generate double `id_var' = `id'
    }

    if ("`reporting'" == "") {
        generate long `grp_var' = 1
    }
    else {
        egen long `grp_var' = group(`reporting')
        preserve
            keep `grp_var' `reporting'
            duplicates drop
            save `group_map'
        restore
    }

    sort `grp_var' `welfare_var' `id_var', stable

    mata: __lis_new_bins("`id_var'", "`welfare_var'", "`weight_var'", "`grp_var'", `nbins', `tolerance')

    if ("`reporting'" != "") {
        merge m:1 `grp_var' using `group_map', nogen assert(match)
        order `reporting' id bin weight welfare
        drop `grp_var'
        sort `reporting' bin welfare id, stable
    }
    else {
        drop `grp_var'
        order id bin weight welfare
        sort bin welfare id, stable
    }

    compress

    return scalar N = _N
    return scalar nbins = `nbins'
end


cap program drop lorenz_table
program define lorenz_table, rclass
    version 16.1

    syntax varname(numeric) [if] [in], weight(varname) reporting(varname) ///
        [nq(integer 100) tolerance(real 1e-6)]

    marksample touse, novarlist

    capture confirm string variable `reporting'
    if (_rc) {
        di as err "reporting() must be a string variable"
        exit 109
    }

    if (`nq' <= 0) {
        di as err "nq() must be a positive integer"
        exit 198
    }

    if (`tolerance' < 0) {
        di as err "tolerance() must be nonnegative"
        exit 198
    }

    quietly keep if `touse'
    keep `varlist' `weight' `reporting'
    quietly drop if missing(`varlist') | missing(`weight')

    quietly count
    if (r(N) == 0) {
        di as err "no nonmissing observations remain after filtering"
        exit 2000
    }

    quietly count if `weight' < 0
    if (r(N) > 0) {
        di as err "weight() must be nonnegative"
        exit 459
    }

    tempvar report_id wt_welfare tot_pop tot_wlf
    tempfile national_copy

    egen long `report_id' = group(`reporting')
    quietly summarize `report_id', meanonly
    local no_dl = r(max)
    drop `report_id'

    local report_type : type `reporting'
    if ("`report_type'" != "strL" & substr("`report_type'", 1, 3) == "str") {
        local report_len = real(substr("`report_type'", 4, .))
        if (`report_len' < 8) {
            recast str8 `reporting'
        }
    }

    if (`no_dl' > 1) {
        preserve
            replace `reporting' = "national"
            save `national_copy'
        restore
        append using `national_copy'
    }

    new_bins `varlist', weight(`weight') nbins(`nq') tolerance(`tolerance') reporting(`reporting')

    generate double `wt_welfare' = welfare * weight

    bysort `reporting': egen double `tot_pop' = total(weight)
    bysort `reporting': egen double `tot_wlf' = total(`wt_welfare')

    generate double pop_share = weight / `tot_pop'
    generate double welfare_share = `wt_welfare' / `tot_wlf'

    collapse (sum) pop_share welfare_share pop=weight wt_welfare=`wt_welfare' ///
        (max) quantile=welfare, by(`reporting' bin)

    generate double avg_welfare = wt_welfare / pop
    drop wt_welfare

    order `reporting' bin avg_welfare pop_share welfare_share quantile pop
    sort `reporting' bin, stable
    compress

    return scalar reporting_levels = `no_dl'
    return scalar nq = `nq'
    return scalar N = _N
end


cap mata: mata drop __lis_new_bins()
mata:
void __lis_new_bins(
    string scalar idvar,
    string scalar welfarevar,
    string scalar weightvar,
    string scalar grpvar,
    real scalar nbins,
    real scalar tolerance)
{
    real matrix X, panel, out
    real colvector id, welfare, weight, grp
    real scalar n, groups, maxout, out_n
    real scalar g, start, stop, i
    real scalar totalweight, binsize, curbin, curweight
    real scalar remaining, room, take

    X = st_data(., (idvar, welfarevar, weightvar, grpvar))
    n = rows(X)

    if (n == 0) {
        stata("drop _all")
        st_addvar("double", "id")
        st_addvar("long", grpvar)
        st_addvar("long", "bin")
        st_addvar("double", "weight")
        st_addvar("double", "welfare")
        return
    }

    id      = X[, 1]
    welfare = X[, 2]
    weight  = X[, 3]
    grp     = X[, 4]

    panel  = panelsetup(grp, 1)
    groups = rows(panel)
    maxout = n + groups * (nbins - 1)
    out    = J(maxout, 5, .)
    out_n  = 0

    for (g = 1; g <= groups; g++) {
        start = panel[g, 1]
        stop  = panel[g, 2]

        totalweight = sum(weight[|start \ stop|])
        if (totalweight <= 0) {
            continue
        }

        binsize   = totalweight / nbins
        curbin    = 1
        curweight = 0

        for (i = start; i <= stop; i++) {
            remaining = weight[i]

            if (remaining <= 0) {
                continue
            }

            while (remaining > 0 & curbin <= nbins) {
                room = binsize - curweight

                if (abs(room) < tolerance) {
                    curbin = curbin + 1
                    curweight = 0
                    continue
                }

                take = min((remaining, room))

                out_n = out_n + 1
                out[out_n, 1] = id[i]
                out[out_n, 2] = grp[i]
                out[out_n, 3] = curbin
                out[out_n, 4] = take
                out[out_n, 5] = welfare[i]

                remaining = remaining - take
                curweight = curweight + take

                if (curweight >= binsize - tolerance) {
                    curbin = curbin + 1
                    curweight = 0
                }
            }

            if (curbin > nbins & remaining > 0) {
                out_n = out_n + 1
                out[out_n, 1] = id[i]
                out[out_n, 2] = grp[i]
                out[out_n, 3] = nbins
                out[out_n, 4] = remaining
                out[out_n, 5] = welfare[i]
            }
        }
    }

    stata("drop _all")
    st_addobs(out_n)
    st_addvar("double", "id")
    st_addvar("long", grpvar)
    st_addvar("long", "bin")
    st_addvar("double", "weight")
    st_addvar("double", "welfare")

    if (out_n > 0) {
        st_store(., "id", out[|1, 1 \ out_n, 1|])
        st_store(., grpvar, out[|1, 2 \ out_n, 2|])
        st_store(., "bin", out[|1, 3 \ out_n, 3|])
        st_store(., "weight", out[|1, 4 \ out_n, 4|])
        st_store(., "welfare", out[|1, 5 \ out_n, 5|])
    }
}
end


/*===========================================================================
  2: LIS caller
  Mirrors LIS_bins_data() and the survey loop in 01.LIS_1000bins.R.
  Run this section only after the program definitions in Section 1.

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


local surveys "us14 us16 mx14 mx16 it14 it16"
local y = substr("`surveys'", 3,.)
local year "20`y'"
local surveys: subinstr local surveys " " "ih ", all
local surveys "`surveys'h"
display "`surveys'"
pwd

/*---------- 2b. Loop over surveys -----------------------------------------*/

local i = 1

foreach x of local surveys {

	cap {
		use ${`x'}, clear

		// Survey-level metadata
		local country_code  = upper(iso3[1])
		local surveyid_year = year[1]
		local wave          = wave[1]

		// Currency: second "-" segment of label (e.g. "USD-USD-A" -> "USD")
		// mirrors R: tstrsplit(..., "-", keep=1:2)[[2]]
		decode currency, gen(curr_str)
		split curr_str, parse(-)
		local currency = curr_str2[1]
		if ("`currency'" == "") local currency = curr_str1[1]
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
		lorenz_table welfare, weight(weight) reporting(reporting_level) nq(1000)

		// Attach survey metadata
		gen str3   country_code  = "`country_code'"
		gen int    surveyid_year = `surveyid_year'
		gen str4   wave          = "`wave'"
		gen str10  currency      = "`currency'"
		gen double min_welfare   = `min_welfare'
		gen double max_welfare   = `max_welfare'

		order reporting_level bin avg_welfare pop_share welfare_share ///
		      quantile pop country_code surveyid_year wave            ///
		      currency min_welfare max_welfare
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

// if `i' > 1 {
// 	use `datasofar', clear
//
// 	local today = c(current_date)
// 	local today: subinstr local today " " "_", all
//
// 	// Save as dta
// 	save "wb_1000bin_append_`today'.dta", replace
//
// 	// Save as CSV (equivalent to readr::write_csv in R):
// 	export delimited using "wb_1000bin_append_`today'.csv", replace
// }
// else {
// 	di as err "No surveys were successfully processed."
// }

// exit
/* End of do-file */

// ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
// Notes:
// 1. lorenz_table and new_bins are defined in Section 1 (program defs + Mata).
// 2. Section 2 mirrors 01.LIS_1000bins.R exactly:
//    - welfare  = dhi / nhhmem  (same as R: dhi/nhhmem)
//    - weight   = hpopwgt * nhhmem  (same as R: hpopwgt*nhhmem)
//    - nq       = 1000
//    - Only welfare >= 0 observations retained.
// Version Control: