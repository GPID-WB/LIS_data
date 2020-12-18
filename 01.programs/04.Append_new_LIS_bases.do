/*===========================================================================
Project:     Append new LIS dbs + those that have changed to be shared with Minh
Creation:    Jan 2020
Modified:	 Dec 18 2020
Author:      Martha Viveros
Institution: World Bank Group - Povcalnet Team
============================================================================*/
drop _all

* Create paths
global input "C:\Users\wb463998\OneDrive - WBG\GIT\LIS_data\02.data"
global output "P:\01.PovcalNet\03.QA\06.LIS\04.Share_with_GP"
global vintage "P:\01.PovcalNet\03.QA\06.LIS\03.Vintage_control"

/*==============================================================================
                      I -  Define years per country
==============================================================================*/

* Call dta of new bases + those that changed
 use "${input}/comparison_results.dta", clear
 
* Keep survyes that Minh needs: new ones + those that have changed (diff Gini from last version)  
 keep if gn !=1  
 
* Clean survey versions (duplicate years with wrong/outdated acronym) 
 drop if country_code=="AUS" & year==1989 & survey_acronym=="SIH-LIS"
 drop if country_code=="ISR" & inrange(year,1979,1992) & survey_acronym=="IHDS-LIS"
 drop if country_code=="USA" & inrange(year,2002,2003) & survey_acronym=="CPS-LIS"
 drop if year==.
 
* Local with survey list
 egen concat = concat(country_code surveyid_year)
 levelsof concat, local(surveys)
 local surveys2 "`surveys' CAN2012 CAN2014 CAN2015 CAN2016" 
 drop _all
 
* Temp database
tempfile LIS
save `LIS', empty
/*==============================================================================
                     II -  Load LIS bases, modify and append
==============================================================================*/
foreach s of local surveys2 {
	
	local c = substr("`s'",1,3)   // country ISO
	local y = substr("`s'",4,.)   // year
	display in red " *** `c' - `y' ***"
	
	* Load most recent LIS surveys
	cap pcn load,  countries(`c') year(`y') maindir(${vintage}) clear
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

/*==============================================================================
                    III -  Close tempfile and save
==============================================================================*/	
use `LIS', clear
keep code year bins lcu_pc lcu_pc min_lcu_pc max_lcu_pc popw share
sort year bins

* Save appended bins data
save "${output}\LIS_bins_Dec_18_2020.dta", replace

* End of File
