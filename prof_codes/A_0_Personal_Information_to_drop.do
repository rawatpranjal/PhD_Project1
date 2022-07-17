
********************************************************************************
* Step 1: Check Overlap Between Events in FloweEvents and Santoni's file
********************************************************************************

import excel "${raw_data}FloweEvents.xlsx", first clear
keep Microservice IntegrationEvent Whenitsfired InterestingAG
format Whenitsfired %100s
rename IntegrationEvent label
gduplicates drop label, force
sort Microservice
save "${working_data}Description_Events", replace

import delimited "${raw_data}SantoniEvents.csv", clear varnames(1) 
keep label
gduplicates drop
merge m:1 label using  "${working_data}Description_Events"
order _merge label Whenitsfired
sort Microservice
sort label

********************************************************************************
* Step 1: Data Library
********************************************************************************

use "${working_data}Label_Event_content_NOPANEL", clear
gen To_drop=0
keep field Example Frequency Event To_drop N_Event 

gen N_char=length(field)-1
replace field=substr(field,2,.)
replace field=substr(field,1,N_char-1)
drop N_char

*gduplicates drop field Example, force
*sort field

/*
gen temp=substr(Event,1,4)
gen is_Goal=temp=="Goal"
replace To_drop=1 if is_Goal==1

gen is_Group=temp=="Grou"
replace To_drop=1 if is_Group==1

gen is_CashBack=temp=="Cash"
replace To_drop=1 if is_CashBack==1
*/

gen Too_infrequent=0
replace Too_infrequent=1 if Frequency<0.1
drop if Too_infrequent==1 
replace To_drop=1 if field=="address"
replace To_drop=1 if field=="addressNumber"
replace To_drop=1 if field=="bankAccountId"
replace To_drop=1 if field=="bankCustomerId"
replace To_drop=1 if field=="bic"
replace To_drop=1 if field=="creditorMailAddress"
replace To_drop=1 if field=="creditorDisplayName"
replace To_drop=1 if field=="creditorName"
replace To_drop=1 if field=="debtorDisplayName"
replace To_drop=1 if field=="debtorIban"
replace To_drop=1 if field=="debtorMailAddress"
replace To_drop=1 if field=="debtorCardMaskedPan"
replace To_drop=1 if field=="email"
replace To_drop=1 if field=="firstName"
replace To_drop=1 if field=="fromUserName"
replace To_drop=1 if field=="iban"
replace To_drop=1 if field=="lastName"
replace To_drop=1 if field=="partyDetail"
replace To_drop=1 if field=="partyPhoneNumber"
replace To_drop=1 if field=="phoneNumber"
replace To_drop=1 if field=="taxId"
replace To_drop=1 if field=="toUserPhoneNumber"
replace To_drop=1 if field=="toUserName"
replace To_drop=1 if field=="userName"

drop N_Event Frequency Too_infrequent
