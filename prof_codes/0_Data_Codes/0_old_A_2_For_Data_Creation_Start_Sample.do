
********************************************************************************
* Part 1: App Actions File
********************************************************************************

*import delimited "${raw_data}part-0001.csv", clear varnames(1) delimiters(",")
*save "${raw_data}part-0001.dta", replace
import delimited "${raw_data}part-0001_new.csv", clear varnames(1) 
save "${raw_data}part-0001_new.dta", replace

* Step: Load the Events File
use "${raw_data}part-0001_new_mac.dta", clear
replace clearedbody=clearedbody+v6+v7+v8+v9+v10+v11+v12+v13+v14
drop v6-v14
rename (integrationevent clearedbody creationdateutc) (label event_field creationdate) 
keep   userid creationdate label event_field  /*messageid*/  
order  userid creationdate label event_field  
replace event_field = subinstr(event_field,"{","",.)
replace event_field = subinstr(event_field,"}","",.)
	*Separate individual field-content touple 
split event_field, parse(", \")
drop event_field event_field14-event_field45

	*The field creationdate is less precise that the one contained in the event_filed.
 	*this means we might loose more observations that necessary in the next duplicates drop
	*which means we might be missing fields belonging to an event
foreach var of varlist event_field*{
	gen  temp_`var'=strpos(`var',"creationDate" )
	}
gen new_CreationDate="."	
foreach var of varlist event_field*{
	replace new_CreationDate=`var' if temp_`var'>0 & new_CreationDate=="."
	}
gen temp_length=strlen(new_CreationDate)			
drop if temp_length>60	
split new_CreationDate, parse(": \")	
drop temp_* new_CreationDate new_CreationDate1 
format new_CreationDate2 %60s
rename new_CreationDate2 creationdate2
order userid label creationdate creationdate2
	
	*The creationdate2 has more duplicates for the NudgeCreated (because sent to multiple people
	*at the same time)
bysort label creationdate2: gen Obs2=_N
bysort label creationdate: gen Obs=_N
drop Obs* 
drop creationdate
rename creationdate2 creationdate

gduplicates drop label creationdate, force 
bysort label: gen Number_times=_N
order Number_times
drop userid 
greshape long event_field, by(label Number_times creationdate) keys(new)

format event_field %50s
drop if event_field==""
drop new
sort label event_field
split event_field, parse(": ")
format event_field1 %25s
replace event_field2=event_field2+" "+event_field3
format event_field2 %50s
drop event_field3
order Number
keep Number label event_field event_field1 event_field2 
rename Number_times N_label
bysort label event_field1: gen N_label_event=_N
order N_label label N_label_event
gsort -N_label label -N_label_event event_field1
save "${working_data}Label_Event_content_PANEL_full_new", replace

use "${working_data}Label_Event_content_PANEL_full_new", clear
gduplicates drop label event_field1, force
gsort -N_label label -N_label_event event_field1
keep N_label label N_label_event event_field1 event_field2

rename N_label N_Event
rename label Event
rename N_label_event N_field
rename event_field1 field
rename event_field2 Example
replace N_field=N_field/N_Event
rename N_field Frequency
replace field = subinstr(field,"\","",.)
save "${working_data}Label_Event_content_NOPANEL_full_new", replace


* Step: Load Santoni File
use "${working_data}Label_Event_content_NOPANEL_santoni", clear
rename (N_Event Frequency Example) (N_EventS FrequencyS ExampleS)
save "${working_data}temp_santoni_event_field", replace
keep Event N_EventS
gduplicates drop Event, force
save "${working_data}temp_santoni_event", replace

use "${working_data}Label_Event_content_NOPANEL_full_new", clear
duplicates drop Event, force
merge 1:1 Event using  "${working_data}temp_santoni_event"
order _merge N_* Event field Frequency* Example*
keep  _merge N_* Event
gsort -N_Event Event 
sort Event 

	*Q: What's the difference between createdateutc and creationdate in the clearbody
	
use "${working_data}Label_Event_content_NOPANEL_full_new", clear
gduplicates drop Event field, force
merge 1:1 Event field using  "${working_data}temp_santoni_event_field"
order _merge N_* Event field Frequency* Example*
gsort -N_Event Event field
drop if Event=="OobRequestCreated"
format field %30s

	*When Event is merged, overlap with fields almost perfect

********************************************************************************
* Part 2: Login Attention Files
********************************************************************************

* Events in Santoni File
import delimited "${raw_data}appCenterEvents_MSantoni.csv", clear varnames(1) 
keep eventname
gduplicates drop eventname, force
save ${working_data}temp_for_merge, replace

* Events in Sample of Users
use ${raw_data}part-0000.dta, clear
keep eventname
gduplicates drop eventname, force
merge 1:1 eventname using ${working_data}temp_for_merge
replace eventname=lower(eventname)
gen test=strpos(eventname,"eco")


use ${raw_data}part-0000.dta, clear
drop if v15~=""
drop v*
format * %20s
global vars_to_keep userid devicecode eventname area timestamp sessionid
order $vars_to_keep
keep $vars_to_keep
keep if area!="" & eventname!=""
tab eventname, sort
tab area, sort

gegen num_sessions=nvals(sessionid), by(userid)
preserve 
gduplicates drop userid, force
tab num_sessions, sort
hist num_sessions if num_sessions<100
restore


replace timestamp=subinstr(timestamp,"T"," ",1)
replace timestamp=substr(timestamp,1,strpos(timestamp,".")-1)
generate double time_stata = clock(timestamp, "YMDhms")
format  time_stata %tc
gen temp_day=substr(timestamp,1,10)
gen stata_day = date(temp_day, "YMD")
format  stata_day %td
tab stata_day

bysort userid (stata_day): gen day_of_usage=_n
gen first_time_use= day_of_usage==1
gegen num_users=nvals(userid), by(stata_day)
gegen num_first_time_users=sum(first_time_use), by(stata_day)

preserve 
gduplicates drop stata_day, force
tab num_users, sort
hist num_users 
gsort stata_day
line num_users stata_day 
sleep 10
line num_first_time_users num_users stata_day 
restore









