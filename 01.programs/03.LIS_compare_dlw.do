/*==================================================
project:       Compare data in povcalnet repo with data in datlibweb
Author:        R.Andres Castaneda 
E-email:       acastanedaa@worldbank.org
url:           
Dependencies:  The World Bank
----------------------------------------------------
Creation Date:    15 Dec 2020 - 12:09:13
Modification Date:   
Do-file version:    01
References:          
Output:             
==================================================*/

/*==================================================
0: Program set up
==================================================*/
version 16.1
drop _all
frame change default

//------------create frames
cap frame create dlw
cap frame create repo
cap frame create cpi
cap frame create ctr


//------------main directory with LIS data
global maindir "//wbntpcifs/povcalnet/01.PovcalNet/03.QA/06.LIS/03.Vintage_control/"

//------------Personal directory
if (lower("`c(username)'") == "wb562356") {
	global pdir "c:/Users/wb562356/OneDrive - WBG/Documents/MPI for LIS countries"
}
else if (lower("`c(username)'") == "wb463998") {
	global pdir "C:/Users/wb463998/OneDrive - WBG/GIT/LIS_data"
}
else if (lower("`c(username)'") == "wb384996") {
	global pdir "c:/Users/wb384996/OneDrive - WBG/WorldBank/DECDG/PovcalNet Team/LIS_data"
}

cd "${pdir}"

//------------ Make sure rcall is installed
cap which rcall
if (_rc) {
	cap which github
	if (_rc) {
		net install github, from("https://haghish.github.io/github/")
	}
	github install haghish/rcall, stable
}

cap which fastgini
if (_rc) {
	ssc install fastgini
}

/*=================================================
1: Get repo from Datalibweb
==================================================*/

//------------ Countries inventory
drop _all
frame ctr {
	datalibweb_inventory
	rename countrycode country_code
	sort country_code
}

//------------ LIS inventory
drop _all
frame repo {
	rcall vanilla: source("${pdir}/01.programs/LIS_inventory.R");  ///
	st.load(dt)
}


frame repo {
	gen vermast_int = regexs(1) if regexm(vermast, "[Vv]([0-9]+)")
	gen veralt_int  = regexs(1) if regexm(veralt, "[Vv]([0-9]+)")
	destring vermast_int veralt_int, replace force
	
	tempvar mmast malt
	bysort country_code surveyid_year survey_acronym: egen `mmast' = max(vermast_int)
	keep if `mmast' == vermast_int
	
	bysort country_code surveyid_year survey_acronym: egen `malt'  = max(veralt_int)
	keep if `malt'  == veralt_int
	
	// Link with countries frame
	frlink m:1 country_code, frame(ctr)
	frget countryname region, from(ctr)
	
}

//------------ Cases to be added to DLW
frame repo {	
	destring surveyid_year, gen(year)
	
	local the7 = "AUS|CAN|ISR|JPN|KOR|TWN|USA"
	gen to_keep = .
	replace to_keep = 1 if regexm(country_code, "`the7'")
	replace to_keep = 1 if regexm(survey_acronym, "SILC") & year <= 2002
	replace to_keep = 1 if country_code == "DEU" & year >= 1991
	replace to_keep = 1 if country_code == "GBR" & year <= 2003
	keep if to_keep == 1
}


//------------ CPI DATA


frame cpi: {
/*	local cpidir "//wbgfscifs01/GPWG-GMD/Datalib/GMD-DLW/Support/Support_2005_CPI/"
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
	*/ //MV
	import delimited "https://github.com/PIP-Technical-Team/aux_cpi/raw/main/cpi.csv", clear varn(1) asdouble
	ren cpi_data_level datalevel
	sort code year datalevel survname
}


/*==================================================
2:  Loop over repo data
==================================================*/

*##s
frame change default
frame repo {
	local n = _N
	qui ds
	local dlwvars = "`r(varlist)'"
}


cap frame drop res 
frame create res  str20 (country_code  surveyid_year survey_acronym) ///
double (wfdlw wfpcn wtdlw wtpcn gndlw gnpcn) str25 note

