
********************************************************************************
* Part 0: Load the Raw Data and do some initial checks
********************************************************************************

import delimited "${raw_data}part-00000-tid-7073521145656742331-3e06173f-1926-41aa-b3b7-847006329acc-4624-1-c000.csv", clear varnames(1) 
replace clearedbody=clearedbody+v6+v7+v8
drop v6-v8
rename (integrationevent clearedbody creationdateutc) (event fields creationdate) 
keep   userid creationdate event fields /*messageid*/  
order  userid creationdate event fields
	*remove { } and "
replace fields = subinstr(fields,"{","",.)
replace fields = subinstr(fields,"}","",.)
replace fields = subinstr(fields,char(34),"",.) /* removes ""*/
replace fields = subinstr(fields,"\\u00e8","e",.) 
replace fields = subinstr(fields,"\\u00e9","e",.) 
replace fields = subinstr(fields,"notificationChannel","NotificationChannel",.)
* tab event
*          UserSignedIn | 11,015,365       59.80      100.00
		  
*EcoBalanceDataComputed |  1,805,667        9.80        9.80
*  TransactionConfirmed |  2,693,551       14.62       35.12
*    TransactionCreated |    913,536        4.96       40.08

*          TreeAcquired |     22,111        0.12       40.20

*    RiskLevelEvaluated |     83,870        0.46       20.41
*   LoyaltyLevelChanged |     74,062        0.40       10.20
* PhysicalCardRequested |     19,320        0.10       19.96
* SubscriptionActivated |     16,023        0.09       20.50

*          NudgeCreated |  1,650,331        8.96       19.16
*             NudgeRead |    126,947        0.69       19.85
save "${raw_data}Raw_data_BunchedEvents.dta", replace

gduplicates drop userid event, force
* tab event
*          UserSignedIn |     73,584       14.44      100.00
*EcoBalanceDataComputed |     48,325        9.48        9.48
*  TransactionConfirmed |     73,584       14.44       73.97
*    TransactionCreated |     36,942        7.25       81.22
*          TreeAcquired |     22,106        4.34       85.56

*   RiskLevelEvaluated  |     73,298       14.38       56.98
*   LoyaltyLevelChanged |     68,871       13.51       23.00
* SubscriptionActivated |     13,009        2.55       59.54
* PhysicalCardRequested |     19,145        3.76       42.60

*	  	   NudgeCreated |     62,122       12.19       35.19
*             NudgeRead |     18,643        3.66       38.84

* Merge sequentially into UserSignedIn all the files (only the unique list of users)
use "${raw_data}Raw_data_BunchedEvents.dta", clear
gduplicates drop userid event, force
keep userid event
foreach event in UserSignedIn TreeAcquired TransactionCreated  TransactionConfirmed ///
SubscriptionActivated RiskLevelEvaluated PhysicalCardRequested ///
NudgeRead NudgeCreated LoyaltyLevelChanged EcoBalanceDataComputed {
	preserve
	keep if  event=="`event'"
	save "${raw_data}temp_`event'", replace 
	restore
	}
