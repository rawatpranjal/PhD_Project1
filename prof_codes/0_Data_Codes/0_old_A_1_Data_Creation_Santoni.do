
********************************************************************************
* Step 1: Check Overlap Between Events in FloweEvents and Santoni's file
********************************************************************************

import excel "${raw_data}FloweEvents.xlsx", first clear
keep Microservice IntegrationEvent Whenitsfired
format Whenitsfired %100s
rename IntegrationEvent label
gduplicates drop label, force
save "${working_data}Description_Events", replace

import delimited "${raw_data}SantoniEvents.csv", clear varnames(1) 
keep label
gduplicates drop
merge m:1 label using  "${working_data}Description_Events"
order _merge label Whenitsfired

********************************************************************************
* Step 2: Extract Fields for Each Event
********************************************************************************

import delimited "${raw_data}SantoniEvents.csv", clear varnames(1) 
sort label
sort label
keep label creationdate event
replace event = subinstr(event,"{","",.)
replace event = subinstr(event,"}","",.)
split event, parse(,)
drop event
gduplicates drop label creationdate, force
bysort label: gen Number_times=_N
order Number_times
reshape long event, i(label Number_times creationdate) j(new)
format event %50s
drop if event==""
drop new
sort label event
split event, parse(:)
format event1 %25s
format event2 %50s
format event3 %50s
order Number
keep Number label event event1 event2 event3
rename Number_times N_label
bysort label event1: gen N_label_event=_N
order N_label label N_label_event
gsort -N_label label -N_label_event event1
save "${working_data}Label_Event_content_PANEL_santoni", replace

gduplicates drop label event1, force
gsort -N_label label -N_label_event event1
keep N_label label N_label_event event1 event2

rename N_label N_Event
rename label Event
rename N_label_event N_field
rename event1 field
rename event2 Example
replace N_field=N_field/N_Event
rename N_field Frequency
save "${working_data}Label_Event_content_NOPANEL_santoni", replace
use "${working_data}Label_Event_content_NOPANEL_santoni", clear

********************************************************************************
* Step 3: Try to create a Standard Data Tables
********************************************************************************

use "${working_data}Label_Event_content_NOPANEL_santoni", clear

global Tables_Loop UserSignedIn ActivityCompleted ///
TransactionCreated TransactionCategorized TransactionConfirmed EcoBalanceDataComputed ///
NudgeCreated GroupTransactionLinked CardPreAuthorizationReceived TreeAcquired

foreach Tables in $Tables_Loop{
	import delimited "${raw_data}SantoniEvents.csv", clear varnames(1) 
	keep if label=="`Tables'"

		if "`Tables'"=="UserSignedIn"{
			global Fields Label userId firstName lastName mobileOS deviceCode phoneNumber email
			}
		if "`Tables'"=="TransactionCategorized"{
			global Fields Label userId rowId category 
			*byUser confidence
			}
		if "`Tables'"=="ActivityCompleted"{
			global Fields Label userId activityId category ctaRef description ///
			gems name points referenceItem type silent
			}	
		if "`Tables'"=="TransactionConfirmed"{
			global Fields Label userId rowId category  amount income operationDate partySubject  ///
			type valueDate partialAmount mcc partyDetail 
			*partyUserId requestId groupRefundExtraData wireTransferIn
			}
		if "`Tables'"=="GroupTransactionLinked"{
			global Fields Label userId groupId groupOwnerId transactionId budgetAmount
			}	
		if "`Tables'"=="CardPreAuthorizationReceived"{
			global Fields Label userId amount partySubject isAtm currency currencyAmount rowId
			}	
		if "`Tables'"=="TreeAcquired"{
			global Fields Label userId compensatedCO2 creationDate id sowingDate treeId type
			}		
		if "`Tables'"=="EcoBalanceDataComputed"{
			global Fields Label userId rowId amount carbonEmissionInGrams carbonSocialCost  isCompensated mcc
			*creationDate
			}	
		if "`Tables'"=="TransactionCreated"{
			global Fields Label userId accountId amount carbonEmissionInGrams carbonSocialCost ///
			 direction isCompensated transactionId type ///
			 partySubject isWireTransferExecuted 
			*creationDate
			*linkedSharedExpenseId ///
			*merchantExpenseCategory valueDate id isWireTransferBetweenP0Users ///
			*isPaymentExecuted
			}	
		if "`Tables'"=="NudgeCreated"{
			global Fields Label userId nudgeId message title nudge NotificationChannel NotificationType topic
			*creationDate
			}		
	keep label creationdate enqueueddatetime event
	gen temp_date=substr(creationdate,1,10)
	gen date=date(temp_date, "YMD")
	format date %td
	keep label date event
	replace event = subinstr(event,"{","",.)
	replace event = subinstr(event,"}","",.)
	split event, parse(,)
	drop event
	foreach var of varlist event*{
		replace `var' = substr(`var',2,.)
		}
		
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
				replace ${new_var}=`var' if temp_`var'==1 & ${new_var}=="."
			}
		drop temp*	
		replace ${new_var}=substr(${new_var},${N_char},.)
		capture: destring ${new_var}, replace 
		}
	drop event*	
	drop label Label
	save "${working_data}`Tables'_Santonio", replace	
	}
ddd

use "${working_data}UserSignedIn", clear	
sort date

use "${working_data}ActivityCompleted", clear	
sort date

use "${working_data}GroupTransactionLinked", clear	
sort date

use "${working_data}CardPreAuthorizationReceived", clear	
sort date

use "${working_data}TreeAcquired", clear	
sort date
 
 
use "${working_data}TransactionCategorized", clear
merge m:1 rowId using  "${working_data}TransactionConfirmed"
order _merge
sort date
tab  category  _merge

use "${working_data}TransactionConfirmed", clear	
rename (amount mcc) (amount_t mcc_t)
merge m:1 rowId using "${working_data}EcoBalanceDataComputed"

use "${working_data}EcoBalanceDataComputed", clear

use "${working_data}NudgeCreated", clear


********************************************************************************
* Step 4: Browsing History
********************************************************************************

* Step 4.1 Find the fields in the browsing dataset
import delimited "${raw_data}appCenterEvents_MSantoni.csv", clear varnames(1) 
keep event
replace event = subinstr(event,"{","",.)
replace event = subinstr(event,"}","",.)
split event, parse(",")
drop event
foreach even of varlist event*{
	gen field_`even' = substr(`even',1,strpos(`even',":")-2)
	}
keep field*
gen index=_n
reshape long field_event, i(index) j(field_name)
keep field_event
drop if field_event==""
bysort field_event: gen Obs=_N
gduplicates drop
sort Obs

* Step 4.2 Create the Panel
import delimited "${raw_data}appCenterEvents_MSantoni.csv", clear varnames(1) 
keep eventname area timestamp event

*type
drop if eventname==""
drop if eventname=="App error"
replace event = subinstr(event,"{","",.)
replace event = subinstr(event,"}","",.)

global Useful   devicecode EventName area Timestamp IngressTimestamp  Properties /// 
			EventId SessionId CorrelationId   MessageId  MessageType AppId ///
			AppVersion

global Useless   IsTestMessage OsApiLevel LiveUpdateReleaseLabel SdkVersion ///
			OsVersion ScreenSize AppBuild WrapperSdkName InstallId CountryCode ///
			 UserId CarrierName LiveUpdatePackageHash ///
			TimeZoneOffset Model LiveUpdateDeploymentKey  CarrierCountry   ///
			Locale AppNamespace OemName SdkName WrapperRuntimeVersion ///
			OsName WrapperSdkVersion OsBuild 

global variables $Useful $Useless

foreach var in $variables{
	gen 	temp = substr(event,strpos(event,"`var'"),.)
	gen `var'    = substr(temp,strpos(temp,":")+1,.)
	replace `var'= substr(`var',1,strpos(`var',",")-1)
	format `var' %20s
	drop temp
	}
order event, last

replace timestamp=subinstr(timestamp,"T"," ",1)
replace timestamp=substr(timestamp,1,strpos(timestamp,".")-1)

replace IngressTimestamp=subinstr(IngressTimestamp,"T"," ",1)
replace IngressTimestamp=substr(IngressTimestamp,2,strpos(IngressTimestamp,".")-2)

generate double time_stata = clock(timestamp, "YMDhms")
format  time_stata %tc
generate double Ingress_time_stata = clock(IngressTime, "YMDhms")
format Ingress_time_stata  %tc
gen Delta=(time_stata-Ingress_time_stata)/1000

gen temp_day=substr(timestamp,1,10)
gen stata_day = date(temp_day, "YMD")
format  stata_day %td
 
order eventname area time_stata Ingress_time_stata Delta stata_day
sort time_stata
drop if eventname=="RootedDevice"
drop if eventname=="Flowe Backgrounded"
drop if eventname=="Flowe Foregrounded"
drop if eventname=="App info"
drop timestamp Timestamp IngressTimestamp Delta
	
		/*
		keep area
		bysort area: gen N_times=_N
		gduplicates drop
		gsort -N_times
		*/
		
order eventname area SessionId
gen SessionId_manual=0
replace SessionId_manual=1 if area=="Login"
order SessionId_manual
replace  SessionId_manual=sum(SessionId_manual)

bysort SessionId_manual: keep if _n==1 | _n==_N
bysort SessionId_manual: gen Duration=time_stata[_n+1]-time_stata
order Duration
bysort SessionId_manual: keep if _n==1 

replace Duration=Duration/1000
replace Duration=3 if Duration==.

bysort stata_day: gen N_logins=_N
bysort stata_day: gegen N_seconds=sum(Duration)
keep stata_day N_*
gduplicates drop stata_day, force
line N_logins stata_day
line N_seconds stata_day










