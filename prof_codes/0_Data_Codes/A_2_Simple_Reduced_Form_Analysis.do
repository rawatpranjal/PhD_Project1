********************************************************************************
* Simple analysis: 
* - take investors' transactions
* - merge in the information regarding their various subscriptions
* - test whether the beginning or the end of each subscription makes any difference
********************************************************************************
* Datasets available 
* "${working_data}UserSignedIn"
* "${working_data}Transactions_for_analysis"	
* "${working_data}TreeAcquired"
* "${working_data}RiskLevelEvaluated"
* "${working_data}PhysicalCardRequested"
* "${working_data}LoyaltyLevelChanged_for_analysis"
* "${working_data}SubscriptionActivated_for_analysis"
* "${working_data}NudgeCreated"
* "${working_data}NudgeRead"

********************************************************************************
* STEP 0.0 Understand the degree of overlap between the three datasets: 
*		   LoyaltyLevelChanged_for_analysis
*		   SubscriptionActivated_for_analysis	
*		   Transactions_for_analysis
********************************************************************************

	*Isolate the date of the FIRST TRANSACTION for each user
	use "${working_data}Transactions_for_analysis.dta" , clear	
	keep userId date amount direction income carbonEmissionInGrams isCompensated
	bysort userId (date): keep if _n==1
	sort userId date
	keep userId date
	rename date First_Transaction
	save "${working_data}temp_to_erase_first_transaction", replace

	*Keep unique user-date combinations in LoyaltyLevelChanged...
		use "${working_data}LoyaltyLevelChanged_for_analysis", clear
		keep userId date	
		gduplicates drop 
		gen orig="LoyaltyLevelChanged"
		save "${working_data}temp_unique_dateIDs_loyaltyLevel", replace

	*...and append to those in SubscriptionActivated 
	use "${working_data}SubscriptionActivated_for_analysis", clear
	keep userId date
	gduplicates drop
	gen orig="SubscriptionActivated"
	append using "${working_data}temp_unique_dateIDs_loyaltyLevel"
	sort userId date
		*Check which ones appear in either (or both) datasets
	by userId: egen N_files=nvals(orig)
		  *1 |     69,209       78.27       78.27
          *2 |     19,215       21.73      100.00
	tab orig
	  *LoyaltyLevelChanged   |     73,511       83.13       83.13
      *SubscriptionActivated |     14,913       16.87      100.00
	
	*Reshape 
	gen reshape_id=1     if orig=="LoyaltyLevelChanged"
	replace reshape_id=2 if orig=="SubscriptionActivated"
	reshape wide orig, i(userId date) j(reshape_id)
	sort userId date
	
		*The users in both datasets can appear on the SAME date or in DIFFERENT ones
	gen Dummy_in_both_on_same_date=(orig1!="" & orig2!="")
	merge m:1 userId using "${working_data}temp_to_erase_first_transaction"
	drop if _merge==2
		* Using only (2) |        318        0.37        0.37
        *    Matched (3) |     85,423       99.63      100.00
		*keep if _merge==2
		*keep userId
		*gduplicates drop
		*save "${working_data}temp_unique_users_only_in_transaction_file", replace
	drop _merge
		*For how many users first transaction is AFTER the first event in their
		*"subscription" data?
	gen Transact_post=date>First_Transaction
	bysort userId (date): gen obs=_n
	tab Transact_post if obs==1
	     * 0 |     73,165       99.86       99.86
         * 1 |        101        0.14      100.00
	gen Delta=First_Transaction-date if obs==1
	summ Delta, det /*Median is 18, 75pct is 168*/
	keep userId date orig1 orig2 N_files Dummy_in_both_on_same_date First_Transaction
	save "${working_data}temp_to_erase_compare_subscriptions_file", replace

	*Save users-date for users who appean in both files 
		use "${working_data}temp_to_erase_compare_subscriptions_file", clear
		keep if N_files>1 & Dummy_in_both_on_same_date==0
		keep userId date
		save "${working_data}temp_in_both_at_different_times", replace
		
		use "${working_data}temp_to_erase_compare_subscriptions_file", clear
		tab date if Dummy_in_both_on_same_date==1
			*from 19 jan 2022 to 10 mar 2022
		keep if Dummy_in_both_on_same_date==1
		keep userId date
		save "${working_data}temp_in_both_at_thesame_times", replace
	
		*How does the info look like for those who appear in both files ON THE SAME DAY?
	use "${working_data}LoyaltyLevelChanged_for_analysis", clear
	merge m:1 userId date using "${working_data}temp_in_both_at_thesame_times"
	keep if _merge==3
	tab currentLoyaltyLevel /*All Fan2 that are empty*/
	
	use "${working_data}SubscriptionActivated_for_analysis", clear
	merge m:1 userId date using "${working_data}temp_in_both_at_thesame_times"
	keep if _merge==3
	tab product

		 *How does the info look like for those who appear in both files SEQUENTIALLY?
	use "${working_data}LoyaltyLevelChanged_for_analysis", clear
	merge m:1 userId date using "${working_data}temp_in_both_at_different_times"
	keep if _merge==3
	sort userId date
	keep currentLoyaltyLevel userId date subscription expiration
	save "${working_data}temp_to_for_comparison", replace
	
	use "${working_data}SubscriptionActivated_for_analysis", clear
	merge m:1 userId date using "${working_data}temp_in_both_at_different_times"
	keep if _merge==3
	keep userId date product actualProductsSet expiration includedServices
	append using "${working_data}temp_to_for_comparison"
	sort userId date
	
********************************************************************************
* STEP 1: Load the LoyaltyLevelChanged, generate dummies for Eco, Anal, Card and CO2 compensation.
********************************************************************************

	*It goes From 15 May 2020 to 10 March 2022
		*Things to ask to Nicolo
		* N: However, "subscribedProducts" appears as NON MISSING only from 27may2021
			* Odd that none of the Fan did not activate the EcoBalance, also all Friend should have Ecobalance as product
		* N: and ExpirationDates are recorded from 11 October 2021
		* N: What's the difference between Doconomy and Ecobalance?
			use "${working_data}LoyaltyLevelChanged_for_analysis", clear
			sort date
			bro 	
			bro if currentLoyaltyLevel=="Friend"
			bro if currentLoyaltyLevel=="Fan"
		* N: Before a certain date (jan 2021?) Fan (60 days trial) and Friend (include Ecobalance, and C02Compensation?) accounts, after that
		*									   Fan (60 days trial), Flex (only Ecobalance) and Friend (both Eco and C02 compensation)
	*Our Transaction file is decently populated from Feb/March 2021