use "${raw_data}temp_UserSignedIn.dta", clear
foreach event in  TreeAcquired TransactionCreated  TransactionConfirmed ///
SubscriptionActivated RiskLevelEvaluated PhysicalCardRequested ///
NudgeRead NudgeCreated LoyaltyLevelChanged EcoBalanceDataComputed {
	display "`temp_`event'"
	merge 1:1 userid using "${raw_data}temp_`event'"
	rename _merge `event'
	}

********************************************************************************
* Part 1: Understand the Fields in Each Event and how frequent they are
********************************************************************************

* Step: Separate fields-content tuple in Events related to USERSIGNEDIN
use "${raw_data}Raw_data_BunchedEvents.dta", clear
keep if event=="UserSignedIn"
split fields, parse(", \") /*This is how fields within an event are separated in json*/
drop fields 
drop fields1 /*erase deviceCode field*/ 
rename fields2 fields1
gen fields2="creationDate\: \" +creationdate+"\"
save "${working_data}temp_Full_to_erase_LOGIN", replace 

* Step: Separate fields-content tuple in Events related to TRANSACTIONS
use "${raw_data}Raw_data_BunchedEvents.dta", clear
keep if event=="TransactionConfirmed" | event=="TransactionCreated" ///
	  | event=="EcoBalanceDataComputed" | event=="TreeAcquired"
gen n=0
replace n=1 if _n==1 | _n==1000000 | _n==2000000 | _n==3000000 | _n==4000000 | _n==5000000 | _n==6000000 
replace n=sum(n)
	*do it a gruppi di 1,000,000 observations
forvalues n=1/6{
	preserve
	keep if n==`n'
	split fields, parse(", \")
	save "${raw_data}temp_`n'", replace 
	display "`n'"
	restore
	}
use "${raw_data}temp_1", clear
forvalues n=2/6{
	append using "${raw_data}temp_`n'"
	erase "${raw_data}temp_`n'.dta" 
	}
erase "${raw_data}temp_1.dta"
drop n
drop fields fields13 /*to speed up the code*/
save "${working_data}temp_Full_to_erase_TRANSACTIONS", replace 

* Step: Separate fields-content tuple in Events related to BIO
use "${raw_data}Raw_data_BunchedEvents.dta", clear
keep if event=="RiskLevelEvaluated"   | event=="PhysicalCardRequested" ///
	  | event=="LoyaltyLevelChanged"  | event=="SubscriptionActivated"  
	  *LoyaltyLevelChanged   has "subscribedProducts" with Nested Fields
	  *SubscriptionActivated has "actualProductsSet" and "includedServices" with nested Fields
	  *We will process them separately otherwise the parsing creates a mess, for now we erase their content
	  sort event fields	  
	  *nested fields are in "[]" there are at most 2 in any event
	  forvalues i=1/2{
		display "`i'"
		gen temp_before=strpos(fields,"[") 				   
		gen temp_after=strpos(fields,"]")			       
		gen to_replace=substr(fields,temp_before,temp_after-temp_before+1) 
		replace fields = subinstr(fields,to_replace,"X",.) 
		drop temp* to_replace
		}
split fields, parse(", \")
drop fields 
save "${working_data}temp_Full_to_erase_BIO", replace 

* Step: Separate fields-content tuple in Events related to NUDGES
use "${raw_data}Raw_data_BunchedEvents.dta", clear
keep if event=="NudgeCreated" | event=="NudgeRead"
split fields, parse(", \")
drop fields 
save "${working_data}temp_Full_to_erase_NUDGE", replace 

foreach x in TRANSACTIONS BIO NUDGE LOGIN { 
	
	use "${working_data}temp_Full_to_erase_`x'", clear 
		*The variable "creationdate" is less precise that the one contained in "fields"
		*this means we might loose more observations that necessary in the next duplicates drop
		*which means we might be missing fields belonging to an event
	foreach var of varlist fields*{
		gen  temp_`var'=strpos(`var',"creationDate" )
		}
	gen new_CreationDate="."	
	foreach var of varlist fields*{
		replace new_CreationDate=`var' if temp_`var'>0 & new_CreationDate=="."
		}
	gen temp_length=strlen(new_CreationDate)			
	drop if temp_length>60	
	split new_CreationDate, parse(": \")	
	drop temp_* new_CreationDate new_CreationDate1 
	format new_CreationDate2 %60s
	rename new_CreationDate2 creationdate2

	bysort event creationdate2: gen Obs2=_N
	bysort event creationdate: gen Obs=_N
	order userid event creationdate creationdate2 Obs*
	drop creationdate Obs*
	rename creationdate2 creationdate

	gduplicates drop event creationdate, force 
	bysort event: gen Number_times=_N
	order Number_times
	drop userid 
	greshape long fields, by(event Number_times creationdate) keys(new)

	format fields %50s
	drop if fields==""
	drop new
	sort event fields
	split fields, parse(": ")
	format fields1 %25s
	capture replace fields2=fields2+" "+fields3
	format fields2 %50s
	capture drop fields3
	order Number
	keep Number event fields fields1 fields2 
	rename Number_times N_event
	bysort event fields1: gen N_event_field=_N
	order N_event event N_event_field
	gsort -N_event event -N_event_field fields1
	save "${working_raw_data}temp_Event_Fields_Panel_`x'_panel", replace

	gduplicates drop event fields1, force
	gsort -N_event event -N_event_field fields1
	keep N_event event N_event_field fields1 fields2
	rename (N_event event fields1 fields2) (N_Event Event field example)
	gen    Frequency=N_event_field/N_Event
	replace field = subinstr(field,"\","",.)
	save "${working_data}temp_Event_Fields_Panel_`x'_nopanel", replace
	}

*This gives, for each event, the list of fields (and their frequency)
use "${working_data}temp_Event_Fields_Panel_TRANSACTIONS_nopanel", clear
append using "${working_data}temp_Event_Fields_Panel_BIO_nopanel"
append using "${working_data}temp_Event_Fields_Panel_NUDGE_nopanel"
append using "${working_data}temp_Event_Fields_Panel_LOGIN_nopanel"
format example %50s
	
********************************************************************************
* Part 2: Create Panels 
********************************************************************************

* ActivityCompleted ProfileClosureRequested UserDataValidated [We no longer have them]
global Events_Attention    UserSignedIn
global Events_Transactions EcoBalanceDataComputed TransactionCreated  TransactionConfirmed  /*TransactionCategorized*/ TreeAcquired 
global Events_Bio	       RiskLevelEvaluated  PhysicalCardRequested  LoyaltyLevelChanged     SubscriptionActivated
global Events_Nudges	   NudgeCreated        NudgeRead
global Tables_Loop $Events_Attention $Events_Transactions $Events_Bio $Events_Nudges

foreach Tables in $Tables_Loop{
	*use "${raw_data}part-0001_new_mac.dta", clear
	use "${raw_data}Raw_data_BunchedEvents.dta", clear
	
	*We process the Nested fields in LoyaltyLevelChanged and SubscriptionActivated separately
	forvalues i=1/3{
		display "`i'"
		gen temp_before=strpos(fields,"[") 				   
		gen temp_after=strpos(fields,"]")			       
		gen to_replace=substr(fields,temp_before,temp_after-temp_before+1) 
		replace fields = subinstr(fields,to_replace,"X",.) 
		drop temp* to_replace
		}
		
	display "`Tables'"
	rename event label
	rename fields event
	keep if label=="`Tables'"
	
		*User Sign
		if "`Tables'"=="UserSignedIn"{
			*global Fields Label userId  id creationDate deviceCode  mobileOS /*Fields from previous file we were given*/
			global  Fields       userId     			  
			}	

		if "`Tables'"=="EcoBalanceDataComputed"{
			*global Fields Label userId rowId  creationDate amount carbonEmissionInGrams carbonSocialCost isCompensated mcc
			global Fields      userId rowId  creationDate amount carbonEmissionInGrams carbonSocialCost isCompensated mcc
			}	

		if "`Tables'"=="TransactionConfirmed"{
			*global Fields Label userId        rowId category  creationDate amount income operationDate  ///
			*type valueDate partialAmount mcc 
		    global Fields 	     userId        rowId category  creationDate amount income operationDate  ///
			type valueDate partialAmount mcc 	
			}
			
		if "`Tables'"=="TransactionCreated"{
			*global Fields Label userId id transactionId creationDate amount ///
			*carbonEmissionInGrams carbonSocialCost isCompensated merchantExpenseCategory ///
			*direction isWireTransferBetweenP0Users isWireTransferExecuted type valueDate
			global Fields 		 userId id transactionId creationDate amount ///
			carbonEmissionInGrams carbonSocialCost isCompensated merchantExpenseCategory ///
			direction 								 isWireTransferExecuted type valueDate ///
			linkedSharedExpenseId
			}		
			
		*if "`Tables'"=="TransactionCategorized"{
		*	global Fields Label userId byUser rowId category creationDate confidence
		*	*careful about Frequency...
		*	}
			
			
		if "`Tables'"=="TreeAcquired"{
			*global Fields Label userId compensatedCO2 creationDate id sowingDate treeId type
			global Fields 		 userId compensatedCO2 creationDate id sowingDate treeId type
			}
			
		if "`Tables'"=="RiskLevelEvaluated"{
		*	global Fields userId id gender creationDate birthCountry birthDate birthPlace ///
        *   domicileData personalData residenceData userData
			global Fields userId 	gender creationDate birthCountry birthDate birthProvince ///
					annualIncomeCode country istatCode level openingPurposeCode province totalAssetsCode zipCode
			}
			
	    if "`Tables'"=="PhysicalCardRequested"{
			global Fields userId creationDate gems paid cardType loyaltyLevel 
			}
			
		if "`Tables'"=="LoyaltyLevelChanged"{
			global Fields userId creationDate currentLoyaltyLevel ddsCounter subscribedProducts 
			}
							
		if "`Tables'"=="SubscriptionActivated"{
			global Fields userId creationDate actualProductsSet product includedServices activationGems activationAmount expirationDate
			}
				
		if "`Tables'"=="NudgeCreated"{
			*global Fields Label userId nudgeId message title nudge NotificationChannel NotificationType topic creationDate
			 global Fields       userId nudgeId message 	  nudge NotificationChannel NotificationType topic creationDate notificationChannel
			}
				
		if "`Tables'"=="NudgeRead"{
			*global Fields Label userId nudgeCreationDate title nudgeId creationDate
			global Fields       userId nudgeCreationDate title nudgeId creationDate
			}
			
		/*
		if "`Tables'"=="ProfileClosureRequested"{
			global Fields Label userId reason requestMode tutorUserId userNote contractId creationDate
			}		
		
	    if "`Tables'"=="UserDataValidated"{
			global Fields id addressNumber address country documentData expiryDate province releaseCountry ///
				  releaseDate releasePlace releaseProvince type zipCode residence
			}
			
		if "`Tables'"=="ActivityCompleted"{
			global Fields Label userId activityId category ctaRef description ///
			gems name points referenceItem type silent creationDate 
			}
		*/
		
	keep userid label creationdate  event
	gen temp_date=substr(creationdate,1,10)
	gen date=date(temp_date, "YMD")
	format date %td
	keep label date event creationdate userid 
	split event, parse(", \")
	drop event
		*erase all the \ 
	foreach var of varlist event*{
		replace `var'= subinstr(`var',"\","",.)
		}
		*Create Columns Corresponding to Fields (with correct content)
		*tricky part is that the order of the fields (even within same Event is not always the same)
	foreach field in $Fields{
		global new_var  "`field'"
		gen ${new_var}="."
		gen temp="`field'"
		gen temp_Length=length(temp)
		global N_char=temp_Length[1]+3
		foreach var of varlist event*{
			gen temp_`var'=strpos(`var',"`field'" )
			}
		foreach var of varlist event*{
				replace ${new_var}=`var' if temp_`var'>0 & ${new_var}=="."
			}		
		drop temp*	
		replace ${new_var}=substr(${new_var},${N_char},.)
		}
	drop event*	
	capture drop label Label
	save "${working_data}`Tables'", replace	
	}

	
 *PANEL: Transactions. It requires EcoBalanceDataComputed, TransactionConfirmed and TransactionCreated
			use "${working_data}EcoBalanceDataComputed", clear
			keep userId rowId date creationDate amount carbonEmissionInGrams carbonSocialCost isCompensated mcc
			destring mcc amount carbonSocialCost carbonEmissionInGrams, replace
			rename (mcc amount) (mcc_ECO amount_ECO)
			gduplicates drop userId rowId, force
			save "${working_data}temp_EcoBalanceDataComputed_to_merge", replace 
		
		use "${working_data}TransactionConfirmed", clear
		/*This dataset goes from 13 May 2021 till now, it has to be merged with EcoBalanceDataComputed */
		gduplicates drop userId rowId, force 
		keep userId creationDate date rowId category amount income operationDate type valueDate partialAmount mcc
		destring mcc amount partialAmount, replace	
		merge 1:1 rowId userId using  "${working_data}temp_EcoBalanceDataComputed_to_merge"
		rename _merge merge_trans_ecobalance
		order userId rowId date creationDate operationDate valueDate type category income amount amount_ECO partialAmount ///
		type valueDate partialAmount mcc mcc_ECO carbonEmissionInGrams carbonSocialCost
		format userId        %40s
		format creationDate  %30s
		format operationDate %20s
		format valueDate     %20s
		format type			 %10s
		format category		 %20s
		save "${working_data}temp_EcoBalanceDataComputed_for_append", replace
		
	use "${working_data}TransactionCreated", clear 
		*From April 2020 to 12 May 2021
	destring carbonEmissionInGrams carbonSocialCost, force replace
	destring amount, replace
	rename type type_tcreated
	append using "${working_data}temp_EcoBalanceDataComputed_for_append"
	sort date
	order userId transactionId rowId creationDate operationDate valueDate date ///
	amount direction income type type_tcreated carbonEmissionInGrams carbonSocialCost isCompensated  ///
	 merchantExpenseCategory mcc category id
	format creationDate    %15s
	sort userId date	
	save "${working_data}Transactions_for_analysis", replace

*PANEL: LoyaltyLevelChange also requires changes because of nested field "subscribedProducts"

	use "${raw_data}Raw_data_BunchedEvents.dta", clear
	keep if event=="LoyaltyLevelChanged"
	gduplicates drop
	sort event fields
	gen temp_before=strpos(fields,"subscribedProducts")	
	gen temp_after=strpos(fields,"]")	
	gen subscription=substr(fields,temp_before,temp_after-temp_before+1)
	drop if subscription==""
	replace subscription = subinstr(subscription,"[]","X",.)
	keep userid creationdate subscription
	foreach to_remove in subscribedProducts\: \ , ] [{
		replace subscription=subinstr(subscription,"`to_remove'","",.)	
		}
	split subscription, parse("product:")
	keep userid creationdate subscription*
	rename subscription subscription_full
	format subscription_full %50s
	reshape long subscription, i(userid creationdate subscription_full) j(n_subs)
	drop n_sub
	drop if subscription==""
	split subscription, parse("expirationDate:")
	drop subscription
	rename (subscription1 subscription2) (subscription expiration) 
	bysort userid creationdate: gen N_sub=_N
	replace subscription_full = subinstr(subscription_full,"X","[]",.)
	replace subscription = subinstr(subscription,"X","[]",.)
	rename subscription_full subscribedProducts_full 
	save "${working_data}temp_LoyaltyLevelChanged_for_merge", replace	

	use "${working_data}LoyaltyLevelChanged.dta", clear	
	merge m:m userid creationdate using "${working_data}temp_LoyaltyLevelChanged_for_merge"
	order userId creationDate date currentLoyaltyLevel ///
	ddsCounter subscribedProducts* subscription expiration N_sub , first
	drop _merge
	sort userId creationDate
	save "${working_data}LoyaltyLevelChanged_for_analysis", replace

*PANEL: SubscriptionActivated also requires changes because of the nested fields includedServices and actualProductSet

	use "${raw_data}Raw_data_BunchedEvents.dta", clear
	keep if event=="SubscriptionActivated"
	gen temp_before=strpos(fields,"includedServices")	
	gen temp_after=strpos(fields,"]")	
	gen includedServices=substr(fields,temp_before,temp_after-temp_before+1)
	replace includedServices = subinstr(includedServices,"[]","X",.)	
	foreach to_remove in includedServices\: \ , ] [{
		replace includedServices=subinstr(includedServices,"`to_remove'","",.)	
		}
	drop temp*
	gen temp_before=strpos(fields,"actualProductsSet")	
	gen temp_after=strrpos(fields,"]")	
	gen actualProductsSet=substr(fields,temp_before,temp_after-temp_before+1)
	replace actualProductsSet = subinstr(actualProductsSet,"[]","X",.)
	foreach to_remove in actualProductsSet\: \ , ] [{
		replace actualProductsSet=subinstr(actualProductsSet,"`to_remove'","",.)	
		}
	
	split actualProductsSet, parse("product:")
	keep userid creationdate includedServices actualProductsSet*
	drop actualProductsSet
	gduplicates drop userid creationdate includedServices, force
	reshape long actualProductsSet, i(userid creationdate includedServices) j(n_Products)
	drop if actualProductsSet==""
	drop n_Products
	split actualProductsSet, parse("expirationDate:")
	drop actualProductsSet
	rename (actualProductsSet1 actualProductsSet2) (actualProductsSet expiration) 
	bysort userid creationdate: gen N_ProductsSet=_N
	save "${working_data}SubscriptionActivated_for_merge", replace
	
	use "${working_data}SubscriptionActivated.dta", clear	
	gduplicates drop userid creationdate, force
	drop actualProductsSet includedServices
	merge 1:m userid creationdate using "${working_data}SubscriptionActivated_for_merge"
	order userId creationDate date product actualProductsSet expiration expirationDate activationAmount activationGems N_ProductsSet
	drop _merge
	sort userId creationDate actualProductsSet
	save "${working_data}SubscriptionActivated_for_analysis", replace

	
********************************************************************************
* LOAD INDIVIDUALLY 
********************************************************************************

*** Logins
use "${working_data}UserSignedIn", clear
order userId date creationdate
keep  userId date creationdate
gen time=substr(creationdate,12,8)
keep userId date time
gduplicates drop userId date, force
gsort userId date time
/*
by userId: gegen min_date=min(date)
by userId: gegen max_date=max(date)
gen diff=max_date-min_date+1
bysort userId (date): gen days_with_logins=_N 
gen percentage_of_days_with_logins=days_with_logins/diff*100
gduplicates drop userId, force
gsort percentage_of_days_with_logins
hist percentage_of_days_with_logins
*/ 
	
*** Transactions - Compensation -- Sustainable Behavior	
use "${working_data}Transactions_for_analysis", clear
order amount direction income type type_tcreated carbonEmissionInGrams carbonSocialCost ///
isCompensated merchantExpenseCategory mcc category

/*
drop if userId==""
gsort userId date 
keep userId date
gduplicates drop userId date, force
by userId: gegen min_date=min(date)
by userId: gegen max_date=max(date)
gen diff=max_date-min_date+1
bysort userId (date): gen days_with_transactions=_N 
gen pct_days_with_transactions=days_with_transactions/diff*100
gduplicates drop userId, force
gsort pct_days_with_transactions
keep if pct_days_with_transactions>20 & diff>365
hist pct_days_with_transactions
 
*/


use "${working_data}TreeAcquired", clear
order userId creationDate type treeId sowingDate id compensatedCO2
destring compensatedCO2, replace

*** Bio
use "${working_data}RiskLevelEvaluated", clear
order userId level creationDate date gender birthCountry birthDate birthProvince ///
zipCode country province istatCode  annualIncomeCode  openingPurposeCode totalAssetsCode 
gen temp=substr(birthDate,1,1)
replace birthDate="1"+birthDate if temp=="9"
replace birthDate="2"+birthDate if temp=="0"
destring birthDate, replace
gen Years=2022-birthDate

use "${working_data}PhysicalCardRequested", clear
order userId date creationDate gems paid cardType loyaltyLevel
keep  userId date creationDate gems paid cardType loyaltyLevel
destring gems cardType, replace

use "${working_data}LoyaltyLevelChanged_for_analysis", clear
order userId creationDate subscribedProducts subscribedProducts_full ddsCounter currentLoyaltyLevel
format subscribedProducts_full %70s
format subscribedProducts %1s
destring ddsCounter, replace
replace subscription="empty" if subscription==""
tab subscription currentLoyaltyLevel 

bysort date: gen Obs=_N
gduplicates drop date, force
line Obs date

use "${working_data}SubscriptionActivated_for_analysis", clear
order userId creationDate  actualProductsSet expiration includedServices product expirationDate activationGems activationAmount 
tab product

bro product  expiration




bysort date: gen Obs=_N
gduplicates drop date, force
line Obs date

*** Nudges
use "${working_data}NudgeCreated", clear
order userId creationDate NotificationChannel NotificationType topic  message nudge

use "${working_data}NudgeRead", clear
order userId nudgeCreationDate nudgeId title



