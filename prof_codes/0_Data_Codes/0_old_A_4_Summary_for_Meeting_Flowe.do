
import excel "${raw_data}mcc_mapping.xls", sheet("MCC List") firstrow clear
drop if mcc==""
save "${working_data}mcc_code.dta", replace

********************************************************************************
* Part 1.1: User SignedIn (Tables)
********************************************************************************

use "${working_data}UserSignedIn", clear	
keep userId date
sort userId date

* Total Number of Logins
by userId: gen N_logins=_N

* Number of Logins per Day
bysort  userId date: gen temp=_N
bysort  userId date: gen obs=_n
replace temp=. if obs>1
by  userId: gegen N_logins_per_day=mean(temp)
drop temp

* Number of Logins per Day
egen N_day=nvals(date), by(userId) 

* Span
by userId: gegen first=min(date)
by userId: gegen last=max(date)
gen Span=last-first+1

* Fraction of Days with Login
gen Frac_day_logins=(N_day/Span)*100			// questo mi sa che è sbagliato

* Days Beytween Logins
gduplicates drop userId date, force
by  userId: gen temp=date-date[_n-1]
by  userId: gegen N_days_between_logins=mean(temp)

gduplicates drop userId , force

global Which_Summary N mean p50 sd min p1 p5 p10 p25  p75 p90 p95 p99 max
global ToSumm N_logins N_logins_per_day N_day Span Frac_day_logins N_days_between_logins
tabstat $ToSumm, stats($Which_Summary) columns(statistics) save
tabstatmat temp
matrix temp = temp'
logout, save("${results}Summary_Logins.tex") dec(2) tex replace: mat li temp, noheader

********************************************************************************
* Part 1.2: User SignedIn (Figures)
********************************************************************************

	*Time Series Patterns
use "${working_data}UserSignedIn", clear	
keep userId date
sort userId date
egen N_users=nvals(userId), by(date) 
by userId (date): gen temp_first=1 if _n==1
by userId (date): gen temp_last=1 if _n==_N
bysort date: gegen N_first_users=sum(temp_first)
bysort date: gegen N_last_users=sum(temp_last)
gduplicates drop date, force

su date, meanonly
line N_first_users N_last_users date, graphregion(fcolor(white)) graphregion(lcolor(white)) ///
									legend(label(1 "Primo Login") ///
									label(2 "Ultimo Login")) ///
									legend(size(small))  legend( ring(0) ///
									position(1) cols(1)) ///
									lpattern(solid solid) scheme(s1color) ///
									lcolor("8 81 156"  "146 0 0") ///
									xtitle(" ")  ytitle("Numero_di_utenti") ///
									xlabel(`r(min)'(31)`r(max)', format(%td) ///
									labsize(vsmall) angle(45)) 
graph export  ${results}Login_primo_ultimo.png, replace	

* Day-of-week Patterns
use "${working_data}UserSignedIn", clear
gen Day=dow(date)
gduplicates drop userId date, force
bysort date: gen N_users=_N
gduplicates drop date, force
graph box N_users, over(Day, relabel(1 "Dom" 2 "Lun"  3 "Mar" 4 "Mer" 5 "Gio" 6 "Ven" 7 "Sab")) ///
						noout medtype(cline)  medline(lcolor(red)) ///
 graphregion(fcolor(white)) graphregion(lcolor(white)) 
graph export  ${results}Day_of_week.png, replace	

* Intraday Patterns
use "${working_data}UserSignedIn", clear
gen hour=substr(creationdateutc,12,2)
destring hour, replace
*replace hour=hour+2
*replace hour=0 if hour==24
*replace hour=1 if hour==25
gduplicates drop userId date hour, force
bysort date hour: gen N_users=_N
graph box N_users, over(hour) noout  medtype(cline)  ///
	medline(lcolor(red))  graphregion(fcolor(white)) graphregion(lcolor(white))
graph export  ${results}Hour_of_Day.png, replace	
  
* Heatmap
use "${working_data}UserSignedIn", clear	
keep userId date
sort userId date
bysort userId date: gen Obs=_N
gduplicates drop userId date, force
bysort userId: gen N_logins=_N
gsort N_logins userId date
gen temp=0
replace temp=1 if userId!=userId[_n-1]

gen ID=sum(temp)
keep date ID Obs
xtset ID date
tsfill, full
replace Obs=0 if Obs==.
replace Obs=1 if Obs>=1
*heatplot Obs ID date, discrete 
su date, meanonly

