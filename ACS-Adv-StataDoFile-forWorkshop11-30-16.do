
/**********************************************************************************
** 	1. LOAD DATA (ASSUMING IT IS ALREADY IN STATA FORMAT)
**********************************************************************************/

*Load data file (This is a person level 2014 ACS file for Florida)
*Will need to edit file name and path in next line.
	use "C:\P\ACS\ACS2014pus_FL.dta", clear

/* Execute an existing DO file called "labelACS.do" that will add Census defined 
** labels to the variables */
*Will need to edit file name and path in next line. 
	do "C:\P\ACS\label_ACS_2014.do"
	
*Check out the data

	*run some basic summary stats of key variables
		sum SERIALNO ST RELP AGEP WAGP SSIP PINCP POVPIP RAC1P HISP
	*read variable labels
		desc SERIALNO ST RELP AGEP WAGP SSIP PINCP POVPIP RAC1P HISP	
		label list relpLB
	*browse the data	
		browse SERIALNO ST RELP AGEP WAGP SSIP PINCP POVPIP RAC1P HISP
	

/**********************************************************************************
** 	2. CREATE DEMOGRAPHIC VARIABLES
**********************************************************************************/
		
** Create age category variable
generate byte AgeCat = 0								
label variable AgeCat "3 Category Age Variable"
replace AgeCat = 1 if AGEP <= 17 		
replace AgeCat = 2 if AGEP >= 18 & AGEP <= 64	
replace AgeCat = 3 if AGEP >= 65	 
label define AgeCatLB 1 "0-17" 2 "18-64" 3 "65+" 
label values AgeCat AgeCatLB

	*Double check that it's working ok:
		tab AgeCat
		tab AGEP AgeCat

** Create race category variable
generate byte RaceCat = 5								/* Other: Not Hispanic, White, Black, or Asian */
label variable RaceCat "5 Category Race/Ethnic Variable"
replace RaceCat = 1 if RAC1P    		== 1		/* White alone, Non-Hispanic */
replace RaceCat = 2 if RAC1P   			== 2		/* Black alone , Non-Hispanic */
replace RaceCat = 4 if RAC1P   			== 6		/* Asian alone , Non-Hispanic */ 
replace RaceCat = 3 if HISP >= 2 & HISP <= 24 		/* Hispanic */
label define RaceCatLB 1 "White Non-Hisp" 2 "Black Non-Hisp" 3 "Hispanic" 4 "Asian Non-Hisp" 5 "Other Non-Hisp" 
label values RaceCat RaceCatLB

	*Double check that it's working ok:
		tab RaceCat
		tab RAC1P RaceCat
		tab RAC1P RaceCat if HISP == 1
		tab RAC1P RaceCat if HISP != 1
		

/**********************************************************************************
** 	3. DEFINE POVERTY 
**********************************************************************************/

/* Define who is in the poverty universe by excluding persons who 
** are unrelated children (persons under 15 who are not related to reference person)
** -or- those that live in group quarters (dorms, nusring homes, youth homes, prisons, 
** mental facilities, etc.) and whose POVPIP value is missing. */
generate byte povuniv = 1
replace       povuniv = 0 if AGEP < 15 & RELP >= 11   
replace       povuniv = 0 if RELP > 15 & POVPIP == .                
label variable povuniv "Poverty Universe: Excludes some people living in group quarters and unrelated children under 15"

** Create a binary variable that identifies poor families (below 100% of poverty).
generate byte inpoverty = (POVPIP < 100)
label variable inpoverty "Family income is below the poverty line"


/**********************************************************************************
** 	4. PRODUCE TABLES
**********************************************************************************/

** Show a table of population by state.
table ST [pweight=PWGTP], f(%15.0fc) row

** Show a table of the population within the poverty universe by state.
table ST if povuniv==1 [pweight=PWGTP], f(%15.0fc) row

** Show a table of population by age
table AgeCat [pweight=PWGTP] if ST == 12 & povuniv == 1, f(%15.0fc) row

** Show poverty rates by age
table AgeCat [pweight=PWGTP] if ST == 12 & povuniv == 1, f(%15.3fc) c(mean inpoverty) row

** Show population by age & race
table AgeCat RaceCat [pweight=PWGTP] if ST == 12 & povuniv == 1, f(%15.0fc) row col

** Show poverty rates by age & race
table AgeCat RaceCat [pweight=PWGTP] if ST == 12 & povuniv == 1, f(%15.3fc) c(mean inpoverty) row col

** Show number of people in poverty by age & race
table AgeCat RaceCat [pweight=PWGTP] if ST == 12 & povuniv == 1 & inpoverty == 1, f(%15.0fc) row col



