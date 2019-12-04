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
qui do "$gitloc\congogbv\congogbv_dataprep.do"

*********************************************
**TABLE 1: Sample overview of bargaining 
*********************************************
use "$dataloc\clean\analysis.dta", clear

tabout  riskwifestatus  riskhusbandstatus using "$tableloc/tabs.csv", cells(freq row col) replace style(csv)
tabout  riskwifestatus  riskhusbandstatus using "$tableloc/tabs.tex",  replace style(tex) format(0c) h3(nil)

**************************
**Table 3: Balance Table**
**************************
drop if ball5 == .
balance_table numballs husbmoreland wifemoreland riskwife riskhusband barghusbandcloser bargwifecloser victimproplost victimfamlost ///
contribcashyn contribinkindyn tinroof livestockany terrfe* if !missing(ball5) using "$tableloc\balance.tex", ///
	rawcsv treatment(ball5) cluster(vill_id)

reg ball5  husbmoreland wifemoreland riskwife riskhusband barghusbandcloser bargwifecloser victimproplost victimfamlost ///
contribcashyn contribinkindyn tinroof livestockany terrfe*, vce(cluster vill_id)

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
meandiffs numballs using "$figloc/meancompare_mar3.png", treatment(ball5)  by(contribcashyn) coeffs(`diffs') append

**********************************************
**Mean Comparisons across Conflict**
**********************************************
meandiffs numballs using "$figloc/meancompare_conf1.png", treatment(ball5)  by(victimproplost) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_conf2.png", treatment(ball5)  by(victimfamlost) coeffs(`diffs') append

**********************************************
**Mean Comparisons across SES**
**********************************************
meandiffs numballs using "$figloc/meancompare_ses1.png", treatment(ball5)  by(tinroof) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_ses2.png", treatment(ball5)  by(livestockany) coeffs(`diffs') append


*export to CSV
preserve
use `diffs', clear
export delimited using "$tableloc\incidence.csv", datafmt replace
restore


**********************************************
**Regression Analysis**
**********************************************
local using using "$tableloc\results_regression.tex"

tempfile regs //"$tableloc\regs.csv"
eststo l1: kict ls numballs  tinroof livestockany terrfe*, condition(ball5) nnonkey(4) estimator(linear)
regsave using "`regs'", replace addlabel(reg,l1)  pval
eststo l2: kict ls numballs  husbmoreland contribcashyn tinroof livestockany terrfe*, condition(ball5) nnonkey(4) estimator(linear)
regsave using "`regs'", replace addlabel(reg,l2)  pval 
eststo l3: kict ls numballs  husbmoreland contribcashyn tinroof livestockany terrfe*  victimproplost victimfamlost, condition(ball5) nnonkey(4) estimator(linear)
regsave using "`regs'", append addlabel(reg,l3)  pval
eststo l4: kict ls numballs  husbmoreland contribcashyn tinroof livestockany terrfe* barghusbandcloser, condition(ball5) nnonkey(4) estimator(linear)
regsave using "`regs'", append addlabel(reg,l4)  pval

eststo l5: kict ls numballs  husbmoreland barghusbandcloser contribcashyn victimproplost victimfamlost tinroof livestockany terrfe*, condition(ball5) nnonkey(4) estimator(linear)
regsave using "`regs'", append addlabel(reg,l5)  pval


esttab l? `using', replace ///
	nomtitles keep(Delta:*)  se label ///
	drop(terr*) ///
	starlevels(* 0.10 ** 0.05 *** 0.01)

preserve
use `regs', clear
export delimited using "$tableloc\regs.csv", datafmt replace

