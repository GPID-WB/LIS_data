version 16.1

cap program drop lorenz_table
cap program drop _lorenz_table_new_bins
cap mata: mata drop __lorenz_table_new_bins()

program define lorenz_table, rclass
    version 16.1

    syntax varname(numeric) [if] [in], Wvar(varname) Reporting(varname) ///
        [NQ(integer 100) Tolerance(real 1e-6)]

    marksample touse, novarlist

    capture confirm numeric variable `wvar'
    if (_rc) {
        di as err "wvar() must be a numeric variable"
        exit 109
    }

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
    keep `varlist' `wvar' `reporting'
    quietly drop if missing(`varlist') | missing(`wvar')

    quietly count
    if (r(N) == 0) {
        di as err "no nonmissing observations remain after filtering"
        exit 2000
    }

    quietly count if `wvar' < 0
    if (r(N) > 0) {
        di as err "wvar() must be nonnegative"
        exit 459
    }

    tempvar report_id wt_welfare tot_pop tot_wlf
    tempfile national_copy

    egen long `report_id' = group(`reporting')
    quietly summarize `report_id', meanonly
    local no_dl = r(max)
    drop `report_id'

    local report_type : type `reporting'
    if ("`report_type'" != "strL") {
        if (substr("`report_type'", 1, 3) == "str") {
            local report_len = real(substr("`report_type'", 4, .))
            if (`report_len' < 8) {
                recast str8 `reporting'
            }
        }
    }

    if (`no_dl' > 1) {
        preserve
            replace `reporting' = "national"
            save `national_copy'
        restore
        append using `national_copy'
    }

    _lorenz_table_new_bins `varlist', wvar(`wvar') nbins(`nq') tolerance(`tolerance') reporting(`reporting')

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

program define _lorenz_table_new_bins, rclass
    version 16.1

    syntax varname(numeric) [if] [in], Wvar(varname) ///
        [ID(varname) NBINS(integer 100) Tolerance(real 1e-6) Reporting(varname)]

    marksample touse, novarlist

    capture confirm numeric variable `wvar'
    if (_rc) {
        di as err "wvar() must be a numeric variable"
        exit 109
    }

    if ("`id'" != "") {
        capture confirm numeric variable `id'
        if (_rc) {
            di as err "id() must be a numeric variable"
            exit 109
        }
    }

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

    local keepvars `varlist' `wvar'
    if ("`id'" != "") {
        local keepvars `keepvars' `id'
    }
    if ("`reporting'" != "") {
        local keepvars `keepvars' `reporting'
    }
    keep `keepvars'

    quietly drop if missing(`varlist') | missing(`wvar')

    quietly count
    if (r(N) == 0) {
        di as err "no nonmissing observations remain after filtering"
        exit 2000
    }

    quietly count if `wvar' < 0
    if (r(N) > 0) {
        di as err "wvar() must be nonnegative"
        exit 459
    }

    generate double `welfare_var' = `varlist'
    generate double `weight_var' = `wvar'

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

    mata: __lorenz_table_new_bins("`id_var'", "`welfare_var'", "`weight_var'", "`grp_var'", `nbins', `tolerance')

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

mata:
void __lorenz_table_new_bins(
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
    real scalar last_id, last_welfare, last_remaining

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
        last_id = .
        last_welfare = .
        last_remaining = 0

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

                if (out_n >= rows(out)) {
                    out = out \ J(max((n, nbins)), 5, .)
                }
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

            last_id = id[i]
            last_welfare = welfare[i]
            last_remaining = remaining
        }

        if (curbin > nbins & last_remaining > 0) {
            if (out_n >= rows(out)) {
                out = out \ J(max((n, nbins)), 5, .)
            }
            out_n = out_n + 1
            out[out_n, 1] = last_id
            out[out_n, 2] = grp[stop]
            out[out_n, 3] = nbins
            out[out_n, 4] = last_remaining
            out[out_n, 5] = last_welfare
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