heatplot Obs ID date, colors(magma, reverse)  ybins(2000) ///
		xlabel(`r(min)'(31)`r(max)', format(%td) labsize(vsmall) ///
		angle(45)) graphregion(fcolor(white)) graphregion(lcolor(white))

********************************************************************************
* Part 2.1: User SignedIn (Tables)
********************************************************************************
use "${working_data}UserDataValidated", clear	
replace province=substr(province,2,strlen(province)-2)
egen N_users=nvals(userid), by(province) 
sort N_users
keep N_users province
gduplicates drop province, force
gsort -N_users
egen temp=sum(N_users)
gen Fraction=N_users/temp 
keep province Fraction
keep if Fraction>=0.01
graph bar Fraction, over(province, label(labsize(small) ) ///
	sort((mean) Fraction))  graphregion(fcolor(white)) graphregion(lcolor(white)) ytitle("")
graph export  ${results}Distribuzione_utenti.png, replace		

********************************************************************************
* Part 3.1: Transactions (Summary Stats)
********************************************************************************

use "${working_data}Transactions_for_analysis", clear
sort userId date

gen sign_amount=amount
replace sign_amount=-amount if income=="false" | direction==1
drop if sign_amount==.
gen temp_INflow=sign_amount>0
gen temp_OUTflow=sign_amount<0
gen INflow=sign_amount if sign_amount>0
gen OUTflow=sign_amount if sign_amount<0
replace OUTflow=-OUTflow
replace type=substr(type,2,strlen(type)-2)
save "${working_data}Transactions_for_analysis_plot", replace

	*Need to double check tab direction type_tcreated, tab type, tab type_tcreated isCompensated
gen is_card=1				if type=="Card" | type_tcreated==7 | type_tcreated==3
gen card_amount=sign_amount if type=="Card" | type_tcreated==7 | type_tcreated==3
replace card_amount=. if card_amount>0
by userId: gegen card_user=max(is_card)

* Dollar Amount Compensated
by userId: gegen temp_Doll_Card=sum(card_amount)
by userId: gegen temp_temp_Compensated=sum(card_amount) if isCompensated=="true"
by userId: gegen temp_Compensated=max(temp_temp_Compensated)
replace temp_Compensated=0 if card_user==1 & temp_Compensated==.
by userId: gen Frac_D_Comp=temp_Compensated/temp_Doll_Card
drop temp_Doll_Card temp_temp_Compensated temp_Compensated

* N transactions Compensated
by userId: gegen temp_N_Card=sum(is_card)
by userId: gegen temp_temp_N_Compensated=sum(is_card) if isCompensated=="true"
by userId: gegen temp_N_Compensated=max(temp_temp_N_Compensated)
replace temp_N_Compensated=0 if card_user==1 & temp_N_Compensated==.
by userId: gen Frac_N_Comp=temp_N_Compensated/temp_N_Card
drop temp_N_Card temp_temp_N_Compensated temp_N_Compensated

* Number Total of Inflow and Outflow transactions
by userId: gegen N_Tot_IN=sum(temp_INflow)
by userId: gegen N_Tot_OUT=sum(temp_OUTflow)

* Dollar Total Inflow and Outflow transactions
by userId: gegen Doll_Tot_IN=sum(INflow)
by userId: gegen Doll_Tot_OUT=sum(OUTflow)

* Dollar Avg Inflow and Outflow transactions
by userId: gegen Doll_Avg_IN=mean(INflow)
by userId: gegen Doll_Avg_OUT=mean(OUTflow)

* Number of Days with at least a transaction
egen N_day=nvals(date), by(userId) 

* Span
by userId: gegen first=min(date)
by userId: gegen last=max(date)
gen Span=last-first+1

* Fraction of Days with Transaction
gen Frac_day=(N_day/Span)*100

* Days Beytween Logins
gduplicates drop userId date, force
by  userId: gen temp=date-date[_n-1]
by  userId: gegen N_days_betweens=mean(temp)

gduplicates drop userId , force

global Which_Summary N mean p50 sd min p1 p5 p10 p25  p75 p90 p95 p99 max
global ToSumm N_Tot* Doll_Tot* Doll_Avg* N_day Span Frac_day N_days_betweens Frac_D_Comp Frac_N_Comp
tabstat $ToSumm, stats($Which_Summary) columns(statistics) save
tabstatmat temp
matrix temp = temp'
logout, save("${results}Summary_Transactions.tex") dec(2) tex replace: mat li temp, noheader


********************************************************************************
* Part 3.1: Carbon Footprint
********************************************************************************

use "${working_data}Transactions_for_analysis_plot", clear
replace carbonEmissionInGrams=carbonEmissionInGrams/100
keep if sign_amount<0
replace sign_amount=-sign_amount
keep if type=="Card" | type_tcreated==7 | type_tcreated==3
replace merchantExpenseCategory=substr(merchantExpenseCategory,2,strlen(merchantExpenseCategory)-2)
replace mcc=substr(mcc,2,strlen(mcc)-2)
replace mcc=merchantExpenseCategory if mcc==""
drop if mcc==""

merge m:1 mcc using "${working_data}mcc_code.dta"
keep if _merge==3

	/*
	keep mcc category descr
	bysort mcc category: gen N_category=_N
	gduplicates drop mcc category, force
	bysort mcc: gen N_Tot_Category=_N
	gsort -N_Tot_Category mcc
	format descr %50s
    replace descr=substr(descr,1,40)
	replace descr = subinstr(descr, "&", "et",.) 
	replace category = subinstr(category, "_", " ",.) 
	dataout, save("${results}Category.tex") tex replace excel word dec(2)
	*/
	
	bysort descr: gegen D_Tot=sum(sign_amount)
	bysort descr: gen   N_Tot=_N
	
	/*
	gduplicates drop descr, force
	keep descr D_Tot N_Tot
	gsort D_Tot
	gsort -D_Tot
	replace descr = subinstr(descr, "&", "et",.) 
	dataout, save("${results}What_spent_on.tex") tex replace excel word dec(2)
	*/

keep amount carbonEmissionInGrams mcc category sign_amount descr N_Tot D_Tot
format descr %50s

gen temp=sign_amount
sort temp 
order temp amount
forvalues x=0(10)1000{
	replace amount=`x'+10 if temp>`x'
	} 
sort temp

sort amount mcc carbonEmissionInGrams

bysort amount: gegen mu_amount=mean(carbonEmissionInGrams)
bysort amount: gegen sd_amount=sd(carbonEmissionInGrams)
bysort amount: gen ind_amount=_n
*scatter sd_amount amount if ind_amount==1 & amount<550, msize(tiny)
binscatter sd_amount amount if ind_amount==1 & amount<300, nquantiles(50)   ytitle("Std carbonEmissionInGrams /100 ")
graph export  ${results}Variation_Emissions_within_amount.png, replace

gen Emission_per_dollar=carbonEmissionInGrams/amount
bysort mcc: gegen mu_mcc=mean(Emission_per_dollar)
bysort mcc: gegen sd_mcc=sd(Emission_per_dollar)

	/*
	bysort mcc: gegen mu_Emission_per_dollar=mean(Emission_per_dollar)
	bysort mcc: gegen std_Emission_per_dollar=sd(Emission_per_dollar)
	gduplicates drop descr, force
	keep descr   mu_Emission_per_dollar 
	gsort -mu_Emission_per_dollar
	replace descr = subinstr(descr, "&", "et",.) 
	dataout, save("${results}Most_Pollution_per_dollar.tex") tex replace excel word dec(2)
	*/

	/*
bysort mcc: gegen sd_mcc=sd(temp)
bysort mcc: gen ind_mcc=_n
destring mcc, force replace
scatter sd_mcc mcc if ind_mcc==1, msize(tiny)
	*/

		*For this you should round at 10 dollars
bysort amount mcc: gegen mu_amount_mcc=mean(carbonEmissionInGrams)
bysort amount mcc: gegen sd_amount_mcc=sd(carbonEmissionInGrams)
bysort amount mcc: gen Nobs=_N
keep mu_amount_mcc sd_amount_mcc amount mcc Nobs
sort amount mcc sd_amount_mcc
gduplicates drop amount mcc, force

*replace sd_amount_mcc=500 if sd_amount_mcc>500
heatplot sd_amount_mcc amount mcc if amount<200 , colors(magma, reverse) ybins(20) xlabel(, labsize(half_tiny) angle(90)) graphregion(fcolor(white)) graphregion(lcolor(white))
graph export  ${results}Heat_Kg_mcc_amount.png, replace	

gen Relative=sd_amount_mcc/mu_amount_mc
heatplot Relative amount mcc if amount<=200, colors(magma, reverse) ybins(20) xlabel(, labsize(half_tiny) angle(90)) graphregion(fcolor(white)) graphregion(lcolor(white))
graph export  ${results}Heat_Relative_mcc_amount.png, replace		

