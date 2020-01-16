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
local update_surveynames = 0 // change to 1 to update survey names. 
local use_personal_dir   = 0 // change to 1 to use personal dirs
//---------------------------



//------------Add personal drive cloned from github repo
if (`use_personal_dir' == 1) {
	if (lower("`c(username)'") == "wb384996") {
		local dir "c:/Users/wb384996/OneDrive - WBG/WorldBank/DECDG/PovcalNet Team/LIS_data"
	}
} 
else { // if network drive 
	local dir "p:/01.PovcalNet/04.LIS"
}
cd "`dir'"
//----------------------------------------------------


//------------ Modify this to specify different text files 
local files: dir "00.LIS_output/" files "LISSY_Jan2020_*.txt"
local files: dir "00.LIS_output/" files "test*.txt"
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

local datadir "p:/01.PovcalNet/01.Vintage_control"

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
	
	qui do "01.programs/lis_functions.mata"	
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
		
		qui disp _n "`ccode' ${ccode} `year' `sacronym' - `sname'" _n
		
		cap mkdir "`datadir'/`ccode'"
		local cy_dir "`ccode'_`year'_`sacronym'" // country year dir
		cap mkdir "`datadir'/`ccode'/`cy_dir'"
		
		
		//------------get matrix into dta and save
		drop _all
		mata: T = `A'.get((`i',2))
		getmata (weight welfare min max)=T
		
		char _dta[wave]         "`wave'" 
		char _dta[id]           "`id'"
		char _dta[author]       "`c(username)'"
		char _dta[orig_file]    "`file'"
		char _dta[survey_name]  "`sname'"
		
		
		//------------ check if file exists or if it has changed
		cap datasignature confirm using /* 
		*/ "`datadir'/`ccode'/`cy_dir'/`cy_dir'", strict
		
		if (_rc == 601) { // file not found
			nois disp in y "file `id' not found. Creating folder with version 01"
			local av = "01"  // alternative version
		} 
		else if (_rc == 9) {  // data have changed
			local vers: dir "`datadir'/`ccode'/`cy_dir'" dirs "*", respectcase
			
			local avs 0
			foreach ver of local vers {
				if regexm("`ver'", "_v([0-9]+)_A_GMD$") local v = regexs(1)
				local avs = "`avs', `v'"
			}
			
			local av = max(`avs') + 1
			if (length("`av'") == 1) {
				local av = "0" + "`av'"
			}
		}
		else {
			noi disp in y "File `id' has not changed since last time"
			continue
		}
		
		datasignature set, reset saving("`datadir'/`ccode'/`cy_dir'/`cy_dir'", replace)
		
		//------------Create versions folders
		local svid "`cy_dir'_v01_M_v`av'_A_GMD"
		cap mkdir "`datadir'/`ccode'/`cy_dir'/`svid'"
		
		local ddir "`datadir'/`ccode'/`cy_dir'/`svid'/data" // data dir
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