use "${working_data}LoyaltyLevelChanged_for_analysis", clear
keep userId date currentLoyaltyLevel subscription expiration /*subscribedProducts_full*/
merge m:1 userId date using "${working_data}temp_in_both_at_thesame_times"
drop if _merge==3
drop _merge

sort userId date 

	*Edit Subscription and Exipiration
replace subscription=strtrim(subscription) /*Otherwise "Doconomy" and "Doconomy " appear as different*/
tab subscription currentLoyaltyLevel
replace subscription="" if subscription=="[]"

	/*
	sort date userId
	keep if currentLoyaltyLevel=="Fan" | currentLoyaltyLevel=="Fan2" | currentLoyaltyLevel=="Friend" | currentLoyaltyLevel=="Friend4Life"		
	tab  subscription currentLoyaltyLevel if date>td(27may2021) /*Fan can have services, but they should be with an Expiration Date*/
	gen Dummy_Expiration=expiration!="" & date>td(27may2021)
	tab currentLoyaltyLevel Dummy_Expiration if date>td(27may2021) & subscription=="EcoBalance"
	tab currentLoyaltyLevel Dummy_Expiration if date>td(27may2021) & subscription=="CO2Compensation"
	tab  currentLoyaltyLevel Dummy_Expiration if date>td(27may2021) & subscription=="Doconomy" /*It never has an expiration*/
	*/
		
gen expirationDate= substr(expiration,1,11)
replace expirationDate=strtrim(expirationDate)
replace expirationDate="" if expirationDate=="null"
gen temp=date(expirationDate, "YMD")
format temp %td
drop expirationDate expiration
rename  temp expirationDate 
tab expirationDate if subscription=="CO2Compensation"
tab expirationDate if subscription=="EcoBalance"

	*Reshape File
gen     reshape_id=1 if subscription==""
replace reshape_id=2 if subscription=="CO2Compensation"
replace reshape_id=3 if subscription=="EcoBalance"
replace reshape_id=4 if subscription=="Doconomy"
replace reshape_id=5 if subscription=="Mooney"

gduplicates drop userId date currentLoyaltyLevel, force /*just drops 687 obs*/
	
 reshape wide subscription expirationDate, i(userId date currentLoyaltyLevel) j(reshape_id)
	*If we see a Fan account with Eco or C02 WITHOUT an expiration date it means data are not recorded correctly
	*and we IMPUTE it. Recall that ExpirationDates are recorded from 11 October 2021...
replace expirationDate2=date+60 if expirationDate2==. & subscription2=="CO2Compensation" & (currentLoyaltyLevel=="Fan" | currentLoyaltyLevel=="Fan2")
replace expirationDate3=date+60 if expirationDate3==. & subscription3=="EcoBalance"	     & (currentLoyaltyLevel=="Fan" | currentLoyaltyLevel=="Fan2")
	
	*Reshape File
egen panel_id=group(userId) /*enconde does not work, too many values*/
gduplicates drop panel_id date, force /*just drop 500 obs*/
xtset panel_id date
tsfill, full

sort panel_id date
by panel_id: carryforward userId currentLoyaltyLevel , replace
drop if currentLoyaltyLevel=="" /*remove all obs before the first activity, due to the tsfill*/
keep  userId date currentLoyaltyLevel subscription2 subscription3 expirationDate2 expirationDate3

	*bysort userId: egen temp_N_C02=nvals(expirationDate2)
	*bysort userId: egen temp_N_Eco=nvals(expirationDate3)
sort userId date
by userId: gegen Exp_C02=max(expirationDate2)
by userId: gegen Exp_Eco=max(expirationDate3)

by userId: gen temp_Activation_C02=date if expirationDate2!=.
by userId: gen temp_Activation_Eco=date if expirationDate3!=.
by userId: gegen Activ_C02=max(temp_Activation_C02)
by userId: gegen Activ_Eco=max(temp_Activation_Eco)
drop temp*

format Exp_C02 Exp_Eco Activ_C02 Activ_Eco %td

gen Eco=date>=Activ_Eco & date<=Exp_Eco
gen C02=date>=Activ_C02 & date<=Exp_C02

	*Friend and Friend4Life have these features by default
	*Some users go from Fan to Friend and so have these features reactivated
replace Eco=1 if currentLoyaltyLevel=="Friend" | currentLoyaltyLevel=="Friend4Life"
	*Need to check this with Nicolo
replace C02=1 if currentLoyaltyLevel=="Friend" | currentLoyaltyLevel=="Friend4Life"
	
keep   userId date currentLoyaltyLevel Eco C02
order  userId date currentLoyaltyLevel Eco C02
keep if date>=td(01jan2021)
drop if date>td(16jan2022)  
	*use "${working_data}temp_to_erase", clear
	*keep  if date>td(16jan2022)
	*drop if Dummy_in_both_on_same_date==1
	*by userId: gen Delta=date[_n+1]-date if orig1!=""
save "${working_data}User_LoyaltyLevel_products_time_panel.dta", replace 
	
********************************************************************************
* STEP 2: Load the subscription data, generate dummies for Eco, Anal, Card  and CO2 compensation.
********************************************************************************

	*use "${working_data}SubscriptionActivated_for_analysis", clear
	*keep userId creationDate date product actualProductsSet expiration  includedServices
	*by userId: egen N_creationDate=nvals(creationDate)
	*tab N_creationDate
    *bro if N_creationDate>1
	 
use "${working_data}SubscriptionActivated_for_analysis", clear

	*from 17-Jan-2022 to June 2022	
keep userId creationDate date product actualProductsSet product	includedServices expiration

	*Expiration Date in Date Format
