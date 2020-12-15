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


/*=================================================
	1: Get repo from Datalibweb
==================================================*/
qui cap datalibweb, type(GMD) repo(create dlwrepo)
  qui cap datalibweb, type(GMD) repo(erase dlwrepo, force)
  rename (country years survname) (country_code surveyid_year survey_acronym)
  keep if inlist(module, "BIN", "GPWG", "HIST", "GROUP", "ALL")
  



/*==================================================
              2: 
==================================================*/


/*==================================================
              3: 
==================================================*/





exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:


