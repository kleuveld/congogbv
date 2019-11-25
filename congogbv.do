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


