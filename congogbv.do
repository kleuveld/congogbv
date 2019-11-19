/*
Analysis of GBV in Congo, based on MFS II baseline data

Author: Koen Leuveld
Git repo: https://github.com/freetambo/congogbv.git

Date: 14/11/2019

*/



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



***************
***Data prep***
***************
/*Load the following data:
	-Main
	_Roster
	-Marriage*/


********
**MAIN**
********
use "$dataloc\HH_Base_sorted.dta" , clear
tempfile nosave
save `nosave'

/*
m8_4 -->
1 = 4 boules
2 = 5 boules
*/

*clean up list experiment data
replace m8_4 = . if m8_2_cercle == 9
replace m8_5 = . if m8_2_cercle == 9
gen ball5 = m8_4
recode ball5 (1=0) (2=1)
la var ball5 "Extra ball"
replace ball5 = . if ball5 == 9
ren m8_5 numballs
la var numballs "Number of balls"
replace numballs = . if numballs == 9
replace numballs = . if numballs == 5 & ball5 == 0


*territory fe
drop terr_id
replace terr_nm = proper(terr_nm)
replace terr_nm = "Fizi" if regexm(terr_nm,"^Fiz")
replace terr_nm = "Fizi" if regexm(terr_nm,"Secteur Mu")
encode terr_nm, gen(terr_id)
gen terr_fizi = terr_id == 1
la var terr_fizi "Territory Fizi"

*secteur FE
tab sect_nm, m
drop sect_id
ren sect_nm sect_nm_old 
replace sect_nm_old = "" if regexm(sect_nm_old,"^9+$")
replace sect_nm_old = proper(sect_nm_old)
replace sect_nm_old = "Bafuliru" if regexm(sect_nm_old,"^(Ba)?[Ff]ul[ie]r[ou]")
replace sect_nm_old = "Mutambala" if regexm(sect_nm_old,"[BM]u?tam?b[ua][lz][aeu]")
bys vill_id: egen sect_nm = mode(sect_nm_old)
encode sect_nm, gen(sect_id)
tab sect_id, gen(sectfe_)
drop sectfe_1 sect_nm_old

*village FEs
tab vill_id,gen(villfe_)
drop villfe_11


*victimization
gen victim_proplost = m7_1_1 == 1
la var victim_proplost "Conflict: property lost"
gen victim_hurt = m7_1_3 == 1
la var victim_hurt "Conflict: HH member hurt"
gen victim_kidnap = m7_1_5 == 1
la var victim_kidnap "Conflict: HH member kidnapped"
gen victim_famlost = m7_1_7 == 1
la var victim_famlost "Conflict: HH member killed"

gen victim_any = m7_1_1 ==1 | m7_1_3 == 1 | m7_1_5 == 1 | m7_1_7 == 1
la var victim_any "Conflict: any"

*family connections
ren m1_6_a fam_chief

**********
**Roster**
**********

*merge in personal data from roster
ren m8_2_1 m1_1_a
merge 1:1 vill_id group_id hh_id m1_1_a using "$dataloc\HH_Roster_sorted.dta", keep(match) gen(roster_merge)

*rename and clean up variables (Nb: 98 = don't know; 99 is not entered) and keep only adult women
ren m1_1_d age
replace age = . if age >= 98
drop if age < 16

ren m1_1_e sex
keep if sex == 2

ren m1_1_f head
replace head = 0 if head > 1
la val head

ren m1_1_g resstat
ren m1_1_h edu
ren m1_1_h_temp eduyrs

*rename wife ID to match id in marriage module
ren m1_1_a m1_3_e


************
**Marriage**
************

*merge in marriage
preserve
use "$dataloc\Mariage_sorted.dta", clear 

*dedup by dropping spouses outside household, and keeping most recent marriage
drop if m1_3_e > 20
replace m1_3_k_aa = 0 if m1_3_k_aa > 2012 //make sure unknown marriages are not prioritized
bys vill_id group_id hh_id m1_3_e ( m1_3_k_aa m1_3_h): gen n = _n
bys vill_id group_id hh_id m1_3_e ( m1_3_k_aa m1_3_h): gen N = _N
replace m1_3_k_aa = . if m1_3_k_aa == 0
drop if n < N
drop n 
ren N nummarriage
la var nummarriage "Number of times married"

*rename variables
ren m1_3_j_e mar_rap
gen mar_agediff = m1_3_c - m1_3_f
la var mar_agediff "Age husband - Age wife"

ren m1_3_k_aa mar_year
la var mar_year "Year of marriage"
gen mar_years = 2012 - mar_year
la var mar_years "Years married"

tempfile marriage
save `marriage'

