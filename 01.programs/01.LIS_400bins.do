/*==================================================
project:       Create 400 bins in each dataset of LIS repository
Author:        R.Andres Castaneda Aguilar 
E-email:       acastanedaa@worldbank.org
url:           
Dependencies:  The World Bank
----------------------------------------------------
Creation Date:    11 Dec 2019 - 20:53:13
Modification Date:   
Do-file version:    01
References:          
Output:             
==================================================*/

/*==================================================
              0: Program set up
==================================================*/

local surveys "au04h us16h"  // modify this

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
	
	noi table `nvar'  [`weight' = `wgt'], c(sum one mean `varlist')  /* 
	 */ left concise format(%16.5f)
	
}

end

/*==================================================
        2:  Loop over surveys
==================================================*/


foreach x of local surveys {
	qui {
	use ${`x'}, clear
		local iso  = upper(iso3[1])
		local year = year[1]
		local wave = wave[1]

		noi mata: printf("## `iso' `year' `wave'\n")

		keep hid  dhi hpopwgt nhhmem 
		gen double popw=hpopwgt*nhhmem 
		gen double lcu_pc = (dhi/nhhmem)/12

		drop if (lcu_pc < 0 | lcu_pc >= . | popw >= .)
	}

	* _nq lcu_pc [aw = popw], nq(400) nvar(nq)
	_nq lcu_pc [pw = popw], nq(400) nvar(nq)
}




exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:


