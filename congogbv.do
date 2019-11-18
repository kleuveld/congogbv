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
		
	
		qui regress `var' `treatment' `reg_weight', vce(cluster `cluster')
		matrix table = r(table)
		scalar pvalue = coeff[3,1]

		*calculate difference
		local diff = string(diff,"%9.2f") + cond(pvalue < 0.1,"*","") + cond(pvalue < 0.05,"*","") + cond(pvalue < 0.01,"*","")
		n di "`diff'"
		
		post `memhold' (Variable) (N2) ("`Mean2'") (N1) ("`Mean1'") (N0) ("`Mean0'") ("`diff'")
		post `memhold' ("")       (.)  ("`SD2'")   (.)  ("`SD1'")   (.)  ("`SD0'")   ("")
		scalar drop _all
		n di "test: end var loop `var'"
		}
	postclose `memhold'
	**Export table
	
	use "`balance'", clear

	if regexm("`using'",".xlsx?$")==1 {
		n di "exporting excel"
		export excel "`using'", sheet("`sheet'") firstrow(variables) sheetreplace
	}
	if regexm("`using'",".tex$")==1 {
		n di "exporting tex"
		n di "a"
		tempfile temp
		texsave using "`temp'", replace frag  size(small) marker(tab:balance)  title(covariate balance) footnote("Standard Deviations in parantheses; *p $<$ 0.1,**p $<$ 0.05,***p $<$ 0.0")
		n di "b"
		filefilter "`temp'" "`using'", from("{Variable}&{N2}&{MeanSD2}&{N1}&{MeanSD1}&{N0}&{MeanSD0}&{diff} \BStabularnewline") to("&\BSmulticolumn{2}{c}{All}&\BSmulticolumn{2}{c}{Treatment}&\BSmulticolumn{2}{c}{Control}& \BStabularnewline\n{Variable}&{N}&{Mean}&{N}&{Mean}&{N}&{Mean}&{diff} \BStabularnewline") replace
		n di "c"
		
	}
	
	restore
end



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
la var victim_hurt "Conflict: household member hurt"
gen victim_kidnap = m7_1_5 == 1
la var victim_kidnap "Conflict: household member kidnapped"
gen victim_famlost = m7_1_7 == 1
la var victim_famlost "Conflict: household member killed"

gen victim_any = m7_1_1 ==1 | m7_1_3 == 1 | m7_1_5 == 1 | m7_1_7 == 1
la var victim_any "Conflict: any type of victimization"
*family connections
ren m1_6_a fam_chief


*merge in personal data from roster
ren m8_2_1 m1_1_a
merge 1:1 vill_id group_id hh_id m1_1_a using "$dataloc\HH_Roster_sorted.dta", keep(master match) gen(roster_merge)

*rename and clean up variables
ren m1_1_d age
ren m1_1_e sex
ren m1_1_f relchef
replace relchef = 0 if relchef > 1 & relchef < .
ren m1_1_g resstat
ren m1_1_h edu
ren m1_1_h_temp eduyrs

*only keep adult women
drop if sex == 1
drop if age < 16

*rename wife ID to match id in marriage module
ren m1_1_a m1_3_e

*merge in marriage
preserve
use "$dataloc\Mariage_sorted.dta", clear ///

*dedup by dropping spuses outside household, and keeping most recent marriage
drop if m1_3_e > 20
bys vill_id group_id hh_id m1_3_e ( m1_3_k_aa m1_3_h): gen n = _n
bys vill_id group_id hh_id m1_3_e ( m1_3_k_aa m1_3_h): gen N = _N
drop if n < N
drop n N

*rename variables
ren m1_3_j_e mar_rap
gen mar_agediff = m1_3_c - m1_3_f
la var mar_agediff "Age husband - Age wife"

replace m1_3_k_aa = . if m1_3_k_aa == 9999
ren m1_3_k_aa mar_year
gen mar_years = 2012 - mar_year

tempfile marriage
save `marriage'

restore
merge 1:1 vill_id group_id hh_id m1_3_e using `marriage' , keep(master match) gen(marmerge)
preserve

*mege in dottes
use "$dataloc\Dottes_sorted.dta" ,clear
bys vill_id group_id hh_id: replace line_id = _n if line_id == .

replace m1_4_e = . if m1_4_e >= 9998
ren m1_4_e dot_wife

replace m1_4_c = . if m1_4_c >= 9998
ren m1_4_c dot_husband