restore
merge 1:1 vill_id group_id hh_id m1_3_e using `marriage' , keep(master match) gen(marmerge)
preserve

*mege in dottes
use "$dataloc\Dottes_sorted.dta" ,clear
bys vill_id group_id hh_id: replace line_id = _n if line_id == .

replace m1_4_e = . if m1_4_e >= 9000
ren m1_4_e dot_wife
replace dot_wife = dot_wife / 900 if dot_wife > 1500
la var dot_wife "Contr. Wife to marriage ($)"

replace m1_4_c = . if m1_4_c >= 9000
ren m1_4_c dot_husband
replace dot_husband = dot_husband / 900 if dot_husband > 1500
la var dot_husband "Contr. husband to marriage ($)"

tempfile dot 
save `dot' 

restore
merge 1:1 vill_id group_id hh_id line_id using `dot', keep(master match) gen(dotmerge)

drop if ball5 == .


********************
**Table 1: Balance**
********************
balance_table age victim_* dot_husband dot_wife mar_rap mar_agediff mar_year mar_years terr_fizi if !missing(ball5) using "$tableloc\balance.tex", ///
	sheet(sheet1) treatment(ball5) cluster(vill_id)


*****************************
**Figure 1: Mean Comparison**
*****************************
//https://stats.idre.ucla.edu/stata/faq/how-can-i-make-a-bar-graph-with-error-bars/



preserve
collapse (mean) meanballs= numballs (sd) sdballs=numballs (count) n=numballs, by(ball5)

generate hiballs = meanballs + invttail(n-1,0.025)*(sdballs / sqrt(n))
generate loballs = meanballs - invttail(n-1,0.025)*(sdballs / sqrt(n))


graph twoway (scatter meanballs ball5) (rcap hiballs loballs ball5), ///
	ytitle(Number of reported issues) xtitle(Treatment) ///
	ylabel(0(0.5)3) xscale(range(-0.5 1.5)) xlabel(0/1) ///
	legend(order(1 "Average number of issues" 2 "95% CI"))

graph export "$figloc/meancompare1.png", as(png) replace

tempfile all
save `all'
restore

**********************************************************
**Figure 2: Mean Comparison 2: Victimization**
**********************************************************

*victimization
preserve
collapse (mean) meanballs= numballs (sd) sdballs=numballs (count) n=numballs, by(ball5 victim_any)
generate hiballs = meanballs + invttail(n-1,0.025)*(sdballs / sqrt(n))
generate loballs = meanballs - invttail(n-1,0.025)*(sdballs / sqrt(n))

generate victim_ball5 = .
replace victim_ball5 = ball5 if victim_any == 0
replace victim_ball5 = ball5 + 3 if victim_any == 1

graph twoway ///
	(scatter meanballs victim_ball5 if ball5 == 0, msymbol(circle)) ///
	(scatter meanballs victim_ball5 if ball5 == 1, msymbol(triangle)) ///
 	(rcap hiballs loballs victim_ball5), ///
	ytitle(Number of reported issues) ylabel(0(0.5)3) ///
	xtitle(Victimization)  xlabel( 0.5 "Not victimized" 3.5 "Victimized", noticks) xscale(range(-0.5 4.5))  ///
	legend(order(1 "Control" 2 "Treatment" 2 "95% CI"))
graph export "$figloc/meancompare2.png", as(png) replace

restore