gen expirationDate= substr(expiration,1,11)
replace expirationDate=strtrim(expirationDate)
replace expirationDate="" if expirationDate=="null"
gen temp=date(expirationDate, "YMD")
format temp %td
drop expirationDate expiration
rename  temp expirationDate 

	*Clean Product, IncludedServices and ActualProductSet
replace product=strtrim(product)
replace actualProductsSet=strtrim(actualProductsSet)

/*
replace includedServices = subinstr(includedServices,"X","",.)			
split includedServices, parse(" ") generate(includedServices_)
replace includedServices=strtrim(includedServices)

 Since product is always included in ActualProductSet

	bysort userId creationDate: gen Check=product==actualProductsSet 
	bysort userId creationDate: gegen max_Check=max(Check)

and the field includedServices does not include anything new compared to actual we can base everything on
ActualProductsSet

rename product includedServices_0
rename actualProductsSet includedServices_6
forval vv=0/6{
	replace includedServices_`vv'=strtrim(includedServices_`vv')
	}
gen product=includedServices_6

forval vv=1/5{
	gen     temp_is_included_`vv'=includedServices_`vv'==product 
	replace temp_is_included_`vv'=. if includedServices_`vv'==""
	bysort userId includedServices_0: gegen is_included_`vv'=max(temp_is_included_`vv')
	tab is_included_`vv'
	}	
reshape long includedServices_ , i(userId creationDate product expiration) j(temp)

replace expiration=. if product!=includedServices_
drop product
drop if includedServices_==""
keep userId creationDate expiration temp date includedServices_

sort userId creationDate includedServices_
bysort userId creationDate includedServices_: gegen temp_date=max(expiration)
replace expiration=temp_date

gduplicates drop userId creationDate includedServices_, force
sort userId includedServices_ creationDate
by   userId includedServices_ : gen obs=_n
drop if obs>1
keep userId creationDate expirationDate date includedServices_
*/

*Only Keep Last ProductSet within the Day
keep userId creationDate expirationDate date actualProductsSet 
sort userId date creationDate
gen temp=creationDate!=creationDate[_n-1]
by userId date: gen blocks=sum(temp)
by userId date: gegen max_blocks=max(blocks)
keep if max_blocks==blocks
drop temp* *blocks

encode userId, generate(userId_enc)
drop userId
save "${working_data}temp_to_erase", replace

	*Fully filled panel from 17 jan2022 to end with just userId_enc and date
use "${working_data}temp_to_erase", clear
keep userId date
gduplicates drop userId date, force
xtset userId date
tsfill, full
keep userId_enc date
save "${working_data}temp_to_erase_full_panel_for_merge_in", replace

	*Individual panels of LoyaltyLevel, EcoBalance and C02Compensation
	use "${working_data}temp_to_erase", clear
	gen temp=substr(actualProductsSet ,1,3)
	gen LoyaltyLevelChanged=actualProductsSet  if ///
	temp=="Fan" | temp=="Fle" | temp=="Fri"  | temp=="Sta"  
	keep if LoyaltyLevelChanged!=""	
	keep userId creationDate date LoyaltyLevelChanged
	rename LoyaltyLevelChanged currentLoyaltyLevel
	keep  userId date currentLoyaltyLevel
	gduplicates drop userId_enc date, force
	save "${working_data}temp_to_erase_Loyalty_Level", replace

	
		use "${working_data}temp_to_erase", clear
		gen IsEcon=actualProductsSet=="EcoBalance"
		sort userId creationDate
		gen temp=creationDate!=creationDate[_n-1]
		by userId : gen blocks=sum(temp)
		by userId : gegen max_blocks=max(blocks)
		bysort userId creationDate : gegen isEcon_block=max(IsEcon)
		drop if max_blocks==1
		replace isEcon_bloc=1 if block==1
		gduplicates drop userId date, force
		keep userId_enc date isEcon_block
		xtset userId_enc date
		tsfill, full
		sort userId date
		by userId_enc: carryforward isEcon_block, replace
		keep if isEcon_block==0
		keep date userId_enc
		save "${working_data}temp_to_erase_EcoBalance_removal", replace
	
		use "${working_data}temp_to_erase", clear
		gen isC02=actualProductsSet=="CO2Compensation"
		sort userId creationDate
		gen temp=creationDate!=creationDate[_n-1]
		by userId : gen blocks=sum(temp)
		by userId : gegen max_blocks=max(blocks)
		bysort userId creationDate : gegen isC02_block=max(isC02)
		drop if max_blocks==1
		replace isC02_bloc=1 if block==1
		gduplicates drop userId date, force
		keep userId_enc date isC02_block
		xtset userId_enc date
		tsfill, full
		sort userId date
		by userId_enc: carryforward isC02_block, replace
		keep if isC02_block==0
		keep date userId_enc
		save "${working_data}temp_to_erase_C02_removal", replace
		
		use "${working_data}temp_to_erase", clear
		keep if actualProductsSet=="EcoBalance"
		sort userId expirationDate
		bysort userId: gen temp_Obs=_N
		bysort userId expiration (date): gen temp_tag=_n==1
		keep if temp_tag==1 /*Unless expiration date changes keep only first istance (since ActualProductsSet builds up)*/	
		drop temp*
		gen creation=date
		keep userId date expiration creation
		rename (expiration creation) (expirationEco creationEco)
		format creationEco %td
		gduplicates drop userId_enc date, force
		save "${working_data}temp_to_erase_EcoBalance", replace
				
		use "${working_data}temp_to_erase", clear
		keep if actualProductsSet=="CO2Compensation"
		sort userId date
		bysort userId: gen temp_Obs=_N
		bysort userId expiration (date): gen temp_tag=_n==1
		keep if temp_tag==1 /*Unless expiration date changes keep only first istance (since ActualProductsSet builds up)*/
		drop temp*
		gen creation=date
		keep userId date expiration creation
		rename (expiration creation) (expirationC02 creationC02)
		format creationC02 %td
		gduplicates drop userId_enc date, force
		save "${working_data}temp_to_erase_CO2Compensation", replace