bysort mcc: gegen Popular_mcc=sum(Nobs)
foreach mcc_loop in 5411 5812 5999 5816{
	scatter sd_amount_mcc  amount if mcc=="`mcc_loop'" & amount<=200, title("`mcc_loop'") name("p`mcc_loop'", replace)
	}
graph combine p5411 p5812 p5999 p5816, cols(2)
graph export  "${results}Breakdown_Heat_by_Popularity.png", replace	

foreach mcc_loop in 5411 5812 5999 5816{
	scatter Relative  amount if mcc=="`mcc_loop'" & amount<=200, title("`mcc_loop'") name("p`mcc_loop'", replace)
	}
graph combine p5411 p5812 p5999 p5816, cols(2)
graph export  "${results}Breakdown_Heat_Relative_by_Popularity.png", replace	

			
********************************************************************************
* Part 3.2: Transactions  (Figures)
********************************************************************************

	*Time Series Patterns
use "${working_data}Transactions_for_analysis_plot", clear
gduplicates drop userId date, force
by userId (date): gen temp_first=1 if _n==1
by userId (date): gen temp_last=1 if _n==_N
bysort date: gegen N_first_users=sum(temp_first)
bysort date: gegen N_last_users=sum(temp_last)
egen N_users=nvals(userId), by(date) 
gduplicates drop date, force

