//Extract data LIS txt file

clear

global datain C:\Users\wb463998\OneDrive - WBG\GIT\LIS_data\00.LIS_output\

local date = c(current_date)
local time = c(current_time)
local user = c(username)

tempfile dataall  data1
save `dataall', replace emptyok

local listfile : dir "$datain\" files "LISSY_Mar2024*.txt", respectcase   // Modify this
dis `"`listfile'"'

foreach file of local listfile {
	dis "`file'"
	import delimited using "${datain}\`file'" , clear

	//drop header
	drop in 1/119
	*drop in 1/133
	//drop ender
	drop if v1==". exit"
	drop if v1=="end of do-file"
	drop if v1=="----------------------------------------------------------------------------------"
	drop if v1=="----------+-----------------------------------------------------------------------"

	drop v2 v3 v4

	replace v1 = trim(v1)
	replace v1 = subinstr(v1,"|","",.)
	split v1, parse("")

	gen seq = _n
	gen seq2 = seq if v11=="##1"
	gen cum = sum(seq2)
	save `data1',replace

	levelsof cum, local(lista)
	qui foreach lvl of local lista {
		use `data1', clear
		keep if cum==`lvl'
		gen seq3 = _n
		gen code = v12[1]
		gen year = v13[1]
		gen wave = v14[1]
		gen currency = v14[2] + " " + v15[2]
		gen file = "`file'"
		ren v12 weight
		ren v13 welfare
		ren v14 min
		ren v15 max	
		drop if v11=="##1" | v11=="##2" |v11=="nq"
		ren v11 bin
		
		destring weight welfare min max, replace
		destring bin, replace
		format %20.10g weight welfare min max
		
		drop v1 seq  seq2 cum seq3
		append using `dataall'
		save `dataall', replace
	}
} //file list

use `dataall', clear
destring year wave, replace

save "C:\Users\wb463998\OneDrive - WBG\GIT\LIS_data\02.data\LIStxt_1_dta_temp.dta", replace

*Organize
ren code country_code
tostring year, gen(surveyid_year)
tostring wave, replace
sort country_code surveyid_year bin
drop year bin file v16

save "C:\Users\wb463998\OneDrive - WBG\GIT\LIS_data\02.data\LIStxt_2_dta_temp_alt.dta", replace