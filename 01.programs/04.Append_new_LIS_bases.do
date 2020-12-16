drop _all
/*==============================================================================
                      I -  Define years per country
==============================================================================*/

* Temp db
tempfile LIS
save   `LIS', empty
local years "2012 2014 2015 2016 2017"
local c "can"

foreach y of local years {
	display in red " *** `c' - `y' ***"
	
	* load
	cap pcn load,  countries(`c') year(`y') lis clear
    if _rc!=0  continue	
	
			
	ren welfare lcu_pc
	ren min min_lcu_pc
	ren max max_lcu_pc
	
	ren weight popw
	qui: sum popw
	local total = r(sum) 
	
	gen share = (popw/`total')*100		
    gen code  = upper("`c'") 
	gen year  = `y'
	gen bins  = _n
	        
	order code year bins lcu_pc min_lcu_pc max_lcu_pc popw share
	
	********************
	*      Append      *
    ********************
	append using `LIS'
    save `LIS', replace 

} // close years
	
use `LIS', clear
sort year bins
exit 

save "P:\02.personal\wb463998\LIS data\LIS data - April 2020\LIS_bins_April_25_2020.dta", replace
