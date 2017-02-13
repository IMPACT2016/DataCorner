/*******************************************************************************
* File Name: UsefulStataCommands.do
* File Location: https://365cbpp.sharepoint.com/sites/Intranet/Data/ExampleAnalyses/Forms/AllItems.aspx
* Author(s): Vincent Palacios
* Posted Date: 9/15/16
* Description: Demonstrates various useful commands with ACS PUMS 1-Yr data
*
* Inputs:
* ${F6}/ACS/2014/2014pus.dta
* label_ACS_2014_v2.do
*
* Note: This was written on a PC running Windows 7
*
* Version 1.0
*******************************************************************************/



/*******************************************************************************
** 0. SET ENVIRONMENT
*******************************************************************************/

/* Change the current directory (where Stata will read and write files by default).
** The `c(username)' is a system macro that will swap in your CBPP username automatically. */
cd "C:/Users/`c(username)'/Documents"
** Close the log Data1_log if it exists
capture log close Data1_log
** State the log Data1_log, and replace it if it exists already
log using "Data1_log-`c(current_date)'.txt", replace name(Data1_log)

** Set directory trunk for synced files
if "$F5" == "" {
    if      c(os) = "Windows" global F5 "C:/Users/`c(username)'/OneDrive for Business/S"
    else if c(os) = "MacOSX"  global F5 "/Users/`c(username)'/OneDriveBusiness/S"
}

** Set directory trunk for data files (often to large to sync easily)
if "$F6" == "" {
    if      c(os) = "Windows" global F6 "C:/P"
    else if c(os) = "MacOSX"  global F6 "/P"
}

** Maximum matrix size increased
set matsize 1000

** Allow output to display without having to press space bar for more
set more off

** clear Stata's memory
clear



/*******************************************************************************
**	1. Load data
*******************************************************************************/
** Read in 1-year ACS PUMS data for US, person file, select variables
use SERIALNO SPORDER RELP AGEP SEX RAC1P HISP POVPIP OCCP PINCP ST PWGTP using ${F6}/ACS/2014/2014pus.dta

** Create original sort ID of observations
gen double SortID = _n

** Merge in 1-year ACS PUMS data for US, household file, select variables
** CAUTION: When merging, 
merge m:1 SERIALNO using ${F6}/ACS/2014/2014hus.dta, keepusing(NP NPF NRC HINCP FINCP WGTP)

** Label ACS vairables, using quietly command to supress output
quietly do "C:/Users/palacios/OneDrive for Business/S/DEV/Utility/label_ACS_2014_v2.do"



/*******************************************************************************
**	2. Inspect data
*******************************************************************************/

** Describe dataset and all variables (type, format, label)
describe

** Summary statistics for all variables
summarize

** Summary statistics for all variables with more detail
summarize, detail

** Numeric summmary of all variables by integer/missing category
inspect

** One-way frequency tabulation of RELP
tabulate RELP

** One-way weighted frequency tabulation of RELP without value labels
tabulate RELP [iw=PWGTP], nolabel

** Two-way weighted frequency tabulation of SEX and RAC1P by ST
tab2 ST SEX RAC1P [fw=PWGTP], firstonly

** Look at results of merge command with _merge variable
tab RELP _merge, nolabel missing

** Keep only observations where merge was successful, i.e. drop vacant households
keep if _merge == 3

** Drop _merge variable
drop _merge



/*******************************************************************************
**	3. Sort and Order Data
*******************************************************************************/

** Check to see if SortID uniquely identifies all observations
isid SortID

/* Return to origianl sort order
** CAUTION: Sorting with variables that do not uniquely ID every observation will
** have Stata randomly break ties where all sort variables have matching values */
sort SortID

/* Create person sort ID of observations within household; must be sorted on by variable.
** If sorting on more than one variable, the second variable breaks ties in first variable.
** With bysort, variables in parenthese will still sort the data, but not group the data. */
bysort SERIALNO (SortID): gen double PersonID = _n

** Compares PersonID with SPORDER
compare PersonID SPORDER

** Check to see if SERIALNO SPORDER together uniquely identify all observations
isid SERIALNO SPORDER

** Sort in descending order
gsort -SERIALNO -SPORDER

** Test to see if sorting on ST SERIALNO SPORDER matches original sort order of data
bysort ST SERIALNO (SPORDER): gen double TestID = _n
compare TestID SortID