* Merge the three
use "${working_data}temp_to_erase_full_panel_for_merge_in", clear
merge 1:1 userId date using "${working_data}temp_to_erase_Loyalty_Level"
drop _merge
merge 1:1 userId date using "${working_data}temp_to_erase_EcoBalance" 	
bysort userId (date): carryforward creationEco, replace
drop _merge
merge 1:1 userId date using "${working_data}temp_to_erase_CO2Compensation" 	
bysort userId (date): carryforward creationC02, replace
drop _merge
sort userId date
			
			*At most only one per user
by userId: gegen Exp_C02=max(expirationC02)
by userId: gegen Exp_Eco=max(expirationEco)
format Exp_C02 Exp_Eco %td

gen Eco=date>=creationEco & date<=Exp_Eco
gen C02=date>=creationC02 & date<=Exp_C02

keep   userId date currentLoyaltyLevel Eco C02
order  userId date currentLoyaltyLevel Eco C02

merge 1:1 userId_enc date using "${working_data}temp_to_erase_EcoBalance_removal"
replace Eco=0 if _merge==3
drop if _merge==2
drop _merge

merge 1:1 userId_enc date using "${working_data}temp_to_erase_C02_removal"
replace C02=0 if _merge==3
drop if _merge==2
drop _merge

decode userId_enc, generate(userId)
drop userId_enc

append using "${working_data}User_LoyaltyLevel_products_time_panel.dta"
sort userId date 
order userId
by userId: carryforward currentLoyaltyLevel, replace
drop if currentLoyaltyLevel=="" /*Drop observations for users only appearing in the SubscriptionActivated dataset, whose first event is after 17jan2022*/

	*Friend, Friend4Life have these features by default
	*Some users go from Fan to Friend and so have these features reactivated
replace Eco=1 if currentLoyaltyLevel=="Friend" | currentLoyaltyLevel=="Friend2" ///
			    | currentLoyaltyLevel=="Friend4Life" | currentLoyaltyLevel=="Friend4Life2" ///
				| currentLoyaltyLevel=="Flex" | currentLoyaltyLevel=="Flex2"

replace C02=1 if currentLoyaltyLevel=="Friend" | currentLoyaltyLevel=="Friend2" ///
               | currentLoyaltyLevel=="Friend4Life" | currentLoyaltyLevel=="Friend4Life2"
	
save "${working_data}temp_Eco_C02_temp_for_merge.dta", replace

* Append observations from 17jan2022 to the end for those only appear in LoyaltyLevel
	use "${working_data}temp_to_erase_compare_subscriptions_file", clear
	keep if N_files==1
	keep if orig1=="LoyaltyLevelChanged"
	gduplicates drop userId, force
	keep  userId date
	replace date=td(17jan2022)
	replace date=td(13jun2022) in 1
	encode userId, generate(userId_enc)
	xtset userId_enc date
	tsfill, full
	sort userId_enc date
	by userId_enc: carryforward userId, replace
	gsort userId_enc -date
	by userId_enc: carryforward userId, replace
	drop userId_enc

append using "${working_data}temp_Eco_C02_temp_for_merge.dta"
sort userId date 
by userId: carryforward currentLoyaltyLevel Eco C02, replace
save "${working_data}Eco_C02_temp_for_merge.dta", replace


