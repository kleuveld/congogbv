
capture program drop balance_table
program define balance_table
	version  13
	syntax varlist [if] using/, Treatment(varlist) [Cluster(varlist)] [Sheet(string)] [Title(string) Weight(varlist)] [rawcsv]
	preserve
	if "`if'"!="" {
		qui keep `if'
	}

	**Manipulate input
	if "`weight'"=="" {
		tempvar equal_weight
		qui gen `equal_weight' = 1
		local weight `equal_weight'
	}
	**Create table
	tempname memhold
	tempname memhold_raw
	tempname raw 
	tempfile balance
	tempfile balance_raw
	qui postfile `memhold' str80 Variable Nall str12 MeanSDall N1 str12 MeanSD1 N0 str12 MeanSD0 str12 diff using "`balance'", replace
	qui postfile `memhold_raw' str32 var str80 varlabel nall meanall sdall n1 mean1 sd1 n0 mean0 sd0 diff p using "`balance_raw'", replace
	**Calculate statistics
	foreach var of varlist `varlist' {
		scalar Variable = `"`: var label `var''"'

		 *calculate statistics for full sample
		qui su `var' [aweight=`weight']
		scalar nall = `r(N)'
		scalar meanall = `r(mean)'
		scalar sdall = r(sd)

		*calculate statistics per treatment
		forvalues i = 0/1{
			qui su `var' if `treatment'== `i' [aweight=`weight']
			scalar n`i' = `r(N)'
			scalar mean`i' = `r(mean)'
			scalar sd`i' = `r(sd)'
		}

		foreach x in all 0 1{
			local mean`x'_f = string(mean`x',"%9.2f")
			local sd`x'_f = "("+ string(sd`x',"%9.2f") + ")"
		}
		
		**Calculate p-values with correction for clusters
		local aweight "[aweight=`weight']"
		local reg_weight "[aweight=`weight']"
		
	
		qui regress `var' `treatment' `reg_weight', vce(cluster `cluster')
		matrix table = r(table)
		scalar diff = table[1,1]
		scalar pvalue = table[4,1]

		*calculate difference
		local diff_f = string(diff,"%9.2f") + cond(pvalue < 0.1,"*","") + cond(pvalue < 0.05,"*","") + cond(pvalue < 0.01,"*","")
		
		post `memhold' (Variable) (nall) ("`meanall_f'") (n1) ("`mean1_f'") (n0) ("`mean0_f'") ("`diff_f'")
		post `memhold' ("")       (.)  ("`sdall_f'")   (.)  ("`sd1_f'")   (.)  ("`sd0_f'")   ("")
		
		post `memhold_raw' ("`var'") (Variable) (nall) (meanall) (sdall) (n1) (mean1) (sd1) (n0) (mean0) (sd0) (diff) (pvalue)

		scalar drop _all
	}

	postclose `memhold'
	postclose `memhold_raw'

	**Export table
	use "`balance'", clear
	
	foreach x in all 1 0{
		la var N`x' "N"
		la var MeanSD`x' "Mean"		
	}
	la var diff " "

	if regexm("`using'",".xlsx?$")==1 {
		n di as result "exporting excel"
		export excel "`using'", sheet("`sheet'") firstrow(variables) sheetreplace
	}
	if regexm("`using'",".tex$")==1 {
		n di as result "exporting tex"
		tempfile temp
		qui texsave using "`temp'", location(htb) autonumber varlabels replace frag  size(3) marker(tab:balance)  title(covariate balance) footnote("Standard Deviations in parantheses; *p $<$ 0.1,**p $<$ 0.05,***p $<$ 0.01")
		qui filefilter "`temp'" "`using'", from("&{(1)}&{(2)}&{(3)}&{(4)}&{(5)}&{(6)}&{(7)} \BStabularnewline") to("&{(1)}&{(2)}&{(3)}&{(4)}&{(5)}&{(6)}&{(7)} \BStabularnewline\n&\BSmulticolumn{2}{c}{All}&\BSmulticolumn{2}{c}{Treatment}&\BSmulticolumn{2}{c}{Control}&{(4)-(6)}\BStabularnewline") replace
		
	}
	if regexm("`using'",".csv$")==1 {
		n di as result "exporting csv"
		qui export delimited using "`using'", datafmt replace
	}

	if length("`raw'") > 0{
		n di as result  "exporting rawcsv"
		qui use "`balance_raw'", clear
		format mean* sd* %9.2f
		if regexm("`using'","(.*)\..*"){
			local usingraw = regexs(1) 
		}
		qui export delimited using "`usingraw'.csv", datafmt replace
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


*program to export tab to csv (didn;t like tabout)
cap prog drop tab2csv

program define tab2csv

syntax varlist(min=2 max=2) using

preserve


tokenize `varlist'
local var1 `1'
local var2 `2'
levelsof `var2',local(levels)

local collapse (sum)

*generate indicators foreach var2
foreach level in `levels'{
	tempvar `var2'`level'
	//local vallab`level': label (`var2') `level'
	gen ``var2'`level'' = `var2' == `level'
	local collapse `collapse' `var2'`level' = ``var2'`level''
	di "`collapse'"
}

*collapse all
tempvar n 
gen `n' = 1
collapse `collapse' (count) total = `n', by(`var1')

/*  labels don't get exported anyway
*labels
foreach level in `levels'{
	la var `var2'`level' "`vallab`level''"
}
 */

*generate total row
set obs `= _N + 1'
foreach var of varlist `var2'* total{
	su `var'
	replace `var' = r(sum) in `=_N'
}

*generate a key column to easily refer
tostring riskwife,gen(key)
replace key = "total" in `= _N'
order key, first


export delimited `using', datafmt replace
restore
end