**********************************************************
**Figure 2: Mean Comparison 3: Marriage**
**********************************************************
*marriage
preserve
drop if mar_rap == .
collapse (mean) meanballs= numballs (sd) sdballs=numballs (count) n=numballs, by(ball5 mar_rap)
generate hiballs = meanballs + invttail(n-1,0.025)*(sdballs / sqrt(n))
generate loballs = meanballs - invttail(n-1,0.025)*(sdballs / sqrt(n))

generate subgroup = .
replace subgroup = ball5 if mar_rap == 1
replace subgroup = ball5 + 3 if mar_rap == 0

graph twoway ///
	(scatter meanballs subgroup if ball5 == 0, msymbol(circle)) ///
	(scatter meanballs subgroup if ball5 == 1, msymbol(triangle)) ///
 	(rcap hiballs loballs subgroup), ///
	ytitle(Number of reported issues) ylabel(0(0.5)3) ///
	xtitle(Victimization)  xlabel( 0.5 "Forced marriage" 3.5 "Other Marriages", noticks) xscale(range(-0.5 4.5))  ///
	legend(order(1 "Control" 2 "Treatment" 2 "95% CI"))
graph export "$figloc/meancompare3.png", as(png) replace

restore

bys ball5: su numballs
ttest numballs, by(ball5) unequal


***************************************
**Figure 3: Comparison of differences**
***************************************
tempfile coef
*base
reg numballs ball5, vce(cluster vill_id)
regsave using `coef' , ci  addlabel(regno, 1)


gen ball5_victim_any = ball5 * victim_any
reg numballs ball5 victim_any ball5_victim_any, vce(cluster vill_id)
regsave using `coef' , addlabel(regno, 2) ci append

*marriage
gen ball5_mar_rap = ball5 * mar_rap

reg numballs ball5 mar_rap ball5_mar_rap, vce(cluster vill_id)
regsave using `coef' ,addlabel(regno, 3)  ci append

*merge and plot
preserve
use `coef', clear

drop if var == "_cons"
drop if !regexm(var,"^ball5_") & regno > 1
sort regno


graph twoway ///
	(scatter coef regno) (rcap ci_upper ci_lower regno), ///
	xtitle(Mean Difference)  xlabel( 1 "Overall" 2 "Victimization" 3 "Marriage", noticks) xscale(range(0.6/3.4))  ///
	legend(off)

graph export "$figloc/meancompare4.png", as(png) replace
restore


********************************
**Figure 4: Pre-war vs Postwar**
********************************

gen ball5_age = ball5 * age

tempfile coef

reg numballs ball5 victim_any ball5_victim_any age ball5_age, vce(cluster vill_id)
regsave using `coef' , addlabel(regno, 1) ci replace

reg numballs ball5 victim_any ball5_victim_any age ball5_age if mar_year < 1997, vce(cluster vill_id)
regsave using `coef' , addlabel(regno, 2) ci append

reg numballs ball5 victim_any ball5_victim_any age ball5_age if mar_year > 2006, vce(cluster vill_id)
regsave using `coef' , addlabel(regno, 3) ci append

preserve
use `coef', clear

drop if var == "_cons"
drop if var == "ball5_age"
drop if !regexm(var,"^ball5_") //& regno > 1
sort regno


graph twoway ///
	(scatter coef regno) (rcap ci_upper ci_lower regno), ///
	xtitle(Mean Difference Victimized vs Non-victimized)  xlabel( 1 "Overall" 2 "Married pre-war" 3 "Married post-war", noticks) xscale(range(0.6/3.8))  ///
	legend(off)

brok
restore


***********************
**Regression Analyses**
***********************
*full sample



*generate interaction terms
global ints
foreach var of varlist $vars {
	gen ball5_`var' =  ball5 * `var'
	global ints $ints ball5_`var'
}

reg numballs ball5 $vars $ints, vce(cluster vill_id)

drop $ints


*married sample
global vars victim_proplost fam_chief dot_husband dot_wife mar_rap mar_agediff terr_fizi

*check orthogonality
orth_out $vars, by(ball5)


global ints
foreach var of varlist $vars {
	gen ball5_`var' =  ball5 * `var'
	global ints $ints ball5_`var'
}

reg numballs ball5 $vars $ints, vce(cluster vill_id)
drop $ints



***********************
**Proper Analyses**
***********************





