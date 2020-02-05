/*==================================================
project:       Extract vectors from text file
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
version 14

local AA   class AssociativeArray scalar
local RS   real scalar
local SS   string scalar
local SL   struct lis scalar


mata:
	mata drop lis*()
	//========================================================
	// create structure
	//========================================================
	
	//------------ set upt structure
	struct lis {
		`RS' fh    // file handle
		`RS' i     // counter of surveys
	}
	
	`SL' lis_set() {
		`SL' l
		
		l.fh = _fopen("${fn}", "r")
		l.i  = 0
		
		return(l)
	}
	
	
	//========================================================
	//  Survey ID
	//========================================================
	
	`SS' lis_svid (`SL' l) {
		
		string scalar id_s, svid
		real scalar pos_a , pos
		
		id_s = "^##1 "  // survey id sign
		pos = pos_a = ftell(l.fh)
		
		while ((svid=strtrim(fget(l.fh)))!=J(0,0,"")) {  // find end of file
			if (regexm(svid, id_s)) {           // check if condition meets
				fseek(l.fh, pos, -1)              // re positioning l.fh to line that meets criteria
				break
			}
			pos = ftell(l.fh)              // store old position if criteria does not meet
		}
		
		//------------return results
		if (rows(svid) == 0 ) {
			return(strofreal(pos))
		}
		else {
			svid = regexr(svid, id_s, "")
			return(svid)        // text line
		}
	}
	
	//========================================================
	//  Country currency
	//========================================================
	
	`SS' lis_currency (`SL' l) {
		
		string scalar id_s, crcy
		real scalar pos_a , pos
		
		id_s = "^##2 "  // survey id sign
		pos = pos_a = ftell(l.fh)
		
		while ((crcy=strtrim(fget(l.fh)))!=J(0,0,"")) {  // find end of file
			if (regexm(crcy, id_s)) {           // check if condition meets
				fseek(l.fh, pos, -1)              // re positioning l.fh to line that meets criteria
				break
			}
			pos = ftell(l.fh)              // store old position if criteria does not meet
		}
		
		//------------return results
		if (rows(crcy) == 0 ) {
			return(strofreal(pos))
		}
		else {
			crcy = regexr(crcy, id_s, "")
			return(crcy)        // text line
		}
	}
	
	
	//========================================================
	// extract Data
	//========================================================
	
	real matrix lis_bins (`SL' l) {
		
		`SS' rstr, rend, line
		string vector r
		real scalar pos
		
		rstr = "^1 \|"                                // condition to start search
		rend = "^[\-]+$"               // condition to end search
		r = J(0, 1, .)                // vector with raw text
		
		//------------get 400 bins
		// starting point
		while ((line=strtrim(fget(l.fh)))!=J(0,0,"")) {  // find end of file
			if (regexm(line, rstr)) {           // check if condition meets
				r = line
				
				// subsequen lines
				while (!regexm(line=strtrim(fget(l.fh)), rend)) {  // find end of table
					r = r \ line
					pos = ftell(l.fh)              // store old position
				}
				
				fseek(l.fh, pos, -1)                       // re positioning l.fh to line that meets criteria
				break   // break outer while loop
			} // end of if condition
			
		} // end of outer while loop
		
		
		if (rows(r) != 0) {		
			//------------ mining
			r = strtrim(stritrim(r))          // remove blanks
			r = regexr(r, "[0-9]+ \| ", "")   // remove row number and divider
			
			f = J(0, 2, .)             // final matrix
			for (i = 1; i <= rows(r); i++) {
				if (rows(f) == 0) {
					f = tokens(r[i])
				}
				else {
					f = f \ tokens(r[i])
				} // end of appending 
			} // end of for loop
			
			f = strtoreal(f)
			return(f)
		}
		else { // if error
			return(pos)
		}
	}
	
	
	//========================================================
	// Looping function
	//========================================================
	
	
	`AA' lis_iter(`SL' l) 
	{
		//------------set up associative array with results
		// fh = _fopen("`fn'", "r")
		`AA' A
		A.reinit("real", 2)
		A.notfound(0)
		
		//------------iterate
		while ((strtrim(fget(l.fh)))!=J(0,0,"")) {  // find end of file
			
			l.i = l.i + 1
			
			A.put((l.i, 1), lis_svid(l)) 
			A.put((l.i, 2), lis_bins(l)) 
			A.put((l.i, 3), lis_currency(l)) 
		}
		fclose(l.fh)
		return(A)
	}

	
	void lis_metadata(string matrix LIS, 
                    string scalar c, 
                    string scalar y) {
		
		string matrix  A, B
		
		A = select(LIS, LIS[,1] :== c)
		B = select(A, A[,2] :== y)
		
		if (rows(B) == 1) {
			st_local("sname", B[3])	
			st_local("sacronym", B[4])
			st_local("scoverage", B[8])	
		}
	
}
	
end


exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:


