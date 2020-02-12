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

*add: age & education

drop if ball5 == .
balance_table ///
	agewife agehusband eduwife eduhusband /// demograhpics
	numballs ///list experiment
	victimproplost victimfamlost acledviolence10 acledfatalities10 /// conflict
	husbmoreland wifemoreland contribcash contribcashyn riskwife riskhusband barghusbandcloser bargwifecloser  /// bargainin and empowerment
	atthusbtotal attwifetotal /// gender attitidues 
	tinroof livestockany ///assets
	terrfe* /// other
	if !missing(ball5) using "$tableloc\balance.tex", ///
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
meandiffs numballs using "$figloc/meancompare_conf3.png", treatment(ball5)  by(acledviolence10d) coeffs(`diffs') append


regfig victimproplost victimfamlost acledviolence30d using "$figloc/regfig_conf.png"




**********************************************
**Mean Comparisons across SES**
**********************************************
meandiffs numballs using "$figloc/meancompare_ses1.png", treatment(ball5)  by(tinroof) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_ses2.png", treatment(ball5)  by(livestockany) coeffs(`diffs') append

regfig tinroof livestockany using "$figloc/regfig_ses.png"


**********************************************
**Mean Comparisons across SES**
**********************************************
meandiffs numballs using "$figloc/meancompare_att1.png", treatment(ball5)  by(atthusbtotalbin) coeffs(`diffs') append
meandiffs numballs using "$figloc/meancompare_att2.png", treatment(ball5)  by(attwifetotalbin) coeffs(`diffs') append

regfig atthusbtotalbin attwifetotalbin using "$figloc/regfig_att.png"
regfig attwife?bin atthusb?bin using "$figloc/regfig_att_full.png"

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
eststo l1: kict ls numballs  husbmoreland, condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'", replace addlabel(reg,l1)  pval
eststo l2: kict ls numballs  victimfamlost, condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'", append addlabel(reg,l2)  pval
eststo l3: kict ls numballs  acledviolence10d, condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'", append addlabel(reg,l3)  pval  
eststo l4: kict ls numballs  atthusbtotalbin attwifetotalbin, condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'", append addlabel(reg,l4)  pval
eststo l5: kict ls numballs  husbmoreland victimfamlost acledviolence10d atthusbtotalbin attwifetotalbin , condition(ball5) nnonkey(4) estimator(linear) vce(cluster vill_id)
regsave using "`regs'", append addlabel(reg,l5)  pval


esttab l? `using', replace ///
	nomtitles keep(Delta:*)  se label ///
	starlevels(* 0.10 ** 0.05 *** 0.01)

preserve
use `regs', clear
format coef stderr pval %9.2f
export delimited using "$tableloc\regs.csv", datafmt replace


***************************
**Robustness checks**
*********************
restore
*choice of acled parameters:
*civilians
regfig acledviolence5d acledviolence10d acledviolence15d acledviolence20d acledviolence25d acledviolence30d using "$figloc/regfig_conf_viold.png"
regfig acledviolence5 acledviolence10 acledviolence15 acledviolence20 acledviolence25 acledviolence30 using "$figloc/regfig_conf_violc.png"

*battles
regfig acledbattles5d acledbattles10d acledbattles15d acledbattles20d acledbattles25d acledbattles30d using "$figloc/regfig_conf_battd.png"
regfig acledbattles5 acledbattles10 acledbattles15 acledbattles20 acledbattles25 acledbattles30 using "$figloc/regfig_conf_battc.png"

*fatalities
regfig acledfatalities5d acledfatalities10d acledfatalities15d acledfatalities20d acledfatalities25d acledfatalities30d using "$figloc/regfig_conf_fatd.png"
regfig acledfatalities5 acledfatalities10 acledfatalities15 acledfatalities20 acledfatalities25 acledfatalities30 using "$figloc/regfig_conf_fatc.png"
