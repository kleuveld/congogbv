/*
Analysis of GBV in Congo, based on MFS II baseline data

Author: Koen Leuveld
Git repo: https://github.com/freetambo/congogbv.git

Date: 14/11/2019

*/

set scheme lean1

global dataloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Data //holds raw and clean data
global tableloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Tables //where tables are put
global figloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Figures //where figures are put
global gitloc C:\Users\Koen\Documents\GitHub //holds do files

*run helpers
qui do "$gitloc\congogbv\congogbv_helpers.do"
qui do "$gitloc\congogbv\congogbv_dataprep.do"

*********************************************
**TABLE 1: Sample overview of bargaining 
*********************************************
use "$dataloc\clean\analysis.dta", clear

tab2csv riskwifestatus riskhusbandstatus using "$tableloc/tabs.csv"
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
//meandiffs fuction is defined in congogbv_helpers.do
meandiffs numballs using "$figloc/meancompare_mar1.png", treatment(ball5)  by(statpar) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_mar2.png", treatment(ball5)  by(bargresult) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_mar3.png", treatment(ball5)  by(contribcashyn) coeffs(`diffs') append

regfig statpar bargresult contribcashyn using "$figloc/regfig_mar.png"



**********************************************
**Mean Comparisons across Conflict**
**********************************************
meandiffs numballs using "$figloc/meancompare_conf1.png", treatment(ball5)  by(victimproplost) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_conf2.png", treatment(ball5)  by(victimfamlost) coeffs(`diffs') append 
meandiffs numballs using "$figloc/meancompare_conf3.png", treatment(ball5)  by(acled_battles_d) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_conf4.png", treatment(ball5)  by(acled_violence_d) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_conf5.png", treatment(ball5)  by(acled_fatalities_d) coeffs(`diffs') append


regfig victimproplost victimfamlost acled_battles_d acled_violence_d acled_fatalities_d  using "$figloc/regfig_conf.png"



**********************************************
**Mean Comparisons across SES**
**********************************************
meandiffs numballs using "$figloc/meancompare_ses1.png", treatment(ball5)  by(tinroof) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_ses2.png", treatment(ball5)  by(livestockany) coeffs(`diffs') append

regfig tinroof livestockany using "$figloc/regfig_ses.png"

*export to CSV
preserve
use `diffs', clear
export delimited using "$tableloc\incidence.csv", datafmt replace
restore


**********************************************
**Regression Analysis**
**********************************************


//use "$dataloc\clean\analysis.dta", clear

regfig husbmoreland victimfamlost livestockany using "$figloc/regfig_pool.png", pool


*table

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

