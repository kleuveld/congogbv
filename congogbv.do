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

capture program drop balance_table
pause off
program define balance_table
	version  13
	syntax varlist [if] using/, Treatment(varlist) Cluster(varlist) Sheet(string) [Title(string) Weight(varlist)]
	preserve
	if "`if'"!="" {
		keep `if'
	}

	**Manipulate input
	if "`weight'"=="" {
		tempvar equal_weight
		gen `equal_weight' = 1
		local weight `equal_weight'
	}
	**Create table
	tempname memhold
	tempfile balance
	qui postfile `memhold' str80 Variable N2 str12 MeanSD2 N1 str12 MeanSD1 N0 str12 MeanSD0 str12 diff using "`balance'", replace
	**Calculate statistics
	foreach var of varlist `varlist' {
		n di "test: start var loop `var'"
		scalar Variable = `"`: var label `var''"'

		 *calculate statistics for full sample
		su `var' [aweight=`weight']
		scalar N2 = `r(N)'
		scalar Mean2 = `r(mean)'
		scalar SD2 = round(`r(sd)',2)

		***Calculate statistics for upgraded
		su `var' if `treatment'== 1 [aweight=`weight']

		scalar N1 = `r(N)'
		scalar Mean1 = `r(mean)'
		scalar SD1 = round(`r(sd)',2)
		
		***Calculate statistics for non-upgraded
		qui su `var' if `treatment'==0  [aweight=`weight']
		scalar N0 = `r(N)'
		scalar Mean0 = `r(mean)'
		scalar SD0 = round(`r(sd)',2)

		scalar diff = Mean1 - Mean0 

		forvalues i = 0/2{
			local Mean`i' = string(Mean`i',"%9.2f")
			local SD`i' = "("+ string(SD`i',"%9.2f") + ")"

			n di "`Mean`i''"
			n di "`SD`i''"
		}

		n di "test2"

		**Calculate p-values with correction for clusters
		local aweight "[aweight=`weight']"
		local reg_weight "[aweight=`weight']"
		
	
		regress `var' `treatment' `reg_weight', vce(cluster `cluster')
		matrix table = r(table)
		scalar pvalue = table[4,1]

		*calculate difference
		local diff = string(diff,"%9.2f") + cond(pvalue < 0.1,"*","") + cond(pvalue < 0.05,"*","") + cond(pvalue < 0.01,"*","")
		n di "`diff'"
		pause
		post `memhold' (Variable) (N2) ("`Mean2'") (N1) ("`Mean1'") (N0) ("`Mean0'") ("`diff'")
		post `memhold' ("")       (.)  ("`SD2'")   (.)  ("`SD1'")   (.)  ("`SD0'")   ("")
		scalar drop _all
		n di "test: end var loop `var'"
		}
	postclose `memhold'
	**Export table
	
	use "`balance'", clear
	forvalues i = 0/2{
		la var N`i' "N"
		la var MeanSD`i' "Mean"		
	}
	la var diff " "

	if regexm("`using'",".xlsx?$")==1 {
		n di "exporting excel"
		export excel "`using'", sheet("`sheet'") firstrow(variables) sheetreplace
	}
	if regexm("`using'",".tex$")==1 {
		n di "exporting tex"
		n di "a"
		tempfile temp
		texsave using "`temp'", autonumber varlabels replace frag  size(3) marker(tab:balance)  title(covariate balance) footnote("Standard Deviations in parantheses; *p $<$ 0.1,**p $<$ 0.05,***p $<$ 0.01")
		n di "b"
		filefilter "`temp'" "`using'", from("&{(1)}&{(2)}&{(3)}&{(4)}&{(5)}&{(6)}&{(7)} \BStabularnewline") to("&{(1)}&{(2)}&{(3)}&{(4)}&{(5)}&{(6)}&{(7)} \BStabularnewline\n&\BSmulticolumn{2}{c}{All}&\BSmulticolumn{2}{c}{Treatment}&\BSmulticolumn{2}{c}{Control}&{(4)-(6)}\BStabularnewline") replace
		n di "c"
		
	}
	
	restore
end



*Main
use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain.dta",clear