local i = 0
* local n = `i'  // to delete
noi _dots 0, title(comparing LIS in PCN with DLW) reps(`n')
qui while (`i' <= `n') {
	local ++i
	
	// Reset locals
	local wfdlw = .
	local wfpcn = .
	local wtdlw = .
	local wtpcn = .
	
	// read dlw repo one by one.
	foreach var of local dlwvars {
		local `var' ""
		local `var' = _frval(repo, `var', `i')
	}
	
	// option 2
	* frame repo {
		* foreach var of local dlwvars {
			* local `var' = `var'[`i']
		* }
	* }
	
	//========================================================
	//  load PCN data and get mean of welfare and weight
	//========================================================
	
	cap pcn load, countr(`country_code') year(`surveyid_year') ///
	maindir("${maindir}") clear
	
	if (_rc) {
		frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
		(.) (.) (.) (.) (.) (.) ("Error in PCN")
		noi _dots `i' 2
		continue
	}
	
	keep welfare weight
	
	sum welfare, meanonly
	local wfpcn = r(mean)
	
	sum weight, meanonly
	local wtpcn  = r(mean)
	
	fastgini welfare [w=weight]
	local gnpcn =  r(gini)
	
	
	//========================================================
	//  load dlw data base and get the mean of welfare and weight
	//========================================================
	
	frame dlw {
		qui cap datalibweb, country(`country_code') year(`surveyid_year') type(GMD)  ///
		survey(`survey_acronym') module(BIN)
		
		if (_rc == 678) {
			frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
			(.) (.) (.) (.) (.) (.) ("Err:DLW>Access denied")
			noi _dots `i' 1
			continue
		}
		
		else if (_rc == 676) {
			frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
			(.) (.) (.) (.) (.) (.) ("Err:DLW>Not found")
			noi _dots `i' 1
			continue
		}
		
		else if (_rc) {
			frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
			(.) (.) (.) (.) (.) (.) ("Err:DLW")
			noi _dots `i' 1
			continue
		}
		
		
		
		cap {
			sum welfare, meanonly
			local wfdlw  = r(mean)
			
			sum weight, meanonly
			local wtdlw = r(mean)
			
			fastgini welfare [w=weight]
			local gndlw =  r(gini)
		}
		
		if (_rc) {
			frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
			(.) (.) (.) (.) (.) (.) ("Error in calculations")
			noi _dots `i' 1
			continue
		}
		
	}	
	
	//========================================================
	//  save means in external frame 
	//========================================================
	
	frame post res ("`country_code'") ("`surveyid_year'") ("`survey_acronym'") ///
	(`wfdlw') (`wfpcn') (`wtdlw') (`wtpcn')	 (`gndlw') (`gnpcn') ("passed")
	noi _dots `i' 0
	
} // end of while 

noi disp ""

/*==================================================
Read results
==================================================*/

frame res {
	
	destring surveyid_year, gen(year)
	gen code      = country_code
	gen survname  = survey_acronym
	gen datalevel = 2
	
	// link with CPI data
	frlink m:1 code year datalevel survname, frame(cpi)
	frget cpi2011 cpi2011_unadj cur_adj, from(cpi)
	gen double curr = cpi2011 /cpi2011_unadj /cur_adj
	
	
	gen wf = round(wfdlw/wfpcn, .001)
	gen wt = round(wtdlw/wtpcn, .001)
	gen gn = round(gndlw/gnpcn, .001)
	save "02.data/comparison_results.dta", replace
}


frame res {
	tab note
	count
	count if wf == 1
	count if wt == 1
	count if gn == 1
	
}

use "02.data/comparison_results.dta", clear
keep if gn != 1


*##e


exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:

* frame change res
local c = "CAN"
local y = "1981"
local a = "SILC-LIS"

frame change default
pcn load, countr(`c') year(`y') ///
	maindir("${maindir}") clear
	


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



frame res {
	list  country_code  surveyid_year if ///
		(wf != 1 | wt != 1 | gn != 1) & !missing(wf, wt, gn)
}





