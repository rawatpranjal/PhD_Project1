
********************************************************************************
* Part 1: Create the Panels
********************************************************************************

use "${working_data}Label_Event_content_NOPANEL_full_new", clear
drop if Event=="OobRequestCreated"

global Tables_Loop ///
	UserSignedIn UserDataValidated ///
	EcoBalanceDataComputed TransactionCategorized TransactionConfirmed TransactionCreated TreeAcquired  ///
	ActivityCompleted NudgeCreated NudgeRead ProfileClosureRequested 

	global Tables_Loop  UserDataValidated 
	
foreach Tables in $Tables_Loop{
	use "${raw_data}part-0001_new_mac.dta", clear
	display "`Tables'"
	rename integrationevent label
	replace clearedbody=clearedbody+v6+v7+v8+v9+v10+v11+v12+v13+v14
	rename clearedbody event
	drop v6-v14
	keep if label=="`Tables'"
	
		if "`Tables'"=="UserSignedIn"{
			global Fields Label userId id creationDate deviceCode  mobileOS 
			}	

		*if "`Tables'"=="RiskLevelEvaluated"{
		*	global Fields userId id gender creationDate birthCountry birthDate birthPlace ///
        *   domicileData personalData residenceData userData
		*	}
		
		if "`Tables'"=="UserDataValidated"{
			global Fields id addressNumber address country documentData expiryDate province releaseCountry ///
				  releaseDate releasePlace releaseProvince type zipCode residence
			}
		
		if "`Tables'"=="EcoBalanceDataComputed"{
			global Fields Label userId    rowId         creationDate amount ///
			carbonEmissionInGrams carbonSocialCost isCompensated mcc
			}	
			
		if "`Tables'"=="TransactionCreated"{
			global Fields Label userId id transactionId creationDate amount ///
			carbonEmissionInGrams carbonSocialCost isCompensated merchantExpenseCategory ///
			direction isWireTransferBetweenP0Users isWireTransferExecuted type valueDate
			}	
	
		if "`Tables'"=="TransactionCategorized"{
			global Fields Label userId byUser rowId category creationDate confidence
			*careful about Frequency...
			}
			
		if "`Tables'"=="TransactionConfirmed"{
			global Fields Label userId        rowId category  creationDate amount income operationDate  ///
			type valueDate partialAmount mcc 
			}
			
		if "`Tables'"=="TreeAcquired"{
			global Fields Label userId compensatedCO2 creationDate id sowingDate treeId type
			}	
			
		if "`Tables'"=="ActivityCompleted"{
			global Fields Label userId activityId category ctaRef description ///
			gems name points referenceItem type silent creationDate 
			}	
		if "`Tables'"=="NudgeCreated"{
			global Fields Label userId nudgeId message title nudge NotificationChannel NotificationType topic ///
			creationDate
			}	
		if "`Tables'"=="NudgeRead"{
			global Fields Label userId nudgeCreationDate title nudgeId creationDate
			}
		if "`Tables'"=="ProfileClosureRequested"{
			global Fields Label userId reason requestMode tutorUserId userNote contractId creationDate
			}		

	*keep label creationdate enqueueddatetime event
	keep userid label creationdateutc  event
	gen temp_date=substr(creationdate,1,10)
	gen date=date(temp_date, "YMD")
	format date %td
	keep label date event creationdateutc userid 
	replace event = subinstr(event,"{","",.)
	replace event = subinstr(event,"}","",.)
	split event, parse(", ")
	drop event
	foreach var of varlist event*{
		replace `var' = substr(`var',2,.)
		}
	foreach var of varlist event*{
		replace `var'= subinstr(`var',"\","",.)
		}
				
	foreach field in $Fields{
		global new_var  "`field'"
		gen ${new_var}="."
		gen temp="`field'"
		gen temp_Length=length(temp)
		global N_char=temp_Length[1]+5
		foreach var of varlist event*{
			gen temp_`var'=strpos(`var',"`field'" )
			}
			
		foreach var of varlist event*{
				replace ${new_var}=`var' if temp_`var'>0 & ${new_var}=="."
			}
			
		drop temp*	
		replace ${new_var}=substr(${new_var},${N_char},.)
		capture: destring ${new_var}, replace 	
		}
	drop event*	
	capture drop label Label
	save "${working_data}`Tables'", replace	
	}



