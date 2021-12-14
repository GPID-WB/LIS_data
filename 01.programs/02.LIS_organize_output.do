/*==================================================
project:       Organize output from LISSY
Author:        R.Andres Castaneda Aguilar
E-email:       acastanedaa@worldbank.org
url:
Dependencies:  The World Bank
----------------------------------------------------
Creation Date:    11 Dec 2019 - 20:55:47
Modification Date:
Do-file version:    01
References:
Output:
==================================================*/

/*==================================================
0: Program set up
==================================================*/

version 16

//------------ Make sure rcall is installed
cap which rcall
if (_rc) {
	cap which github
	if (_rc) {
		net install github, from("https://haghish.github.io/github/")
	}
	github install haghish/rcall, stable
}


//------------modify this
global update_surveynames = 1   // 1 to update survey names.
global replace            = 0   // 1 to replace data in memory even if it has not changed
global p_drive_output_dir = 0   // 1 to use default Vintage_control folder
//---------------------------



//------------Add personal drive cloned from github repo

if (lower("`c(username)'") == "wb562356") {
	local dir "c:/Users/wb562356/OneDrive - WBG/Documents/MPI for LIS countries"
}
else if (lower("`c(username)'") == "wb463998") {
	local dir "C:/Users/wb463998/OneDrive - WBG/GIT/LIS_data"
}
else if (lower("`c(username)'") == "wb384996") {
	local dir "c:/Users/wb384996/OneDrive - WBG/WorldBank/DECDG/PovcalNet Team/LIS_data"
}
else { // if network drive
	noi disp in r "You must provide your working directory"
	exit
}
cd "`dir'"


//------------ Update survey names
if (${update_surveynames} == 1) {
	* make sure file is closed
	import excel using "02.data/_aux/LIS datasets.xlsx", sheet(LIS_survname) /*
	*/  firstrow case(lower) allstring clear
	missings dropvars, force
	sort country_code surveyid_year
	
	save "02.data/_aux/LIS_survname.dta", replace
}



local path    = "`dir'/00.LIS_output"
* local pattern = "LISSY_Dec2020_3\\.txt"  // modify this
local pattern = "LISSY_Dec2020.*txt"  // modify this
//----------------------------------------------------

//------------ crate frames
cap frame create txt // data from txt
cap frame create nms // names 
cap frame create cpi // CPI


//========================================================
//  Get txt data to dta using function in R
//========================================================

drop _all
frame txt {
	rcall vanilla: source("`dir'/01.programs/LIStxt_2_dta.R");  /// Run functions
	fls <- find_txt(path = "`path'", pattern = "`pattern'"); /// get text files paths
	ls_frames <- map(fls, frames_in_txt); /// list of frames in each txt
	all_frames <- rbindlist(ls_frames, use.names = TRUE,fill = TRUE); ///
	st.load(all_frames)
	destring weight welfare min max, replace force
	
	drop if country_code == ""
	
	//------------ Change for WB ISO3 codes
	replace country_code = "SRB" if country_code == "RSB"
	
	
	//------------check specific cases
	* keep if country_code == "DEU" & surveyid_year == "2004"  // to delete
	
	save "02.data/LIStxt_2_dta_temp.dta", replace
}

//========================================================
//  Load all necessary data
//========================================================

//------------Survey names
frame nms {
	use "02.data/_aux/LIS_survname.dta", clear
	sort country_code surveyid_year
} 


//------------ CPIs
frame cpi: {
	* use "p:/01.PovcalNet/03.QA/08.DLW/Support/Support_2005_CPI/Support_2005_CPI_v04_M/Data/Stata/Final_CPI_PPP_to_be_used.dta", clear
	
	local cpidir "//wbgfscifs01/GPWG-GMD/Datalib/GMD-DLW/Support/Support_2005_CPI/"
	local cpifolders: dir "`cpidir'" dirs "*_M", respectcase
	local cpivers ""
	foreach cpifolder of local cpifolders {
		if regexm("`cpifolder'", "([0-9]+)(_M$)") local ver = regexs(1)
		local cpivers "`cpivers'`ver' "
	}
	local cpivers = trim("`cpivers'")
	local cpivers:  subinstr local cpivers " " ", ", all
	local maxver = max(`cpivers')
	
	if length("`maxver'") == 1 {
		local maxver "0`maxver'"
	}
	local cpifile "`cpidir'Support_2005_CPI_v`maxver'_M/Data/Stata/Final_CPI_PPP_to_be_used.dta"
	use "`cpifile'", clear
	
	
	
	
	rename (code survname) (country_code  survey_acronym)
	tostring year, gen(surveyid_year)
	sort country_code surveyid_year  datalevel survey_acronym 
}


//------------create just inventory
frame copy txt inv, replace
frame inv {
	contract country_code surveyid_year currency
	drop _freq
	sort country_code surveyid_year
	frlink 1:1 country_code surveyid_year, frame(nms)
	frget survey_acronym, from(nms)
	drop if country_code == ""
}


//========================================================
// Loop over new inventory
//========================================================

*##s
frame change default
if (${p_drive_output_dir} == 1) {
	local outputdit "p:/01.PovcalNet/01.Vintage_control"
}
else {
	local outputdit "P:/01.PovcalNet/03.QA/06.LIS/03.Vintage_control"
}