tempfile nosave
save `nosave'

*list experiment split into two variables: chef de menage and epouse
gen numballs = v283
la var numballs "Number of issues faced"
replace numballs = v327 if numballs == . 
gen ball5 = hh_grp_gendergender_eplist_conli == 5 if !missing(hh_grp_gendergender_eplist_conli)
la var ball5 "Treatment"
replace ball5 = hh_grp_gendergender_cdmlist_cdml == 5 if ball5 == .


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



gen riskspousediff = riskcouple - riskspouse  
gen riskheaddiff = riskcouple - riskhead

gen riskheadcloser = abs(riskspousediff) > abs(riskheaddiff) if !missing(riskcouple)
gen riskspousecloser = abs(riskheaddiff) > abs(riskspousediff) if !missing(riskcouple)

la var riskheadcloser "Bargaining: closer to husband"
la var riskspousecloser "Bargaining: closer to wife"

gen barg = 2
replace barg = 1 if riskspousecloser
replace barg = 3 if riskheadcloser

*keep relevant vars
keep barg KEY vill_id numballs ball5 resp_id terrfe_* riskspouse riskhead riskcouple riskheadcloser  riskspousecloser

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

gen wifemoreland = a_marrnonhh_statpar == 1
la var wifemoreland "Family wife had more land"
gen husbmoreland = a_marrnonhh_statpar == 3
la var husbmoreland "Family husband had more land"

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

egen marcohab = anymatch(a_marrmarr_type?), values(1)
egen marcivil = anymatch(a_marrmarr_type?), values(2)
egen marreli = anymatch(a_marrmarr_type?), values(3)
egen martrad = anymatch(a_marrmarr_type?), values(4)





**************************
**Table 1: Balance Table**
**************************
balance_table numballs husbmoreland wifemoreland riskspouse riskhead riskheadcloser riskspousecloser terrfe* if !missing(ball5) using "$tableloc\balance.tex", ///
	sheet(sheet1) treatment(ball5) cluster(vill_id)

*****************************
**Figure 1: Mean Comparison**
*****************************
//https://stats.idre.ucla.edu/stata/faq/how-can-i-make-a-bar-graph-with-error-bars/

*create csv file from which to read estimates in the paper
tempfile diffs

preserve
collapse (mean) meanballs= numballs (sd) sdballs=numballs (count) n=numballs, by(ball5)

generate hiballs = meanballs + invttail(n-1,0.025)*(sdballs / sqrt(n))
generate loballs = meanballs - invttail(n-1,0.025)*(sdballs / sqrt(n))


graph twoway (scatter meanballs ball5) (rcap hiballs loballs ball5), ///
	ytitle(Number of reported issues) xtitle(Treatment) ///
	ylabel(0(0.5)3) xscale(range(-0.5 1.5)) xlabel(0/1) ///
	legend(order(1 "Average number of issues" 2 "95% CI"))

graph export "$figloc/meancompare1.png", as(png) replace

keep ball5  meanballs n sdballs
gen key = "overall"
reshape wide meanballs n sdballs, i(key) j(ball5)

//ren * *0
//ren var0 var

save `diffs'
restore

**********************************************************
**Figure 3: Mean Comparison 2: Status**
**********************************************************
*marriage

preserve

ren a_marrnonhh_statpar statpar
replace statpar = . if statpar > 3
drop if statpar == .


collapse (mean) meanballs= numballs (sd) sdballs=numballs (count) n=numballs, by(ball5 statpar)
generate hiballs = meanballs + invttail(n-1,0.025)*(sdballs / sqrt(n))
generate loballs = meanballs - invttail(n-1,0.025)*(sdballs / sqrt(n))

generate subgroup = .
replace subgroup = (statpar - 1) * 3 + ball5

graph twoway ///
	(scatter meanballs subgroup if ball5 == 0, msymbol(circle)) ///
	(scatter meanballs subgroup if ball5 == 1, msymbol(triangle)) ///
 	(rcap hiballs loballs subgroup), ///
	ytitle(Number of reported issues) ylabel(0(0.5)3) ///
	xtitle(Partner whose family had more land)  xlabel( 0.5 "Wife" 3.5 "Same" 6.5 "Husband", noticks) xscale(range(-0.5 7.5))  ///
	legend(order(1 "Control" 2 "Treatment" 2 "95% CI"))
graph export "$figloc/meancompare2.png", as(png) replace



*reshape and store estimate
keep ball5  meanballs statpar n sdballs
ren statpar group
la val group

reshape wide meanballs n sdballs, i(group) j(ball5)
gen key = "statpar" + string(group) //no underscore because latex doesn't like it


//reshape wide meanballs0 meanballs1 n0 n1, i(var) j(statpar)
append using `diffs'
save `diffs', replace

restore

**********************************************************
**Figure 4: Mean Comparison 2: Bargaining**
**********************************************************
*marriage



preserve
drop if riskcouple == .


collapse (mean) meanballs= numballs (sd) sdballs=numballs (count) n=numballs, by(ball5 barg)
generate hiballs = meanballs + invttail(n-1,0.025)*(sdballs / sqrt(n))
generate loballs = meanballs - invttail(n-1,0.025)*(sdballs / sqrt(n))

generate subgroup = .
replace subgroup = (barg - 1) * 3 + ball5

graph twoway ///
	(scatter meanballs subgroup if ball5 == 0, msymbol(circle)) ///
	(scatter meanballs subgroup if ball5 == 1, msymbol(triangle)) ///
 	(rcap hiballs loballs subgroup), ///
	ytitle(Number of reported issues) ylabel(0(0.5)3) ///
	xtitle(Bargaining: couple decision closer to)  xlabel( 0.5 "Wife" 3.5 "Same" 6.5 "Husband", noticks) xscale(range(-0.5 7.5))  ///
	legend(order(1 "Control" 2 "Treatment" 2 "95% CI"))
graph export "$figloc/meancompare3.png", as(png) replace


*reshape and store estimate
keep ball5  meanballs barg n sdballs
ren barg group
la val group

reshape wide meanballs n sdballs, i(group) j(ball5)
gen key = "barg" + string(group) //no underscore because latex doesn't like it

append using `diffs'



*create CSV file from which LaTeX can read estimates of incidence

gen p = .
forvalues i = 1/`=_N'{
	ttesti `=n0[`i']' `=meanballs0[`i']' `=sdballs0[`i']' `=n1[`i']' `=meanballs1[`i']' `=sdballs1[`i']', unequal
	replace p = r(p) in `i'

}

gen n = n0 + n1
gen incidence = meanballs1 - meanballs0
gen incidence_pct = incidence * 100

format meanballs* incidence %9.2f
format *_pct %9.0f
format p %9.3f



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
