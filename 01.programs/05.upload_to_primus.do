//------------Add personal drive cloned from github repo
version 16.1

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

//------------  main directory with LIS data (vintage control)
global vintagedir "//wbntpcifs/povcalnet/01.PovcalNet/03.QA/06.LIS/03.Vintage_control/"

//------------- create a list of cases to be uploaded
cwf default
frame copy default status, replace // data status (status)
frame status:  {
    *use "02.data/create_dta_status.dta", clear 
   	// filter here the surveys to be uploaded
	use "02.data/comparison_results.dta", clear  
	drop if country_code==""
	
	* Remove old/duplicate survey/years (removed or replaced by LIS)
	  /*the following list is taken from 04.Append_new_LIS_bases*/
	drop if country_code=="AUT" & year==1987
	drop if country_code=="AUT" & year==1995 & survey_acronym != "ECHP-LIS" 
	drop if country_code=="CAN" & year==1997 & survey_acronym != "SLID-LIS" 
	drop if country_code=="GBR" & year==1995 & survey_acronym != "FRS-LIS"  
	drop if country_code=="FRA" & year==1978 & survey_acronym != "TIS-LIS" 
	drop if country_code=="FRA" & year==1984 & survey_acronym != "TIS-LIS"
	drop if country_code=="FRA" & year==1989 
	drop if country_code=="FRA" & year==1994 
	drop if country_code=="FRA" & year==2000 & survey_acronym != "TSIS-LIS"  
	drop if country_code=="KOR" & year==2016 & survey_acronym != "SHFLC-LIS"  
	drop if country_code=="ESP" & year==1985 & survey_acronym != "HBCS-LIS"  
	drop if country_code=="JPN" & survey_acronym != "JHPS-KHPS-LIS" 
	drop if country_code=="SWE" & year==1967
	
	keep country_code surveyid_year survey_acronym note
	
	*flag new and changed cases
	replace note = "changed" if (note=="passed" | note=="Err:DLW")
	replace note = "new" if note=="Error in calculations"
	drop in 1/389 //where code stopped uploading
	
    global status_n = _N
    numlist "1/${status_n}" 
    global nloop = r(numlist)
}


* globals
global common_opts "welfare(welfare) welfaretype(INC) weight(weight) weighttype(FW) mod(BIN) hhid(bins) pfwid(Support_2005_CPI_V14_M) icpbase(2021) proc(16)"

//------------ Upload to Primus
* loop over each row in frame status and upload the data
foreach i of global nloop {
    local note           = _frval(status, note, `i')
    local country_code   = _frval(status, country_code, `i')
    local surveyid_year  = _frval(status, surveyid_year, `i')
    local survey_acronym = _frval(status, survey_acronym, `i')
    
    if (regexm("`note'", "changed")) {
        local cmd_update "auto"
    }
    else if (regexm("`note'", "new")) {
        local cmd_update "verm(01) vera(01)"
    } 
    else {
        continue
    }

    // Step 1: load the data to be uploaded
	pcn load,  countries(`country_code') year(`surveyid_year') survey(`survey_acronym') maindir(${vintagedir}) clear
		
	  /*clean vars to upload*/
	  qui: sum weight
	  local total = r(sum) 
	  gen share = (weight/`total')*100	
	  gen code  = upper("`country_code'")
	  gen year = `surveyid_year'
	  gen bins = _n
	  drop min max
      order code year bins welfare weight share

	  *local primus_cmd "primus_gmdupload, country(`country_code') year(`surveyid_year') survey(`survey_acronym') `cmd_update' $common_opts"
      noi disp _n "{input: `i'-->}" // `"{res: `primus_cmd'}"'
	  
	  qui: primus_gmdupload, country(`country_code') year(`surveyid_year') survey(`survey_acronym') `cmd_update' $common_opts
}

*EOF