/*
* Do some Checks
use "${working_data}SubscriptionActivated_for_analysis", clear
sort userId creationDate
by userId: egen N_creationDate=nvals(creationDate)
by userId: egen N_date=nvals(date)

use "${working_data}Eco_C02_temp_for_merge.dta", clear

0643b535-40af-4ab0-b309-6637c272862b	2022-03-09T13:57:14.3324382Z	09mar2022	EcoBalance	EcoBalance	2022-05-09T13:57:14.3269421Z
0643b535-40af-4ab0-b309-6637c272862b	2022-03-09T13:57:14.3324382Z	09mar2022	EcoBalance	Fan	
0643b535-40af-4ab0-b309-6637c272862b	2022-04-23T12:35:27.4558338Z	23apr2022	Flex2	AdvancedExpensesAnalysis	
0643b535-40af-4ab0-b309-6637c272862b	2022-04-23T12:35:27.4558338Z	23apr2022	Flex2	EcoBalance	
0643b535-40af-4ab0-b309-6637c272862b	2022-04-23T12:35:27.4558338Z	23apr2022	Flex2	Flex2	
bro if userId=="0643b535-40af-4ab0-b309-6637c272862b"

userId	creationDate	date	product	actualProductsSet	expiration
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-21T20:43:40.7445656Z	21feb2022	Fan2	Fan2	
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-21T20:43:40.7445656Z	21feb2022	Fan2	Mooney	
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-22T18:12:43.6959955Z	22feb2022	EcoBalance	EcoBalance	2022-04-22T18:12:43.6888771Z
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-22T18:12:43.6959955Z	22feb2022	EcoBalance	Fan2	
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-22T18:12:43.6959955Z	22feb2022	EcoBalance	Mooney	
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-23T14:37:31.1560659Z	23feb2022	Friend2	AdvancedExpensesAnalysis	
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-23T14:37:31.1560659Z	23feb2022	Friend2	CO2Compensation	
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-23T14:37:31.1560659Z	23feb2022	Friend2	EcoBalance	
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-23T14:37:31.1560659Z	23feb2022	Friend2	Friend2	
02097194-0259-4f7d-b131-e242fb2cd5e1	2022-02-23T14:37:31.1560659Z	23feb2022	Friend2	Mooney	
bro if userId=="02097194-0259-4f7d-b131-e242fb2cd5e1"

0632f7ad-ee06-4d23-8248-2c86a50274d2	2022-01-19T17:48:36.4435504Z	19jan2022	Fan2	Fan2
0632f7ad-ee06-4d23-8248-2c86a50274d2	2022-01-19T17:48:36.4435504Z	19jan2022	Fan2	Mooney
0632f7ad-ee06-4d23-8248-2c86a50274d2	2022-01-26T19:47:19.1209091Z	26jan2022	Flex2	EcoBalance
0632f7ad-ee06-4d23-8248-2c86a50274d2	2022-01-26T19:47:19.1209091Z	26jan2022	Flex2	Flex2
0632f7ad-ee06-4d23-8248-2c86a50274d2	2022-01-26T19:47:19.1209091Z	26jan2022	Flex2	Mooney
0632f7ad-ee06-4d23-8248-2c86a50274d2	2022-05-12T07:40:12.0087359Z	12may2022	Fan2	Fan2
0632f7ad-ee06-4d23-8248-2c86a50274d2	2022-05-12T07:40:12.0087359Z	12may2022	Fan2	Mooney
bro if userId=="0632f7ad-ee06-4d23-8248-2c86a50274d2"

070ecb56-fc95-440d-9be7-2773535d8840	2022-05-03T09:20:36.8650431Z	03may2022	Fan2	Fan2	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-03T09:20:36.8650431Z	03may2022	Fan2	Mooney	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-05T11:04:23.3552062Z	05may2022	PhysicalDebitCard	Fan2	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-05T11:04:23.3552062Z	05may2022	PhysicalDebitCard	Mooney	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-05T11:04:23.3552062Z	05may2022	PhysicalDebitCard	PhysicalDebitCard	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-25T11:08:13.4295419Z	25may2022	AdvancedExpensesAnalysis	AdvancedExpensesAnalysis	2022-07-25T11:08:13.4198074Z
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-25T11:08:13.4295419Z	25may2022	AdvancedExpensesAnalysis	Fan2	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-25T11:08:13.4295419Z	25may2022	AdvancedExpensesAnalysis	Mooney	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-25T11:08:13.4295419Z	25may2022	AdvancedExpensesAnalysis	PhysicalDebitCard	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-30T20:53:29.4001576Z	30may2022	EcoBalance	AdvancedExpensesAnalysis	2022-07-25T11:08:13.42
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-30T20:53:29.4001576Z	30may2022	EcoBalance	EcoBalance	2022-07-30T20:53:29.3923854Z
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-30T20:53:29.4001576Z	30may2022	EcoBalance	Fan2	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-30T20:53:29.4001576Z	30may2022	EcoBalance	Mooney	
070ecb56-fc95-440d-9be7-2773535d8840	2022-05-30T20:53:29.4001576Z	30may2022	EcoBalance	PhysicalDebitCard	
bro if userId=="070ecb56-fc95-440d-9be7-2773535d8840"

01924f43-1563-47aa-867e-737302914b25	2022-02-10T10:00:40.116718Z	10feb2022	EcoBalance	EcoBalance
01924f43-1563-47aa-867e-737302914b25	2022-02-10T10:00:40.116718Z	10feb2022	EcoBalance	Fan
01924f43-1563-47aa-867e-737302914b25	2022-02-10T10:00:40.116718Z	10feb2022	EcoBalance	Mooney
01924f43-1563-47aa-867e-737302914b25	2022-02-10T10:14:27.9939966Z	10feb2022	Flex2	AdvancedExpensesAnalysis
01924f43-1563-47aa-867e-737302914b25	2022-02-10T10:14:27.9939966Z	10feb2022	Flex2	EcoBalance
01924f43-1563-47aa-867e-737302914b25	2022-02-10T10:14:27.9939966Z	10feb2022	Flex2	Flex2
01924f43-1563-47aa-867e-737302914b25	2022-02-10T10:14:27.9939966Z	10feb2022	Flex2	Mooney
bro if userId=="01924f43-1563-47aa-867e-737302914b25"

0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-07T18:31:56.984862Z	07feb2022	Fan2	Fan2
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-07T18:31:56.984862Z	07feb2022	Fan2	Mooney

0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T05:44:45.4669489Z	08feb2022	Flex2	AdvancedExpensesAnalysis
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T05:44:45.4669489Z	08feb2022	Flex2	EcoBalance
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T05:44:45.4669489Z	08feb2022	Flex2	Flex2
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T05:44:45.4669489Z	08feb2022	Flex2	Mooney
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T05:52:21.3601622Z	08feb2022	Fan2	Fan2
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T05:52:21.3601622Z	08feb2022	Fan2	Mooney
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T15:44:40.7163267Z	08feb2022	Flex2	AdvancedExpensesAnalysis
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T15:44:40.7163267Z	08feb2022	Flex2	EcoBalance
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T15:44:40.7163267Z	08feb2022	Flex2	Flex2
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-02-08T15:44:40.7163267Z	08feb2022	Flex2	Mooney

0174c1d8-c801-431a-96ad-0333028fd1f4	2022-03-05T16:33:07.5563711Z	05mar2022	Fan2	Fan2
0174c1d8-c801-431a-96ad-0333028fd1f4	2022-03-05T16:33:07.5563711Z	05mar2022	Fan2	Mooney
bro if userId=="0174c1d8-c801-431a-96ad-0333028fd1f4"

415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-04-04T10:27:56.103497Z	04apr2022	Fan2	Fan2	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-04-04T10:27:56.103497Z	04apr2022	Fan2	Mooney	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-05-02T08:13:10.3443508Z	02may2022	PhysicalDebitCard	Fan2	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-05-02T08:13:10.3443508Z	02may2022	PhysicalDebitCard	Mooney	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-05-02T08:13:10.3443508Z	02may2022	PhysicalDebitCard	PhysicalDebitCard	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-01T05:42:42.752909Z	01jun2022	Flex2	AdvancedExpensesAnalysis	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-01T05:42:42.752909Z	01jun2022	Flex2	Budgeting	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-01T05:42:42.752909Z	01jun2022	Flex2	EcoBalance	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-01T05:42:42.752909Z	01jun2022	Flex2	Flex2	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-01T05:42:42.752909Z	01jun2022	Flex2	Mooney	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-01T05:42:42.752909Z	01jun2022	Flex2	PhysicalDebitCard	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-05T06:22:30.7229795Z	05jun2022	Friend2	AdvancedExpensesAnalysis	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-05T06:22:30.7229795Z	05jun2022	Friend2	Budgeting	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-05T06:22:30.7229795Z	05jun2022	Friend2	CO2Compensation	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-05T06:22:30.7229795Z	05jun2022	Friend2	EcoBalance	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-05T06:22:30.7229795Z	05jun2022	Friend2	Friend2	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-05T06:22:30.7229795Z	05jun2022	Friend2	Mooney	
415e26d5-32c2-4ac7-89b5-c852eec75f12	2022-06-05T06:22:30.7229795Z	05jun2022	Friend2	PhysicalDebitCard	
bro if userId=="415e26d5-32c2-4ac7-89b5-c852eec75f12"

b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-28T17:00:34.0889173Z	28mar2022	Fan2	Fan2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-28T17:00:34.0889173Z	28mar2022	Fan2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-29T12:53:22.0661699Z	29mar2022	EcoBalance	EcoBalance	2022-05-29T12:53:22.0577469Z
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-29T12:53:22.0661699Z	29mar2022	EcoBalance	Fan2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-29T12:53:22.0661699Z	29mar2022	EcoBalance	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-29T21:40:18.7965289Z	29mar2022	Flex2	AdvancedExpensesAnalysis	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-29T21:40:18.7965289Z	29mar2022	Flex2	EcoBalance	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-29T21:40:18.7965289Z	29mar2022	Flex2	Flex2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-29T21:40:18.7965289Z	29mar2022	Flex2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-30T00:33:27.1498768Z	30mar2022	Fan2	Fan2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-03-30T00:33:27.1498768Z	30mar2022	Fan2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-11T23:53:37.9354816Z	11apr2022	Flex2	AdvancedExpensesAnalysis	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-11T23:53:37.9354816Z	11apr2022	Flex2	EcoBalance	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-11T23:53:37.9354816Z	11apr2022	Flex2	Flex2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-11T23:53:37.9354816Z	11apr2022	Flex2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T00:52:29.1849421Z	12apr2022	Friend2	AdvancedExpensesAnalysis	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T00:52:29.1849421Z	12apr2022	Friend2	CO2Compensation	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T00:52:29.1849421Z	12apr2022	Friend2	EcoBalance	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T00:52:29.1849421Z	12apr2022	Friend2	Friend2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T00:52:29.1849421Z	12apr2022	Friend2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T03:25:45.1366864Z	12apr2022	PhysicalDebitCard	AdvancedExpensesAnalysis	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T03:25:45.1366864Z	12apr2022	PhysicalDebitCard	CO2Compensation	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T03:25:45.1366864Z	12apr2022	PhysicalDebitCard	EcoBalance	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T03:25:45.1366864Z	12apr2022	PhysicalDebitCard	Friend2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T03:25:45.1366864Z	12apr2022	PhysicalDebitCard	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T03:25:45.1366864Z	12apr2022	PhysicalDebitCard	PhysicalDebitCard	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T08:02:01.3088105Z	12apr2022	Flex2	AdvancedExpensesAnalysis	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T08:02:01.3088105Z	12apr2022	Flex2	EcoBalance	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T08:02:01.3088105Z	12apr2022	Flex2	Flex2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T08:02:01.3088105Z	12apr2022	Flex2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-12T08:02:01.3088105Z	12apr2022	Flex2	PhysicalDebitCard	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-13T18:01:40.2097137Z	13apr2022	Fan2	Fan2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-13T18:01:40.2097137Z	13apr2022	Fan2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-13T18:01:40.2097137Z	13apr2022	Fan2	PhysicalDebitCard	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-28T13:00:09.9325117Z	28apr2022	Friend2	AdvancedExpensesAnalysis	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-28T13:00:09.9325117Z	28apr2022	Friend2	CO2Compensation	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-28T13:00:09.9325117Z	28apr2022	Friend2	EcoBalance	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-28T13:00:09.9325117Z	28apr2022	Friend2	Friend2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-28T13:00:09.9325117Z	28apr2022	Friend2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-04-28T13:00:09.9325117Z	28apr2022	Friend2	PhysicalDebitCard	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T18:14:03.6424883Z	04may2022	Flex2	AdvancedExpensesAnalysis	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T18:14:03.6424883Z	04may2022	Flex2	EcoBalance	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T18:14:03.6424883Z	04may2022	Flex2	Flex2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T18:14:03.6424883Z	04may2022	Flex2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T18:14:03.6424883Z	04may2022	Flex2	PhysicalDebitCard	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T19:04:49.4837911Z	04may2022	Friend2	AdvancedExpensesAnalysis	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T19:04:49.4837911Z	04may2022	Friend2	CO2Compensation	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T19:04:49.4837911Z	04may2022	Friend2	EcoBalance	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T19:04:49.4837911Z	04may2022	Friend2	Friend2	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T19:04:49.4837911Z	04may2022	Friend2	Mooney	
b7be4918-7d00-4169-9d38-989b01170a9f	2022-05-04T19:04:49.4837911Z	04may2022	Friend2	PhysicalDebitCard	
bro if userId=="b7be4918-7d00-4169-9d38-989b01170a9f"
*/


