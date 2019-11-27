/*
Analysis of GBV in Congo, based on MFS II baseline data

Author: Koen Leuveld
Git repo: https://github.com/freetambo/congogbv.git

Date: 14/11/2019

*/

set scheme lean1

global dataloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Data
global tableloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Tables
global figloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Figures
global gitloc C:\Users\Koen\Documents\GitHub

*run helpers
qui do "$gitloc\congogbv\congogbv_helpers.do"


*Main
use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain.dta",clear

tempfile nosave
save `nosave'

*list experiment split into two variables: chef de menage and epouse
gen numballs = v283
replace numballs = v327 if numballs == . 
la var numballs "Number of reported issues"

gen ball5 = hh_grp_gendergender_eplist_conli == 5 if !missing(hh_grp_gendergender_eplist_conli)
replace ball5 = hh_grp_gendergender_cdmlist_cdml == 5 if ball5 == .
la var ball5 "Treatment"
la def treatment 0 "Control" 1 "Treatment"


*id of respondent 
ren hh_grp_gendergender_ep_who resp_id
replace resp_id = 1 if resp_id == . & numballs != . //chef de menage is always line 1


*territory fe 
tab territory, gen(terrfe_)
drop terrfe_1


*risk game 
ren hh_grp_gendergender_eprisk_f riskspouse
la var riskspouse "Bargaining: choice wife"
ren hh_grp_gendergender_cdmrisk_cdm riskhead
la var riskhead "Barganing: choice husband"
ren hh_grp_gendergender_crisk_c riskcouple 
la var riskcouple "Barganing: choice couple"

gen bargspousediff = riskcouple - riskspouse  
gen bargheaddiff = riskcouple - riskhead

gen bargheadcloser = abs(bargspousediff) > abs(bargheaddiff) if !missing(riskcouple)
gen bargspousecloser = abs(bargheaddiff) > abs(bargspousediff) if !missing(riskcouple)

la var bargheadcloser "Bargaining: closer to husband"
la var bargspousecloser "Bargaining: closer to wife"

gen bargresult = 2
la var bargresult "Bargaining result"
la def bargresult 1 "Closest to wife" 2 "Equal distance" 3 "Closest to husband"
la val bargresult bargresult
replace bargresult = 1 if bargspousecloser
replace bargresult = 3 if bargheadcloser

*keep relevant vars
keep barg* KEY vill_id grp_id hh_id numballs ball5 resp_id terrfe_* riskspouse riskhead barg*

tempfile main 
save `main'


*get data of spouses of heads
use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain-hh_-hhroster.dta", clear
keep if a_relhead == 2

*identify, and deal with, duplicates
bys PARENT_KEY: gen linenum2 = _n
egen numwives = max(linenum2)
drop if linenum2 > 1
drop linenum2

*save only relevant data
replace linenum = 1
keep KEY PARENT_KEY linenum a_marrmarr_type1 - a_marrspousegifts
tempfile spouses
save `spouses'

*roster
use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain-hh_-hhroster.dta", clear

*merge in spouse data
merge 1:1 PARENT_KEY linenum using `spouses', update gen(spousemerge)
*ids
ren linenum resp_id
ren KEY ROSTER_KEY
ren PARENT_KEY KEY

tempfile roster
save `roster'

*merge dat scheiss
use `main'
merge 1:1 KEY resp_id using `roster', keep(match) gen(rostermerge)


*final cleaning
drop if a_gender == 1

*status of parents
ren a_marrnonhh_statpar statpar
replace statpar = . if statpar > 3
la var statpar "Land holdings of families before marriage"
la def statpar 1 "Wife's had more land" 2 "Equal" 3 "Husband's had more land"


gen wifemoreland = statpar == 1 if !missing(statpar)
la var wifemoreland "Family wife had more land"
gen husbmoreland = statpar == 3 if !missing(statpar)
la var husbmoreland "Family husband had more land"




*dots and gifts
replace a_relhead = 1 if resp_id == 1

*items
foreach i of numlist 1/3{
	gen marrwiveprov`i' = .
	gen marrhusbprov`i' = .
	
	*respondent is head
	replace marrwiveprov`i' = a_marrheadprov`i' if a_relhead == 1
	replace marrhusbprov`i' = a_marrspouseprov`i' if a_relhead == 1

	*respondent is spouse
	replace marrwiveprov`i' = a_marrheadprov`i' if a_relhead == 2
	replace marrhusbprov`i' = a_marrspouseprov`i' if a_relhead == 2
}



