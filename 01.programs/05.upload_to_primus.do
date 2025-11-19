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


cwf default
frame copy default status, replace // data status (status)
frame status:  {
    use "02.data/create_dta_status.dta", clear 
    // filter here the surveys to be uploaded
    global status_n = _N
    numlist "1/${status_n}" 
    global nloop = r(numlist)
}


* globals
global common_opts "welfare(welfare) welfaretype(INC) weight(weight) weighttype(FW) mod(BIN) hhid(bins) pfwid(Support_2005_CPI_V13_M) icpbase(2021) proc(16)"


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

    // load the data to be uploaded



    local primus_cmd "primus_gmdupload, country(`country_code') year(`surveyid_year') survey(`survey_acronym') `cmd_update' $common_opts"
    
    noi disp _n "{input: `i'-->}" `"{res: `primus_cmd'}"'
}