********************************************************************************
* Part 2: Very Preliminary View
********************************************************************************

* User-level
use "${working_data}UserSignedIn", clear	
keep userId date
sort userId date
by userId: gegen first=min(date)
by userId: gegen last=max(date)
gen Difference=last-first+1
gduplicates drop userId date, force
by userId: gen Obs=_N
gduplicates drop userId, force
gen Frac=Obs/Difference
summ Frac if Difference>90, det
summ Obs if Difference>90, det

use "${working_data}UserDataValidated", clear	
bysort date: gen Obs=_N
gduplicates drop date, force
line Obs date


* Sustainable Behavior

use "${working_data}TransactionCreated", clear 
	/*This dataset goes from June 2020 to 12 May 2021.
	 has transactionId and direction */
gen Label="Transaction_Created"
order Label, first
destring carbonEmissionInGrams, force replace
destring carbonSocialCost, force replace
append using "${working_data}EcoBalanceDataComputed"
	/*This dataset goes from 13 May 2021 to now
	 has rowId and Nodirection */ 
sort date
order Label creationdateutc creationDate date userId transactionId rowId ///
amount carbonEmissionInGrams carbonSocialCost isCompensated direction type merchantExpenseCategory mcc ///
id
format creationdateutc %15s
format creationDate    %15s



use "${working_data}TransactionCategorized", clear	
order userId creationDate creationdateutc date rowId category byUser
format creationdateutc %15s
format creationDate    %15s

use "${working_data}TransactionConfirmed", clear
	/*This dataset goes from 13 May 2021 to now
	 has to be merged with EcoBalanceDataComputed */
order userId creationdateutc creationDate date rowId category amount income mcc
format creationdateutc %15s
format creationDate    %15s

use "${working_data}TreeAcquired", clear	
sort date
summ compensatedCO2 
tab type

	/*	
use "${working_data}TransactionConfirmed", clear
	global Rename creationdateutc date category creationDate amount ///
	income operationDate type valueDate partialAmount mcc
	foreach var of varlist $Rename{
		rename `var' `var'_t
		}
	merge 1:1 rowId userId using  ${working_data}EcoBalanceDataComputed	
	order userId rowId creationdateutc* creationDate* date* amount*  mcc* carbonEmissionInGrams carbonSocialCost isCompensated
	tab type _merge /*Only for card transactions we have ecobalance*/
	*/

	use "${working_data}TransactionConfirmed", clear
	merge 1:1 rowId userId using  ${working_data}EcoBalanceDataComputed
	rename _merge merge_trans_ecobalance
	save "${working_data}EcoBalanceDataComputed_for_append", replace
	
use "${working_data}TransactionCreated", clear 
gen Label="Transaction_Created"
destring type, replace
destring carbonEmissionInGrams, force replace
destring carbonSocialCost, force replace
rename type type_tcreated
append using "${working_data}EcoBalanceDataComputed_for_append"
sort date
order Label creationdateutc creationDate date userId transactionId rowId ///
amount direction income type type_tcreated carbonEmissionInGrams carbonSocialCost isCompensated  ///
 merchantExpenseCategory mcc category ///
id
format creationdateutc %15s
format creationDate    %15s
sort date	
save "${working_data}Transactions_for_analysis", replace

use "${working_data}Transactions_for_analysis", clear
sort userId date
gen temp=strlen(type)
replace type=substr(type,2,strlen(type)-2)
replace category=substr(category,2,strlen(category)-2)
keep if category=="CULTURE_AND_FUN"
sort amount carbonE date

keep if type=="Card" | type_tcreated==3 
keep if isCompensated=="true" | isCompensated=="false"
replace direction=1 if income=="false"
keep if direction==1
keep userId date amount carbonEmissionInGrams  isCompensated
gen     dummy_compensated=0
replace dummy_compensated=1 if isCompensated=="true"
gsort userId


