/*
Analysis of GBV in Congo, based on MFS II baseline data.

Dependencies:
congogbv_dataprep.do: prepares MFS II data, and ACLED data.
congogbv_helpers.do: defines programs to create figures and tables.

Author: Koen Leuveld
Git repo: https://github.com/freetambo/congogbv.git

Date: 10/02/2020

*/

set scheme lean1

*set controls
global dataloc X:\Dropbox (Personal)\PhD\Papers\CongoGBV\Data_encrypted //holds raw and clean data
global tableloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Tables //where tables are put
global figloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Figures //where figures are put
global gitloc C:\Users\Koen\Documents\GitHub //holds do files

global allcontrols agewife agehusband genderhead eduwife_prim eduwife_sec eduhusband_prim eduhusband_sec tinroof livestockany terrfe_* treatment


*run helpers
run "$gitloc\congogbv\congogbv_helpers.do" //contains functions used to generate tables and figures.
run "$gitloc\congogbv\congogbv_dataprep.do" //cleans data.


*********************************************
**TABLE 1: Comparison between DHS and my sample
*********************************************
local using using "$tableloc/dhs_compare.tex"

use "$dataloc\clean\dhs.dta", clear
eststo dhs_nat: estpost su agewife tinroof eduwife_prim eduwife_sec [iweight=wgt]
eststo dhs_sk: estpost su agewife tinroof eduwife_prim eduwife_sec [iweight=wgt] if province == 11

use "$dataloc\clean\analysis.dta", clear
eststo sample_all: estpost su agewife tinroof eduwife_prim eduwife_sec
eststo sample_selected: estpost su agewife tinroof eduwife_prim eduwife_sec if !missing(ball5)


esttab dhs_nat dhs_sk sample_all sample_selected `using', cells("mean(fmt(2))") label noobs mtitles("DHS National" "DHS South Kivu" "Full Sample" "Gender Module") replace nonumbers

eststo clear

*********************************************
**Table 2: Gender module sample make up
*********************************************
use "$dataloc\clean\analysis.dta", clear

*sample make up
tab2csv riskwifestatus riskhusbandstatus using "$tableloc/sample_tabs.csv"
tabout  riskwifestatus  riskhusbandstatus using "$tableloc/sample_tabs.tex",  replace style(tex) format(0c) // h3(nil)

**************************
**Table 4: Balance Table**
**************************
use "$dataloc\clean\analysis.dta", clear
drop if ball5 == .

balance_table ///
	numballs ///list experiment
	victimproplost victimfamlost acledviolence10 /// conflict
	husbmoreland wifemoreland /* contribcash  contribcashyn*/ riskwife riskhusband barghusbandcloser bargwifecloser  /// bargainin and empowerment
	$allcontrols ///
	if !missing(ball5) using "$tableloc\balance.tex", ///
	rawcsv treatment(ball5) cluster(vill_id)

/* 
reg ball5 ///
	victimproplost victimfamlost acledviolence10 /// conflict
	husbmoreland wifemoreland /* contribcashyn */ riskwife riskhusband barghusbandcloser bargwifecloser  /// bargainin and empowerment
	atthusbtotal attwifetotal /// gender attitidues 
	, vce(cluster vill_id)
 */

**********************************************
**Figure 1: Mean Comparisons Overall**
**********************************************
tempfile diffs
meandiffs numballs using "$figloc/meancompare_overall.png", treatment(ball5) coeffs(`diffs') //!!!meandiffs fuction is defined in congogbv_helpers.do