su date, meanonly 
line N_first_users N_last_users date, graphregion(fcolor(white)) graphregion(lcolor(white)) ///
									legend(label(1 "Prima Transazione") label(2 "Ultima Transazione")) legend(size(small))  legend( ring(0) position(1) cols(1)) ///
									lpattern(solid solid) scheme(s1color) lcolor("8 81 156"  "146 0 0") ///
									xtitle(" ")  ytitle("Numero_di_utenti")  xlabel(`r(min)'(31)`r(max)', format(%td) labsize(vsmall) angle(45))
graph export  ${results}Transazione_primo_ultimo.png, replace	

su date, meanonly 
line N_users date, graphregion(fcolor(white)) graphregion(lcolor(white)) ///
									legend(label(1 "Prima Transazione") label(2 "Ultima Transazione")) legend(size(small))  legend( ring(0) position(1) cols(1)) ///
									lpattern(solid solid) scheme(s1color) lcolor("8 81 156"  "146 0 0") ///
									xtitle(" ")  ytitle("Numero_di_utenti")  xlabel(`r(min)'(31)`r(max)', format(%td) labsize(vsmall) angle(45))
graph export  ${results}Transazione_Numero.png, replace

	*Heatmap
use "${working_data}Transactions_for_analysis_plot", clear	
gen Out=sign_amount if sign_amount<0
gen In=sign_amount if sign_amount>0
replace Out=-10000 if sign_amount<=-10000
replace Out=-Out
replace In=10000   if sign_amount>=10000

bysort userId date: gegen Tot_Out=sum(Out)
bysort userId date: gegen Tot_In=sum(In)
gen 						temp=Tot_Out+Tot_In
bysort userId	  : gegen Tot_sort=sum(temp)

keep userId date Tot*
gduplicates drop userId date, force
gsort Tot_sort userId date
gen temp=0
replace temp=1 if userId!=userId[_n-1]

gen ID=sum(temp)
keep date ID Tot*
xtset ID date
tsfill, full
replace Tot_sort=0 if Tot_sort==.
replace Tot_sort=1 if Tot_sort>0
su date, meanonly
heatplot Tot_sort ID date, colors(magma, reverse)  levels(5) ///
ybins(1000)  xlabel(`r(min)'(31)`r(max)', format(%td) labsize(vsmall) angle(45)) ///
graphregion(fcolor(white)) graphregion(lcolor(white))


use "${working_data}Transactions_for_analysis_plot", clear
gen Out=sign_amount if sign_amount<0
gen In=sign_amount if sign_amount>0
replace Out=-10000 if sign_amount<=-10000
replace In=10000   if sign_amount>=10000

bysort date: gegen Tot_Outflow=sum(Out)
bysort date: gegen Tot_Inflow=sum(In)
gduplicates drop date, force
su date, meanonly
line Tot_Outflow Tot_Inflow date , ///
			graphregion(fcolor(white)) graphregion(lcolor(white)) ///
			legend(label(1 "Out") label(2 "In")) legend(size(small)) ///
			legend( ring(0) position(1) cols(1)) ///
			lpattern(solid solid) scheme(s1color) lcolor("8 81 156"  "146 0 0") ///
			xtitle(" ")  ytitle("Total Euros")  xlabel(`r(min)'(31)`r(max)', ///
			format(%td) labsize(vsmall) angle(45)) 
graph export  ${results}Totale_In_Out.png, replace	

	*Day-of-week Patterns
use "${working_data}Transactions_for_analysis_plot", clear
gen Out=sign_amount if sign_amount<0
gen In=sign_amount if sign_amount>0
replace Out=-10000 if sign_amount<=-10000
replace Out=-Out
replace In=10000   if sign_amount>=10000

gen Day=dow(date)
bysort date: gegen Tot_Outflow=sum(Out)
bysort date: gegen Tot_Inflow=sum(In)

gduplicates drop date, force
graph box Tot_Outflow,  over(Day, relabel(1 "Dom" 2 "Lun"  3 "Mar" 4 "Mer" 5 "Gio" 6 "Ven" 7 "Sab")) noout medtype(cline)  medline(lcolor(red)) ///
 graphregion(fcolor(white)) graphregion(lcolor(white)) 
graph export  ${results}Out_day_of_week.png, replace	


graph box Tot_Inflow,  over(Day, relabel(1 "Dom" 2 "Lun"  3 "Mar" 4 "Mer" 5 "Gio" 6 "Ven" 7 "Sab")) noout medtype(cline)  medline(lcolor(red)) ///
 graphregion(fcolor(white)) graphregion(lcolor(white)) 
graph export  ${results}In_day_of_week.png, replace	


********************************************************************************
* Part 3.3: Carbon footprint across individuals
********************************************************************************

use "${working_data}Transactions_for_analysis_plot", clear
replace carbonEmissionInGrams=carbonEmissionInGrams/100
keep if sign_amount<0
replace sign_amount=-sign_amount
keep if type=="Card" | type_tcreated==7 | type_tcreated==3
replace merchantExpenseCategory= ///
		substr(merchantExpenseCategory,2,strlen(merchantExpenseCategory)-2)
replace mcc=substr(mcc,2,strlen(mcc)-2)
replace mcc=merchantExpenseCategory if mcc==""
drop if mcc==""

merge m:1 mcc using "${working_data}mcc_code.dta"
keep if _merge==3

bysort userId: gegen A_user_Tot=sum(sign_amount)
bysort userId: gegen C_user_Tot=sum(carbonEmissionInGrams)
gen user_ratio=C_user_Tot/A_user_Tot


bysort userId mcc: gegen A_user_Tot_mcc=sum(sign_amount)
bysort userId mcc: gegen C_user_Tot_mcc=sum(carbonEmissionInGrams)
bysort userId mcc: gen user_ratio_mcc=C_user_Tot_mcc/A_user_Tot_mcc


preserve 
gduplicates drop userId mcc, force
bysort mcc: gegen sd_ratio_mcc=sd(user_ratio_mcc)
bysort mcc: gegen A_tot_mcc=sum(A_user_Tot_mcc)
bysort mcc: gegen tot_users_mcc=nvals(userId)
gduplicates drop mcc, force
keep mcc sd_ratio_mcc A_tot_mcc tot_users_mcc
keep if tot_users_mcc>20 /* This is actually quite important */ 
keep if sd_ratio_mcc!=.
gsort  sd_ratio_mcc -A_tot_mcc
gen obs=_n
gen Obs=_N
keep if obs==1 | obs==Obs
gen sd_dispertion="Low" if obs==1
replace sd_dispertion="High" if obs==Obs
keep mcc sd_dispertion sd_ratio_mcc tot_users_mcc
save ${wdata}mcc_dispersion_for_merge.dta, replace 
restore
drop _merge
merge m:1 mcc using mcc_dispersion_for_merge.dta


gduplicates drop  userId mcc, force

gstats winsor user_ratio_mcc,  cut(2 98) replace 
hist user_ratio_mcc if sd_dispertion=="Low",    scheme(s1color) ///
	xscale(range(0(1)12)) xlabel(0(1)12) ///
		xtitle("Ratio of Total Carbon Emissions Over Spending")
graph export  ${results}individual_level_Ratio_Carbon_to_/*
								*/Spending_financial_institutions.png, replace	

gstats winsor user_ratio_mcc,  cut(2 98) replace 
hist user_ratio_mcc if sd_dispertion=="High",    scheme(s1color) ///
	xscale(range(0(1)12)) xlabel(0(1)12) ///
		xtitle("Ratio of Total Carbon Emissions Over Spending")
graph export  ${results}individual_level_Ratio_Carbon_to_/*
								*/Spending_Drinking.png, replace	


gduplicates drop  userId, force
								
gstats winsor user_ratio, cut(2 98) replace 
hist user_ratio, scheme(s1color) ///
	xscale(range(0(1)12)) xlabel(0(1)12) ///
	xtitle("Ratio of Total Carbon Emissions Over Spending") xscale(range(2(1)10))
graph export  ${results}individual_level_Ratio_Carbon_to_Spending.png, replace	




********************************************************************************
* Part 3.4: Carbon footprint within individuals but across time
********************************************************************************


use "${working_data}Transactions_for_analysis_plot", clear
replace carbonEmissionInGrams=carbonEmissionInGrams/100
keep if sign_amount<0
replace sign_amount=-sign_amount
keep if type=="Card" | type_tcreated==7 | type_tcreated==3
replace merchantExpenseCategory= ///
		substr(merchantExpenseCategory,2,strlen(merchantExpenseCategory)-2)
replace mcc=substr(mcc,2,strlen(mcc)-2)
replace mcc=merchantExpenseCategory if mcc==""
drop if mcc==""

merge m:1 mcc using "${working_data}mcc_code.dta"
keep if _merge==3

gen monthly_date=mofd(date)
format monthly_date %tm

bysort userId monthly_date: gegen C_user_Tot=sum(carbonEmissionInGrams)
bysort userId monthly_date: gegen A_user_Tot=sum(sign_amount)
keep userId monthly_date C_user_Tot A_user_Tot
gduplicates drop userId monthly_date, force 
gen C_over_A_user_Tot=C_user_Tot/A_user_Tot
gegen user_new_id=group(userId)
keep user_new_id monthly_date C_over_A_user_Tot
order  user_new_id monthly_date C_over_A_user_Tot
bysort user_new_id: gen OBS=_N
keep if OBS>6
bysort user_new_id: gegen sd_C_over_A_user_Tot=sd(C_over_A_user_Tot)
bysort user_new_id: gegen m_C_over_A_user_Tot=mean(C_over_A_user_Tot)

gduplicates drop user_new_id, force
keep user_new_id sd_C_over_A_user_Tot m_C_over_A_user_Tot
gegen sd_overall=sd(m_C_over_A_user_Tot)
global sd_overall=sd_overall
kdensity sd_C_over_A_user_Tot , xline(${sd_overall}) scheme(s1color) ///
	xtitle("Cross-sectional Dispersion in individual-level Carbon-emission Standard Deviation")
graph export  ${results}Cross_sectional_Dispersion_in_individual_level_Carbon_emission_SD.png, replace	
gsort sd_C_over_A_user_Tot 
gen ts_greater_than_cs=sd_C_over_A_user_Tot>sd_overall
reg ts_greater_than_cs



********************************************************************************
* Part 3.5: Carbon footprint and offsetting
********************************************************************************


use "${working_data}Transactions_for_analysis_plot", clear
replace carbonEmissionInGrams=carbonEmissionInGrams/100
keep if sign_amount<0
replace sign_amount=-sign_amount
keep if type=="Card" | type_tcreated==7 | type_tcreated==3
replace merchantExpenseCategory= ///
		substr(merchantExpenseCategory,2,strlen(merchantExpenseCategory)-2)
replace mcc=substr(mcc,2,strlen(mcc)-2)
replace mcc=merchantExpenseCategory if mcc==""
drop if mcc==""

merge m:1 mcc using "${working_data}mcc_code.dta"
keep if _merge==3

gen monthly_date=mofd(date)
format monthly_date %tm

bysort userId monthly_date isCompensated: gegen C_user_Tot=sum(carbonEmissionInGrams)
bysort userId monthly_date isCompensated: gegen A_user_Tot=sum(sign_amount)
keep userId monthly_date isCompensated C_user_Tot A_user_Tot
gen C_over_A_user_Tot=C_user_Tot/A_user_Tot
gstats winsor C_over_A_user_Tot, cut(2 98)
gen dummy_comp=0 if isCompensated=="false"
replace dummy_comp=1 if isCompensated=="true"
reghdfe C_over_A_user_Tot dummy_comp, absorb(userId monthly_date) 
reghdfe C_over_A_user_Tot dummy_comp, absorb(userId monthly_date) ///
					cluster(userId )
				



