*value
foreach item in dot gifts{
	*dot value
	gen marrhusb`item' = .
	gen marrwive`item' = .

	*respondent is head
	replace marrwive`item' =  a_marrhead`item' if a_relhead == 1
	replace marrhusb`item' =  a_marrspouse`item' if a_relhead == 1

	*respondent is spouse
	replace marrwive`item' =  a_marrspouse`item' if a_relhead == 2
	replace marrhusb`item'=  a_marrhead`item' if a_relhead == 2

	replace marrhusb`item' = 0 if marrhusb`item' == . 
	replace marrhusb`item' = . if marrhusb`item' == 98
	
	replace marrwive`item' = 0 if marrwive`item' == .
	replace marrwive`item' = . if marrwive`item' == 98
}

*marriage types
egen marcohab = anymatch(a_marrmarr_type?), values(1)
egen marcivil = anymatch(a_marrmarr_type?), values(2)
egen marreli = anymatch(a_marrmarr_type?), values(3)
egen martrad = anymatch(a_marrmarr_type?), values(4)



*save endline
tempfile endline
save `endline'

use "$dataloc\baseline\HH_Base_sorted.dta" , clear
tempfile nosave2
save `nosave2'



*victimization
gen victimproplost = m7_1_1 == 1
la var victimproplost "Conflict: property lost"


gen victimhurt = m7_1_3 == 1
la var victimhurt "Conflict: HH member hurt"

gen victimkidnap = m7_1_5 == 1
la var victimkidnap "Conflict: HH member kidnapped"
gen victimfamlost = m7_1_7 == 1
la var victimfamlost "Conflict: HH member killed"

gen victimany = m7_1_1 ==1 | m7_1_3 == 1 | m7_1_5 == 1 | m7_1_7 == 1
la var victimany "Conflict: any"

ren group_id grp_id
keep vill_id grp_id hh_id victim*
tempfile baseline
save `baseline'



use `endline'
duplicates tag vill_id grp_id hh_id, gen(dup)

duplicates drop vill_id grp_id hh_id, force
merge 1:1 vill_id grp_id hh_id  using `baseline', keep(master match) gen(blmerge)

la def yesno 0 "No" 1 "Yes"
la val victim* yesno




**************************
**Table 1: Balance Table**
**************************
balance_table numballs husbmoreland wifemoreland riskspouse riskhead bargheadcloser bargspousecloser terrfe* if !missing(ball5) using "$tableloc\balance.tex", ///
	sheet(sheet1) treatment(ball5) cluster(vill_id)

**********************************************
**Mean Comparisons Overall**
**********************************************
tempfile diffs
meandiffs numballs using "$figloc/meancompare_overall.png", treatment(ball5) coeffs(`diffs')

**********************************************
**Mean Comparisons Marriage**
**********************************************
meandiffs numballs using "$figloc/meancompare_mar1.png", treatment(ball5)  by(statpar) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_mar2.png", treatment(ball5)  by(bargresult) coeffs(`diffs') append



**********************************************
**Figure 2: Mean Comparisons across Conflict**
**********************************************
meandiffs numballs using "$figloc/meancompare_conf1.png", treatment(ball5)  by(victimproplost) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_conf2.png", treatment(ball5)  by(victimhurt) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_conf3.png", treatment(ball5)  by(victimkidnap) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_conf4.png", treatment(ball5)  by(victimfamlost) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_conf5.png", treatment(ball5)  by(victimany) coeffs(`diffs') append




**********************************************
**Figures 1: Mean Comparisons across SES**
**********************************************

*export to CSV
preserve
use `diffs', clear
export delimited using "$tableloc\incidence.csv", datafmt replace
restore






kict ls numballs husbmoreland riskspousecloser riskheadcloser  terrfe*, condition(ball5) nnonkey(4) estimator(linear)


/*
*base estimate
kict ls numballs, condition(ball5) nnonkey(4) estimator(linear)
kict ls numballs husbmoreland wifemoreland  terrfe*, condition(ball5) nnonkey(4) estimator(linear)
kict ls numballs husbmoreland riskspousecloser riskheadcloser  terrfe*, condition(ball5) nnonkey(4) estimator(linear)


kict ml numballs husbmoreland riskspousecloser riskheadcloser  terrfe*, condition(ball5) nnonkey(4) estimator(imai)

//kict ml numballs a_age a_marrheadagemarr wifemoreland husbmoreland terrfe*, condition(ball5) nnonkey(4) estimator(imai)