frame inv {
	local n = _N
	qui ds
	local invvars = "`r(varlist)'"
}


cap frame drop res 
frame create res str20 (country_code surveyid_year survey_acronym) ///
str60 note

local i = 0
* local n = `i'  // to delete
noi _dots 0, title(Saving txt from LIS to PCN-QA folder) reps(`n')
qui while (`i' <= `n') {
	local ++i
	
	//========================================================
	//  Prepare data
	//========================================================
	
	foreach var of local invvars {
		local `var' ""
		local `var' = _frval(inv, `var', `i')
	}
	
	if ("`survey_acronym'" == "") {
		frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
		("No Survey name available")
		noi _dots `i' 1
		continue
	}
	
	
	frame copy txt wrk, replace // working frame 
	frame wrk {
		keep if country_code == "`country_code'" & surveyid_year == "`surveyid_year'"
		local cy_dir = "`country_code'_`surveyid_year'_`survey_acronym'"
		
		char _dta[wave]         "`=wave[1]'"
		char _dta[id]           "`cy_dir'"
		char _dta[author]       "`c(username)'"
		char _dta[survey_name]  "`survey_acronym'"
		char _dta[currency]     "`currency'"
		char _dta[udpatedon]    "`c(current_date)' `c(current_time)'"
		
		local ff = ""
		//------------ Adjust if it is in Euros
		if regexm("`currency'", "[Ee]uro") {
			gen datalevel      = 2
			gen survey_acronym = "`survey_acronym'"
			
			sort country_code surveyid_year datalevel survey_acronym 
			cap frlink m:1 country_code surveyid_year  datalevel survey_acronym , frame(cpi)
			
			if (_rc) {
				frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
				("could not link to CPI")
				noi _dots `i' 1
				continue
			}
			
			
			if (r(unmatched) != 0) {
				local ff = r(unmatched)
				gen cur_adj = 1
			}
			else {
				frget cur_adj, from(cpi)
				char _dta[currency]     "LCU"  // update with master info
			}
			
			foreach x in welfare min max {
				replace `x' = (`x' / cur_adj)
			}
			
		} // end Euro condition 
		
		keep welfare weight min max
		
		if ("`ff'" != "") {
			local msg = "-`ff' obs did not match with CPI data"
		}
		else {
			local msg = ""
			local ff = 0
		}
		
		//========================================================
		//  Save data
		//========================================================
		
		//------------ Directories
		cap mkdir "`outputdit'"
		cap mkdir "`outputdit'/`country_code'"
		cap mkdir "`outputdit'/`country_code'/`cy_dir'"
		
		cap datasignature confirm using /*
		*/ "`outputdit'/`country_code'/`cy_dir'/`cy_dir'", strict
		local rcds = _rc
		
		// find versions available
		local vers: dir "`outputdit'/`country_code'/`cy_dir'" dirs "*", respectcase
		
		if (`"`vers'"' == `""') {  // if no folder available
			local av = "01"  // alternative version	
		} 
		
		else {  // if at least one folder is available
			local avs 0
			
			foreach ver of local vers {
				if regexm("`ver'", "_[Vv]([0-9]+)_A_GMD$") local v = regexs(1)
				local avs = "`avs', `v'"
			}
			
			if inlist(`rcds',9,601) {  // data has changed
				if (${replace} != 1) local av = max(`avs') + 1 // Add new version
				else                 local av = max(`avs')     // replace current version
			}
			else {              // data has not changed
			
				if (${replace} != 1) {
					frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
					("skipped`msg'")
					noi _dots `i' -1 + `ff'
					continue
				}	
				local av = max(`avs')
			} // end of data has not changed
			
			// final version number
			if (length("`av'") == 1) {
				local av = "0" + "`av'"
			}
			l
		} // end of creating new version of files
		
		
		datasignature set, reset saving("`outputdit'/`country_code'/`cy_dir'/`cy_dir'", replace)
		
		//------------Create versions folders
		local svid "`cy_dir'_v01_M_v`av'_A_GMD"
		cap mkdir "`outputdit'/`country_code'/`cy_dir'/`svid'"
		
		local ddir "`outputdit'/`country_code'/`cy_dir'/`svid'/data" // data dir
		cap mkdir "`ddir'"
			
		if (inlist(`rcds',9,601)  & ${replace} == 1 ) {  // data has changed
			frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
			("replaced`msg'")
		}
		else {
			frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
			("saved`msg'")
		}
	
		save "`ddir'/`svid'_BIN.dta", replace
		
		noi _dots `i' 0 + `ff'	
		
	} // end of wrk frame 
	
} // end of while loop 

frame change res
save "02.data/create_dta_status.dta", replace

*##e

exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:

frame change res

local country_code  = "AUT"
local surveyid_year = "2004"
local survey_acronym = "SILC-LIS"


frame copy txt wrk, replace
frame change wrk
keep if country_code == "`country_code'" & surveyid_year == "`surveyid_year'"

gen datalevel      = 2
gen survey_acronym = "`survey_acronym'"


frlink m:1 country_code surveyid_year  datalevel survey_acronym , frame(cpi)


local country_code  = "AUT"
local surveyid_year = "2004"
local survey_acronym = "SILC-LIS"

count if country_code == "`country_code'" & ///
surveyid_year == "`surveyid_year'" & survey_acronym == "`survey_acronym'"

