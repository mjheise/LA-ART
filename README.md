# SPLASH: Ward 86 & Ponce de Leon Outcomes by Viremia at Initiation

This script analyzes clinical outcomes for patients receiving long-acting injectable CAB/RPV (cabotegravir/rilpivirine) across two HIV clinics: UCSF Ward 86 (San Francisco) and Emory Ponce de Leon (Atlanta). Data from both sites are cleaned, harmonized, and merged into a single analytic dataset linking viral load measurements to injection records via fuzzy date matching (±14 days).

## Sections

### 1. Data Cleaning – Ward 86
Cleans demographic, viral load, injection timing, BMI, CD4, and discontinuation data; derives substance use indicators; fuzzy-joins viral loads to injection dates; appends unmatched records; runs data integrity checks.

### 2. Data Cleaning – Ponce de Leon
Parallel cleaning pipeline for Ponce data, including pivot from wide-to-long viral load format and derivation of injection timing from dosing intervals.

### 3. Site Merge
Combines Ward 86 and Ponce datasets; harmonizes variables across sites; derives viremia classification at initiation and post-suppression virologic outcomes (**suppressed**, **blips**, **PLLV**, **virologic failure**) using a rule-based algorithm applied to each patient's post-suppression viral load trajectory.

### 4. Table 1
Demographic and clinical characteristics by site.

### 5. Kaplan-Meier
Time to first viral suppression (<50 copies/mL) among patients initiating with viremia, with KM curve and risk table.

### 6. Blips
Logistic regression examining predictors of viral blips; secondary analysis testing whether late injections predict subsequent elevated viral loads using a mixed-effects model.

### 7. Injection Adherence
Summary of on-time injection rates and lateness (median/IQR); mixed-effects logistic regression predicting on-time adherence.

### 8. Persistent Low-Level Viremia (PLLV)
Firth logistic regression (due to separation) examining predictors of PLLV.

### 9. Virologic Failure
Firth logistic regression examining predictors of confirmed virologic failure.

### 10. PLLV/Blips as Precursors to Virologic Failure
Among patients who achieved suppression, characterizes whether blips or PLLV preceded virologic failure using Fisher's exact tests and proportion tests comparing VF vs. non-VF patients.

### 11. Supplemental Tables
Merged formatted regression tables for blips, PLLV, and virologic failure.