********************************************************************************
* STEP 2
* Load the transactions data
********************************************************************************

use "${working_data}Transactions_for_analysis.dta" , clear	
keep userId date amount direction income carbonEmissionInGrams isCompensated type type_tcreated

*InternalTransfer = 1,
*WireTransfer = 2,
*Card = 3,
*Cash = 4,
*SDD = 5,
*Reservation = 6,
*CardAuthorization = 7,
*FloweFee = 8
 
* Construct spending var and keep only spending
gen spending_ind=0
replace spending_ind=1 if direction=="1" | income=="false"
keep if spending_ind==1
drop direction income spending_ind

* Keep only instances when we have carbon emissions
drop if carbonEmissionInGrams==.
bysort userId date: gegen s_amount=sum(amount) 
bysort userId date: gegen s_carbonEmissionInGrams=sum(carbonEmissionInGrams) 
gen carbonEmissionInGrams_net=carbonEmissionInGrams
replace carbonEmissionInGrams_net=0 if isCompensated=="true"
bysort userId date: gegen s_carbonEmissionInGrams_net=sum(carbonEmissionInGrams_net) 

gduplicates drop userId date, force
drop amount carbonEmissionInGrams type* carbonEmissionInGrams_net
save "${working_data}Transactions_aggregated_for_merge.dta", replace 

********************************************************************************
* STEP 3: Run regressions
********************************************************************************

use "${working_data}Transactions_aggregated_for_merge.dta", clear

* Work only for the period with a decent number of transactions
keep if date>=td(01feb2021)

