/*
Analysis of GBV in Congo, based on MFS II baseline data

Author: Koen Leuveld
Git repo: https://github.com/freetambo/congogbv.git

Date: 14/11/2019

*/



global dataloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Data
global tableloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Tables
use "$dataloc\HH_Base_sorted.dta" , clear

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
bys vill_id: egen terr_id2 = mode(terr_id), maxmode
tab terr_id2, gen(terrfe)

*victimization
gen victim_proplost = m7_1_1 == 1
gen victim_hurt = m7_1_3 == 1
gen victim_kidnap = m7_1_5 == 1
gen victim_famlost = m7_1_7 == 1
gen victim_any = m7_1_1 ==1 | m7_1_3 == 1 | m7_1_5 == 1 | m7_1_7 == 1

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
global vars victim_proplost fam_chief terrfe2 terrfe3


*generate interaction terms
global ints
foreach var of varlist $vars {
	gen ball5_`var' =  ball5 * `var'
	global ints $ints ball5_`var'
}

reg numballs ball5 $vars $ints, vce(cluster vill_id)

drop $ints


*married sample
global vars victim_proplost fam_chief dot_husband dot_wife mar_rap mar_agediff terrfe2 terrfe3

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
orth_out age victim_any dot_husband dot_wife mar_rap mar_agediff terrfe2 terrfe3, by(ball5)

*check for design effect
kict deff numballs, nnonkey(4) condition(ball5)


*do some histograms 
hist numballs if ball5, d frac
hist numballs if !ball5, d frac


*run kict
eststo basic_1: kict ls numballs, nnonkey(4) condition(ball5) estimator(linear) vce(cluster vill_id) //26% of the women in the sample have experienced sexual violence(!!!); delta is the relevant coeff
eststo basic_2: kict ls numballs age victim_any dot_husband dot_wife mar_rap mar_agediff terrfe2 terrfe3, nnonkey(4) condition(ball5) estimator(linear) vce(cluster vill_id) //26% of the women in the sample have experienced sexual violence(!!!); delta is the relevant coeff

eststo adv_1: kict ml numballs, nnonkey(4) condition(ball5) estimator(imai) vce(cluster vill_id)
eststo adv_2: kict ml numballs age victim_any dot_husband dot_wife mar_rap mar_agediff terrfe2 terrfe3, nnonkey(4) condition(ball5) estimator(imai) vce(cluster vill_id)


esttab basic_? adv_? using "$tableloc\table1.tex", replace ///
	mgroups("Linear" "Imai", pattern(1 0 1 0)) nomtitles keep(Delta:*)
eststo clear
