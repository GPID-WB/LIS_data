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
*##s
* version 14
discard
clear all

//------------modify this
local update_surveynames = 0  // change to 1 to update survey names.
local code_personal_dir  = 1  // change to 1 to use Code personal dir
local data_personal_dir  = 0  // change to 1 to use Data personal dir
local replace            = 1  // change to 1 to replace data in memory even if it hasnot changed
//---------------------------

//------------Add personal drive cloned from github repo
if (`data_personal_dir' == 1) {
	if (lower("`c(username)'") == "wb384996") {
		local dir "c:/Users/wb384996/OneDrive - WBG/WorldBank/DECDG/PovcalNet Team/LIS_data"
	}
}
else { // if network drive
	local dir "p:/01.PovcalNet/04.LIS"
}
cd "`dir'"
if (`code_personal_dir' == 1) {
	if (lower("`c(username)'") == "wb384996") {
		local perdir "c:/Users/wb384996/OneDrive - WBG/WorldBank/DECDG/PovcalNet Team/LIS_data/"
	}
}
else {
	local perdir ""
}
//----------------------------------------------------


//------------ Modify this to specify different text files
local files: dir "00.LIS_output/" files "LISSY_2020-02-06*.txt"
* local files: dir "00.LIS_output/" files "test*.txt"
* local files = "test2.txt"
* disp `"`files'"'
//-----------------------------------------------------------


//========================================================
// Load survey name data
//========================================================

//------------do NOT modify this
mata: mata clear
cap which missings
if (_rc) ssc install missings

* data with survey name
if (`update_surveynames' == 1) {
	* make sure file is closed
	import excel using "02.data/_aux/LIS datasets.xlsx", sheet(LIS_survname) /*
	*/  firstrow case(lower) allstring clear
	missings dropvars, force

	save "02.data/_aux/LIS_survname.dta", replace
}
else { // use current version
	use "02.data/_aux/LIS_survname.dta", clear
}
tostring _all, force replace
putmata LIS = (*), replace

*##e
//========================================================
// Start execution
//========================================================

local outputdit "p:/01.PovcalNet/01.Vintage_control"

local f = 0
foreach file of local files {
	local ++f

	global fn = "`dir'/00.LIS_output/`file'"

	local A: word `f' of `c(ALPHA)'
	local l: word `f' of `c(alpha)'

	//========================================================
	// extract vectors into Associative Array
	//========================================================

	/* This part is not efficient. File lif_functions.mata should be executed only
	once before looping over files. I had to include it here because there is problem
	with the structure of the Associative Array. Basicaly, once it is defined and executed,
	you cannot change the values. I think the problem is in the way the text files are being
	read. Maybe they should be read outside the lis_set() function. I don't have time to
	check and fix the the error, so I execute this file here. It is not efficient
	but it works. */

	qui do "`perdir'01.programs/lis_functions.mata"
	mata: `l' = lis_set()
	mata: `A' = lis_iter(`l')

	//========================================================
	// convert to dta and place in corresponding folder
	//========================================================

	local go = 1
	local i = 0
	qui while (`go' == 1) {
		local ++i

		//------------ convert to local from AA
		cap mata: st_local("id", `A'.get((`i',1)))
		if (_rc != 0 | wordcount("`id'") != 3) {
			continue, break
		}
		//------------Currency info
		cap mata: st_local("currency", `A'.get((`i',3)))
		if (_rc != 0) {
			continue, break
		}

		//------------ get info

		local ccode: word 1 of `id'
		local year:  word 2 of `id'
		local wave:  word 3 of `id'

		if (length("`wave'") == 1) {
			local wave = "0" + "`wave'"
		}

		mata: lis_metadata(LIS, "`ccode'", "`year'")
		if ("`sacronym'" == "") {
			local sacronym = "USN-LIS" // for Unknown Survey Name-LIS
			local sname    = "Unknown Survey Name-LIS"
		}

		//------------ create country/year folders

		noi disp _n `"`ccode' `year' `sacronym' - `sname'"' _n

		cap mkdir "`outputdit'/`ccode'"
		local cy_dir "`ccode'_`year'_`sacronym'" // country year dir
		cap mkdir "`outputdit'/`ccode'/`cy_dir'"


		//------------get matrix into dta and save
		drop _all
		mata: T = `A'.get((`i',2))
		getmata (weight welfare min max)=T

		char _dta[wave]         "`wave'"
		char _dta[id]           "`id'"
		char _dta[author]       "`c(username)'"
		char _dta[orig_file]    "`file'"
		char _dta[survey_name]  "`sname'"
		char _dta[currency]     "`currency'"
		char _dta[udpatedon]    "`c(current_date)' `c(current_time)'"

		//------------Conver euro to LCU
		if regexm("`currency'", "[Ee]uro") {
			preserve
			pcn load cpi, clear
			keep if countrycode == "`ccode'" & year == `year'
			if (_N == 1) {
				local ccf  = cur_adj[1]
				restore
				foreach x in welfare min max {
					replace `x' = (`x' / `ccf')
				}
				char _dta[currency]     "LCU"  // update with master info
			}
			else restore
		}

		//------------ check if file exists or if it has changed
		cap datasignature confirm using /*
		*/ "`outputdit'/`ccode'/`cy_dir'/`cy_dir'", strict
		local rcds = _rc

		if (`rcds' == 601) { // file not found
			nois disp in y "file `id' not found. Creating folder with version 01"
			local av = "01"  // alternative version
		}
		else { // file found
			// find versions available
			local vers: dir "`outputdit'/`ccode'/`cy_dir'" dirs "*", respectcase

			local avs 0
			foreach ver of local vers {
				if regexm("`ver'", "_v([0-9]+)_A_GMD$") local v = regexs(1)
				local avs = "`avs', `v'"
			}

			if (`rcds' == 9) {  // data has changed
				local av = max(`avs') + 1
			}
			else {              // data has not changed
				noi disp in y "File `id' has not changed since last time"
				if (`replace' == 1) {
					noi disp in y "Yet, it will be replaced since option replace == 1"
				}
				else {
					continue
				}
				local av = max(`avs')
			} // end of data has not changed

			// final version number
			if (length("`av'") == 1) {
				local av = "0" + "`av'"
			}
		} // end of file found


		datasignature set, reset saving("`outputdit'/`ccode'/`cy_dir'/`cy_dir'", replace)

		//------------Create versions folders
		local svid "`cy_dir'_v01_M_v`av'_A_GMD"
		cap mkdir "`outputdit'/`ccode'/`cy_dir'/`svid'"

		local ddir "`outputdit'/`ccode'/`cy_dir'/`svid'/data" // data dir
		cap mkdir "`ddir'"


		save "`ddir'/`svid'_BIN.dta", replace
	} // end of while loop

} // close loop  `n' = .txt files


exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:



// F = lis_svid(l)
//G = lis_bins(l)