tempfile dot 
save `dot' 

restore
merge 1:1 vill_id group_id hh_id line_id using `dot', keep(master match) gen(dotmerge)



***********************
**Regression Analyses**
***********************
*full sample
global vars victim_proplost fam_chief terr_fizi



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

*check orthogonality
local using using "$tableloc\balance.tex"
orth_out age victim_any dot_husband dot_wife mar_rap mar_agediff terr_fizi using "$tableloc\balance1.tex", by(ball5) pcompare test se count latex full overall vce(cluster vill_id)

orth_out dot_husband dot_wife mar_rap mar_agediff using "$tableloc\balance2.tex", by(ball5) pcompare test se count latex overall vce(cluster vill_id)


balance_table age victim_any dot_husband dot_wife mar_rap mar_agediff terr_fizi dot_husband dot_wife mar_rap mar_agediff if !missing(ball5) using "$tableloc\test.tex", ///
sheet(sheet1) treatment(ball5) cluster(vill_id)

brok

*check for design effect
kict deff numballs, nnonkey(4) condition(ball5)

/* 
*do some histograms 
hist numballs if ball5, d frac
hist numballs if !ball5, d frac


*run kict
eststo linear_1: kict ls numballs, nnonkey(4) condition(ball5) estimator(linear) vce(cluster vill_id) //26% of the women in the sample have experienced sexual violence(!!!); delta is the relevant coeff
eststo linear_2: kict ls numballs age victim_any dot_husband dot_wife mar_rap mar_agediff terr_fizi, nnonkey(4) condition(ball5) estimator(linear) vce(cluster vill_id) //26% of the women in the sample have experienced sexual violence(!!!); delta is the relevant coeff

//eststo imai_1: kict ml numballs, nnonkey(4) condition(ball5) estimator(imai) vce(cluster vill_id)
//eststo imai_2: kict ml numballs age victim_any dot_husband dot_wife mar_rap mar_agediff terr_fizi, nnonkey(4) condition(ball5) estimator(imai) vce(cluster vill_id)


esttab linear_? imai_? using "$tableloc\results.tex", replace ///
	mgroups("Linear" "ML", pattern(1 0 1 0)) nomtitles keep(Delta:*)
eststo clear




 */

 *villager fe
 //kict ml numballs vill_fe*, nnonkey(4) condition(ball5) estimator(imai) vce(cluster vill_id) 
 //kict ls numballs age victim_any dot_husband dot_wife mar_rap mar_agediff villfe_*, nnonkey(4) condition(ball5) estimator(linear) vce(cluster vill_id)


global vars victim_any villfe_*

global ints
foreach var of varlist $vars {
	gen ball5_`var' =  ball5 * `var'
	global ints $ints ball5_`var'
}
reg numballs ball5 $vars $ints
drop $ints

*secteir FEs
global vars victim_any sectfe_*

global ints
foreach var of varlist $vars {
	gen ball5_`var' =  ball5 * `var'
	global ints $ints ball5_`var'
}
reg numballs ball5 $vars $ints
drop $ints


//kict ls numballs $vars, nnonkey(4) condition(ball5) estimator(linear) vce(cluster vill_id) 
//kict ml numballs $vars, nnonkey(4) condition(ball5) estimator(imai) vce(cluster vill_id) 



**************
**Coefplots**
*************
//https://stats.idre.ucla.edu/stata/faq/how-can-i-make-a-bar-graph-with-error-bars/

drop if ball5 == .


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


*****************************
**Comparison of differences**
*****************************

*base
preserve 
reg numballs ball5, vce(cluster vill_id)
regsave, ci
keep if var == "ball5"
tempfile base
save `base'
restore

*victimized
preserve
gen ball5_victim = ball5 * victim_any
reg numballs ball5 victim_any ball5_victim, vce(cluster vill_id)
regsave, ci
keep if var == "ball5_victim"
tempfile victim
save `victim'
restore

*marriage
preserve
reg numballs ball5 mar_rap ball5_marrap, vce(cluster vill_id)
regsave, ci
keep if var == "ball5_marrap"
tempfile marriage
save `marriage'


*merge and plot
use `base'
append using `victim'
append using `marriage'
gen n = _n

graph twoway ///
	(scatter coef n) (rcap ci_upper ci_lower n), ///
	xtitle( )  xlabel( 1 "Overall" 2 "Victimization" 3 "Marriage", noticks) xscale(range(0.6/3.4))  ///
	legend(off)

graph export "$figloc/meancompare4.png", as(png) replace
restore