by userId: gen Obs=_N
by userId: gen obs=_n

by userId: gegen Tot_compensated=sum(dummy_compensated)
bro if Tot_compensated!=Obs & Tot_compensated!=0

by userId: gegen Max_dummy=max(dummy_compensated)
gen no_compensation=Max_dummy-dummy_compensated



		
sort userId date	
bysort userId: gen N_trans=_N 	
bysort userId: gen n_obs=_n
tab N_trans if n_obs==1
	
bysort userId (date): gen temp_first=date if _n==1	
bysort userId (date): gen temp_last=date if _n==_N	
bysort userId : gegen first=max(temp_first)
bysort userId : gegen last=max(temp_last)
		
gen N_days=last-first		
summ N_days if n_obs==1, det
	
gduplicates drop userId, force
	
* Other Stuff	
use "${working_data}ActivityCompleted", clear	
sort date

use "${working_data}NudgeCreated", clear	
sort date

use "${working_data}NudgeRead", clear	
sort date


* 

use "${working_data}UserSignedIn", clear	
keep userId 
gduplicates drop
gen userid=substr(userId,2,36)
keep userid
save "${working_data}unique_id_UserSignedIn", replace

use "${working_data}Transactions_for_analysis", clear

use "${working_data}Transactions_for_analysis", clear
bysort userId: gen Obs=_N
gduplicates drop userId, force

keep userId 
gduplicates drop
gen userid=substr(userId,2,36)
keep userid
save "${working_data}unique_id_Transactions_for_analysis", replace

use "${working_data}UserDataValidated", clear
gduplicates drop userid, force	
merge 1:1 userid using  "${working_data}unique_id_UserSignedIn"
drop _merge
merge 1:1 userid using  "${working_data}unique_id_Transactions_for_analysis"





use "${working_data}Transactions_for_analysis", clear
outsheet using "${working_data}Transactions_for_analysis.csv", comma replace

keep userId amount direction carbonEmissionInGrams isCompensated
gen compensation=isCompensated=="true"
keep if direction==1
drop if carbonEmissionInGrams==.
bysort userId isCompensated: gegen sum_amount_=sum(amount)
bysort userId isCompensated: gegen sum_carbonEmissionInGrams_=sum(carbonEmissionInGrams)

keep userId sum_* compensation
gduplicates drop userId compensation, force
reshape wide sum_amount sum_carbonEmissionInGrams , i(userId) j(compensation)
foreach var in 0 1 {	
	gen ratio_emission_amount_`var'=sum_carbonEmissionInGrams_`var'/sum_amount_`var'
} 

foreach var in sum_amount sum_carbonEmissionInGrams {
	foreach gg in 0 1 {
	replace `var'_`gg'=0 if `var'_`gg'==.	
		}
	}
		
gen sum_amount=sum_amount_0+sum_amount_1
gen sum_carbonEmissionInGrams=sum_carbonEmissionInGrams_0+sum_carbonEmissionInGrams_1
gen ratio_emission_amount=sum_carbonEmissionInGrams/sum_amount
gstats winsor ratio_emission_amount, cut(2 98) replace 
hist ratio_emission_amount

gduplicates drop userId, force 
twoway (kdensity ratio_emission_amount) (kdensity ratio_emission_amount_0) ///
		(kdensity ratio_emission_amount_1)

gen log_sum_amount_0=log(1+sum_amount_0)
gen log_sum_amount_1=log(1+sum_amount_1)
twoway (kdensity log_sum_amount_0) (kdensity log_sum_amount_1) 
		
summ sum_amount_*		

gstats winsor ratio_emission_amount_*, cut(2 98) replace 

ttest ratio_emission_amount_0=ratio_emission_amount_1
		
gen userid=substr(userId,2,36)
merge 1:m userid using "${working_data}UserDataValidated"
encode province, gen(province_enc)
reg ratio_amount_emission i.province_enc
tab province_enc if ratio_amount_emission~=.

reg 












