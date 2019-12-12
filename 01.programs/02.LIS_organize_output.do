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
version 14
clear all

//------------modify this
*local dir "c:\Users\wb384996\OneDrive - WBG\temp\04.LIS\"

local dir "p:/01.PovcalNet/04.LIS/"
local file "test.txt" // modify this


//------------do NOT modify this
cd "`dir'"
global fn = "`dir'/00.LIS_output/`file'"
do "01.programs/lis_functions.mata"

//========================================================
// extrac vectors into Associative Array
//========================================================

mata: l = lis_set()
mata: A = lis_iter(l) 

//========================================================
// convert to dta and place in corresponding folder
//========================================================

local go = 1
local i = 0
while (`go' == 1) {
	local ++i
	
	//------------ convert to local from AA
	cap mata: st_local("id", A.get((`i',1)))
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
	
	//------------ create folders
	
	local sname "USN"   // Unknown Survey Name
	
	cap mkdir "02.data/`ccode'"
	cap mkdir "02.data/`ccode'/`ccode'_`year'_`sname'"
	
	local svid "`ccode'_`year'_`sname'_v01_M_v`wave'_A_LIS"
	cap mkdir "02.data/`ccode'/`ccode'_`year'_`sname'/`svid'"
	
	local ddir "02.data/`ccode'/`ccode'_`year'_`sname'/`svid'/data" // data dir
	cap mkdir "`ddir'"
	
	//========================================================
	// get matrix into dta and save
	//========================================================
	
	drop _all
	mata: T = A.get((`i',2))
	getmata (weight welfare)=T
	
	save "`ddir'/`svid'.dta", replace
}


*##e

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



