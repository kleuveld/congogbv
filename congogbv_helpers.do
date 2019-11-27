
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




cap prog drop meandiffs
program meandiffs
	syntax varlist [using/], treatment(varlist) [by(varlist)] [coeffs(string)] [append]
	
	preserve
	local var `varlist'
	local ytitle: variable label `var'

	if length("`by'") == 0{
		gen by = 1
		local by by
		local key "overall"
		local xlabel 0.5 " ", noticks
	}
	else{
		levelsof `by', local(levels)
		local labname: value label `by'
		local xlabel
		foreach level in `levels'{
			local label: label `labname' `level'
			local tick = (`level' - 1)* 3 + 0.5
			local xlabel `xlabel' `tick' "`label'"
		}
		local xlabel `xlabel', noticks
		local key "`by'"
	}
	drop if missing(`by')
	collapse (mean) mean = `var' (sd) sd =`var' (count) n=`var', by(`treatment' `by')

 	generate ci_hi = mean + invttail(n-1,0.025)*(sd / sqrt(n))
	generate ci_lo = mean - invttail(n-1,0.025)*(sd / sqrt(n))
	

	clonevar subgroup = `by'
	replace subgroup = (`by' - 1) * 3 + `treatment'

	qui su subgroup
	local xmax = `r(max)' + 0.5

	graph twoway ///
		(scatter mean subgroup if `treatment' == 0, msymbol(circle)) ///
		(scatter mean subgroup if `treatment' == 1, msymbol(triangle)) ///
	 	(rcap ci_hi ci_lo subgroup), ///
		ylabel(0(0.5)3) ytitle(`ytitle') ///
		xtitle("`: variable label `by'' ")  ///
		xlabel(`xlabel') ///
		xscale(range(-0.5 `xmax'))  ///
		legend(order(1 "Control" 2 "Treatment" 3 "95% CI"))
	
	*export
	if length(`"`using'"') > 0{
		graph export `"`using'"', as(png) replace	
	}
	
	if length(`"`coeffs'"') > 0 {

		keep `treatment'  mean n sd `by'
		reshape wide mean n sd, i(`by') j(ball5)

		ren `by' group
		gen key = "`key'" + string(group)

		*calculate p(s)
		gen p = .
		forvalues i = 1/`=_N'{
			ttesti `=n0[`i']' `=mean0[`i']' `=sd0[`i']' `=n1[`i']' `=mean1[`i']' `=sd1[`i']', unequal
			replace p = r(p) in `i'
		}

		*generate helper vars
		gen n = n0 + n1
		gen incidence = mean1 - mean0
		gen incidence_pct = incidence * 100


		*format
		la val group
		format mean* incidence %9.2f
		format *_pct %9.0f
		format p %9.3f

		if length("`append'") > 0{
			append using `coeffs'
		}
		save `coeffs', replace
	}


 	restore

end