* Merge CO2 and Ecobalance info
merge 1:1 userId date using ${working_data}Eco_C02_temp_for_merge.dta
keep if _merge==3 
sort userId date

* Do some checks
gen subType=substr(currentLoyaltyLevel,1,3)
drop if subType=="Sta" | subType=="Fou" | subType=="Tea"

tab Eco C02
drop if Eco==0 & C02==1
rename  C02 CO2

* Construct dummies for those who lose Eco balance and for those who are only Fan (and so do not have Eco and C0 by default)
gen t_dummy_Eco_removed=0
bysort userId (date): replace t_dummy_Eco_removed=1 if Eco==0 & Eco[_n-1]==1
by userId: 				gegen dummy_Eco_removed=max(t_dummy_Eco_removed)

by userId: gen Obs=_N
by userId: gen temp_N_Fans=subType=="Fan"
by userId: gegen N_Fans=sum(temp_N_Fans)
gen Dummy_Only_Fan=N_Fans==Obs

* Gen some monthly and quarterly observations for time dummies
gen monthly_date=mofd(date)
format monthly_date %tm
gen quarterly_date=qofd(date)
format quarterly_date %tq

* Compute the number of days with transactions within the month
bysort userId monthly_date: gen avg_days_with_trans_in_month=_N
bysort userId : gegen min_avg_days_with_trans_in_month=min(avg_days_with_trans_in_month)

* Compute some left-hand variables
gen carbon_per_dollar=s_carbonEmissionInGrams/s_amount
gen carbon_per_dollar_net=s_carbonEmissionInGrams_net/s_amount

gstats winsor carbon_per_dollar, cut(1 99) replace
gstats winsor carbon_per_dollar_net, cut(1 99) replace

replace carbon_per_dollar	   =ln(1+carbon_per_dollar)
replace carbon_per_dollar_net  =ln(1+carbon_per_dollar)
replace s_carbonEmissionInGrams=ln(1+s_carbonEmissionInGrams)
replace s_carbonEmissionInGrams_net=ln(1+s_carbonEmissionInGrams_net)
replace s_amount=ln(1+s_amount)

global Y s_amount carbon_per_dollar carbon_per_dollar_net s_carbonEmissionInGrams s_carbonEmissionInGrams_net

* Select Conditions
global condition   N_trans>10 & date>=td(1jan2022) 

global condition  date>=td(1feb2021)   & min_avg_days_with_trans_in_month>=2 &  date>=td(1jun2021)

global condition  Dummy_Only_Fan==1    & N_trans>10 &  date>=td(1jun2021) 

global condition  Dummy_Only_Fan==1    & min_avg_days_with_trans_in_month>2 &  date>=td(1jun2021) 

*global condition  Dummy_Only_Fan==1    & N_trans>10 &  date>=td(1jan2021) 

global condition  Dummy_Only_Fan==1    & dummy_Eco_removed==1 & date>=td(1jun2021)

*global condition  dummy_Eco_removed==1 & N_trans>10 & date>=td(1jun2021)

* Run Regressions
global table_spec cells("b(fmt(3) star)" "t(fmt(2) par)") style(tex) varlabels(_cons \_cons) ///
 stats(r2_a N, labels("R-Square adj")) star(* 0.10 ** 0.05 *** 0.01) label 
 
foreach y in $Y{
	eststo clear
    eststo: reghdfe `y'  Eco#CO2 if $condition, absorb(date)                    cluster(userId date) 
	eststo: reghdfe `y'  Eco#CO2 if $condition, absorb(monthly_date)            cluster(userId monthly_date)
	eststo: reghdfe `y'  Eco#CO2 if $condition, absorb(userId date)             cluster(userId date) 
	eststo: reghdfe `y'  Eco#CO2 if $condition, absorb(userId monthly_date)     cluster(userId monthly_date)	
	esttab using "${results}REG_`y'.txt", $table_spec replace
	}
	
tab Eco CO2 if subType=="Fan" & date>=td(1jun2021)  & min_avg_days_with_trans_in_month>10
tab Eco CO2 if dummy_Eco_removed==1 & date>=td(1jun2021)  & N_trans>10
tab Eco CO2 if dummy_Eco_removed==1 & date>=td(1jun2021) & subType=="Fan"


gen is_Fan=subType=="Fan"
gen is_Flex=subType=="Fle"
gen is_Friend=subType=="Fri"

global condition  N_trans>10 &  date>=td(1jun2021) 
foreach y in $Y{
	eststo clear
    eststo: reghdfe `y'  is_Flex is_Friend if $condition, absorb(date)                    cluster(userId date) 
	eststo: reghdfe `y'  is_Flex is_Friend if $condition, absorb(monthly_date)            cluster(userId monthly_date)
	esttab using "${results}REG_`y'_Type.txt", $table_spec replace
	}
	
reghdfe s_amount  is_Flex is_Friend is_Fan if $condition, absorb(userId)             cluster(userId date) 

/*

/*
Alberto's code
use "${working_data}SubscriptionActivated_for_analysis", clear
drop expirationDate
gen expirationDate= substr(expiration,1,11)
replace expirationDate=strtrim(expirationDate)
replace expirationDate="" if expirationDate=="null"
gen temp=date(expirationDate, "YMD")
format temp %td
drop expirationDate
rename  temp expirationDate 

* Keep all products people sign up for
keep userId date product actualProductsSet product	includedServices expirationDate 
split includedServices, parse(" ") generate(includedServices_)
rename product includedServices_0
rename actualProductsSet includedServices_6

forval vv=0/6{
	replace includedServices_`vv'=strtrim(includedServices_`vv')
}
gen product=includedServices_6
gduplicates drop userId date product, force

* Reshape the data long so we can easily keep subscriptions we care about
reshape long includedServices_ , i(userId date product expirationDate) j(temp)
drop product includedServices

keep if includedServices=="EcoBalance" | includedServices=="AdvancedExpensesAnalysis" | /*
	*/ includedServices=="PhysicalDebitCard" | includedServices=="CO2Compensation" 

replace includedServices="Eco" if includedServices=="EcoBalance"
replace includedServices="Anal" if includedServices=="AdvancedExpensesAnalysis"
replace includedServices="Card" if includedServices=="PhysicalDebitCard"
replace includedServices="CO2" if includedServices=="CO2Compensation"
drop temp 

