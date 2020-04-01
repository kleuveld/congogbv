
set scheme lean1

global dataloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Data
global tableloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Tables
global figloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Figures
global gitloc C:\Users\Koen\Documents\GitHub

*run helpers
qui do "$gitloc\congogbv\congogbv_helpers.do"


*DHS
/*
Sampling weights, create weight, by dividing by 10e6:
household and householdmembers (HR & PR file): hv005
women and children (IR, KR, BR files): v005
domestic violence (IR file): d005
men (MR file): mv005
ise iweight
*/

//stata 13!
use "$dataloc\dhs\CDIR61DT\CDIR61FL.DTA", clear
keep v005 v150 v129 v012 v149 v101


gen wgt = v005 / 10e6

ren v101 province

ren v150 relhead
keep if inlist(relhead,1,2)

gen tinroof = v129 == 31
ren v012 agewife

gen eduwife_prim = v149 >= 2
la var eduwife_prim "Primary education"
gen eduwife_sec = v149 >= 4
la var eduwife_sec "Secondary education"
keep agewife tinroof eduwife_prim eduwife_sec province wgt

save "$dataloc\clean\dhs.dta", replace