** Move PWGTP to last variable in dataset (i.e. last column in browser)
order PWGTP, last

** browse ST SERIALNO SPORDER SortID TestID // Browse ID variables



/*******************************************************************************
**	4. Creating Categoric Variables
*******************************************************************************/

/* Define who is in the poverty universe by excluding those who are unrelated children 
** (persons under 15 who are not related to reference person) or who live in group 
** quarters (dorms, nusring homes, youth homes, prisons, mental facilities, etc.). 
** Note: This differs slightly than the poverty universe used in ACS summary tables. */
generate byte povunivNoGQ = 1
replace       povunivNoGQ = 0 if AGEP < 15 & RELP >= 11 // & cy >= 2008   
replace       povunivNoGQ = 0 if RELP >= 16             // & cy >= 2008               
label variable povunivNoGQ "Poverty Universe: Excludes unrelated children under 15 and people living in group quarters."

/* Create a binary variable that identifies poor families (below 100% of poverty)
** using a comparison expression; resulting values are 1 if true and 0 if false.*/
generate byte b100 = (POVPIP < 100)
label variable b100 "Family income is below the poverty line"

**	Using inrange() qualifier; see also inlist() 
gen byte RaceCat = 5                         /* Other/Multiracial, Non-Hispanic */
replace RaceCat = 1 if RAC1P   == 1          /* White alone, Non-Hispanic */
replace RaceCat = 2 if RAC1P   == 2          /* Black alone, Non-Hispanic */
replace RaceCat = 4 if RAC1P   == 6          /* Asian alone, Non-Hispanic */ 
replace RaceCat = 3 if inrange(HISP,2,24)    /*Hispanic, any race */
label var RaceCat "5 Category Race/Ethnic Variable"
label define RaceCatLB 1 "White, NH" 2 "Black, NH" 3 "Hispanic" 4 "Asian, NH" 5 "Other/Multiracial, NH" 
label values RaceCat RaceCatLB