* Technical step to fix some of the expiration dates entries coming for the 
* includedServices column rather than the product column
bysort userId date includedServices_: gegen max_expirationDate=max(expirationDate)
replace expirationDate=max_expirationDate
drop max_expirationDate
gduplicates drop userId date expirationDate includedServices, force

* Construct panels for merging for Eco, Anal, Card and CO2
foreach var in CO2 Eco Anal Card {
	preserve
	keep if includedServices=="`var'"
	encode userId, gen(userId_enc)
	xtset userId_enc date
	tsfill, full
	order userId_enc, first 
	gsort userId_enc date
	by userId_enc: carryforward  ///
							includedServices expirationDate userId, replace
	gsort userId_enc -date 						
	by userId_enc: carryforward  ///
							includedServices expirationDate userId, replace

	gen `var'=0
	replace `var'=1 if expirationDate==. | ///
								(date<expirationDate & expirationDate!=.)
	keep userId userId_enc date `var'
	order userId, first
	gduplicates drop 
	save ${working_data}`var'_temp_for_merge.dta, replace 
	restore
}
*/



********************************************************************************
* STEP 3
* Merge the two and run the analysis 
********************************************************************************
use "${working_data}Transactions_aggregated_for_merge.dta", clear

* Work only for the period where we have all the info
keep if date>=td(17jan2022)

* Merge CO2 and Ecobalance info
merge 1:1 userId date using ${working_data}Eco_temp_for_merge.dta, keepusing(Eco)
keep if _merge==1 | _merge==3 
drop _merge
merge 1:1 userId date using ${working_data}CO2_temp_for_merge.dta, keepusing(CO2)
keep if _merge==1 | _merge==3 
drop _merge

* Putting to zero those periods where we did not have a match
replace Eco=0 if Eco==.
replace CO2=0 if CO2==.

* BE CAREFUL ABOUT THIS! It is imposing that CO2 is taken away when ecobalance is
replace CO2=0 if Eco==0

* Gen some monthly and quarterly observations for time dummies
gen monthly_date=mofd(date)
format monthly_date %tm
gen quarterly_date=qofd(date)
format quarterly_date %tq

* Construct dummies for those who lose Eco balance
gen t_dummy_Eco_removed=0
bysort userId (date): replace t_dummy_Eco_removed=1 if Eco==0 & Eco[_n-1]==1
by userId: gegen dummy_Eco_removed=max(t_dummy_Eco_removed)

* Compute the number of days with transactions within the month
bysort userId monthly_date: gen avg_days_with_trans_in_month=_N
bysort userId : gegen min_avg_days_with_trans_in_month=min(avg_days_with_trans_in_month)

/*
gen s_carbonEmissionInGrams_net=s_carbonEmissionInGrams
replace s_carbonEmissionInGrams_net=0 if CO2==1
*/

gen carbon_per_dollar=s_carbonEmissionInGrams_net/s_amount
gstats winsor carbon_per_dollar, cut(5 95) replace
encode userId, gen (userId_enc)

* Compute baseline results
* No time FE
reghdfe carbon_per_dollar Eco#CO2, absorb(userId_enc) cluster(userId_enc)
reghdfe carbon_per_dollar Eco#CO2, absorb(userId_enc) cluster(userId_enc date)

* Monthly time FE
reghdfe carbon_per_dollar Eco#CO2, absorb(userId_enc monthly_date) cluster(userId_enc )
reghdfe carbon_per_dollar Eco#CO2, absorb(userId_enc monthly_date) cluster(userId_enc monthly_date)

* Quarterly time FE
reghdfe carbon_per_dollar Eco#CO2, absorb(userId_enc quarterly_date) cluster(userId_enc )
reghdfe carbon_per_dollar Eco#CO2, absorb(userId_enc quarterly_date) cluster(userId_enc quarterly_date)


* Compute results only for those who lose Eco balance
* Coefficients are identical to above because we only get identification from these
* No time FE
reghdfe carbon_per_dollar Eco#CO2 if dummy_Eco_removed==1, absorb(userId_enc) cluster(userId_enc)
reghdfe carbon_per_dollar Eco#CO2 if dummy_Eco_removed==1, absorb(userId_enc) cluster(userId_enc date)

* Monthly time FE
reghdfe carbon_per_dollar Eco#CO2 if dummy_Eco_removed==1, absorb(userId_enc monthly_date) cluster(userId_enc)
reghdfe carbon_per_dollar Eco#CO2 if dummy_Eco_removed==1, absorb(userId_enc monthly_date) cluster(userId_enc monthly_date)

* Quarterly time FE
reghdfe carbon_per_dollar Eco#CO2 if dummy_Eco_removed==1, absorb(userId_enc quarterly_date) cluster(userId_enc )
reghdfe carbon_per_dollar Eco#CO2 if dummy_Eco_removed==1, absorb(userId_enc quarterly_date) cluster(userId_enc quarterly_date)



* Compute results only for those who lose Eco balance
* Coefficients are identical to above because we only get identification from these
* No time FE
reghdfe carbon_per_dollar Eco#CO2 if min_avg_days_with_trans_in_month>=5, absorb(userId_enc) cluster(userId_enc)
reghdfe carbon_per_dollar Eco#CO2 if min_avg_days_with_trans_in_month>=5, absorb(userId_enc) cluster(userId_enc date)

* Monthly time FE
reghdfe carbon_per_dollar Eco#CO2 if min_avg_days_with_trans_in_month>=5, absorb(userId_enc monthly_date) cluster(userId_enc)
reghdfe carbon_per_dollar Eco#CO2 if min_avg_days_with_trans_in_month>=5, absorb(userId_enc monthly_date) cluster(userId_enc monthly_date)

* Quarterly time FE
reghdfe carbon_per_dollar Eco#CO2 if min_avg_days_with_trans_in_month>=5, absorb(userId_enc quarterly_date) cluster(userId_enc )
reghdfe carbon_per_dollar Eco#CO2 if min_avg_days_with_trans_in_month>=5, absorb(userId_enc quarterly_date) cluster(userId_enc quarterly_date)
*/
