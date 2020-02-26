
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
		qui texsave using "`temp'", location(hp) autonumber varlabels replace frag  size(3) marker(tab:balance)  title(covariate balance) footnote("Standard Deviations in parantheses; *p $<$ 0.1,**p $<$ 0.05,***p $<$ 0.01")
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
		foreach var of varlist mean*{
			gen `var'_pct = `var' * 100
			format `var'_pct %9.0f
		}

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


*program to export tab to csv (I didn;t like tabout)
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


*regfig
*generates a graph of coefficients for a diff-in-diff regression
cap prog drop regfig
program define regfig
	syntax varlist(min=1) using/ , [pool]

	preserve

	*initialize a file that will hold the coefficients that will be plotted
	tempname memhold
	tempfile coeffs
	postfile `memhold' str80 Variable coeff ll ul series using `coeffs', replace

	*run the separate regressions, saving the outputs to the coeff file
	foreach var of varlist `varlist' {
		gen ball5_`var' = ball5 * `var'
		reg numballs ball5 `var' ball5_`var'
		matrix table = r(table)
		scalar coeff = table[1,3]
		scalar ll = table[5,3]
		scalar ul = table[6,3]
		splitlabel `var', l(15)
		post `memhold' (`"`: var label `var''"') (coeff) (ll) (ul) (1)

	}

	*parameters to use for the graph layout when there is NO pooled regression
	local legend off
	local series = 1
	local offset = 0

	if length("`pool'") > 0{
		reg numballs ball5 ball5_* `varlist'
		matrix table = r(table)
		local counter 1
		foreach var of varlist `varlist' {
			scalar coeff = table[1,1 +`counter']
			scalar ll = table[5,1 +`counter']
			scalar ul = table[6,1 +`counter']
			local counter = `counter' + 1
			post `memhold' (`"`: var label `var''"') (coeff) (ll) (ul) (2)
		}

		*parameters to use for the graph layout when there IS a pooled regression
		local series2 (scatter coeff graphpos if series == 2)
		local legend order(1 "Separate" 2 "Pooled")
		local series = 2
		local offset = 0.5

	}

	*generate a variable that holds the position of each coefficient on the X-axis
	postclose `memhold'
	use `coeffs', clear
	bys series: gen regno = _n
	gen graphpos = (regno - 1) * `series' + series


	*define the definition for the x-axis. Format: # `" "label line 1" "label line 2" "' etc.
	levelsof regno, local(levels)
	local xlabel
	foreach level in `levels'{
		*get the label
		local label `= Variable[`level']'		
		*define tick (where the label will be placed)
		*when there is a pooled regression, the tick ends up between the separate and pooled coefficients
		local tick = 1 + (`level' - 1)* `series' + `offset'
		local xlabel `xlabel' `tick'  `" "`label'" "'
	}
	local xlabel `xlabel', noticks valuelabel angle(90)

	*graph away!
	sort graphpos
	graph twoway ///
		(scatter coeff graphpos if series == 1) ///
		`series2' ///
		(rcap ul ll graphpos), /// 
		xlabel(`xlabel') xtitle("") ///
		yline(0,lpattern(dot)) legend(`legend')
	graph export `"`using'"', as(png) replace	

	restore
end


cap prog drop meandifftab
program define meandifftab
	syntax varlist(max=1) [using/] , by(varlist) treat(varname)
	preserve
	tempname memhold
	tempfile coeffs
	postfile `memhold' str32 var str80 varlabel  ///
		n0 meancontrol0  meantreat0 diff0 sediff0 pdiff0 diff0pct ///
		n1 meancontrol1  meantreat1 diff1 sediff1 pdiff1 diff1pct ///
		dd sedd pdd ///
		using `coeffs', replace

	
	foreach var of varlist `by'{ 

		assert `var' == 0 | `var' == 1 | missing(`var')

		*group 0
		forvalues i=0/1{
			reg `varlist' `treat' if `var' == `i'
			matrix table = r(table)

			count if `var' == `i'
			scalar n`i' = r(N)
			scalar meancontrol`i' = table[1,2] //intercept
			scalar meantreat`i' = meancontrol`i' + table[1,1] //intercept + treatmentdummy
			scalar diff`i' = table[1,1] //treatmentdummy
			scalar sediff`i' = table[2,1] //treatmentdummy
			scalar pdiff`i' = table[4,1] //p-value of treatment dummy
			scalar diff`i'pct = diff`i' * 100
		}



		*diff-in-diff
		reg `varlist' c.`treat'##i.`var'
		matrix table = r(table)
		scalar dd = table[1,5] //treatmentdummy*groupdummy
		scalar sedd = table[2,5]
		scalar pdd = table[4,5]

		post `memhold' ("`var'") (`"`: var label `var''"') ///
			(n0) (meancontrol0) (meantreat0) (diff0) (sediff0) (pdiff0) (diff0pct) ///
			(n1) (meancontrol1) (meantreat1) (diff1) (sediff1) (pdiff1) (diff1pct) ///
			(dd) (sedd) (pdd)
	}
	postclose `memhold'
	use `coeffs', clear

	foreach coeff in diff0 diff1 dd {
		gen star`coeff' = string(`coeff',"%9.2f") + cond(p`coeff' < 0.1,"*","") + cond(p`coeff' < 0.05,"*","") + cond(p`coeff' < 0.01,"*","")
	}
	


	format mean* diff* dd  %9.2f
	format diff* pdd se* %9.3f
	format n? *pct %9.0f

	qui export delimited using "`using'", datafmt replace
	restore
end



*splitlabel
*Splits variable labels using quotes, so graph labels don't end up too long.
cap prog drop splitlabel 
program splitlabel
	syntax varlist(min=1 max=1), [Length(integer 32)]
	
	*get the full variable label, and split it into words
	local longlabel: var label `varlist'
	tokenize "`longlabel'"
	
	*initialize a local, that will hold the label, split in "lines"; each line wrapped in quotes
	local splitlabel 

	while  "`1'"  != ""{
		*(re-)initialize a buffer local to hold each "line"
		local buffer
		
		*fill up the buffer with words until it reaches the length
		while  length("`buffer'") + length("`2'") < `length' &  "`1'"  != ""{
			local buffer "`buffer'`1' "
			macro shift
		}

		*add the buffer at the end of the split label, making sure that quotes are added.
		local splitlabel `" `splitlabel' "`buffer'" "'
	}
	
	*clean up unwanted spaces, and apply to variable
	local splitlabel = strtrim(`"`splitlabel'"' ) 
	la var `varlist' `"`splitlabel'"'
end



