/*==================================================
project:       Create 400 bins in each dataset of LIS repository
Author:        R.Andres Castaneda Aguilar and Diana C. Garcia Rojas
E-email:       acastanedaa@worldbank.org
url:           
Dependencies:  The World Bank
----------------------------------------------------
Creation Date:    11 Dec 2019 - 20:53:13
Modification Date: Oct 19 2022  
Do-file version:    01
References:          
Output:             
==================================================*/

/*==================================================
              0: Program set up
==================================================*/
clear all
version 16.1
local dir "SampleData//"
 
//------------To modify
*local silc   "at be bg cz dk ee fi fr de gr hu is ie it lt lu nl no pl ro rs sk si es se ch uk"  // 27 EUSILC countries
*local nosilc "au br ca cl cn co do ge gt in il ci jp ml mx ps pa py pe ru za kr tw us uy vn"     // 26 rest

local silc   "it"
local nosilc "us mx"
/* 
local surveys "us13 us16 de15 de16 il16 il14"
local y = substr("`surveys'", 3,.)
local year "20`y'"
local surveys: subinstr local surveys " " "h ", all
local surveys "`surveys'h"
display "`surveys'"
*/
//------------Do NOT modify

local countries "`silc' `nosilc'"
numlist "1963/2023"
local years = "`r(numlist)'"
foreach year of loca years {
	local y = substr("`year'", 3,.)
	local ys "`ys' `y'"
}

foreach c of local countries {
	foreach y of local ys {
		local surveys "`surveys' `dir'`c'`y'ih"
	}
}

//------ Add sample surveys
// local surveys "us14i us16i us18i it14i it16i it20i mx16i mx14i mx18i"
// local surveys: subinstr local surveys " " "h `dir'", all
// local surveys "`surveys'h"
// local surveys "`dir'`surveys'"

//------- Check path is used
display "`surveys'"

/*==================================================
              1: Program to calculate 400 bins
==================================================*/

cap program drop _nq
discard
program define _nq, rclass

syntax varname [fweight pweight/] ///
                [if/] [in] [, ///
                BY(varlist) ///
                NQ(string)  ///
                nvar(string) ///
                ]

qui {

	// Weigths
	tempvar wgt
	if ("`weight'" == "") {
		gen `wgt' = 1
	}
	else {
		gen `wgt' = `exp'
	}
	
	// calculations
	
	tempvar a b c
	
	sort `varlist' `wgt', stable

	gen `a' = sum(`wgt')           // cummulative sum
	sum `wgt'                      // total number of people
	gen double `b' = `a'/`r(sum)'  // cummalitve share of population
	gen double `c' = `b'*`nq'      // rescale share of population by number of bins

	gen long `nvar' = ceil(`c')    // round to ceil integer
	replace `nvar' = `nq' if `nvar' > `nq'  // replace to top of number of bins just in case
	
	gen one = 1
	
	// create table .txt
	
// 	version 15
	noi table `nvar' [`weight' = `wgt'], c(sum one mean `varlist'  min `varlist' max `varlist')  /* 
	 */ left concise format(%16.5f)

// 	version 17
// 	noi table `nvar'  [`weight' = `wgt'], statistic(sum one) ///
// 	statistic(mean `varlist') ///
// 	statistic(min `varlist' ) ///
// 	statistic (max `varlist')  /// 
// 	nformat(%16.5f)

	// create dataset

	collapse (sum) weight=one (mean) welfare=`varlist'  (min) min=`varlist'  (max) max=`varlist' (first) country_code surveyid_year ///
	wave currency [`weight' = `wgt'], by(`nvar')
	
}

end

/*==================================================
        2:  Loop over surveys
==================================================*/

local i = 1

foreach x of local surveys {
	cap {
		use "`x'", clear
		
// 		local iso  = upper(iso3[1])
// 		local year = year[1]
// 		local wave = wave[1]
// 		local currency : label currency `=currency[1]'
		
		local country_code = upper(iso3[1])
		local surveyid_year = year[1]
		local wave = wave[1]
		
		decode currency, gen(curr)
		split curr, parse(-)
		rename currency currency_num
		rename curr2 currency
		local currency = currency[1]
		drop curr curr1 

// 		keep hid  dhi hpopwgt nhhmem
		
		keep hid  dhi hpopwgt nhhmem iso3 year wave currency
		rename iso3 country_code
		rename year surveyid_year 
		
		gen double popw = hpopwgt*nhhmem 
		
		gen double lcu_pc = (dhi/nhhmem) // leave it annual per capita

		drop if (lcu_pc < 0 | lcu_pc >= . | popw >= .)
	}
	if (_rc) continue
	
	noi mata: printf("##1 `country_code' `surveyid_year' `wave'\n")
	noi mata: printf("##2 `currency'\n")
	_nq lcu_pc [pw = popw], nq(400) nvar(nq)
	
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

use `datasofar', clear

save combined_data.dta, replace

exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:


