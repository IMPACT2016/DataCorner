/*******************************************************************************
** File name: ACS_state_Fellows_Training_160824.do
** File location: C:/Users/palacios/OneDrive for Business/S/
** Author(s): Vincent Palacios
** Start Date: 9/11/14
** Posted Date: 8/24/16
** Description: 
** This DO file will walk you through various procedures using the Census ACS public 
** use datasets. The purpose is to aquaint you with data set and common commands that 
** are used to analyzed poverty-related and other demographic characteristics of families,
** householders, and children. The script begins with reviewing how to load data and 
** specific variables. Next it defines the poverty universe and determines the population
** of those in poverty by state. Then it moves on to the task of determining families
** and children in poverty where there is a working householder or spouse. 
*******************************************************************************/



/**********************************************************************************
** 	0. SET THE STATA ENVIRONMENT 
**********************************************************************************/

** Saves a log named "Fellows" in your "My Documents" folder.
capture log close Fellows
log using "C:/users/`c(username)'/documents/Fellows_Training_`c(current_date)'.txt", name(Fellows) replace

** Sets the "more" prompt off. This is useful when working with long tables.
set more off

** Clears the data stored in memory.
clear

/* This is a local macro that stores the initials of your state. Replace "dc" with your 
** state's postal abreviation. For example, the line should say "local StateInitials ca" if you
** want data for California. */
local StateInitials ky // Locals are Stata's way of filling in the blank later. Every where below this line, the text `StateInitials' will be replaced with dc when this do file is run 



/**********************************************************************************
** 	1. LOAD DATA (ASSUMING IT IS ALREADY IN STATA FORMAT)
**********************************************************************************/

/* Creates a local macro called "pvars" that contains the names of the variables
** that we want to load from the ACS PUMS dataset. */
local pvars "POVPIP AGEP RELP DIS ESR WKW WKHP SEX SPORDER MAR PUMA SERIALNO ST PWGTP ESP PERNP PINCP RAC1P RACASN RACBLK HISP" // comments

** Load only the necessary ACS variables to reduce memory usage and speed up processing
** times.
use `pvars' using "C:\P\ACS\2014\2014p`StateInitials'.dta", clear //This file path will likely end in 12pXX.dta, where XX are your states's initials.

/* This merges the housing variables to the individual persons in the data by matching
** the serial number of the house. It is many-to-one since there are many persons in the
** already loaded data that share a single house. In other words, every person in 
** a household takes on the same values for the housing variables of that household.
** Only the necessary ACS variables to reduce memory usage. */
local StateInitials "ky"
merge m:1 SERIALNO using "C:\P\ACS\2014\2014h`StateInitials'.dta", keepusing(NP NPF NRC HINCP FINCP WGTP)
 
/* Drop households that were not matched to person files. These are vacant or abandoned 
** houses and do not contain person records. */
keep if _merge == 3

/* Execute an existing DO file called "labelACS.do" that will add Census defined 
** lables to the variables */
capture quietly do "C:\P\ACS\2014\label_ACS_2014_v2.do" //this is a separate do file that we can share on request

** Sort ascending by family identifiers.
sort SERIALNO RELP SPORDER

** Move the following variables to the top of the variable window
order SERIALNO RELP SPORDER AGEP SEX MAR

** Browse all variables
browse

** Browse all variables without labels
browse, nolabel



/**********************************************************************************
** 	2. DEFINE POVERTY 
**********************************************************************************/

/* Define who is in the poverty universe by excluding persons who 
** are unrelated children (persons under 15 who are not related to reference person)
** -or- those that live in group quarters (dorms, nusring homes, youth homes, prisons, 
** mental facilities, etc.) and whose POVPIP value is missing. */
generate byte povuniv = 1
replace       povuniv = 0 if AGEP < 15 & RELP >= 11 // & cy >= 2008   
replace       povuniv = 0 if RELP > 15 & POVPIP == . // & cy >= 2008               
label variable povuniv "Poverty Universe: Excludes some people living in group quarters and unrelated children under 15"

** Create a binary variable that identifies poor families (below 100% of poverty).
generate byte inpoverty = (POVPIP < 100)
label variable inpoverty "Family income is below the poverty line"

** Show a table of population by state.
table ST [pweight=PWGTP], f(%15.3fc) row

** Show a table of the population within the poverty universe by state.
table ST if povuniv==1 [pweight=PWGTP], f(%15.3fc) row

/* Show a table of the population within the poverty universe  and those in poverty
** by state. */
table ST if povuniv==1 [pweight=PWGTP], f(%15.3fc) c(freq sum inpoverty mean inpoverty) row col

** Create race category variable
generate byte RaceCat = 5								/* Other: Not Hispanic, White, Black, or Asian */
label variable RaceCat "5 Category Race/Ethnic Variable"
replace RaceCat = 1 if RAC1P    		== 1		/* White alone, Non-Hispanic */
replace RaceCat = 2 if RAC1P   			== 2		/* Black alone , Non-Hispanic */
replace RaceCat = 4 if RAC1P   			== 6		/* Asian alone , Non-Hispanic */ 
replace RaceCat = 3 if HISP >= 2 & HISP <= 24 		/* Hispanic */
label define RaceCatLB 1 "White NH" 2 "Black NH" 3 "Hispanic" 4 "Asian NH" 5 "Other NH" 
label values RaceCat RaceCatLB

** Verifies that race groups are mutual exclusive
tabulate RaceCat RAC1P if HISP==1 //Visual comparison of race variables
tabulate RaceCat RAC1P if HISP!=1 //Visual comparison of race variables

/* Show a table of the population within the poverty universe, those in poverty,
** and the poverty rate, by race and age category. */
table RaceCat if povuniv==1 [pweight=PWGTP], f(%15.3fc) c(freq sum inpoverty mean inpoverty) row col
table RaceCat if povuniv==1 & AGEP < 18 [pweight=PWGTP], f(%15.3fc) c(freq sum inpoverty mean inpoverty) row col


/**********************************************************************************
** 	3. DEFINE WORK EFFORT FOR ABLE BODIED PERSONS
**********************************************************************************/

** Create a binary variable that identifies related children (related persons under 18).
generate byte relchild = (AGEP < 18 & (RELP > 1 & RELP <= 10))

/* Create a binary variable that identifies able-bodied individuals (under 65 and 
** without a work disability (ds) that also keeps them out of the labor force). */
** Identify able-bodied reference persons and spouses (= "able" if householder or spouse, else 0).
generate byte able = 1
replace  able = 0 if (AGEP >= 65) | (DIS == 1 & ESR == 6)
label variable able "Person is less than 65 and does not have a disability that removes them from the labor force"

** Create a binary variable that identifies able-bodied individuals, reference person and spouse.
generate byte able_HHoS = able * (RELP == 0 | RELP == 1)
label variable able_HHoS "able bodied head/spouse (<65 exc disabil (ds1&esr6))"

** Create a binary variable that identifies those with 1 week of work or greater, all individuals.
generate byte anywork = 0
replace anywork = 1 if (WKW >=1 & WKW <=6) 
label variable anywork "Person has worked at least one week during the past year"

** Create a binary variable that identifies those with 1 week of work or greater, reference person and spouse.
generate byte anywork_HHoS = 0 
replace anywork_HHoS = 1 if (anywork * (RELP == 0 | RELP == 1))
label variable anywork_HHoS "Householder or spouse has worked at least one week during the past year"

** Create a binary variable that identifies full-time work, all individuals.
generate byte ftwork = 0
replace ftwork = 1 if (WKW == 1 & WKHP >= 35) 
label variable ftwork "Person worked full time during the past year"

** Create a binary variable that identifies full-time work, reference person and spouse.
generate byte ftwork_HHoS = 0 
replace ftwork_HHoS = 1 if (ftwork * (RELP == 0 | RELP == 1))
label variable ftwork_HHoS "Householder or spouse worked full time during the past year"

/* Note: the egen command treats missing values as zeros, so summing 
** a value over a household does not return empty values even though an 
** observation might have a missing value for a given variale that is being
** summed.
**	
** By creating family variables and THEN using the egen command to sum up
** over housing units family variables are assigned to non-family members living 
** in the same housing unit. This matches the treatment of non-family members by 
** Census. The alternative, using an "if" statement with egen (e.g. "if RELP <= 10"), 
** produces missing values for non-family members, which may or may not be intended. */
egen byte f_children = sum(relchild), by(SERIALNO)
egen byte f_able_HHoS = sum(able_HHoS), by(SERIALNO)
egen byte f_anywork_HHoS = sum(anywork_HHoS), by(SERIALNO)
egen byte f_ftwork_HHoS = sum(ftwork_HHoS), by(SERIALNO) 
label variable f_children     "Sum of related children in family"
label variable f_able_HHoS    "Sum of able householder or spouse in family"
label variable f_anywork_HHoS "Sum of householder or spouses who worked at all in family"
label variable f_ftwork_HHoS  "Sum of householder or spouses who worked full time in family"

** Create a binary variable that identifies families w/ related children.
generate byte f_childyes = f_children > 0
label variable f_childyes "Families with related children"

/* Create a binary variable that identifies if families with at least one able-bodied 
** householder or spouse. */
generate byte f_able_HHoSyes = (f_able_HHoS >= 1)
label variable f_able_HHoSyes "Fams w/able-bodied head or spouse (<65 exc disab(ds=1 & esf=6))"

/* Create a binary variable that identifies if a family is working if the head 
** or spouse is working (using the aggregated variable). */
generate byte f_anywork_HHoSyes = (f_anywork_HHoS >= 1) 
label variable f_anywork_HHoSyes "Head or spouse worked 1+weeks"

/* Create a binary variable that identifies if a family is working if the head 
** or spouse is working (using the aggregated variable). */
generate byte f_ftwork_HHoSyes = (f_ftwork_HHoS >= 1)
label variable f_ftwork_HHoSyes "Head or spouse worked full-time"



/**********************************************************************************
** 	4. GENERATE TABLES
**********************************************************************************/

/* TABLE 1: Poor families with children in which parents are able to work by state.
** UNIVERSE: Excludes some people living in group quarters and unrelated children under 15" */
table ST if RELP == 0 & inpoverty == 1 & f_childyes == 1 & povuniv == 1 [pw = PWGTP], ///
c(freq sum f_able_HHoSyes mean f_able_HHoSyes) format(%15.3fc) row

/* TABLE 2: Poor families with children, by presence of a worker by state.
** UNIVERSE: Excludes some people living in group quarters and unrelated children under 15"  */
table ST if RELP == 0 & inpoverty == 1 & f_childyes == 1 & f_able_HHoSyes == 1 & povuniv == 1 ///
[pw = PWGTP], c(freq sum f_anywork_HHoSyes mean f_anywork_HHoSyes) format(%15.3fc) row

/* TABLE 3: Number of people in working poor families by state.
** UNIVERSE: Excludes some people living in group quarters and unrelated children under 15"  */
table ST if RELP <= 10 & inpoverty == 1 & f_childyes == 1 & f_able_HHoSyes == 1 & povuniv == 1 ///
[pw = PWGTP], c(freq sum f_anywork_HHoSyes mean f_anywork_HHoSyes) format(%15.3fc) row

/* TABLE 4: Number of related children by state.
** UNIVERSE: Excludes some people living in group quarters and unrelated children under 15" */
table ST if relchild == 1 & inpoverty == 1 & f_childyes == 1 & f_able_HHoSyes == 1 & povuniv == 1 ///
[pw = PWGTP], c(freq sum f_anywork_HHoSyes mean f_anywork_HHoSyes) format(%15.3fc) row

/* TABLE 5: Poor families with children, by presence of a full-time worker.
** UNIVERSE: Excludes some people living in group quarters and unrelated children under 15" */
table ST if RELP == 0 & inpoverty == 1 & f_childyes == 1 & f_able_HHoSyes == 1 & povuniv == 1 ///
[pw = PWGTP], c(freq sum f_ftwork_HHoSyes mean f_ftwork_HHoSyes) format(%15.3fc) row



/**********************************************************************************
** 	5. DEFINING FAMILY STATISTICS AND COMPARING WITH CENSUS VARIABLES  
**********************************************************************************/

** Drop the variale f_numchild if it's already definied
capture drop f_numchild

** Sum up the number of related children by household
egen byte f_numchild = sum(relchild), by (SERIALNO)
label variable f_numchild "number of related children in household"
replace f_numchild = . if RELP>15

** Examines the values of the variale we just created to check for possible errors
inspect f_numchild

** Compare our user-defined variable against the Census-defined variable
compare NRC f_numchild

/* Generate and compare our variable of number of related persons in a family with
** the Census-defined variable. */
capture drop relatedperson f_numper
generate byte relatedperson = RELP <= 10
label variable relatedperson "Person is related to the householder"
egen byte f_numper = sum(relatedperson), by (SERIALNO)
label variable f_numper "Sum of related persons in family"
compare NPF f_numper

/* Identify that families with less then 2 members should be coded as missing.
** Compares our corrected variable against the Census variable. */
tabulate NPF f_numper if f_numper<2, missing
replace f_numper =. if f_numper<2
compare NPF f_numper

** Generate and compare our variable for family income with the Census-defined variable.
capture drop p_pincp f_pincp 
generate long p_pincp = PINCP if RELP <=10
label variable p_pincp "Persons income, only defined for related persons"
egen long f_pincp=sum(p_pincp) , by(SERIALNO)
label variable f_pincp "Sum of personal income by family"
compare FINCP f_pincp


/* TABLE 6: Median family income for poor families with children with at least one 
** able-bodied housholder or spouse, by family
** UNIVERSE: Excludes some people living in group quarters and unrelated children under 15"  */
table ST if RELP == 0 & inpoverty == 1 & f_childyes == 1 & f_able_HHoSyes == 1 & povuniv == 1 ///
[pw = PWGTP], c(freq median f_pincp median FINCP) format(%15.3fc) row



/**********************************************************************************
** 	END OF FILE
**********************************************************************************/
log close Fellows
