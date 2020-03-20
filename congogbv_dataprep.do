/*
Processing of MFS II endline data (and ACLED Data) to allow for analysis of GBV.

Author: Koen Leuveld
Git repo: https://github.com/freetambo/congogbv.git

Date: 10/02/2020

*/

set scheme lean1

global dataloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Data
global tableloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Tables
global figloc C:\Users\Koen\Dropbox (Personal)\PhD\Papers\CongoGBV\Figures
global gitloc C:\Users\Koen\Documents\GitHub

*run helpers
qui do "$gitloc\congogbv\congogbv_helpers.do"

********************************************************************************************
**MAIN
********************************************************************************************
use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain.dta",clear

tempfile nosave
save `nosave'

*drop IDs with errors
drop if KEY == "uuid:a162f061-2dd8-4354-9d78-a854a3112c82" //21 1 9 : interviewer interviewed hh twice, keep second
replace grp_id = 2 if KEY == "uuid:c0558804-97ac-48d6-ae11-aed32437da5e" //wrong group id entered,
drop if KEY == "uuid:e2dacb86-d5f0-4047-8085-566f4f538331" //Supervisor fixed mistake by interviewer
replace hh_id = 98 if KEY == "uuid:45d19b1b-d2c1-4655-838e-e45ed51bc5df" //interviewer interviewd wrong hh
replace hh_id = 7 if KEY == "uuid:c1f787f6-528e-4969-a078-599cfadac202" //basded on lists
replace hh_id = 99 if KEY == "uuid:7f823a73-32fa-4a07-a616-7ea61f2e5d34"

*raw cleaning 
replace hh_grp_gendergender_available1 = . if KEY == "uuid:fcf80486-1912-4a15-90ff-0e8d1ce0d2a5"
replace hh_grp_gendergender_accept_cdm = 0 if KEY == "uuid:2d39dac9-60ea-449e-98d9-afe36bfe3e04"
replace hh_grp_gendergender_accept_ep = 0 if KEY == "uuid:2d39dac9-60ea-449e-98d9-afe36bfe3e04"



*list experiment split into two variables: chef de menage and epouse
gen list_spouse = !missing(v327)
gen list_head = !missing(v283)
gen numballs = v283 //head
replace numballs = v327 if numballs == .  //epouse
la var numballs "Number of reported issues"

gen ball5 = hh_grp_gendergender_eplist_conli == 5 if !missing(hh_grp_gendergender_eplist_conli)
replace ball5 = hh_grp_gendergender_cdmlist_cdml == 5 if ball5 == . & numballs != .
la var ball5 "Treatment"
la def treatment 0 "Control" 1 "Treatment"


*id of respondent 
gen resp_id = hh_grp_gendergender_ep_who 
replace resp_id = 1 if resp_id == . & numballs != . //chef de menage is always line 1


*territory fe 
tab territory, gen(terrfe_)
drop terrfe_1


*risk game 

*get genders of head and spouse 
gen linenum = 1
ren KEY PARENT_KEY
merge 1:1 PARENT_KEY linenum using "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain-hh_-hhroster.dta", keepusing(a_gender a_marstat) keep(match) nogen
ren a_gender genderhead
la var genderhead "Gender of HH Head"
ren a_marstat marstathead

replace linenum =  hh_grp_gendergender_ep_who 
merge 1:1 PARENT_KEY linenum using "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain-hh_-hhroster.dta", keepusing(a_gender) keep(master match) nogen
ren a_gender genderspouse
la var genderspouse "Gender of Spouse"
ren  PARENT_KEY KEY

*bargaining
gen riskwife = hh_grp_gendergender_eprisk_f if genderspouse == 2
replace riskwife = hh_grp_gendergender_cdmrisk_cdm if genderhead == 2
la var riskwife "Bargaining: choice wife"

gen riskhusband = hh_grp_gendergender_cdmrisk_cdm if genderhead == 1
replace riskhusband = hh_grp_gendergender_eprisk_f if genderspouse == 1
la var riskhusband "Barganing: choice husband"

ren hh_grp_gendergender_crisk_c riskcouple 
la var riskcouple "Barganing: choice couple"

gen bargwifediff = riskcouple - riskwife  
gen barghusbanddiff = riskcouple - riskhusband

gen barghusbandcloser = abs(bargwifediff) > abs(barghusbanddiff) if !missing(riskcouple)
gen bargwifecloser = abs(barghusbanddiff) > abs(bargwifediff) if !missing(riskcouple)

la var barghusbandcloser "Bargaining: closer to husband"
la var bargwifecloser "Bargaining: closer to wife"
la val barghusbandcloser bargwifecloser yes_no

gen bargresult = 2
la var bargresult "Bargaining result"
la def bargresult 1 "Closest to wife" 2 "Equal distance" 3 "Closest to husband"
la val bargresult bargresult
replace bargresult = 1 if bargwifecloser
replace bargresult = 3 if barghusbandcloser

*Head/spouse available for gender module
egen riskheadpresent = anymatch(hh_grp_gendergender_available?), values(1)
la var riskheadpresent "Risk game: head present"
egen riskspousepresent = anymatch(hh_grp_gendergender_available?), values(2)
la var riskspousepresent "Risk game: spouse present"

*convert from head/spouse -> husband/wfie
gen riskhusbandpresent = riskheadpresent if genderhead == 1
replace riskhusbandpresent = riskspousepresent if genderspouse == 1
la var riskhusbandpresent "Risk game: husband present"
gen riskwifepresent = riskheadpresent if genderhead == 2
replace riskwifepresent = riskspousepresent if genderspouse == 2
la var riskwifepresent "Risk game: wife present"

*Head/spouse consent to gender module
ren hh_grp_gendergender_accept_cdm riskheadconsent
la var riskheadconsent "Risk game: head consents"
ren hh_grp_gendergender_accept_ep riskspouseconsent //spouse accepts risk 
la var riskspouseconsent "Risk game: spouse consents"

*convert from head/spouse -> husband/wfie
gen riskhusbandconsent = riskheadconsent if genderhead == 1
replace riskhusbandconsent = riskspouseconsent if genderspouse == 1
la var riskhusbandconsent "Risk game: husband consents"
gen riskwifeconsent = riskheadconsent if genderhead == 2
replace riskwifeconsent = riskspouseconsent if genderspouse == 2
la var riskwifeconsent "Risk game: wife consents"

*consolidate all into status indicators for wife and husband
gen riskhusbandstatus = . 
replace riskhusbandstatus = 1 if riskhusbandconsent == 1 
replace riskhusbandstatus = 2 if riskhusbandconsent == 0
replace riskhusbandstatus = 3 if riskhusbandpresent == 0
replace riskhusbandstatus = 4 if riskhusbandstatus == .

la def husbandstatus 1 "Consented" 2 "Refused" 3 "Absent" 4 "No Husband"
la val riskhusbandstatus husbandstatus
tab  riskhusbandstatus genderhead, m

gen riskwifestatus = . 
replace riskwifestatus = 1 if riskwifeconsent == 1 
replace riskwifestatus = 2 if riskwifeconsent == 0
replace riskwifestatus = 3 if riskwifepresent == 0
replace riskwifestatus = 4 if riskwifestatus == .

la def wifestatus 1 "Consented" 2 "Refused" 3 "Absent" 4 "No Wife"
la val riskwifestatus wifestatus
tab  riskwifestatus genderhead, m
la var riskwifestatus "Wife"
la var riskhusbandstatus "Husband"

/*
A 																															B
1: Selon nos mœurs et coutumes, les femmes ont toujours été soumises et devraient rester comme telles. 						Dans notre pays les femmes devraient avoir des mêmes droits et obligations que les hommes. 
2: Si un homme maltraite sa femme elle a droit de se plaîndre. 																Selon nos mœurs et coutumes les femmes ne devraient pas se plaîndre de leurs hommes même si elles se sentent maltraités. 
3: Selon nos mœurs et coutumes, un homme dont la femme a été violée a le droit d’abandonner sa femme.						Une femme qui est victime d’un viol ne devrait pas être rejetée par son marie et la communauté.
4: Les femmes devraient avoir la même chance que les hommes d’occupé des positions socio-administratives dans le village. 	Les hommes sont les meilleurs dirigents et ce sont eux seuls qui devraient occuper les positions socio-administratives dans le village. 
5: Seulement les hommes devraient etre les presidents de comités de gestion qui existent dans le village.					Les femmes ont des connaisances à apporter. Elle devraient donc être eligibles au poste de président des comités de gestion qui existent dans le village. 

*/

*head to wife/husband
di "`varlist'"
local counter 1
foreach var of varlist v261 - v273{
	gen atthusb`counter' = `var' if genderhead == 1
	la var atthusb`counter' "Husuband Gender Prop. `counter'"
	gen attwife`counter' = `var' if genderhead == 2
	la var attwife`counter' "Wife Gender Prop. `counter'"
	local counter = `counter' + 1
}

*spouse to wife/husband
local counter 1
foreach var of varlist v305 - v317{
	replace atthusb`counter' = `var' if genderspouse == 1
	replace attwife`counter' = `var' if genderspouse == 2
	local counter = `counter' + 1
}

*remove missings 
recode att* (97=.)

*recode to ensure higher is more empowered
recode att*2 att*4  (5=1) (4=2) (2=4) (1=5) 

forvalues i = 1/5{
	local name Husband
	foreach person in husb wife{
		gen att`person'`i'bin = inlist(att`person'`i',4,5)
		la var att`person'`i'bin "`name' response to Prop `i' "
		local name Wife
	}
}
la def empoweredyn 0 "Not Empowered" 1 "Empowered"
la val att*bin empoweredyn


lab def genderagree 1 "Strongly Agree with tradional" 2 "Agree with traditional" 3 "Neutral" 4 "Agree with empowered" 5 "Strongly agree with empowered"
la val att* genderagree

egen atthusbtotal = rowtotal(atthusb?), missing
la var atthusbtotal "Husband empowerment attitudes"

egen attwifetotal = rowtotal(attwife?), missing
la var attwifetotal "Wife empowerment attitudes"

*aid
egen aidwomen = anymatch(hh_aid?), values(5)
gen aidany = hh_aid1 > 0 if !missing(hh_aid1)

la var aidwomen "Household was beneficiary of woman's rights project"
la var aidany "Household was beneficiary of a development project"
la val aidany aidwomen yes_no



*livestock
egen livestockcow = anymatch(hh_livestock?), values(1)
la var livestockcow "Household owns cow(s)"

egen livestockgoat = anymatch(hh_livestock?), values(2)
la var livestockgoat "Household owns goat(s)"

egen livestockchicken =  anymatch(hh_livestock?), values(3)
la var livestockchicken "Household owns chicken(s)"

egen livestockpigs =  anymatch(hh_livestock?), values(4)
la var livestockpig "Household owns pigs(s)"

gen livestockany = hh_livestock1 > 0 if !missing(hh_livestock1)
la var livestockany "Household owns livestock"

la val livestock* yes_no

*roof types
tab hh_c_roofmat
gen tinroof = hh_c_roofmat == 1 if !missing(hh_c_roofmat)
la var tinroof "Household has a tin roof"
la val tinroof yes_no


*keep relevant obs
//keep if !missing(numballs)

*keep relevant vars
keep  KEY 	vill_id grp_id hh_id terrfe_* resp_id /// IDs etc.
			numballs ball5  list_spouse list_head /// list experiment
			barg* riskwife riskhusband tinroof aidany aidwomen livestock* ///
			genderhead marstathead /// 
			atthusbtotal attwifetotal atthusb?bin attwife?bin /// gender attituted
			risk*present ris*consent riskspouseconsent risk*status

tempfile main 
save `main'

***********************************************************************************************************
**ROSTER: SPOUSES
***********************************************************************************************************
use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain-hh_-hhroster.dta", clear

*merge in main to tag spouses that played list experiment (list_* will not be missing)
ren KEY KEY_ORG
ren PARENT_KEY KEY
ren linenum resp_id
di _N
merge m:1 KEY resp_id using `main', keepusing(list_*) keep(master match) 
di _N
ren KEY PARENT_KEY
ren KEY_ORG KEY

keep if a_relhead == 2

*identify, and deal with, duplicates (ones who played are kept)
bys PARENT_KEY (list_spouse): gen spousenum = _n
bys PARENT_KEY: egen numwives = count(a_relhead)

drop if spousenum > 1

*age, ethn, education
ren a_age age_spouse
ren a_etn etn_spouse 
ren a_school edu_spouse
ren a_gender gender_spouse

*save only relevant data
gen linenum = 1
keep PARENT_KEY linenum a_marrmarr_type1 - a_marrspousegifts age_spouse etn_spouse edu_spouse gender_spouse
tempfile spouses
save `spouses'

***********************************************************************************************************
**OCCUPATIONS
***********************************************************************************************************
use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain-a_-occs.dta", clear
collapse (sum) contribcash = occ_cash contribinkind = occ_inkind, by(PARENT_KEY)
ren PARENT_KEY KEY
tempfile occupations
save `occupations'

***********************************************************************************************************
**ROSTER
***********************************************************************************************************
use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain-hh_-hhroster.dta", clear

*merge in spouse data
merge 1:1 PARENT_KEY linenum using `spouses', update gen(spousemerge) assert(master match_update)

//*merge in occupation data 
//merge 1:1 KEY using `occupations', keep(master match) gen(occmerge)

*ids
ren linenum resp_id
ren KEY ROSTER_KEY
ren PARENT_KEY KEY

keep if resp_id == 1

*age, ethn, education
ren a_age age_head
ren a_etn etn_head
ren a_school edu_head
ren a_gender gender_head

tokenize `""Age" "Etnicicity" "Level of education""'
foreach var in age etn edu {
	foreach partner in wife husband{
		gen `var'`partner' = .
		la var `var'`partner' "`1' of `partner'"
	}

	*respondent (woman) is head
	replace `var'wife = `var'_head if gender_head == 2
	replace `var'husband = `var'_spouse if gender_head == 2

	*respondent (woman) is spouse
	replace `var'wife =  `var'_spouse if gender_head == 1
	replace `var'husband = `var'_head if gender_head == 1
	macro shift
}


*sameethiniciy
gen sameethn = etnwife == etnhusband if !missing(etnwife) & !missing(etnhusband)
la var sameethn "Couple same ethnicity" 
la val sameethn yes_no

*status of parents
ren a_marrnonhh_statpar statpar
replace statpar = .a if statpar > 3 & !missing(statpar)
la var statpar "Land holdings of families before marriage"
la def statpar 1 "Wife's had more land" 2 "Equal" 3 "Husband's had more land"

gen wifemoreland = statpar == 1 if statpar != . //!missing(statpar)
la var wifemoreland "Family wife had more land"
gen husbmoreland = statpar == 3 if statpar != . //!missing(statpar)
la var husbmoreland "Family husband had more land"
la val wifemoreland husbmoreland yes_no

*dots and gifts
*items
foreach i of numlist 1/3{
	gen marrwiveprov`i' = .
	gen marrhusbprov`i' = .
	
	*respondent is head
	replace marrwiveprov`i' = a_marrheadprov`i' if gender_head == 2
	replace marrhusbprov`i' = a_marrspouseprov`i' if gender_head == 2

	*respondent is spouse
	replace marrwiveprov`i' =   a_marrspouseprov`i' if gender_head == 1
	replace marrhusbprov`i' = a_marrheadprov`i' if gender_head == 1
}


*value
foreach item in dot gifts{
	*dot value
	gen marrhusb`item' = .
	gen marrwive`item' = .

	*respondent is head
	replace marrwive`item' =  a_marrhead`item' if gender_head == 2
	replace marrhusb`item' =  a_marrspouse`item' if gender_head == 2

	*respondent is spouse
	replace marrwive`item' =  a_marrspouse`item' if gender_head == 1
	replace marrhusb`item'=  a_marrhead`item' if gender_head == 2

	replace marrhusb`item' = 0 if marrhusb`item' == . 
	replace marrhusb`item' = . if marrhusb`item' == 98
	
	replace marrwive`item' = 0 if marrwive`item' == .
	replace marrwive`item' = . if marrwive`item' == 98
}

ren a_marstat marstat 
la var marstat "Marital Status"


*marriage types
egen marcohab = anymatch(a_marrmarr_type?), values(1)
la var marcohab "Marriage: cohabiting"
egen marcivil = anymatch(a_marrmarr_type?), values(2)
la var marcivil "Marriage: Civil"
egen marreli = anymatch(a_marrmarr_type?), values(3)
la var marreli "Marriage: Religious"
egen martrad = anymatch(a_marrmarr_type?), values(4)
la var martrad "Marriage: Traditional"
la val marcohab marcivil marreli martrad yes_no

/* 
*contribution cash
la var contribcash "Contribution to cash income"

gen contribcashyn = contribcash >= 50 if !missing(contribcash)
la var contribcashyn "Contribution to cash income"
la def halfhalf 0 "Less than half" 1 "Half or more"
la val contribcashyn halfhalf

gen contribinkindyn = contribinkind >= 50 if !missing(contribinkind)
la var contribinkindyn "Major contribution in-kind-income"
la val contribinkindyn yes_no
 */

keep 	resp_id ROSTER_KEY KEY /// IDs
		agewife agehusband eduwife eduhusband sameethn  gender* ///demographics
		marstat marcohab marcivil marreli martrad /// marriage 
		statpar wifemoreland husbmoreland ///status	
		//contribcash contribinkind contribcashyn contribinkindyn ///contributions	


tempfile roster
save `roster'


*********************
**Baseline Conflict**
*********************
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

la def yes_no 0 "No" 1 "Yes"
la val victim* yes_no

ren group_id grp_id
keep vill_id grp_id hh_id victim*
tempfile baseline
save `baseline'

************************************************
**ACLED
************************************************

import delimited "$dataloc\acled\1997-01-01-2020-01-31-Democratic_Republic_of_Congo.csv", clear
keep if admin1 == "Sud-Kivu"
keep if inlist(event_type,"Battles","Violence against civilians")
drop if year > 2014

gen double acleddate= date(event_date,"DMY")
format acleddate %td
keep if acleddate > td(1jan2012)

gen acledbattles = event_type == "Battles"
gen acledviolence = event_type == "Violence against civilians"
ren fatalities acledfatalities

keep latitude longitude acleddate acledbattles acledviolence acledfatalities


tempfile acled_raw 
save `acled_raw'


use "$dataloc\endline\MFS II Phase B Questionnaire de MénageVersion Terrain.dta",clear
gen int_date = dofc(start)
format int_date %td
keep KEY gpsLatitude gpsLongitude int_date
drop if gpsLatitude == .
drop if gpsLongitude == .

cross using `acled_raw'
keep if  acleddate < int_date & acleddate > int_date - 365

geodist gpsLatitude gpsLongitude latitude longitude , generate(dist)
keep if dist <= 30 

forvalues i = 5(5)25{
	foreach var in acledbattles acledviolence acledfatalities{
		gen `var'`i' = `var' * dist <= `i'
	}
}
ren (acledbattles acledviolence acledfatalities) (acledbattles30 acledviolence30 acledfatalities30)


collapse (sum) acledbattles* acledviolence* acledfatalities*, by(KEY)

forvalues i = 5(5)30{
	la var acledbattles`i' "ACLED: Number of battles"
	la var acledviolence`i' "ACLED: Instances of violence against civilians"
	la var acledfatalities`i' "ACLED: Number of fatalities"
}

tempfile acled 
save `acled'

************************************************
**MERGE AND FINAL CLEAN
************************************************
use `main'
merge 1:1 KEY using `roster', keep(master match) gen(rostermerge)

replace vill_id = 999 if vill_id == .
replace grp_id = 999 if grp_id == .

*we don't merge in anything for households that we have no list experiment data for, so create fake, unique ids for those
clonevar hh_id_orig = hh_id
bys vill_id grp_id (hh_id): replace hh_id = 990 +  _n if numballs == .

merge 1:1 vill_id grp_id hh_id  using `baseline', keep(master match) gen(blmerge)
merge 1:1 KEY using `acled', keep(master match)  gen(aclmerge)

//assert gender == 2 if !missing(numballs)
//drop gender


*impute violence 
foreach var of varlist acledbattles* acledviolence* acledfatalities*{
		bys vill_id: egen miss = mean(`var')
		replace `var' = miss if missing(`var')
		drop miss
}


**generate binary vars
*ACLED
ds acled*
foreach var of varlist `r(varlist)' {
	su `var' if !missing(numballs) , d 
	gen `var'd = `var' >= r(p50) if !missing(`var')
	order `var'd, after(`var')
}

forvalues i = 5(5)30{
	la var acledbattles`i'd "ACLED: Number of battles"
	la var acledviolence`i'd "ACLED: Instances of violence against civilians"
	la var acledfatalities`i'd "ACLED: Number of fatalities"
}

la def median 0 "Less than median" 1 "More than median"
la val acled*d median


*empowerment
su atthusbtotal if !missing(numballs), d

gen atthusbtotalbin = atthusbtotal > r(p50) if !missing(atthusbtotal) 
la var atthusbtotalbin "Husband  empowerment attitudes"
order atthusbtotalbin, after(atthusbtotal)

su attwifetotal if !missing(numballs), d
gen attwifetotalbin = attwifetotal >= r(p50) if !missing(attwifetotal)
la var attwifetotalbin "Wife empowerment attitudes"
order attwifetotalbin, after(attwifetotal)

la def empowered 0 "Less empowered attidudes than median" 1 "More empowered attidudes than median" 
la val atthusbtotalbin attwifetotalbin empowered



save "$dataloc\clean\analysis.dta", replace




