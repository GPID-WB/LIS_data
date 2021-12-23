/*===========================================================================
Project:     Append new LIS dbs + those that have changed to be shared with Minh
Creation:    Jan 2020
Modified:	 Dec 18 2020
Author:      Martha Viveros
Institution: World Bank Group - Povcalnet Team
============================================================================*/
drop _all
cwf default

* Create paths
//------------main directory with LIS data
global maindir "//wbntpcifs/povcalnet/01.PovcalNet/03.QA/06.LIS/03.Vintage_control/"

//------------Personal directory
if (lower("`c(username)'") == "wb562356") {
	global input "c:/Users/wb562356/OneDrive - WBG/Documents/MPI for LIS countries/02.data"
}
else if (lower("`c(username)'") == "wb463998") {
	global input "C:\Users\wb463998\OneDrive - WBG\GIT\LIS_data\02.data"
}
else if (lower("`c(username)'") == "wb384996") {
	global input "c:/Users/wb384996/OneDrive - WBG/WorldBank/DECDG/PovcalNet Team/LIS_data/02.data"
}

global output "//wbntpcifs/povcalnet/01.PovcalNet/03.QA/06.LIS/04.Share_with_GP"
global vintage "//wbntpcifs/povcalnet/01.PovcalNet/03.QA/06.LIS/03.Vintage_control/"

/*==============================================================================
I -  Define years per country
==============================================================================*/

* Call dta of new bases + those that changed
use "${input}/comparison_results.dta", clear

* Keep survyes that Minh needs: new ones + those that have changed (diff Gini from last version)  
keep if gn !=1  
drop if year==.

* Local with survey list
egen concat = concat(country_code surveyid_year)
levelsof concat, local(surveys)
local surveys "`surveys'" 
drop _all

* Temp database
tempfile LIS
save `LIS', empty
/*==============================================================================
II -  Load LIS bases, modify and append
==============================================================================*/
cap frame drop appres 
frame create appres  str20 (country_code  surveyid_year) str25 note

foreach s of local surveys {
	
	local c = substr("`s'",1,3)   // country ISO
	local y = substr("`s'",4,.)   // year
	display in y " *** `c' - `y' ***"
	
	* Load most recent LIS surveys
	cap pcn load,  countries(`c') year(`y') maindir(${vintage}) clear
	if (_rc) {
		frame post appres ("`c'") ("`y'") ///
		("Error in PCN")
		noi _dots `i' 2
		continue
	}
	
	cap {
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
		
		* APPEND:
		append using `LIS'
		save `LIS', replace 
	}
	if (_rc) {
		frame post appres ("`c'") ("`y'") ///
		("Error formatting data")
		noi _dots `i' 2
		continue
	}
		frame post appres ("`c'") ("`y'") ///
		("appended")
	
} // close years

/*==============================================================================
III -  Close tempfile and save
==============================================================================*/	
use `LIS', clear
sort code year bins

* Save appended bins data

local loc_srf = clock("`c(current_date)'`c(current_time)'", "DMYhms")
local loc_hrf: disp %tcCCYY_Mon_DD `loc_srf'
local loc_hrf: subinstr local  loc_hrf " " "_", all


save "${output}\LIS_bins_`loc_hrf'.dta", replace

frame appres: list country_code surveyid_year note if note != "appended"

* End of File