** Using line break (///) for long lines of code
gen wcocc = .
replace wcocc = 1 if OCCP == 3600
replace wcocc = 2 if OCCP == 4020
replace wcocc = 3 if OCCP == 4030
replace wcocc = 4 if OCCP == 4110
replace wcocc = 5 if OCCP == 4220
replace wcocc = 6 if OCCP == 4230
replace wcocc = 7 if OCCP == 4250
replace wcocc = 8 if OCCP == 4600
replace wcocc = 9 if OCCP == 4610
replace wcocc = 10 if OCCP == 4720
replace wcocc = 11 if OCCP == 4760
replace wcocc = 12 if OCCP == 5620
replace wcocc = 13 if OCCP == 6260
replace wcocc = 14 if OCCP == 9130
replace wcocc = 15 if OCCP == 9620
replace wcocc = 16 if OCCP <  9920 & wcocc == .
label var wcocc "Working Class Occupations"
label define wcoccLB ///
1 "Nursing, psychiatric, and home health aides " ///
2 "Cooks" ///
3 "Food preparation workers " ///
4 "Waiters and waitresses " ///
5 "Janitors and building cleaners " ///
6 "Maids and housekeeping cleaners " ///
7 "Grounds maintenance workers " ///
8 "Child care workers " ///
9 "Personal and home care aides " ///
10 "Cashiers " ///
11 "Retail salespersons " ///
12 "Stock clerks and order fillers " ///
13 "Construction laborers " ///
14 "Driver/sales workers and truck drivers" ///
15 "Laborers and freight, stock, and material movers , hand" ///
16 "All other occupations"
label values wcocc wcoccLB

**egen with cut() function; missing values are recoded to missing
egen byte IncomeCat = cut(PINCP), at(-19999,0,25000,50000,75000,125000,250000,9999999) label

**egen with max() function and comparison expression; result is dichotomous variable 
egen byte hasChildren = max(AGEP<18), by(SERIALNO)



/*******************************************************************************
**	5. Tabulating Data for Presenation
*******************************************************************************/
/* TABLE 1: Total Households, Households in Poverty, and Household Poverty Rate, by State.
** UNIVERSE: Excludes people living in group quarters and unrelated children under 15" */
table ST if RELP == 0 & povunivNoGQ == 1 [pw = WGTP], ///
        c(freq sum b100 mean b100) format(%15.3fc) row

** Same table, different command, different formatting        
tabstat b100 if RELP == 0 & povunivNoGQ == 1 [fw = WGTP], ///
        by(ST) stat(n sum mean) format(%15.3gc) 

        
        
/*******************************************************************************
**	6. Working with Matrices
*******************************************************************************/

** Save tabulations into named matrices
** Those above and below poverty, by ST
tab ST b100 [iw=PWGTP] if povunivNoGQ, matcell(TotalPoverty)
** Those above and below poverty, by ST, males only
tab ST b100 [iw=PWGTP] if povunivNoGQ & SEX == 1, matcell(Male_Poverty)
** Those above and below poverty, by ST, frmales only
tab ST b100 [iw=PWGTP] if povunivNoGQ & SEX == 2, matcell(Female_Poverty)

** List all matrices in memory
matrix dir

** Display TotalPoverty matrix
matrix list TotalPoverty

** Combine, by adding new columns, all three poverty matrices
mat PovertyEstimates = TotalPoverty, Male_Poverty, Female_Poverty

** Add column names to PovertyEstimates matrix
mat colnames PovertyEstimates = a100 b100 a100_1 b100_1 a100_2 b100_2

** Display PovertyEstimates matrix
mat list PovertyEstimates

/* Preserve data in memory, and then collapse the data, concatenate the 
** categoric variables, reshape the data from long to wide, save the data
** to a new matrix, and restore the original data to memory */
preserve
    gen byte a100 = b100 == 0
    /*gen byte PopTotal = 1*/
    collapse (sum) a100 b100 /*PopTotal*/ [iw=PWGTP] if povunivNoGQ == 1, by(ST RaceCat SEX)
    egen Sex_Race = concat(SEX RaceCat), p(_)
    replace Sex_Race = "_" + Sex_Race
    drop SEX RaceCat
    reshape wide a100 b100 /*PopTotal*/, i(ST) j(Sex_Race) string
    // order ST a* b* /*P**/
    mkmat _all, matrix(RaceCat_SEX_Poverty)
restore

** Display RaceCat_SEX_Poverty matrix
mat list RaceCat_SEX_Poverty
** Append, column-wise, first column of RaceCat_SEX_Poverty, then PovertyEstimates,
** then remaining columns of RaceCat_SEX_Poverty and replace PovertyEstimates matrix
mat PovertyEstimates = RaceCat_SEX_Poverty[1..51,1],PovertyEstimates, RaceCat_SEX_Poverty[1..51,2..21]
** Display PovertyEstimates matrix
mat list PovertyEstimates

** Working Class Occupations, matrices
tab ST wcocc [iw=PWGTP/3] if povunivNoGQ == 1, matcell(PovUniv_wcocc) ///
         matrow(ST_vals) matcol(wcocc_vals)
tab ST wcocc [iw=PWGTP/3] if povunivNoGQ == 1 & b100 == 0, matcell(PovAAbove_wcocc)
tab ST wcocc [iw=PWGTP/3] if povunivNoGQ == 1 & b100 == 1, matcell(PovBelow_wcocc)


/*******************************************************************************
**	7. Exporting Data to Excel
*******************************************************************************/

** Set local for the name of the excel file, must use .xlsx extension
local filepath "RACETH-OCCP-POV.xlsx"
** Tell Stata which excel file to use in future commands, invoke any options needed
putexcel set  "`filepath'", modify keepcellformat

** User program ExcelR1C1 converts a number to it's alphabetic column equivalent
** in Excel using a base26 conversion, and stores it in the returned macro r(base26)
ExcelR1C1 34
** Save the returned macro to a new local macro called "C"
local C `r(base26)'

** Put the matrices into an excel sheet named "WCOCC POV Stata"
putexcel A11 = matrix(ST_vals) ///
         B10 = matrix(wcocc_vals) B11 = matrix(PovBelow_wcocc) ///
         R10 = matrix(wcocc_vals) R11 = matrix(PovAAbove_wcocc) ///
         `C'10 = matrix(wcocc_vals) `C'10 = matrix(PovUniv_wcocc) ///
         , sheet("WCOCC POV Stata") 

** Put the matrices into an excel sheet named "SEX RACE POV Stata"
putexcel A11 = matrix(PovertyEstimates) ///
        , sheet("SEX RACE POV Stata") 
        
        
        
/*******************************************************************************
**	End of Analysis
*******************************************************************************/
** Close the log named Data1_log
cap log close Data1_log