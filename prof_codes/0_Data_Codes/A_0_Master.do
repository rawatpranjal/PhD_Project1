macro drop _all

global Antonio_Alberto  	1/* Choose 1 if Antonio's folders and 2 for Alberto's*/
global Antonio_M_Mnew_L_C   2	
global Alberto_C        	1 	/* ... */

global run_data_creation_codes 0
global run_data_analysis_codes 0
********************************************************************************
* Part 1: Prepare the Folders
********************************************************************************

*https://github.com/mcaceresb/stata-gtools/issues/73
*ado dir gtools
*ado uninstall [61]
*ssc install gtools

if $Antonio_Alberto==1{
	if  $Antonio_M_Mnew_L_C==1{
		global path  	"/Users/agargano/Dropbox/Flowe" 
		sysdir set PLUS "/Users/agargano/Dropbox/2_Research/OLD_ADO/ado"	
		global win_mac="/" 
		}	
	if  $Antonio_M_Mnew_L_C==2{
		global path     "/Users/agargano/Dropbox/Flowe" 
		sysdir set PLUS "/Users/agargano/Dropbox/2_Research/ado"	
		global win_mac="/" 
		}	
	if  $Antonio_M_Mnew_L_C==3{
		global path 	"L:\agargano\Dropbox\Flowe"  
		sysdir set PLUS "L:\agargano\Dropbox\2_Research\OLD_ADO\ado"	
		global win_mac="\"
		}	
	if  $Antonio_M_Mnew_L_C==4{
		global path     "C:\Users\agargano\Dropbox\Flowe"  
		sysdir set PLUS "C:\Users\agargano\Dropbox\2_Research\OLD_ADO\ado"	
		global win_mac="\" 
		}		
	}
	
	
	
if $Antonio_Alberto==2{
	if  $Alberto_C==1{
		global path "/Users/albertorossi/Dropbox/Gtown/Flowe" 
		global win_mac="/" 
		}
	}
	
global data_codes="${path}"+"${win_mac}"+"0_Data_Codes"+"${win_mac}"
global raw_data="${path}"+"${win_mac}"+"0_Data_Codes"+"${win_mac}"+"0_Raw_Data"+"${win_mac}"
global working_data="${path}"+"${win_mac}"+"0_Data_Codes"+"${win_mac}"+"0_Working_Data"+"${win_mac}"
global results="${path}"+"${win_mac}"+"0_Results"+"${win_mac}"	
global figures_tables="${path}"+"${win_mac}"+"1_Latex_Word"+"${win_mac}"+"Figures"+"${win_mac}"	
cd "${data_codes}"

********************************************************************************
* Part 2: Run the code
********************************************************************************

if  $run_data_creation_codes==1{
	}

if  $run_data_analysis_codes==1{	
	}
/*

import delimited "${raw_data}part-0000.csv", clear varnames(1) 
save "${raw_data}part-0000.dta", replace



