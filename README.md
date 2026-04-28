# LIS Data Process

## Step 1: Reconcile PIP vs LIS current catalog

- Update aux file in `LIS_data → 02.data → _aux → LIS datasets.xlsx` → sheet **"LIS_survey"**
- Compare # of surveys (rows) vs those in METIS
- Update sheet with missing surveys (country, year, survey name, acronym, currency)
- Note: Acronyms have been created by us with the initials of the survey in English – LIS (ie. HBS-LIS).
- Make sure total number of surveys match.
- Inform Minh of new survey-years to be added (or if there's any eventual change in any survey name or acronym) so that he can add them to the Price Framework and CPI files.

> **Important:** If we fail to add a particular LIS survey in the aux file, it won't be properly saved in the P drive inventory. If an acronym in aux file does not match the one in price framework or CPI files, it won't merge correctly.

## Step 2: Extract 1000 bin data from LISSY

- Run `01.LIS_1000bins.R`
- This file will calculate 1000 bins for each of the survey-years in the LIS inventory, and append them.
- Simply update the years in line 212 (`years_full <- 1963:2024`), and the personal saving folder at the bottom of the code. The rest of the code can stay exactly as it is (note that we use "disposable household income" `dhi` as welfare).
- Currently LIS requires each authorized focal-point from the WB to have their own credentials. They will open a folder under the person's name (i.e `mviver/`) inside their own institution's drive, where you can save output files. LIS then shares the specific files saved upon request.
- The output file is very large (~150 MB), so LIS will give you access to download it through their client site: <https://ftps.lisdatacenter.org>. They will create a user and password to log in, on a by-person basis.

## Step 3: Process data internally

### 3a. Organize output

- Run do-file `02.LIS_organize_output.do`
- This code separates the appended LIS output file into individual survey-year databases, and creates vintage versions in the LIS vintage folder. If the database has changed or if it's new, the code creates a new vintage folder; if it hasn't changed, it skips it.
- Simply update your UPI number path where the LIS repo was cloned, the name of the appended `.csv` file from LIS, and the CPI database to deflate. The rest of the code can stay as is.
- Note that for databases with Euro currency, the code deflates to LCU before saving.
- See output file `02.data/create_dta_status.dta` for a summary of vintages created/skipped.
- Note: summaries reading "…obs did not match CPI data" are simply cases where even though we downloaded data from LIS, we don't use it because we have complete microdata from regional teams (e.g. any Latin American country or any European economy after 2002).

### 3b. Compare with datalibweb

- Run do-file `03.LIS_compare_dlw.do`
- This code compares the fresh dataset vintages in the P: drive vs. those in datalibweb, and identifies which ones experienced welfare changes (changes in Gini), only for the cases that matter to us (9 high income economies, and pre-EUSILC).
- Simply update your UPI number path where the LIS repo was cloned, and the CPI database to deflate. The rest of the code can stay as is.
- See output file `02.data/comparison_results.dta`. Cases with values `gn==1` did not change.
- Note: summaries reading "Error…" either typically 1) indicate new country-years being added (code did not find them in datalibweb); or 2) indicate country-year-acronym combinations that were replaced in the past and we don't use anymore (i.e. CAN97, FRA84…), so the code does not match with the CPI db. For the most part they can be ignored, but double-check if all are expected.

### 3c. Append new bases

- Run do-file `04.Append_new_LIS_bases.do`
- This code helps append only the final cases to be uploaded into datalibweb: databases that are "new" + those that "changed", and appends those few cases into a single file.
- Simply update your UPI number path where the LIS repo was cloned. The rest of the code stays as is.

## Step 4: Compare poverty & Gini

- Estimate poverty and Gini for "new" and "changed" databases (short code attached to email).
- Identify if there are any major changes in trends. For LIS cases, most poverty rates are very small.
- Report results to the rest of the team (Christoph, Minh, Andres).
- LIS quarterly reports can help clarify changes in data: <https://www.lisdatacenter.org/news-and-events/highlights/>
- If trends look ok and questions on data changes have been clarified, proceed to upload in PRIMUS.

## Step 5: Upload to PRIMUS

- Upload "new" and "changed" LIS datasets into PRIMUS (GMD) (short steps attached to email).