**********************************************
**Figure 2: Mean Comparisons across Conflict**
**********************************************
graph drop _all
meandiffs numballs, treatment(ball5)  by(victimproplost) coeffs(`diffs') append name(meancompare_conf1, replace) 
meandiffs numballs, treatment(ball5)  by(victimfamlost) coeffs(`diffs') append name(meancompare_conf2, replace) 
meandiffs numballs, treatment(ball5)  by(acledviolence10d) coeffs(`diffs') append name(meancompare_conf3, replace)

grc1leg  meancompare_conf1 meancompare_conf2 meancompare_conf3, position(4) ring(0) 
graph export "$figloc/meancompare_conf.png", as(png) replace

***********************************
**Table 5: conflict by region
***********************************
local using using "$tableloc/conflict_by_terr.tex"
eststo conflict_comp: estpost tabstat victimproplost victimfamlost acledviolence10, by(territory) statistics(mean sd) columns(statistics) 
esttab conflict_comp `using', main(mean) aux(sd) nostar unstack nonote label noobs nonumbers replace


***********************************
**Table 6:Mean Comparisons across Conflict
***********************************
meandifftab numballs using "$tableloc\meandifftab_conf.csv",by(victimproplost victimfamlost acledviolence10d) treat(ball5) robust




**********************************************
**Figure 3: Mean Comparisons Marriage**
**********************************************
meandiffs numballs, treatment(ball5)  by(statpar) coeffs(`diffs') append name(meancompare_mar1,replace)
meandiffs numballs, treatment(ball5)  by(bargresult) coeffs(`diffs') append name(meancompare_mar2,replace)
//meandiffs numballs, treatment(ball5)  by(contribcashyn) coeffs(`diffs') append name(meancompare_mar3,replace)

grc1leg  meancompare_mar1 meancompare_mar2 // , position(4) ring(0) 
graph export "$figloc/meancompare_mar.png", as(png) replace


**********************************************
**Table 7: Mean Comparisons Marriage**
**********************************************
meandifftab numballs using "$tableloc\meandifftab_mar.csv",by(husbmoreland wifemoreland barghusbandcloser bargwifecloser) treat(ball5) robust


*export to CSV
preserve
use `diffs', clear
export delimited using "$tableloc\incidence.csv", datafmt replace
restore

**********************************************
**Table 8: Multivariate Regression
**********************************************

local using using "$tableloc\results_regression.tex"

global controls agewife agehusband genderhead eduwife_sec eduhusband_prim tinroof livestockany terrfe_* treatment

tempfile regs //"$tableloc\regs.csv"
eststo l1: kict ls numballs  husbmoreland $controls, condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'", replace addlabel(reg,l1)  pval
eststo l2: kict ls numballs  victimfamlost $controls , condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'" , append addlabel(reg,l2)  pval
eststo l3: kict ls numballs  acledviolence10 $controls, condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'", append addlabel(reg,l3)  pval  
eststo l5: kict ls numballs  husbmoreland victimfamlost acledviolence10 attwifetotal $controls, condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'", append addlabel(reg,l5)  pval


esttab l? `using', replace ///
	nomtitles keep(Delta:*) order(Delta:husbmoreland Delta:victimfamlost Delta:acledviolence10 Delta:attwifetotal)  se label ///
	starlevels(* 0.10 ** 0.05 *** 0.01) nonotes

preserve
use `regs', clear
gen coef_pct = abs(coef) * 100
format coef stderr pval %9.2f
format coef_pct %9.0f
export delimited using "$tableloc/regs.csv", datafmt replace

restore

*********************************************
**TABLE A1: Sample Selection 
*********************************************
use "$dataloc\clean\analysis.dta", clear

gen wifeconsent = riskwifestatus == 1 if !missing(riskwifestatus)
gen husbandconsent = riskhusbandstatus == 1 if !missing(riskhusbandstatus)
gen coupleconsent = wifeconsent * husbandconsent


*sample selected
local using using "$tableloc/attrition.tex"


eststo attrwife, t("Wife"): logit wifeconsent $allcontrols, vce(cluster vill_id)
eststo attrhusband, t("Husband"): logit husbandconsent $allcontrols, vce(cluster vill_id)
eststo attrcouple, t("Couple"): logit coupleconsent $allcontrols, vce(cluster vill_id)

esttab attr* `using', replace ///
	nodepvar se label ///
	starlevels(* 0.10 ** 0.05 *** 0.01) nonotes eqlabels("" "")

**********************************************
**Table A2: Determinants**
**********************************************
local using using "$tableloc\determinants_regression.tex"
use if !missing(ball5) using "$dataloc\clean\analysis.dta" , clear

local depvars husbmoreland victimfamlost acledviolence10
local rh_vars $allcontrols
foreach var of varlist `depvars' {
	local rh_depvars : list depvars - var
	di  "var: `var'"
	di "rh_depvars: `rh_depvars'"
	eststo det_`var': reg `var' `rh_depvars' `rh_vars',   vce(cluster vill_id)
}


esttab det_* `using', replace ///
	depvars  se label order(`depvars' `rh_vars') ///
	starlevels(* 0.10 ** 0.05 *** 0.01) nonotes


