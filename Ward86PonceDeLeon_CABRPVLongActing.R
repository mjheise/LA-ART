## ---------------------------
##
## Project: SPLASH: Ward 86 & Ponce de Leon Outcomes by Viremia at Initiation
##
## Author: MJ Heise
##
## Date Created: 2026-11-19
## Last Run: 2026-03-16
##
## ---------------------------
# CODE DESCRIPTION:
# 1-3. DATA CLEANING:
#  Clean viral load and CAB/RPV injection data for both Ward 86 and Ponce de Leon clinics and 
#  bind into one df consisting of: de-identified ID/mrn, viral load, date of viral load, CAB/RPV order name,
#  CAB/RPV injection date, whether CAB/RPV was administered on-time (+/- 7 days), age, gender, race and 
#  ethnicity, substance use, viral load at referral, date of referral VL, ART regimen, dosing frequency,
#  whether patient discontinued CAB/RPV, housing status (stably/unstably housed), BMI, CD4 count at initiation,
#  clinic/site, whether patient was viremic at initiation (<50 copies/mL), viremia classification (suppressed
#  at all observations following initial viral suppression, blips 1+ VL >50 copies/mL followed by a suppressed
#  VL, persistent low level viremia - PLLV - 2+ VL 50-200 copies/mL consecutively, or virologic failure
#  2+ VL >200 consecutively), total number of viral load observations, and duration on CAB/RPV from initiation. 
#
# 4. TABLE 1:
#  Additional data organization to harmonize variables across sites, Table 1 of patient demographic &
#  clinical characteristics. 
#
# 5. KAPLAN MEIER:
#  Time to first suppression (VL < 50 copies/mL) for patients initiating with viremia with KM curve and
#  risk table.
#
# 6. BLIPS ACROSS PEOPLE WHO INITIATED WITH VIREMIA OR SUPPRESSED:
#  Logistic regression to examine whether blips were predicted by viremia at initiation, age, race/ethnicity,
#  BMI, CD4 count, dosing pattern (4 or 8 weeks), and percentage of on-time injections.
# 
# 7. PERCENT OF INJECTIONS THAT WERE ON-TIME:
#  Summarizes CAB/RPV injection timing across the cohort (total injections, % on-time, and median/IQR of days 
#  late for truly late injections), then fits a mixed-effects logistic regression with a random intercept for 
#  patient to identify predictors of on-time injection adherence. Lateness is operationalized by inferring each 
#  patient's intended dosing interval (Q4wk vs. Q8wk) from days since prior injection, with a 7-day grace window.
#
# 8. PERSISTENT LOW LEVEL VIREMIA:
#  Logistic regression to examine whether PLLV was predicted by viremia at initiation, age, race/ethnicity,
#  BMI, CD4 count, dosing pattern (4 or 8 weeks), and percentage of on-time injections.
#
# 9. VIRAL FAILURE:
#  Logistic regression to examine whether VF was predicted by viremia at initiation, age, race/ethnicity,
#  BMI, CD4 count, dosing pattern (4 or 8 weeks), and percentage of on-time injections.
# 
# 10. DO PLLV OR BLIPS PREDICT SUBSEQUENT VF:
#  Re-categorize PLLV, blips, and VF to not be mutually exclusive in order to identify whether PLLV or blips
#  occurred before VF. 
#
# 11. SUMMARY TABLES FOR SUPPLEMENT:
#  Formatted regression tables examining blips (see 6), PLLV (see 8), and VF (see 9).


# Libraries
library(tidyverse) # v.2.0.0, data management
library(readxl)    # v.1.4.3, read and write excel files
library(table1)    # v.1.4.3, formatted Table 1
library(janitor)   # v.2.2.1, clean names
library(fuzzyjoin) # v.0.1.6, join VL and injections by closest dates
library(gtsummary) # v.2.1.0, formatted regression tables
library(survival)  # v. 3.8-3, survival analyses, km curve
library(ggsurvfit) # v.1.1.0, survival figures
library(lme4)      # v.1.1-36, mixed effects models
library(lmerTest)  # v.3.1-3, mixed effects models
library(officer)   # v.0.6.8, powerpoint
library(rvg)       # v.0.3.4, powerpoint
library(logistf)   # v.1.26.1, Firth regression


# Function to create or append slides in PowerPoint
create_pptx <- function(plt = last_plot(), path = "output.pptx", width = 0, height = 0){
  if(!file.exists(path)) {
    out <- read_pptx() # Create a new PowerPoint file if it doesn't exist
  } else {
    out <- read_pptx(path) # Open existing PowerPoint file
  }
  
  # Add the plot to the PowerPoint
  if (width != 0 & height != 0) {
    out <- out %>%
      add_slide(layout = "Title and Content", master = "Office Theme") %>%
      ph_with(value = dml(ggobj = plt), location = ph_location(left = 0, top = 0,
                                                               width = width, height = height))
  } else {
    out <- out %>%
      add_slide(layout = "Title and Content", master = "Office Theme") %>%
      ph_with(value = dml(ggobj = plt), location = ph_location_fullsize())
  }
  
  print(out, target = path)
}


#### 1. SPLASH DATA ORGANIZATION ####
# Set powerpoint directory
pptx_path <- 'C:/Users/mheise/Desktop/SPLASH_figures.pptx'

# Set working directory


# Read data
dat_v <- read_excel('LAI patients with viral load lab results 012021 to present (08042025)_deidentified.xlsx')
dat_i <- read_excel('Cabotegravir Injections_01.01.24-08.04.25_deidentified.xlsx')
dat_d <- read.csv('SPLASH-Aug2025_deidentified.csv')
dat_dis <- read.csv('SPLASH-Feb2025.csv')
dat_bmi <- read.csv('mrns_with_bmi.csv')
dat_cd4 <- read_excel('LAI patients with CD4 lab results 012021 to present (08042025)_deidentified.xlsx')

# Janitor names
dat_d <- dat_d %>%
  clean_names()

dat_i <- dat_i %>%
  clean_names()

dat_v <- dat_v %>%
  clean_names()

dat_dis <- dat_dis %>%
  clean_names()

dat_bmi <- dat_bmi %>%
  clean_names()

dat_cd4 <- dat_cd4 %>%
  clean_names()

# Create demographics and patient variables
dat_d <- dat_d %>%
  filter(!is.na(mrn) & mrn != '') %>%
  mutate(mrn = as.numeric(mrn),
         substanceUse_meth = case_when(
           grepl('amphetamine', substance_use, ignore.case = T) ~ 1,
           grepl('meth', substance_use, ignore.case = T) ~ 1,
           .default = 0),
         substanceUse_alc = case_when(
           grepl('alcohol', substance_use, ignore.case = T) ~ 1,
           grepl('AUD', substance_use, ignore.case = T) ~ 1,
           .default = 0),
         substanceUse_cocaine = case_when(
           grepl('crack', substance_use, ignore.case = T) ~ 1,
           grepl('cocaine', substance_use, ignore.case = T) ~ 1,
           grepl('cacaine', substance_use, ignore.case = T) ~ 1,
           .default = 0),
         substanceUse_marijuana = case_when(grepl('marijuana', substance_use, ignore.case = T) ~ 1,
                                            .default = 0),
         substanceUse_psych = case_when(
           grepl('psychidelics', substance_use, ignore.case = T) ~ 1,
           grepl('mushrooms', substance_use, ignore.case = T) ~ 1,
           .default = 0),
         substanceUse_opiate = case_when(
           grepl('benzodiazepines', substance_use, ignore.case = T) ~ 1,
           grepl('oxycontin', substance_use, ignore.case = T) ~ 1,
           grepl('fentanyl', substance_use, ignore.case = T) ~ 1,
           grepl('heroine', substance_use, ignore.case = T) ~ 1,
           grepl('methadone', substance_use, ignore.case = T) ~ 1,
           grepl('heroin', substance_use, ignore.case = T) ~ 1,
           grepl('heoin', substance_use, ignore.case = T) ~ 1,
           grepl('OUD', substance_use, ignore.case = T) ~ 1,
           .default = 0),
         substanceUse_inject = case_when(
           grepl('no IDU', substance_use, ignore.case = T) ~ 0,
           grepl('Denies IDU', substance_use, ignore.case = T) ~ 0,
           grepl('IVDU', substance_use, ignore.case = T) ~ 1,
           grepl('IDU', substance_use, ignore.case = T) ~ 1,
           grepl('IV', substance_use, ignore.case = T) ~ 1,
           .default = 0),
         substanceUse_ghb = case_when(grepl('GHB', substance_use, ignore.case = T) ~ 1,
                                      .default = 0),
         substanceUse_stimulant = case_when(
           grepl('stimulant', substance_use, ignore.case = T) ~ 1,
           substanceUse_meth == 1 ~ 1,
           substanceUse_cocaine == 1 ~ 1,
           .default = 0),
         substanceUse_any = case_when(
           substanceUse_meth == 1 ~ 1,
           substanceUse_cocaine == 1 ~ 1,
           substanceUse_psych == 1 ~ 1,
           substanceUse_opiate == 1 ~ 1,
           .default = 0), 
         substanceUse_currentmeth = case_when(is.na(substance_use) | substance_use == "" ~ NA_real_,  # Keep NA or "" as NA
                                              str_detect(substance_use, "(?i)meth|amphetamine") & 
                                                !str_detect(substance_use, "(?i)past|history|h/o|none currently|remission") ~ 1,
                                              TRUE ~ 0),
         race = case_when(grepl('Black', race_one, ignore.case = T) ~ 'Black',
                          grepl('American Indian', race_one, ignore.case = T) ~ 'American Indian',
                          grepl('Asian', race_one, ignore.case = T) ~ 'Asian',
                          grepl(',', race_one, ignore.case = T) ~ 'Multi-racial',
                          grepl('Other', race_one, ignore.case = T) ~ 'Other',
                          grepl('White', race_one, ignore.case = T) ~ 'White',
                          grepl('Decline', race_one, ignore.case = T) ~ NA,
                          .default = NA),
         race = relevel(factor(race), ref = 'White'),
         race_abbv = case_when(race == 'American Indian' ~ 'Other/multiracial',
                               race == 'Multi-racial' ~ 'Other/multiracial',
                               race == 'Other' ~ 'Other/multiracial',
                               .default = race), 
         race_abbv = relevel(factor(race_abbv), ref = 'White'),
         ethnicity = case_when(grepl('Yes', ethnicity, ignore.case = F) ~ 'Hispanic, Latino/a, or Spanish origin',
                               grepl('Not', ethnicity, ignore.case = F) ~ 'Not Hispanic, Latino/a, or Spanish origin',
                               ethnicity == '' ~ NA,
                               ethnicity == 'Declined to Answer' ~ NA),
         sex = case_when(grepl('Male', sex, ignore.case = F) ~ 'Male',
                         sex == 'Female' ~ 'Female',
                         .default = NA),
         gender = case_when(grepl('Female', gender_identity, ignore.case = T) ~ 'Female',
                            grepl('Male', gender_identity, ignore.case = T) ~ 'Male',
                            grepl('Non-binary', gender_identity, ignore.case = T) ~ 'Nonbinary/Genderqueer/Other',
                            grepl('Other', gender_identity, ignore.case = T) ~ 'Nonbinary/Genderqueer/Other',
                            .default = NA),
         gender = relevel(factor(gender), ref = 'Male'),
         gender_identity = case_when(sex == 'Male' & gender == 'Male' ~ 'Cisgender man',
                                     sex == 'Male' & gender == 'Female' ~ 'Transgender woman',
                                     sex == 'Female' & gender == 'Female' ~ 'Cisgender woman',
                                     sex == 'Female' & gender == 'Male' ~ 'Transgender man',
                                     gender == 'Nonbinary/Genderqueer' ~ 'Nonbinary',
                                     sex == 'Nonbinary' ~ 'Nonbinary',
                                     .default = gender),
         gender_identity = relevel(factor(gender_identity), ref = 'Cisgender man'),
         housing = case_when(grepl('Rent or own', housing_status, ignore.case = T) ~ 'Stable (rent/own)',
                             grepl('Rent ot own', housing_status, ignore.case = T) ~ 'Stable (rent/own)',
                             grepl('SRO', housing_status, ignore.case = T) ~ 'Unstable (SRO, homeless)',
                             grepl('shelter', housing_status, ignore.case = T) ~ 'Unstable (SRO, homeless)',
                             grepl('outdoors', housing_status, ignore.case = T) ~ 'Unstable (SRO, homeless)',
                             grepl('friends', housing_status, ignore.case = T) ~ 'Unstable (SRO, homeless)',
                             grepl('transitional', housing_status, ignore.case = T) ~ 'Unstable (SRO, homeless)'),
         initiation_dose_date = as.Date(initation_dose_date, format = "%m/%d/%Y")) %>%
  select(-initation_dose_date, -sex, -race_one, -housing_status, -date_referred, -status, -x) %>%
  rename(vl_at_referral = v_lat_referral) %>%
  filter(!is.na(initiation_dose_date))

# Clean referral viral load (convert to numeric) & create variable for viremia at initiation (<50 copies/mL)
dat_d <- dat_d %>%
  mutate(mrn = as.character(mrn),
         referral_vl = case_when(vl_at_referral == 'Pending' ~ NA,
                                 TRUE ~ as.numeric(vl_at_referral)),
         referral_vl_date = as.Date(vl_at_referral, format = "%m/%d/%Y"),
         viremic_at_initiation_wLLV = case_when(referral_vl <= 50 ~ 'Suppressed',
                                           referral_vl > 50 & referral_vl < 200 ~ 'LLV',
                                           referral_vl > 200 ~ 'Viremic'),
         viremic_at_initiation = case_when(referral_vl <= 50 ~ 'Suppressed',
                                           referral_vl > 50 & referral_vl < 200 ~ 'Viremic',
                                           referral_vl > 200 ~ 'Viremic'))

# Clean bmi
dat_bmi <- dat_bmi %>%
  select(mrn, last_bmi) %>%
  rename(bmi = last_bmi) %>%
  mutate(mrn = as.character(mrn))

# Clean injection dates
dat_i <- dat_i %>%
  mutate(cabrpv_injection_date = as.Date(administration_instant),
         cabrpv_ontime = case_when(timely_administration_status == 'Early' ~ 'On Time',
                                   timely_administration_status == 'N/A' ~ NA_character_,
                                   TRUE ~ timely_administration_status)) %>%
  select(mrn, order_name, cabrpv_injection_date, cabrpv_ontime)

# Clean viral load
dat_v <- dat_v %>%
  select(mrn, result_date, result_value) %>%
  mutate(mrn = as.character(mrn),
         viral_load_character = case_when(result_value == 'DETECTED' ~ '20',
                                grepl('not detected', result_value, ignore.case = T) ~ '20',
                                grepl('>10 Million', result_value, ignore.case = T) ~ '10000000',
                                TRUE ~ (gsub("detected|copies/ml|,|<", "", result_value, ignore.case = TRUE))),
         viral_load = as.numeric(viral_load_character),
         viral_load_date = as.Date(result_date)) %>%
  filter(!is.na(viral_load)) %>%
  select(mrn, viral_load, viral_load_date)

# Find date patient discontinued
dat_dis <- dat_dis %>%
  mutate(discontinued_date = as.Date(discontinued_date, format = "%m/%d/%Y"))

dat_dis <- dat_dis %>%
  filter(!is.na(discontinued_date)) %>%
  select(mrn, discontinued_date)

# Combine discontinued date with viral load data
dat_v <- dat_v %>%
  left_join(dat_dis, by = 'mrn')

# Filter viral loads after patient discontinued LA-ART
dat_v <- dat_v %>%
  filter(is.na(discontinued_date) | viral_load_date <= discontinued_date)

# ADD THIS: Filter viral loads after initiation injection
dat_v <- dat_v %>%
  left_join(dat_d %>% select(mrn, initiation_dose_date), by = "mrn") %>%
  mutate(initiation_dose_date = as.Date(initiation_dose_date)) %>%
  filter(is.na(initiation_dose_date) | viral_load_date > initiation_dose_date) %>%
  select(-initiation_dose_date)  # Remove this column, we'll get it from dat_d later

# Filter viral loads after initiation injection AND deduplicate
dat_v <- dat_v %>%
  left_join(dat_d %>% select(mrn, initiation_dose_date), by = "mrn") %>%
  mutate(initiation_dose_date = as.Date(initiation_dose_date)) %>%
  filter(is.na(initiation_dose_date) | viral_load_date > initiation_dose_date) %>%
  select(-initiation_dose_date) %>%
  # DEDUPLICATE - keep first row per unique VL date
  group_by(mrn, viral_load_date) %>%
  slice(1) %>%
  ungroup()

# Also deduplicate dat_i if needed
dat_i <- dat_i %>%
  group_by(mrn, cabrpv_injection_date) %>%
  slice(1) %>%
  ungroup()

# Merge injection date and viral load (fuzzy join)
joined <- fuzzy_left_join(
  dat_v,
  dat_i,
  by = c(
    "mrn" = "mrn",
    "viral_load_date" = "cabrpv_injection_date"
  ),
  match_fun = list(
    `==`,
    function(x, y) abs(x - y) <= 14
  )
) %>%
  mutate(mrn = case_when(!is.na(mrn.x) ~ mrn.x,
                         !is.na(mrn.y) ~ mrn.y)) %>%
  select(-mrn.x, -mrn.y)

# Keep closest injection per viral load
closest_vl <- joined %>%
  group_by(mrn, viral_load_date) %>%
  slice_min(abs(viral_load_date - cabrpv_injection_date), with_ties = FALSE) %>%
  ungroup()

# Keep closest viral load per injection (to prevent duplicate injections)
closest_both <- closest_vl %>%
  group_by(mrn, cabrpv_injection_date) %>%
  slice_min(abs(viral_load_date - cabrpv_injection_date), with_ties = FALSE, na_rm = FALSE) %>%
  ungroup()

# Identify unmatched viral loads
unmatched_vl <- anti_join(dat_v, closest_both, by = c("mrn", "viral_load_date"))

# Identify unmatched injections
unmatched_inj <- anti_join(dat_i, closest_both, by = c("mrn", "cabrpv_injection_date"))

# Prepare unmatched data
unmatched_vl_to_append <- unmatched_vl %>%
  mutate(
    cabrpv_injection_date = as.Date(NA),
    cabrpv_ontime = as.character(NA),
    order_name = as.character(NA)
  )

unmatched_inj_to_append <- unmatched_inj %>%
  mutate(
    viral_load_date = as.Date(NA),
    viral_load = as.numeric(NA),
    discontinued_date = as.Date(NA)  # Add this since dat_v has it
  )

# Combine everything
dat_splash_combined <- bind_rows(
  closest_both,
  unmatched_vl_to_append,
  unmatched_inj_to_append
) %>%
  select(mrn, everything()) %>%
  arrange(mrn, viral_load_date, cabrpv_injection_date)

# Merge with demographics
dat_splash_with_demo <- dat_splash_combined %>%
  left_join(dat_d, by = "mrn") %>%
  select(mrn, everything())

# Filter out people on PrEP with injection data
dat_splash <- dat_splash_with_demo %>%
  filter(!is.na(viremic_at_initiation)) %>%
  select(-race, -discontinued_date) %>%
  rename(race = race_abbv) %>%
  select(mrn, viral_load, viral_load_date, order_name, cabrpv_injection_date, cabrpv_ontime,
         age_yrs, gender_identity, ethnicity, race_multi, race, substance_use, vl_at_referral, 
         vl_at_referral_date, regimen, dosing, discontinued, housing)

# Add BMI to dataset
dat_splash <- dat_splash %>%
  left_join(dat_bmi, by = 'mrn')

# Pull CD4 count at LA-ART initiation
dat_cd4 <- dat_cd4 %>%
  filter(component_name == 'ABSOLUTE CD4 T CELLS BY FLOW CYTOMETRY' & !is.na(result_value)) %>%
  select(mrn, result_value) %>%
  rename(cd4 = result_value) %>%
  mutate(cd4 = case_when(cd4 == '< 10' | cd4 == '<10' ~ '10',
         TRUE ~ cd4),
         cd4 = as.numeric(cd4),
         mrn = as.character(mrn))

# Get the earliest LA-ART initiation date for each patient
dat_splash_first <- dat_splash %>%
  mutate(first_laart_date = pmin(viral_load_date, cabrpv_injection_date, na.rm = TRUE))

# Merge CD4 data with splash data and find closest CD4 to LA-ART initiation
dat_firstcd4 <- dat_splash_first %>%
  left_join(dat_cd4, by = "mrn") %>%
  mutate(days_diff = abs(as.numeric(difftime(cd4, first_laart_date, units = "days")))) %>%
  group_by(mrn) %>%
  slice_min(days_diff, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(-days_diff) %>%
  select(mrn, cd4) %>%
  rename(cd4_at_initiation = cd4)

# Merge CD4 at initiation with SPLASH data
dat_splash <- dat_splash %>%
  left_join(dat_firstcd4, by = 'mrn')


# DATA CHECKS AFTER COMBINING VIRAL LOADS AND INJECTION DATA
# Store original counts AFTER filtering
dat_v_filtered <- dat_v %>%
  left_join(dat_d %>% select(mrn, initiation_dose_date), by = "mrn") %>%
  mutate(initiation_dose_date = as.Date(initiation_dose_date)) %>%
  filter(is.na(initiation_dose_date) | viral_load_date > initiation_dose_date)

n_viral_splash <- nrow(dat_v_filtered)
n_inj_splash <- nrow(dat_i)

cat("=== ORIGINAL DATA ===\n")
cat("Viral loads in dat_v (after filtering):", n_viral_splash, "\n")
cat("Injections in dat_i:", n_inj_splash, "\n\n")

# Final counts (use dat_splash_combined before filtering for PrEP patients)
n_final <- nrow(dat_splash_combined)
n_matched_vl <- dat_splash_combined %>% filter(!is.na(viral_load_date)) %>% nrow()
n_matched_inj <- dat_splash_combined %>% filter(!is.na(cabrpv_injection_date)) %>% nrow()

cat("=== FINAL DATA (dat_splash_combined) ===\n")
cat("Total rows:", n_final, "\n")
cat("Rows with viral loads:", n_matched_vl, "\n")
cat("Rows with injections:", n_matched_inj, "\n\n")

# Check for duplicates
dup_vl <- dat_splash_combined %>%
  filter(!is.na(viral_load_date)) %>%
  count(mrn, viral_load_date) %>%
  filter(n > 1)

dup_inj <- dat_splash_combined %>%
  filter(!is.na(cabrpv_injection_date)) %>%
  count(mrn, cabrpv_injection_date) %>%
  filter(n > 1)

cat("=== DUPLICATES ===\n")
cat("Duplicate VLs:", nrow(dup_vl), "\n")
cat("Duplicate injections:", nrow(dup_inj), "\n\n")

# Check for missing data
cat("=== VERIFICATION ===\n")
cat("Viral loads missing?", n_viral_splash - n_matched_vl, "\n")
cat("Injections missing?", n_inj_splash - n_matched_inj, "\n\n")

# Check if it's duplicates in original data
dup_vl_original <- dat_v_filtered %>%
  count(mrn, viral_load_date) %>%
  filter(n > 1)

dup_inj_original <- dat_i %>%
  count(mrn, cabrpv_injection_date) %>%
  filter(n > 1)

cat("Duplicate VLs in original dat_v:", nrow(dup_vl_original), "\n")
cat("Total duplicate VL rows:", sum(dup_vl_original$n), "\n")
cat("Duplicate injections in original dat_i:", nrow(dup_inj_original), "\n")
cat("Total duplicate injection rows:", sum(dup_inj_original$n), "\n\n")

# Summary
cat("=== SUMMARY ===\n")
if (n_viral_splash - n_matched_vl == sum(dup_vl_original$n) - nrow(dup_vl_original) &&
    n_inj_splash - n_matched_inj == sum(dup_inj_original$n) - nrow(dup_inj_original) &&
    nrow(dup_vl) == 0 && nrow(dup_inj) == 0) {
  cat("✓ SUCCESS! All unique viral loads and injections are preserved!\n")
  cat("  (Duplicates in original data were properly deduplicated)\n")
} else {
  cat("Issues to investigate:\n")
  if (n_viral_splash != n_matched_vl) cat("  - VL count difference:", n_viral_splash - n_matched_vl, "\n")
  if (n_inj_splash != n_matched_inj) cat("  - Injection count difference:", n_inj_splash - n_matched_inj, "\n")
  if (nrow(dup_vl) > 0) cat("  - Has", nrow(dup_vl), "duplicate VLs\n")
  if (nrow(dup_inj) > 0) cat("  - Has", nrow(dup_inj), "duplicate injections\n")
}

# Remove all dfs except dat_splash
rm(list = setdiff(ls(), "dat_splash"))


#### 2. PONCE DATA ORGANIZATION ####
# Set working directory

# Read data
dat_v <- read_excel('Ponce_LAART_long_HIVlog_080825_forUCSF_091525.xlsx', sheet = 2)
dat_d <- read_excel('Ponce_LAART_long_HIVlog_080825_forUCSF_091525.xlsx', sheet = 1)
dat_vf <- read_excel('Ponce_LAART_long_HIVlog_080825_forUCSF_091525.xlsx', sheet = 3)
dat_bmi <- read.csv('cohort_bmi_cd4_pre_la_art_UCSF.csv')
dat_i <- read.csv('la_art_admins_thru8.8.25_ucsf_deid.csv')

# Janitor names
dat_d <- dat_d %>%
  clean_names()

dat_vf <- dat_vf %>%
  clean_names()

dat_v <- dat_v %>%
  clean_names()

dat_bmi <- dat_bmi %>%
  clean_names()

dat_i <- dat_i %>%
  clean_names()


# Clean CD4 count and BMI
dat_bmi <- dat_bmi %>%
  rename(mrn = deid_id,
         bmi = bmi_closest,
         cd4_at_initiation = cd4_abs_closest) %>%
  mutate(mrn = as.character(mrn)) %>%
  select(mrn, bmi, cd4_at_initiation)

# Clean viral loads
dat_v <- dat_v %>%
  mutate(mrn = as.character(deidentified_patient_id),
         viral_load_date = as.Date(collection_date_best_available),
         viral_load_character = case_when(value == '<1.30.' ~ '1.30',
                                          grepl('not detected', value, ignore.case = T) ~ '1.30', # log-10 transformed '20'
                                          TRUE ~ (gsub("detected|copies/ml|,|<|>", "", value, ignore.case = TRUE))),
         viral_load_log10 = as.numeric(viral_load_character),
         viral_load = round(10^viral_load_log10)) %>%
  select(mrn, viral_load, viral_load_date)


# Clean injection data
dat_i <- dat_i %>%
  filter(str_detect(med_name, "CABENUVA")) %>%
  rename(order_name = med_name,
         mrn = deid_id) %>%
  mutate(
    cabrpv_injection_date = mdy(admin_date),
    mrn = as.character(mrn),
    dose = case_when(
      str_detect(order_name, "400") ~ 400,
      str_detect(order_name, "600") ~ 600,
      TRUE ~ NA_real_
    )
  ) %>%
  group_by(mrn) %>%
  arrange(cabrpv_injection_date) %>%
  mutate(
    injection_number = row_number(),
    prior_injection_date = lag(cabrpv_injection_date),
    expected_days = case_when(
      dose == 400 ~ 5 * 7,  # 35 days after prior injection
      dose == 600 ~ 9 * 7,  # 63 days after prior injection
      TRUE ~ NA_real_
    ),
    expected_date = prior_injection_date + days(expected_days),
    days_difference = as.numeric(difftime(cabrpv_injection_date, expected_date, units = "days")),
    cabrpv_ontime = case_when(
      injection_number == 1 ~ "On Time",
      days_difference <= 0 ~ "On Time",
      TRUE ~ "Late"
    )
  ) %>%
  ungroup() %>%
  select(mrn, order_name, cabrpv_injection_date, cabrpv_ontime)

# Clean demographics
dat_d <- dat_d %>%
  mutate(mrn = as.character(deidentified_patient_id),
         age_yrs = as.numeric(gsub(".*?(\\d+).*", "\\1", age)),
         gender_identity = case_when(!is.na(gender_identity) ~ gender_identity,
                                     TRUE ~ sex),
         ethnicity = case_when(ethnicity == 'Not Hispanic or Latino' ~ 'Not Hispanic, Latino/a, or Spanish origin',
                               ethnicity == 'Hispanic or Latino' ~ 'Hispanic, Latino/a, or Spanish origin'),
         race_multi = race,
         race = case_when(grepl('\r', race) ~ 'Other/multiracial',
                          grepl('Multi Racial', race, ignore.case = T) ~ 'Other/multiracial',
                          grepl('Black', race, ignore.case = T) ~ 'Black',
                          grepl('American Indian and Alaskan Native', race, ignore.case = T) ~ 'Other/multiracial',
                          grepl('Asian', race, ignore.case = T) ~ 'Asian',
                          grepl('Native Hawaiian', race, ignore.case = T) ~ 'Other/multiracial',
                          grepl('Other Race', race, ignore.case = T) ~ 'Other/multiracial',
                          grepl('White', race, ignore.case = T) ~ 'White',
                          TRUE ~ race),
         substance_use = NA_character_,
         viral_load_character = case_when(grepl('Not detected', hiv_rna_prior_to_la_art, ignore.case = T) ~ '.02',
                                          TRUE ~ (gsub("detected|copies/ml|,|<", "", hiv_rna_prior_to_la_art, ignore.case = TRUE))),
         viral_load_numeric = as.numeric(viral_load_character),
         vl_at_referral = 1000*viral_load_numeric,
         vl_at_referral_date = NA,
         regimen = la_art_agents,
         dosing = cab_rpv_dosing_interval,
         discontinued = treatment_status,
         housing = housing_stability) %>%
  select(mrn, age_yrs, gender_identity, ethnicity,
         race_multi, race, substance_use, vl_at_referral, vl_at_referral_date, regimen, dosing, discontinued, housing, first_cab_rpv_admin_date)

# Filter viral loads for after CAB/RPV initiation
dat_v <- dat_v %>%
  left_join(dat_d, by = 'mrn') %>%
  mutate(first_cab_rpv_admin_date = as.Date(first_cab_rpv_admin_date)) %>%
  filter(viral_load_date > first_cab_rpv_admin_date) %>%
  select(-first_cab_rpv_admin_date)

# Clean viral failures
dat_vf_long <- dat_vf %>%
  # 1. Rename visit-1 and visit-2–7 columns into a clean consistent pattern
  rename(
    date_1   = date_of_first_vl_after_initiation,
    vl_log_1 = value_of_first_vl_after_initiation_log,
    date_2   = date_of_vl2_follow_up,
    date_3   = date_of_vl3_follow_up,
    date_4   = date_of_vl4_follow_up,
    date_5   = date_of_vl5_follow_up,
    date_6   = date_of_vl6_follow_up,
    date_7   = date_of_vl7_follow_up,
    vl_log_2 = vl2_result_log,
    vl_log_3 = vl3_result_log,
    vl_log_4 = vl4_result_log,
    vl_log_5 = vl5_result_log,
    vl_log_6 = vl6_result_log,
    vl_log_7 = vl7_result_log
  ) %>%
  # 2. Keep everything as character for pivot compatibility
  mutate(across(matches("^date_[1-7]$|^vl_log_[1-7]$"), as.character)) %>%
  # 3. Pivot to long format
  pivot_longer(
    cols = matches("^date_[1-7]$|^vl_log_[1-7]$"),
    names_to = c(".value", "visit_number"),
    names_pattern = "(.*)_([1-7])$"
  )

dat_vf_long <- dat_vf_long %>%
  mutate(mrn = deidentified,
         viral_load_log = (gsub("detected|copies/ml|,|<|>", "", vl_log, ignore.case = TRUE)),
         viral_load = round(10^as.numeric(viral_load_log)),
         viral_load_date = as.Date(date),
         cabrpv_ontime = NA,
         age_yrs = as.numeric(gsub(".*?(\\d+).*", "\\1", age)),
         gender_identity = case_when(!is.na(gender_identity) ~ gender_identity,
                                     TRUE ~ sex),
         ethnicity = case_when(ethnicity == 'Not Hispanic or Latino' ~ 'Not Hispanic, Latino/a, or Spanish origin',
                               ethnicity == 'Hispanic or Latino' ~ 'Hispanic, Latino/a, or Spanish origin'),
         race_multi = race,
         race = case_when(grepl('\r', race) ~ 'Other/multiracial',
                          grepl('Multi Racial', race, ignore.case = T) ~ 'Other/multiracial',
                          grepl('Black', race, ignore.case = T) ~ 'Black',
                          grepl('American Indian and Alaskan Native', race, ignore.case = T) ~ 'Other/multiracial',
                          grepl('Asian', race, ignore.case = T) ~ 'Asian',
                          grepl('Native Hawaiian', race, ignore.case = T) ~ 'Other/multiracial',
                          grepl('Other Race', race, ignore.case = T) ~ 'Other/multiracial',
                          grepl('White', race, ignore.case = T) ~ 'White',
                          TRUE ~ race),
         substance_use = NA_character_,
         viral_load_character = case_when(grepl('Not detected', last_hiv_rna_prior_to_la_art, ignore.case = T) ~ '.02',
                                          TRUE ~ (gsub("detected|copies/ml|,|<", "", last_hiv_rna_prior_to_la_art, ignore.case = TRUE))),
         viral_load_numeric = as.numeric(viral_load_character),
         vl_at_referral = 1000*viral_load_numeric,
         vl_at_referral_date = NA,
         regimen = la_art_agents,
         dosing = NA,
         discontinued = NA,
         housing = housing_stability) %>%
  select(mrn, viral_load, viral_load_date, 
         age_yrs, gender_identity, ethnicity, race_multi, race, substance_use, vl_at_referral, 
         vl_at_referral_date, regimen, dosing, discontinued, housing) %>%
  filter(!is.na(viral_load))

# Make sure mrn and viral load fields match types
dat_joined <- dat_v %>%
  mutate(
    mrn = as.character(mrn),
    viral_load = as.character(viral_load),
    viral_load_date = as.character(viral_load_date)
  )

dat_vf_long <- dat_vf_long %>%
  mutate(
    mrn = as.character(mrn),
    viral_load = as.character(viral_load),
    viral_load_date = as.character(viral_load_date)
  )

# Now bind them
dat_viral <- bind_rows(dat_joined, dat_vf_long)

# Coerce viral loads to dates
dat_viral <- dat_viral %>%
  mutate(viral_load_date = as.Date(viral_load_date),
         viral_load = as.numeric(viral_load))

# Merge injection date and viral load (fuzzy join to combine injection date and viral load)
joined <- fuzzy_left_join(
  dat_viral,
  dat_i,
  by = c(
    "mrn" = "mrn",
    "viral_load_date" = "cabrpv_injection_date"
  ),
  match_fun = list(
    `==`,
    function(x, y) abs(x - y) <= 14
  )
) %>%
  mutate(mrn = case_when(!is.na(mrn.x) ~ mrn.x,
                         !is.na(mrn.y) ~ mrn.y)) %>%
  select(-mrn.x, -mrn.y)

# Keep closest injection per viral load
closest_vl <- joined %>%
  group_by(mrn, viral_load_date) %>%
  slice_min(abs(viral_load_date - cabrpv_injection_date), with_ties = FALSE) %>%
  ungroup()

# Keep closest viral load per injection (to prevent duplicate injections)
closest_both <- closest_vl %>%
  group_by(mrn, cabrpv_injection_date) %>%
  slice_min(abs(viral_load_date - cabrpv_injection_date), with_ties = FALSE, na_rm = FALSE) %>%
  ungroup()

# Identify unmatched viral loads
unmatched_vl <- anti_join(dat_viral, closest_both, by = c("mrn", "viral_load_date"))

# Identify unmatched injections
unmatched_inj <- anti_join(dat_i, closest_both, by = c("mrn", "cabrpv_injection_date"))

# Prepare unmatched data
unmatched_vl_to_append <- unmatched_vl %>%
  mutate(
    cabrpv_injection_date = as.Date(NA),
    cabrpv_ontime = as.character(NA),
    order_name = as.character(NA)
  )

unmatched_inj_to_append <- unmatched_inj %>%
  mutate(
    viral_load_date = as.Date(NA),
    viral_load = as.numeric(NA)
  )

# Combine everything
dat_ponce <- bind_rows(
  closest_both,
  unmatched_vl_to_append,
  unmatched_inj_to_append
) %>%
  select(mrn, everything()) %>%
  arrange(mrn, viral_load_date, cabrpv_injection_date)

# Combine with bmi & cd4 count
dat_ponce <- dat_ponce %>%
  left_join(dat_bmi, by = 'mrn')


#### DATA CHECKS
# Original counts
n_viral_ponce <- nrow(dat_viral)  # Total viral loads
n_inj_ponce <- nrow(dat_i)        # Total injections

cat("=== ORIGINAL DATA ===\n")
cat("Viral loads in dat_viral:", n_viral_ponce, "\n")
cat("Injections in dat_i:", n_inj_ponce, "\n\n")

# Final counts
n_final <- nrow(dat_ponce)
n_matched_vl <- dat_ponce %>% filter(!is.na(viral_load_date)) %>% nrow()
n_matched_inj <- dat_ponce %>% filter(!is.na(cabrpv_injection_date)) %>% nrow()

cat("=== FINAL DATA (dat_ponce) ===\n")
cat("Total rows:", n_final, "\n")
cat("Rows with viral loads:", n_matched_vl, "\n")
cat("Rows with injections:", n_matched_inj, "\n\n")

# Check for duplicates
dup_vl <- dat_ponce %>%
  filter(!is.na(viral_load_date)) %>%
  count(mrn, viral_load_date) %>%
  filter(n > 1)

dup_inj <- dat_ponce %>%
  filter(!is.na(cabrpv_injection_date)) %>%
  count(mrn, cabrpv_injection_date) %>%
  filter(n > 1)

cat("=== DUPLICATES ===\n")
cat("Duplicate VLs:", nrow(dup_vl), "\n")
cat("Duplicate injections:", nrow(dup_inj), "\n\n")

# Check for missing data
cat("=== VERIFICATION ===\n")
cat("Viral loads missing?", n_viral_ponce - n_matched_vl, "\n")
cat("Injections missing?", n_inj_ponce - n_matched_inj, "\n\n")

# Summary
cat("=== SUMMARY ===\n")
if (n_viral_ponce == n_matched_vl && n_inj_ponce == n_matched_inj && 
    nrow(dup_vl) == 0 && nrow(dup_inj) == 0) {
  cat("✓ SUCCESS! All data preserved with no duplicates.\n")
} else {
  cat("✗ Issues found:\n")
  if (n_viral_ponce != n_matched_vl) cat("  - Missing", n_viral_ponce - n_matched_vl, "viral loads\n")
  if (n_inj_ponce != n_matched_inj) cat("  - Missing", n_inj_ponce - n_matched_inj, "injections\n")
  if (nrow(dup_vl) > 0) cat("  - Has", nrow(dup_vl), "duplicate VLs\n")
  if (nrow(dup_inj) > 0) cat("  - Has", nrow(dup_inj), "duplicate injections\n")
}

# See which VLs are missing
missing_vl <- anti_join(dat_viral, dat_ponce, by = c("mrn", "viral_load_date"))
cat("Missing VLs:\n")
print(missing_vl %>% select(mrn, viral_load_date, viral_load))

# See which injection is missing
missing_inj <- anti_join(dat_i, dat_ponce, by = c("mrn", "cabrpv_injection_date"))
cat("\nMissing injection:\n")
print(missing_inj %>% select(mrn, cabrpv_injection_date, order_name))

# Check for duplicate VLs in original data
dup_vl_original <- dat_viral %>%
  count(mrn, viral_load_date) %>%
  filter(n > 1)

cat("Duplicate VLs in dat_viral:", nrow(dup_vl_original), "\n")
cat("Total duplicate VL rows:", sum(dup_vl_original$n), "\n\n")

# Check for duplicate injections in original data
dup_inj_original <- dat_i %>%
  count(mrn, cabrpv_injection_date) %>%
  filter(n > 1)

cat("Duplicate injections in dat_i:", nrow(dup_inj_original), "\n")
cat("Total duplicate injection rows:", sum(dup_inj_original$n), "\n")


#### 3. MERGE SPLASH AND PONCE DATA ####
# Coerce viral load to numeric
dat_splash <- dat_splash %>%
  mutate(age_yrs = as.numeric(age_yrs),
         vl_at_referral = as.numeric(vl_at_referral))

dat_ponce <- dat_ponce %>%
  mutate(viral_load = as.numeric(viral_load),
         viral_load_date = as.Date(viral_load_date))

# Add site column to each dataset
dat_splash <- dat_splash %>%
  mutate(site = "UCSF - Ward 86")

dat_ponce <- dat_ponce %>%
  mutate(site = "Emory - Ponce")

# Combine SPLASH (Ward) and Ponce data
dat <- bind_rows(dat_splash, dat_ponce)

# Add in missing demographics/non-time-varying data for rows where it's missing
dat <- dat %>%
  group_by(mrn, site) %>%
  fill(age_yrs, gender_identity, ethnicity, race_multi, race, 
       vl_at_referral, vl_at_referral_date, discontinued, housing, 
       bmi, cd4_at_initiation, 
       .direction = "downup") %>%
  ungroup()

# If vl_at_referral is missing then fill with the first viral load (if +/- 7 days of initiation injection)
dat <- dat %>%
  group_by(mrn, site) %>%
  mutate(
    # Find first injection date (handle all NA case)
    first_injection_date = ifelse(
      all(is.na(cabrpv_injection_date)),
      NA_real_,
      min(cabrpv_injection_date, na.rm = TRUE)
    ),
    first_injection_date = as.Date(first_injection_date, origin = "1970-01-01"),
    
    # Find first VL within 1 week of first injection
    first_vl_near_injection = ifelse(
      !is.na(first_injection_date) & !is.na(viral_load_date) &
        abs(as.numeric(difftime(viral_load_date, first_injection_date, units = "days"))) <= 30,
      viral_load,
      NA_real_
    ),
    
    # Use first available VL near injection for missing vl_at_referral
    vl_at_referral = ifelse(
      is.na(vl_at_referral),
      first(first_vl_near_injection[!is.na(first_vl_near_injection)]),
      vl_at_referral
    )
  ) %>%
  # Clean up temporary columns
  select(-first_injection_date, -first_vl_near_injection) %>%
  ungroup()

# rm(list = setdiff(ls(), c("dat", "dat_splash", "dat_ponce")))


#### CATEGORIZE BLIPS, VIREMIA AT INITIATION ####
# Create variable for whether patient was viremic/suppressed at CAB/RPV initiation
dat <- dat %>%
  mutate(viremic_at_initiation = case_when(vl_at_referral < 50 ~ 'Suppressed at initiation',
                                           vl_at_referral >=50 ~ 'Viremic at initiation',
                                           TRUE ~ NA_character_))

# Blip categorization
# Step 1: Find the first suppressed VL per participant
first_suppressed <- dat %>%
  filter(!is.na(viral_load) & viral_load < 40) %>%  # Added !is.na check
  group_by(mrn) %>%
  slice_min(order_by = viral_load_date, n = 1, with_ties = FALSE) %>%
  rename(first_supp_date = viral_load_date) %>%
  select(mrn, first_supp_date)

# Step 2: Keep all VLs from first suppression onward
post_supp_data <- dat %>%
  inner_join(first_suppressed, by = "mrn") %>%
  filter(!is.na(viral_load) & viral_load_date >= first_supp_date) %>%  # Added !is.na check
  arrange(mrn, viral_load_date)

# Step 3: VF is 2+ VLs > 200, blip is single VL >50, suppressed is all VLs <50
classify_viremia <- function(vl_vector) {
  # Convert values to character
  vl_chr <- as.character(vl_vector)
  vl_chr[is.na(vl_chr)] <- NA_character_
  
  # Detect censored "<N" values
  lt_mask <- grepl("^\\s*<\\s*\\d+\\.?\\d*", vl_chr)
  lt_num <- rep(NA_real_, length(vl_chr))
  
  if (any(lt_mask, na.rm = TRUE)) {
    lt_num[lt_mask] <- as.numeric(gsub("[^0-9.]", "", vl_chr[lt_mask]))
  }
  
  # Convert non-censored values
  num_raw <- suppressWarnings(as.numeric(gsub("[^0-9.]", "", vl_chr)))
  
  # Final numeric values
  vl <- ifelse(lt_mask, lt_num - 1e-6, num_raw)
  vl <- vl[!is.na(vl)]
  
  # Total number of observations
  vl_obs_total <- length(vl)
  
  # If no values exist → unclassified
  if (vl_obs_total == 0) {
    return(list(
      viremia_class  = "Unclassified",
      vl_suppressed   = 0L,
      vl_llv          = 0L,
      vl_unsuppressed = 0L,
      vl_obs_total    = 0L
    ))
  }
  
  # Counts
  vl_suppressed   <- sum(vl < 50)
  vl_llv          <- sum(vl >= 50 & vl <= 200)
  vl_unsuppressed <- sum(vl > 200)
  
  # Helper: any run of >=2 consecutive values in a range
  has_consec <- function(x, low, high) {
    r <- rle(x >= low & x <= high)
    any(r$values & r$lengths >= 2)
  }
  
  # Criteria
  has_pllv     <- has_consec(vl, 50, 200)
  has_failure  <- vl_unsuppressed >= 2
  one_blip     <- (vl_llv + vl_unsuppressed == 1)  # a single VL >50 of any magnitude
  all_supp     <- (vl_suppressed == vl_obs_total)
  
  # Classification
  v_class <- dplyr::case_when(
    has_failure ~ "Confirmed Virologic Failure",
    has_pllv    ~ "Persistent Low-level Viremia",
    one_blip    ~ "Blips",
    all_supp    ~ "Suppressed",
    TRUE        ~ "Unclassified"
  )
  
  list(
    viremia_class  = v_class,
    vl_suppressed   = as.integer(vl_suppressed),
    vl_llv          = as.integer(vl_llv),
    vl_unsuppressed = as.integer(vl_unsuppressed),
    vl_obs_total    = as.integer(vl_obs_total)
  )
}

# Count total viral loads per patient (regardless of suppression status)
vl_counts <- dat %>%
  filter(!is.na(viral_load)) %>%
  group_by(mrn) %>%
  summarize(vl_obs_total = n(), .groups = "drop")

# Count ALL viral loads for ALL patients (not just post-suppression)
vl_counts_all <- dat %>%
  filter(!is.na(viral_load)) %>%
  group_by(mrn) %>%
  summarize(vl_obs_total = n(), .groups = "drop")

# Apply classification function (this only covers patients who achieved suppression)
viremia_status <- post_supp_data %>%
  group_by(mrn) %>%
  summarize(
    result = list(classify_viremia(viral_load)),
    .groups = "drop"
  ) %>%
  tidyr::unnest_wider(result) %>%
  select(-vl_obs_total)  # Remove the post-suppression count

# Merge back to dat with FULL vl_obs_total for everyone
dat <- dat %>%
  left_join(viremia_status, by = "mrn") %>%
  left_join(vl_counts_all, by = "mrn")  # This gives ALL patients their VL count


# In addition to algorithm VF, Ponce had clinical judgement VF:
dat <- dat %>%
  mutate(viremia_class = case_when(grepl("Failure", mrn, ignore.case = TRUE) ~ "Confirmed Virologic Failure",
                                   TRUE ~ viremia_class))

# Clean demographics variables
dat <- dat %>%
  mutate(gender_identity = case_when(gender_identity == 'Choose not to disclose' ~ NA_character_,
                                     gender_identity == 'Female' ~ 'Cisgender woman',
                                     gender_identity == 'Male' ~ 'Cisgender man',
                                     gender_identity == 'Other' ~ 'Nonbinary/Genderqueer/Other',
                                     gender_identity == 'Transgender Female' ~ 'Transgender woman',
                                     gender_identity == 'Transgender Male' ~ 'Transgender man',
                                     TRUE ~ gender_identity),
         race = case_when(race == 'Unknown' ~ NA_character_,
                          TRUE ~ race))

# Create variables for each viremia status
dat <- dat %>%
  mutate(blips = case_when(viremia_class == "Blips" ~ 1,
                           viremia_class %in% c("Suppressed", "Confirmed Virologic Failure", 'Persistent Low-level Viremia') ~ 0,
                           TRUE ~ NA_real_),
         virologic_failure = case_when(viremia_class == "Confirmed Virologic Failure" ~ 1,
                                       viremia_class %in% c("Suppressed", "Blips", 'Persistent Low-level Viremia') ~ 0,
                                       TRUE ~ NA_real_),
         pllv = case_when(viremia_class == 'Persistent Low-level Viremia' ~ 1,
                          viremia_class %in% c("Suppressed", "Blips", "Confirmed Virologic Failure") ~ 0,
                          TRUE ~ NA_real_),
         viremia_class = case_when(is.na(viremia_class) ~ "Unclassified",
                                   TRUE ~ as.character(viremia_class)))

# Create df of one row per participant
dat_unique <- dat %>%
  group_by(mrn) %>%
  arrange(desc(viral_load_date)) %>%
  slice(1) %>%  # most recent row per MRN
  ungroup() %>%
  left_join(
    dat %>%
      group_by(mrn) %>%
      summarize(
        most_common_dosing = {
          dosing_non_na <- dosing[!is.na(dosing) & dosing != ""]
          if (length(dosing_non_na) == 0) NA else {
            names(sort(table(dosing_non_na), decreasing = TRUE))[1]
          }
        },
        most_common_housing = {
          housing_non_na <- housing[!is.na(housing) & housing != ""]
          if (length(housing_non_na) == 0) NA else {
            names(sort(table(housing_non_na), decreasing = TRUE))[1]
          }
        },
        # Infer dosing from order_name across ALL rows
        inferred_dosing = {
          order_names <- order_name[!is.na(order_name) & order_name != ""]
          if (length(order_names) == 0) {
            NA_character_
          } else {
            has_400 <- any(grepl("400", order_names, ignore.case = TRUE))
            has_600 <- any(grepl("600", order_names, ignore.case = TRUE))
            if (has_400 & has_600) "Q4wk to Q8wk switch"
            else if (has_600) "Q8wk"
            else if (has_400) "Q4wk"
            else NA_character_
          }
        },
        # Keep first non-NA BMI
        first_bmi = first(bmi[!is.na(bmi)]),
        # Calculate percent on-time injections
        total_injections = sum(cabrpv_ontime %in% c("On Time", "Late")),
        on_time_injections = sum(cabrpv_ontime == "On Time", na.rm = TRUE),
        percent_ontime = if_else(total_injections > 0, 
                                 100 * on_time_injections / total_injections, 
                                 NA_real_),
        .groups = "drop"
      ),
    by = "mrn"
  ) %>%
  mutate(
    dosing = most_common_dosing,
    housing = most_common_housing,
    bmi = coalesce(bmi, first_bmi)  # Use existing bmi or fill from first_bmi
  ) %>%
  select(-most_common_dosing, -most_common_housing, -first_bmi) %>%
  mutate(
    dosing = case_when(
      dosing == 'Q4wk-to-Q8wk switch' ~ 'Q8wk',
      dosing == 'Q4wk maintenance' ~ 'Q4wk',
      dosing == 'Q8wk maintenance' ~ 'Q8wk',
      dosing == 'Q4WK' ~ 'Q4wk',
      dosing == 'Q8WK' ~ 'Q8wk',
      is.na(dosing) ~ inferred_dosing,
      TRUE ~ dosing
    ),
    housing = case_when(
      housing == 'High Risk' ~ 'Unstable',
      housing == 'Low Risk' ~ 'Stable',
      housing == 'Stable (rent/own)' ~ 'Stable',
      housing == 'Unstable (SRO, homeless)' ~ 'Unstable',
      TRUE ~ NA_character_
    )
  ) %>%
  select(-inferred_dosing)

# There are some patients with injection data, but no viral load data
# Remove patients with no viral loads
dat <- dat %>%
  group_by(mrn) %>%
  filter(any(!is.na(viral_load))) %>%
  ungroup()

# Recreate dat_unique after filtering
dat_unique <- dat %>%
  group_by(mrn) %>%
  arrange(desc(viral_load_date)) %>%
  slice(1) %>%
  ungroup() %>%
  left_join(
    dat %>%
      group_by(mrn) %>%
      summarize(
        most_common_dosing = {
          dosing_non_na <- dosing[!is.na(dosing)]
          if (length(dosing_non_na) == 0) NA else {
            names(sort(table(dosing_non_na), decreasing = TRUE))[1]
          }
        },
        most_common_housing = {
          housing_non_na <- housing[!is.na(housing)]
          if (length(housing_non_na) == 0) NA else {
            names(sort(table(housing_non_na), decreasing = TRUE))[1]
          }
        },
        .groups = "drop"
      ),
    by = "mrn"
  ) %>%
  mutate(
    dosing = most_common_dosing,
    housing = most_common_housing
  ) %>%
  select(-most_common_dosing, -most_common_housing) %>%
  mutate(dosing = case_when(dosing == 'Q4wk-to-Q8wk switch' ~ 'Q8wk',
                            dosing == 'Q4wk maintenance' ~ 'Q4wk',
                            dosing == 'Q8wk maintenance' ~ 'Q8wk',
                            dosing == 'Q4WK' ~ 'Q4wk',
                            dosing == 'Q8WK' ~ 'Q8wk',
                            TRUE ~ NA_character_),
         housing = case_when(housing == 'High Risk' ~ 'Unstable',
                             housing == 'Low Risk' ~ 'Stable',
                             housing == 'Stable (rent/own)' ~ 'Stable',
                             housing == 'Unstable (SRO, homeless)' ~ 'Unstable',
                             TRUE ~ NA_character_))

cat("Patients remaining:", n_distinct(dat$mrn), "\n")
cat("Rows in dat:", nrow(dat), "\n")
cat("Rows in dat_unique:", nrow(dat_unique), "\n")


#### 4. ANALYSES: TABLE 1 ####
#### Edit repeated measures data
dat <- dat %>%
  mutate(# Clean up trailing whitespace/newlines first
    race_clean = str_trim(str_replace_all(race_multi, "\n", ", ")),
    
    race_eth = case_when(
      # Hispanic takes priority regardless of race
      ethnicity == "Hispanic, Latino/a, or Spanish origin" ~ "Hispanic",
      
      # Non-Hispanic from here down
      str_detect(race_clean, regex("^Black or African American$", ignore_case = TRUE)) |
        str_detect(race_clean, regex("^Black or African American,|, Black or African American", ignore_case = TRUE)) |
        str_detect(race_clean, regex("Black or African American\\\\n", ignore_case = TRUE)) ~ "Black",
      
      str_detect(race_clean, regex("^Asian$", ignore_case = TRUE)) |
        str_detect(race_clean, regex("^Asian,|, Asian", ignore_case = TRUE)) ~ "Asian",
      
      str_detect(race_clean, regex("^White$|^White or Caucasian$|^White $|^White or Caucasian$", ignore_case = TRUE)) ~ "Non-Hispanic White",
      
      TRUE ~ "Other"
    ),
    race_eth = factor(race_eth, levels = c("Black", "Hispanic", "Non-Hispanic White", "Asian", "Other")),
    # Add sex
    sex = case_when(gender_identity == 'Cisgender man' ~ 'Male',
                    gender_identity == 'Cisgender woman' ~ 'Female',
                    gender_identity == 'Nonbinary/Genderqueer/Other' ~ NA,
                    gender_identity == 'Transgender man' ~ 'Female',
                    gender_identity == 'Transgender woman' ~ 'Male',
                    TRUE ~ NA),
    # Create a viremia classification variable for only people with 2+ observations
    viremia_class_2obs = case_when(viremia_class == 'Suppressed' & vl_obs_total == 1 ~ 'Unclassified',
                                   TRUE ~ viremia_class),
    # Create numeric 0/1 variable for whether CAB/RPV was administered on-time
    cabrpv_ontime_num = as.numeric(cabrpv_ontime == 'On Time'),
    # Edit dosing patterns to be 8 weeks because so few participants switched
    dosing = case_when(dosing == 'Q4wk-to-Q8wk switch' ~ 'Q8wk',
                       dosing == 'Q4wk maintenance' ~ 'Q4wk',
                       dosing == 'Q8wk maintenance' ~ 'Q8wk',
                       dosing == 'Q4WK' ~ 'Q4wk',
                       dosing == 'Q8WK' ~ 'Q8wk',
                       TRUE ~ NA_character_),
    # Harmonize housing status variable across sites
    housing = case_when(housing == 'High Risk' ~ 'Unstable',
                        housing == 'Low Risk' ~ 'Stable',
                        housing == 'Stable (rent/own)' ~ 'Stable',
                        housing == 'Unstable (SRO, homeless)' ~ 'Unstable',
                        TRUE ~ NA_character_),
    # Scale CD4 at initiation for interpretation
    cd4_at_initiation_scaled100 = cd4_at_initiation/100) %>%
  # Create variable for duration of time (days) on LA-ART
  group_by(mrn) %>%
  mutate(
    first_date = pmin(
      min(viral_load_date, na.rm = TRUE),
      min(cabrpv_injection_date, na.rm = TRUE),
      na.rm = TRUE
    ),
    last_date = pmax(
      max(viral_load_date, na.rm = TRUE),
      max(cabrpv_injection_date, na.rm = TRUE),
      na.rm = TRUE
    ),
    duration_days = as.numeric(difftime(last_date, first_date, units = "days"))
  ) %>%
  ungroup()

#### Edit single-participant data
# Coerce ethnicity and race to new category
dat_unique <- dat_unique %>%
  mutate(
    # Clean up trailing whitespace/newlines first
    race_clean = str_trim(str_replace_all(race_multi, "\n", ", ")),
    race_eth = case_when(
      # Hispanic takes priority regardless of race
      ethnicity == "Hispanic, Latino/a, or Spanish origin" ~ "Hispanic",
      # Non-Hispanic from here down
      str_detect(race_clean, regex("^Black or African American$", ignore_case = TRUE)) |
        str_detect(race_clean, regex("^Black or African American,|, Black or African American", ignore_case = TRUE)) |
        str_detect(race_clean, regex("Black or African American\\\\n", ignore_case = TRUE)) ~ "Black",
      str_detect(race_clean, regex("^Asian$", ignore_case = TRUE)) |
        str_detect(race_clean, regex("^Asian,|, Asian", ignore_case = TRUE)) ~ "Asian",
      str_detect(race_clean, regex("^White$|^White or Caucasian$|^White $|^White or Caucasian$", ignore_case = TRUE)) ~ "Non-Hispanic White",
      TRUE ~ "Other"),
    race_eth = factor(race_eth, levels = c("Black", "Hispanic", "Non-Hispanic White", "Asian", "Other")),
    
    # Add sex
    sex = case_when(gender_identity == 'Cisgender man' ~ 'Male',
                    gender_identity == 'Cisgender woman' ~ 'Female',
                    gender_identity == 'Nonbinary/Genderqueer/Other' ~ NA,
                    gender_identity == 'Transgender man' ~ 'Female',
                    gender_identity == 'Transgender woman' ~ 'Male',
                    TRUE ~ NA),
    sex = relevel(factor(sex), ref = 'Male'),
    
    # Create a viremia classification variable for only people with 2+ observations
    viremia_class_2obs = case_when(viremia_class == 'Suppressed' & vl_obs_total == 1 ~ 'Unclassified',
                                   TRUE ~ viremia_class),
    
    # Edit dosing patterns to be 8 weeks because so few participants switched
    dosing = case_when(dosing == 'Q4wk to Q8wk switch' ~ 'Q8wk',
                       dosing == 'Q4wk'                ~ 'Q4wk',
                       dosing == 'Q8wk'                ~ 'Q8wk',
                       TRUE ~ NA_character_),
    
    # Scale CD4 at initiation for interpretation
    cd4_at_initiation_scaled100 = cd4_at_initiation/100,
    
    # Create two factor levels for viremia at initiation
    viremic_at_initiation_refV = relevel(factor(viremic_at_initiation), ref = "Viremic at initiation"),
    viremic_at_initiation_refS = relevel(factor(viremic_at_initiation), ref = "Suppressed at initiation"),
    
    # Scale age by 10-years for interpretability
    age_yrs_scale10 = age_yrs/10)

# Table 1
table1(~age_yrs + gender_identity + ethnicity + race + housing + viremic_at_initiation + viremia_class_2obs + vl_obs_total + percent_ontime|site,
       data = dat_unique)

# IQR for ages by site
dat_unique %>%
  group_by(site) %>%
  summarize(iqr25 = quantile(age_yrs, .25, na.rm = T),
            iqr75 = quantile(age_yrs, .75, na.rm = T))

# IQR for ages overall
dat_unique %>%
  summarize(iqr25 = quantile(age_yrs, .25, na.rm = T),
            iqr75 = quantile(age_yrs, .75, na.rm = T))

# IQR for VLs by site
dat_unique %>%
  group_by(site) %>%
  summarize(iqr25 = quantile(vl_obs_total, .25, na.rm = T),
            iqr75 = quantile(vl_obs_total, .75, na.rm = T))

# IQR for VLs overall
dat_unique %>%
  summarize(iqr25 = quantile(vl_obs_total, .25, na.rm = T),
            iqr75 = quantile(vl_obs_total, .75, na.rm = T))

# Duration in LA-ART program per site
dat %>%
  distinct(mrn, site, first_date, last_date, duration_days) %>%
  group_by(site) %>%
  summarize(
    mean_duration = mean(duration_days, na.rm = TRUE),
    sd_duration = sd(duration_days, na.rm = TRUE),
    median_duration = median(duration_days, na.rm = TRUE),
    q25_duration = quantile(duration_days, 0.25, na.rm = TRUE),
    q75_duration = quantile(duration_days, 0.75, na.rm = TRUE),
    min_duration = min(duration_days, na.rm = TRUE),
    max_duration = max(duration_days, na.rm = TRUE)
  )

# Duration in LA-ART program overall
dat %>%
  distinct(mrn, first_date, last_date, duration_days) %>%
  summarize(
    mean_duration = mean(duration_days, na.rm = TRUE),
    sd_duration = sd(duration_days, na.rm = TRUE),
    median_duration = median(duration_days, na.rm = TRUE),
    q25_duration = quantile(duration_days, 0.25, na.rm = TRUE),
    q75_duration = quantile(duration_days, 0.75, na.rm = TRUE),
    min_duration = min(duration_days, na.rm = TRUE),
    max_duration = max(duration_days, na.rm = TRUE)
  )

# Total number of injections administered
dat_unique %>%
  summarize(all_inj = sum(total_injections))

# On-time injections for people with viremia
dat_unique %>%
  ungroup() %>%
  group_by(viremic_at_initiation) %>%
  summarize(pct_on_time = mean(percent_ontime, na.rm = T))

# Viral failures across both sites
vf_list <- dat_unique %>%
  filter(virologic_failure == 1) %>%
  group_by(site) %>%
  select(site, mrn)

# Patients who never achieved suppression with duration on ART
never_suppressed_detail <- dat %>%
  filter(!is.na(viral_load)) %>%
  group_by(mrn, site) %>%
  summarize(
    ever_suppressed = any(viral_load < 40, na.rm = TRUE),
    first_date = min(viral_load_date, na.rm = TRUE),
    last_date = max(viral_load_date, na.rm = TRUE),
    duration_days = as.numeric(difftime(last_date, first_date, units = "days")),
    duration_months = round(duration_days / 30.44, 1),
    n_vls = n(),
    all_vls = paste(sort(viral_load), collapse = ", "),
    .groups = "drop"
  ) %>%
  filter(!ever_suppressed) %>%
  arrange(site, duration_days)

print(never_suppressed_detail)

# Summary by site
never_suppressed_detail %>%
  group_by(site) %>%
  summarize(
    n = n(),
    median_months = round(median(duration_months), 1),
    iqr25 = round(quantile(duration_months, 0.25), 1),
    iqr75 = round(quantile(duration_months, 0.75), 1),
    min_months = min(duration_months),
    max_months = max(duration_months),
    .groups = "drop"
  )


#### 5. KAPLAN MEIER TIME TO SUPPRESSION FOR THOSE INITIATING WITH VIREMIA ####
# Create df with days to reach suppression and whether patient was censored (censor_status)
dat_km <- dat %>%
  filter(viremic_at_initiation == "Viremic at initiation") %>%
  group_by(mrn) %>%
  filter(sum(!is.na(viral_load)) >= 2) %>%  # At least 2 viral loads
  ungroup() %>%
  mutate(days = round(as.numeric(difftime(viral_load_date, first_date, units = "days")))) %>%
  filter(days > 0) %>%
  group_by(mrn) %>%
  mutate(
    # Get first suppression date (handle case where never suppressed)
    first_suppressed_date = {
      supp_dates <- viral_load_date[!is.na(viral_load) & viral_load < 50]
      if (length(supp_dates) > 0) as.Date(min(supp_dates), origin = "1970-01-01") else as.Date(NA_real_, origin = "1970-01-01")
    },
    # Censor status: 1 = suppressed, 0 = censored
    censor_status = ifelse(!is.na(first_suppressed_date), 1, 0)
  ) %>%
  # Keep first suppression row OR last row if never suppressed
  filter(
    (viral_load_date == first_suppressed_date & !is.na(first_suppressed_date)) |
      (is.na(first_suppressed_date) & viral_load_date == max(viral_load_date, na.rm = TRUE))
  ) %>%
  slice(1) %>%  # One row per patient
  ungroup()


# Time to suppression
dat_km %>%
  summarize(
    total = n(),
    suppressed = sum(censor_status),
    censored = sum(censor_status == 0),
    median_days = median(days, na.rm = TRUE),
    iqr25 = quantile(days, .25, na.rm = T),
    iqr75 = quantile(days, .75, na.rm = T)
  )

# Percent that ever became suppressed
dat_km %>%
  summarize(
    total = n(),
    ever_suppressed = sum(censor_status == 1),
    percent_ever_suppressed = round(100 * sum(censor_status == 1) / n(), 1),
    never_suppressed = sum(censor_status == 0),
    percent_never_suppressed = round(100 * sum(censor_status == 0) / n(), 1)
  )

cat("Patients included:", nrow(dat_km), "\n")
cat("Events (suppressed):", sum(dat_km$censor_status), "\n")
cat("Censored:", sum(dat_km$censor_status == 0), "\n")

# Fit survival object
surv_fit <- survfit2(Surv(days, censor_status) ~ 1, data = dat_km)

# Median time to achieve viral suppression at vl < 200 for initially viremic
dat_km %>%
  summarize(
    median = median(days, na.rm = TRUE),
    mean = mean(days, na.rm = TRUE),
    sd = sd(days, na.rm = TRUE)
  )

# Extract survival data
surv_data <- data.frame(
  time = surv_fit$time, 
  surv = surv_fit$surv, 
  lower = surv_fit$lower, 
  upper = surv_fit$upper
)

# Plot 1: Full time range
plot1 <- ggplot(surv_data, aes(x = time / 7, y = surv)) +
  geom_step() +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = 'blue', alpha = 0.2) +
  labs(
    x = "Weeks",
    y = "Proportion with viral load <50 copies/mL (95% CI)"
  ) +
  scale_x_continuous(breaks = seq(0, max(surv_data$time / 7), by = 12)) +
  scale_y_reverse(limits = c(1, 0)) +
  theme_minimal()

# Plot 2: Trimmed to 48 weeks
plot2 <- ggplot(surv_data, aes(x = time / 7, y = surv)) +
  geom_step(linewidth = 1.2) +  # Thicker line (or use 'size = 1.2' for older ggplot2)
  geom_step() +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = 'blue', alpha = 0.2) +
  labs(
    x = "Weeks",
    y = "Proportion with viral load <50 copies/mL (95% CI)"
  ) +
  scale_y_reverse(limits = c(1, 0)) +
  coord_cartesian(xlim = c(0, 48), ylim = c(1, 0)) +
  theme_minimal() +
  theme(text = element_text(size = 18))

# Get censored observations
obs_status <- data.frame(
  id = 1:nrow(dat_km),
  time = dat_km$days,
  status = dat_km$censor_status
)

# Save censored observations to overlay on plot as crosses +
censored_points <- obs_status %>% 
  filter(status == 0) %>%
  left_join(surv_data %>% select(time, surv), by = "time")

plot3 <- ggplot(surv_data, aes(x = time / 7, y = surv)) +
  geom_step(linewidth = 1.2) +  # Thicker line (or use 'size = 1.2' for older ggplot2)
  geom_point(data = censored_points,
             aes(x = time / 7, y = surv),
             shape = 3, size = 5, stroke = 2, color = "red") +  # Added stroke for thicker +
  geom_ribbon(aes(ymin = lower, ymax = upper), fill = '#2A5587', alpha = 0.2) +
  labs(
    x = "Weeks",
    y = "Proportion with viral load <50 copies/mL (95% CI)"
  ) +
  scale_x_continuous(breaks = seq(0, 48, by = 12)) +
  scale_y_reverse() +
  coord_cartesian(xlim = c(0, 48), ylim = c(1, 0)) +
  theme_minimal() +
  theme(text = element_text(size = 18))

# Save plots
create_pptx(plt = plot3, path = pptx_path) 

# Risk table
time_points_weeks <- c(0, 12, 24, 36, 48)
time_points_days <- time_points_weeks * 7

surv_summary <- summary(surv_fit, times = time_points_days)

risk_df <- data.frame(
  weeks = time_points_weeks,
  n_risk = surv_summary$n.risk,
  n_event = surv_summary$n.event
)

risk_df


#### 6. BLIPS ACROSS PEOPLE WHO INITIATED WITH VIREMIA OR SUPPRESSED ####
# Blips more common in people who started with viremia
table(dat_unique$blips, dat_unique$viremic_at_initiation)
table(dat_unique$viremic_at_initiation)

# Contingency table
tab <- table(dat_unique$blips, dat_unique$viremic_at_initiation)

# Percent with blips within each viremic_at_initiation group
percent_blips <- prop.table(tab, margin = 2)[2, ] * 100

percent_blips

# Blips predicted by viremia at initiation
fit_blip_final_1 <- glm(blips ~ viremic_at_initiation_refS + age_yrs_scale10 + race_eth + sex + bmi + cd4_at_initiation_scaled100 + dosing + percent_ontime, 
                        family = binomial(link = "logit"),
                        data = dat_unique)

tbl_regression(fit_blip_final_1, exp = T)


# Does VL at referral predict the likelihood of blips (where higher VL at referral predicts more blips?)
# View distribution of viral load at initiation
dat_unique %>%
  filter(viremic_at_initiation == 'Viremic at initiation') %>%
  pull(vl_at_referral) %>%
  hist(main = "VL at Referral (Viremic at Initiation)", xlab = "VL at referral")

# Fit logistic regression (VL at referral predicting blips, adjusted for age, BMI, CD4 at initiation, and clinic site)
fit_blip_vl <- glm(blips ~ log10(vl_at_referral) + age_yrs + bmi + cd4_at_initiation + site,
                   family = binomial(link = "logit"),
                   data = dat_unique %>% filter(viremic_at_initiation == 'Viremic at initiation'))

tbl_regression(fit_blip_vl, exp = T)

# View separation for race & blips
dat_unique %>%
  filter(viremic_at_initiation == 'Viremic at initiation') %>%
  count(race, blips)

# Summarize median VL at referral in viremic patients
dat_unique %>%
  filter(viremic_at_initiation == 'Viremic at initiation') %>%
  group_by(site) %>%
  summarize(median_vl = median(vl_at_referral, na.rm = T),
            iqr = IQR(vl_at_referral, na.rm = T),
            n_blips = sum(blips, na.rm = T),
            n = n())

# Re-fit model controlling for site only
fit_blip_vl <- glm(blips ~ log10(vl_at_referral) + site,
                      family = binomial(link = "logit"),
                      data = dat_unique %>% filter(viremic_at_initiation == 'Viremic at initiation'))

tbl_regression(fit_blip_vl, exp = T)


# Did having a late injection predict subsequent blip? (elevated VL)
# Create a variable for viral load greater than 50 (vl_gt50)
dat <- dat %>%
  mutate(vl_gt50 = as.integer(viral_load > 50))

# Filter data for all data after first suppression (for those who initiated as suppressed, all data included)
vl_dt <- dat %>%
  filter(!is.na(viral_load_date), !is.na(viral_load)) %>%
  select(mrn, viral_load_date, vl_gt50, viral_load,
         age_yrs, race, bmi, site, cd4_at_initiation, viremic_at_initiation) %>%
  left_join(dat_km %>% select(mrn, first_suppressed_date), by = "mrn") %>%
  filter(viral_load_date >= first_suppressed_date | viremic_at_initiation == 'Suppressed at initiation') %>%  # at or after first suppression
  as.data.table() %>%
  setkey(mrn, viral_load_date)

# Filter injection dates
inj_dt <- dat %>%
  filter(!is.na(cabrpv_injection_date), !is.na(cabrpv_ontime)) %>%
  select(mrn, cabrpv_injection_date, cabrpv_ontime, dosing) %>%
  as.data.table() %>%
  setkey(mrn, cabrpv_injection_date)

# Combine viral loads and injection dates (excluding missing rows to pair observations)
dat_vlwithinj <- inj_dt[vl_dt, 
                  roll = TRUE, 
                  on = c("mrn", "cabrpv_injection_date == viral_load_date")] %>%
  rename(viral_load_date = cabrpv_injection_date) %>%
  mutate(cabrpv_ontime_num = as.numeric(cabrpv_ontime == 'On Time'),
         age_yrs_scale10 = age_yrs/10,
         bmi_scale10 = bmi/10,
         cd4_at_initiation_scale100 = cd4_at_initiation/100)

# Mixed effects model for VL predicted by on-time or late injections
fit_late_inj <- glmer(vl_gt50 ~ cabrpv_ontime + viremic_at_initiation + 
                        scale(age_yrs) + scale(bmi) + scale(cd4_at_initiation) +
                        (1 | mrn),
                      family = binomial(link = "logit"),
                      control = glmerControl(optimizer = "bobyqa",
                                            optCtrl = list(maxfun = 2e5)),
                      data = dat_vlwithinj)

summary(fit_late_inj)

tbl_regression(fit_late_inj, exp = T)

dat_vlwithinj %>% 
  summarize(across(c(cabrpv_ontime, viremic_at_initiation, race), 
                   ~ n_distinct(., na.rm = TRUE)))


#### 7. PERCENT OF INJECTIONS THAT WERE ON-TIME ####
dat %>%
  filter(!is.na(cabrpv_injection_date)) %>%
  summarize(
    total_injections = n(),
    on_time = sum(cabrpv_ontime == "On Time", na.rm = TRUE),
    late = sum(cabrpv_ontime == "Late", na.rm = TRUE),
    missing_status = sum(is.na(cabrpv_ontime)),
    percent_on_time = round(100 * sum(cabrpv_ontime == "On Time", na.rm = TRUE) / 
                              sum(!is.na(cabrpv_ontime)), 1)
  )


# When injections were late, what was the IQR of how late they were?
# Calculate days since last injection per patient
late_injections <- dat %>%
  filter(!is.na(cabrpv_injection_date)) %>%
  mutate(cabrpv_injection_date = as.Date(cabrpv_injection_date)) %>%
  arrange(mrn, cabrpv_injection_date) %>%
  group_by(mrn) %>%
  mutate(
    days_since_last_inj = as.numeric(cabrpv_injection_date - lag(cabrpv_injection_date)),
    intended_interval = case_when(is.na(days_since_last_inj)  ~ "Loading/First",   # first injection, no prior
                                  days_since_last_inj < 50   ~ "Q4wk",
                                  days_since_last_inj >= 50  ~ "Q8wk"),
    days_late = case_when(intended_interval == 'Q4wk' ~ days_since_last_inj - 28,
                          intended_interval == 'Q8wk' ~ days_since_last_inj - 56,
                          TRUE ~ NA_integer_)) %>%
  ungroup() %>%
  filter(days_late >= 7)

# Median & IQR of late injections (injections within 7 days were considered on-time)
late_injections %>%
  summarize(median = median(days_late),
            iqr25 = quantile(days_late, .25),
            iqr75 = quantile(days_late, .75))


# Mixed effects logistic regression predicting odds of on-time injection based on patient characteristics, site, etc.
fit <- glmer(cabrpv_ontime_num ~ viremic_at_initiation + age_yrs + race + site + (1|mrn),
             family = binomial(link = 'logit'),
             data = dat)
# Maximal model didn't converge, so fit without housing, ethnicity, and dosing schedule because these were non-sig

fit %>%
  tbl_regression(exp = T)


#### 8. PERSISTENT LOW LEVEL VIREMIA ####
# PLLV more common in people who started with viremia
table(dat_unique$pllv, dat_unique$viremic_at_initiation)
table(dat_unique$viremic_at_initiation)

# Contingency table
tab_pllv <- table(dat_unique$pllv, dat_unique$viremic_at_initiation)

# Percent with PLLV within each viremic_at_initiation group
percent_pllv <- prop.table(tab_pllv, margin = 2)[2, ] * 100
percent_pllv

# PLLV predicted by viremia at initiation and demographic/health characteristics
# (Firth regression because there's separation for viremia at initiation)
fit_pllv_final_1 <- logistf(pllv ~ viremic_at_initiation_refS + age_yrs_scale10 + race_eth + sex + bmi + cd4_at_initiation_scaled100 + dosing + percent_ontime, 
                        family = binomial(link = "logit"),
                        data = dat_unique)

tbl_regression(fit_pllv_final_1, exponentiate = TRUE)


# Does VL at referral predict the likelihood of pllv (where higher VL at referral predicts more blips?)
fit_pllv_log <- logistf(pllv ~ log10(vl_at_referral) + age_yrs + bmi + race_eth + cd4_at_initiation + percent_ontime + site,
                   family = binomial(link = "logit"),
                   data = dat_unique %>% filter(viremic_at_initiation == 'Viremic at initiation'))

tbl_regression(fit_pllv_log, exp = T)


#### 9. VIRAL FAILURE ####
# Virologic failure more common in people who started with viremia
table(dat_unique$virologic_failure, dat_unique$viremic_at_initiation)
table(dat_unique$viremic_at_initiation)

# Contingency table
tab_vf <- table(dat_unique$virologic_failure, dat_unique$viremic_at_initiation)

# Percent with virologic failure within each viremic_at_initiation group
percent_vf <- prop.table(tab_vf, margin = 2)[2, ] * 100
percent_vf

# Virologic failure predicted by viremia at initiation + demographic/health characteristics
# (Firth logistic regression because of separation in sex)
fit_vf_final_1 <- logistf(virologic_failure ~ viremic_at_initiation_refS + age_yrs_scale10 + race_eth + sex + bmi + cd4_at_initiation_scaled100 + dosing + percent_ontime,
                          data = dat_unique)

tbl_regression(fit_vf_final_1, exp = T)


#### 10. DO PLLV OR BLIPS PREDICT SUBSEQUENT VF? ####
# Create df of virologic failures
dat_vf <- dat %>%
  filter(viremia_class == 'Confirmed Virologic Failure') %>%
  group_by(mrn) %>%
  arrange(mrn, viral_load_date)

# Create summary of whether people ever attained VL <50
# After attaining VL <50, do people have blips (one viral load >50 then returning to VL <50?)
# After attaining VL <50, do people have PLLV (2+ viral loads between 50-200)

# Create summary of whether patients ever attained VL <50
vf_suppression <- dat_vf %>%
  group_by(mrn) %>%
  summarize(
    n_measurements = n(),
    ever_suppressed = any(viral_load < 50, na.rm = TRUE),
    n_suppressed = sum(viral_load < 50, na.rm = TRUE),
    n_unsuppressed = sum(viral_load >= 50, na.rm = TRUE),
    percent_suppressed = round(100 * n_suppressed / n_measurements, 1),
    min_vl = min(viral_load, na.rm = TRUE),
    max_vl = max(viral_load, na.rm = TRUE),
    first_vl = first(viral_load),
    last_vl = last(viral_load),
    first_date = first(viral_load_date),
    last_date = last(viral_load_date),
    .groups = 'drop'
  )

print("=== SUMMARY: Did VF patients achieve VL < 50? ===")
print(table(vf_suppression$ever_suppressed))
cat("\nPercentage who ever achieved suppression:\n")
print(prop.table(table(vf_suppression$ever_suppressed)) * 100)


# Identify first suppression date for those who achieved it
first_suppression <- dat_vf %>%
  filter(viral_load < 50) %>%
  group_by(mrn) %>%
  arrange(mrn, viral_load_date) %>%
  slice(1) %>%  # Take the first row for each patient
  select(mrn, first_suppression_date = viral_load_date, first_suppression_vl = viral_load) %>%
  ungroup()

# For patients who achieved suppression, identify subsequent events
post_suppression_analysis <- dat_vf %>%
  inner_join(first_suppression, by = "mrn") %>%
  filter(viral_load_date > first_suppression_date) %>%
  arrange(mrn, viral_load_date) %>%
  group_by(mrn) %>%
  mutate(
    post_suppression_order = row_number(),
    is_elevated = viral_load >= 50,
    is_pllv_range = viral_load >= 50 & viral_load <= 200,
    is_high = viral_load > 200
  )

# Identify BLIPS: Single VL >50 that returns to <50
identify_blips <- function(df) {
  df %>%
    arrange(mrn, viral_load_date) %>%
    group_by(mrn) %>%
    mutate(
      prev_vl = lag(viral_load),
      next_vl = lead(viral_load),
      is_blip = viral_load >= 50 & 
        !is.na(prev_vl) & prev_vl < 50 & 
        !is.na(next_vl) & next_vl < 50
    ) %>%
    ungroup()
}

# Apply to all VF patients
dat_vf_blips <- identify_blips(dat_vf)

blip_summary <- dat_vf_blips %>%
  filter(is_blip) %>%
  select(mrn, viral_load_date, viral_load, prev_vl, next_vl) %>%
  arrange(mrn, viral_load_date)

print("\n=== BLIPS IDENTIFIED ===")
print("(Single VL ≥50 with VL <50 before and after)")
print(blip_summary)

# Count patients with blips
patients_with_blips <- dat_vf_blips %>%
  group_by(mrn) %>%
  summarize(
    n_blips = sum(is_blip, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  filter(n_blips > 0)

cat("\nNumber of patients with blips:", nrow(patients_with_blips), "\n")
print(patients_with_blips)

# Identify PLLV: 2+ consecutive viral loads between 50-200 AFTER achieving suppression
identify_pllv <- post_suppression_analysis %>%
  group_by(mrn) %>%
  arrange(mrn, viral_load_date) %>%
  mutate(
    # Create a run-length encoding to find consecutive PLLV
    pllv_indicator = viral_load >= 50 & viral_load <= 200,
    # Create groups of consecutive PLLV values
    pllv_group = cumsum(pllv_indicator != lag(pllv_indicator, default = FALSE))
  ) %>%
  group_by(mrn, pllv_group) %>%
  mutate(
    consecutive_pllv = sum(pllv_indicator),
    is_pllv_episode = pllv_indicator & consecutive_pllv >= 2
  ) %>%
  ungroup()

pllv_episodes <- identify_pllv %>%
  filter(is_pllv_episode) %>%
  select(mrn, viral_load_date, viral_load, consecutive_pllv, first_suppression_date) %>%
  arrange(mrn, viral_load_date)

print("\n=== PERSISTENT LOW-LEVEL VIREMIA (PLLV) ===")
print("(2+ consecutive VL measurements between 50-200 after achieving VL <50)")
print(pllv_episodes)

# Count patients with PLLV episodes
patients_with_pllv <- identify_pllv %>%
  filter(is_pllv_episode) %>%
  group_by(mrn) %>%
  summarize(
    pllv_measurements = n(),
    pllv_range = paste(min(viral_load), "-", max(viral_load)),
    .groups = 'drop'
  )

cat("\nNumber of patients with PLLV:", nrow(patients_with_pllv), "\n")
print(patients_with_pllv)

# Comprehensive patient classification
patient_classification <- vf_suppression %>%
  left_join(
    patients_with_blips %>% select(mrn, n_blips),
    by = "mrn"
  ) %>%
  left_join(
    patients_with_pllv %>% select(mrn, pllv_measurements),
    by = "mrn"
  ) %>%
  mutate(
    n_blips = replace_na(n_blips, 0),
    pllv_measurements = replace_na(pllv_measurements, 0),
    pattern = case_when(
      !ever_suppressed ~ "Never suppressed",
      n_blips > 0 & pllv_measurements == 0 ~ "Blip(s) only",
      pllv_measurements > 0 & n_blips == 0 ~ "PLLV only",
      n_blips > 0 & pllv_measurements > 0 ~ "Both blip and PLLV",
      ever_suppressed & n_blips == 0 & pllv_measurements == 0 ~ "Sustained suppression"
    )
  )

print("\n=== PATIENT CLASSIFICATION SUMMARY ===")
print(table(patient_classification$pattern))
print("\nDetailed classification:")
print(patient_classification %>% select(mrn, ever_suppressed, n_blips, pllv_measurements, pattern, last_vl))

# Timeline visualization for each patient
create_patient_timeline <- function(mrn_id) {
  patient_data <- dat_vf %>% filter(mrn == mrn_id)
  first_supp <- first_suppression %>% filter(mrn == mrn_id)
  
  p <- ggplot(patient_data, aes(x = viral_load_date, y = viral_load)) +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(size = 3, color = "steelblue") +
    geom_hline(yintercept = 50, linetype = "dashed", color = "red", linewidth = 1) +
    geom_hline(yintercept = 200, linetype = "dotted", color = "orange", linewidth = 0.8) +
    scale_y_log10(labels = scales::comma) +
    labs(
      title = paste("MRN:", mrn_id),
      x = "Date",
      y = "Viral Load (log scale)",
      subtitle = paste("Pattern:", 
                       patient_classification$pattern[patient_classification$mrn == mrn_id])
    ) +
    theme_minimal() +
    theme(plot.title = element_text(face = "bold"))
  
  # Add vertical line at first suppression if applicable
  if(nrow(first_supp) > 0) {
    p <- p + geom_vline(xintercept = first_supp$first_suppression_date, 
                        linetype = "dashed", color = "green", alpha = 0.5)
  }
  
  print(p)
}

# Create timelines for all patients
print("\n=== INDIVIDUAL PATIENT TIMELINES ===")
for(mrn_id in unique(dat_vf$mrn)) {
  create_patient_timeline(mrn_id)
}


# Compare these rates with people who maintained suppression
# === IDENTIFY VF PATIENTS USING virologic_failure == 1 ===
vf_mrns <- dat_unique %>%
  filter(virologic_failure == 1) %>%
  pull(mrn)

cat("=== VF PATIENT IDENTIFICATION ===\n")
cat("Total VF patients (virologic_failure == 1):", length(vf_mrns), "\n")

# === ANALYSIS FOR VF GROUP ===
dat_vf <- dat %>%
  filter(mrn %in% vf_mrns) %>%
  group_by(mrn) %>%
  arrange(mrn, viral_load_date)

# 1. Summary for VF patients
vf_summary <- dat_vf %>%
  group_by(mrn) %>%
  summarize(
    n_measurements = n(),
    ever_suppressed = any(viral_load < 50, na.rm = TRUE),
    n_suppressed = sum(viral_load < 50, na.rm = TRUE),
    n_unsuppressed = sum(viral_load >= 50, na.rm = TRUE),
    percent_suppressed = round(100 * n_suppressed / n_measurements, 1),
    min_vl = min(viral_load, na.rm = TRUE),
    max_vl = max(viral_load, na.rm = TRUE),
    first_vl = first(viral_load),
    last_vl = last(viral_load),
    .groups = 'drop'
  )

# Find first suppression date for VF patients
first_suppression_vf <- dat_vf %>%
  filter(viral_load < 50) %>%
  group_by(mrn) %>%
  arrange(mrn, viral_load_date) %>%
  slice(1) %>%
  select(mrn, first_suppression_date = viral_load_date, first_suppression_vl = viral_load) %>%
  ungroup()

# Identify BLIPS in VF group
dat_vf_blips <- dat_vf %>%
  arrange(mrn, viral_load_date) %>%
  group_by(mrn) %>%
  mutate(
    prev_vl = lag(viral_load),
    next_vl = lead(viral_load),
    is_blip = viral_load >= 50 & 
      !is.na(prev_vl) & prev_vl < 50 & 
      !is.na(next_vl) & next_vl < 50
  ) %>%
  ungroup()

patients_with_blips_vf <- dat_vf_blips %>%
  group_by(mrn) %>%
  summarize(
    n_blips = sum(is_blip, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  filter(n_blips > 0)

# Identify PLLV in VF group (after first suppression)
post_suppression_vf <- dat_vf %>%
  inner_join(first_suppression_vf, by = "mrn") %>%
  filter(viral_load_date > first_suppression_date) %>%
  arrange(mrn, viral_load_date) %>%
  group_by(mrn) %>%
  mutate(
    post_suppression_order = row_number(),
    is_elevated = viral_load >= 50,
    is_pllv_range = viral_load >= 50 & viral_load <= 200,
    is_high = viral_load > 200
  ) %>%
  ungroup()

if(nrow(post_suppression_vf) > 0) {
  identify_pllv_vf <- post_suppression_vf %>%
    group_by(mrn) %>%
    arrange(mrn, viral_load_date) %>%
    mutate(
      pllv_indicator = viral_load >= 50 & viral_load <= 200,
      pllv_group = cumsum(pllv_indicator != lag(pllv_indicator, default = FALSE))
    ) %>%
    group_by(mrn, pllv_group) %>%
    mutate(
      consecutive_pllv = sum(pllv_indicator),
      is_pllv_episode = pllv_indicator & consecutive_pllv >= 2
    ) %>%
    ungroup()
  
  patients_with_pllv_vf <- identify_pllv_vf %>%
    filter(is_pllv_episode) %>%
    group_by(mrn) %>%
    summarize(
      pllv_measurements = n(),
      .groups = 'drop'
    )
} else {
  patients_with_pllv_vf <- data.frame(mrn = character(), pllv_measurements = integer())
}

# Create classification for VF group
patient_classification_vf <- vf_summary %>%
  left_join(
    patients_with_blips_vf %>% select(mrn, n_blips),
    by = "mrn"
  ) %>%
  left_join(
    patients_with_pllv_vf %>% select(mrn, pllv_measurements),
    by = "mrn"
  ) %>%
  mutate(
    n_blips = replace_na(n_blips, 0),
    pllv_measurements = replace_na(pllv_measurements, 0),
    pattern = case_when(
      !ever_suppressed ~ "Never suppressed",
      n_blips > 0 & pllv_measurements > 0 ~ "Both blip and PLLV",
      n_blips > 0 & pllv_measurements == 0 ~ "Blips only",
      pllv_measurements > 0 & n_blips == 0 ~ "PLLV only",
      ever_suppressed & n_blips == 0 & pllv_measurements == 0 ~ "Stable suppression"
    )
  )

print("\n=== VF PATIENTS - ALL PATTERNS ===")
print(table(patient_classification_vf$pattern))
print(table(patient_classification_vf$ever_suppressed))

# === ANALYSIS FOR NON-VF GROUP ===
dat_non_vf <- dat %>%
  filter(!mrn %in% vf_mrns) %>%
  group_by(mrn) %>%
  arrange(mrn, viral_load_date)

non_vf_summary <- dat_non_vf %>%
  group_by(mrn) %>%
  summarize(
    n_measurements = n(),
    ever_suppressed = any(viral_load < 50, na.rm = TRUE),
    n_suppressed = sum(viral_load < 50, na.rm = TRUE),
    n_unsuppressed = sum(viral_load >= 50, na.rm = TRUE),
    percent_suppressed = round(100 * n_suppressed / n_measurements, 1),
    min_vl = min(viral_load, na.rm = TRUE),
    max_vl = max(viral_load, na.rm = TRUE),
    first_vl = first(viral_load),
    last_vl = last(viral_load),
    .groups = 'drop'
  )

first_suppression_non_vf <- dat_non_vf %>%
  filter(viral_load < 50) %>%
  group_by(mrn) %>%
  arrange(mrn, viral_load_date) %>%
  slice(1) %>%
  select(mrn, first_suppression_date = viral_load_date, first_suppression_vl = viral_load) %>%
  ungroup()

dat_non_vf_blips <- dat_non_vf %>%
  arrange(mrn, viral_load_date) %>%
  group_by(mrn) %>%
  mutate(
    prev_vl = lag(viral_load),
    next_vl = lead(viral_load),
    is_blip = viral_load >= 50 & 
      !is.na(prev_vl) & prev_vl < 50 & 
      !is.na(next_vl) & next_vl < 50
  ) %>%
  ungroup()

patients_with_blips_non_vf <- dat_non_vf_blips %>%
  group_by(mrn) %>%
  summarize(
    n_blips = sum(is_blip, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  filter(n_blips > 0)

post_suppression_non_vf <- dat_non_vf %>%
  inner_join(first_suppression_non_vf, by = "mrn") %>%
  filter(viral_load_date > first_suppression_date) %>%
  arrange(mrn, viral_load_date) %>%
  group_by(mrn) %>%
  mutate(
    post_suppression_order = row_number(),
    is_elevated = viral_load >= 50,
    is_pllv_range = viral_load >= 50 & viral_load <= 200,
    is_high = viral_load > 200
  ) %>%
  ungroup()

if(nrow(post_suppression_non_vf) > 0) {
  identify_pllv_non_vf <- post_suppression_non_vf %>%
    group_by(mrn) %>%
    arrange(mrn, viral_load_date) %>%
    mutate(
      pllv_indicator = viral_load >= 50 & viral_load <= 200,
      pllv_group = cumsum(pllv_indicator != lag(pllv_indicator, default = FALSE))
    ) %>%
    group_by(mrn, pllv_group) %>%
    mutate(
      consecutive_pllv = sum(pllv_indicator),
      is_pllv_episode = pllv_indicator & consecutive_pllv >= 2
    ) %>%
    ungroup()
  
  patients_with_pllv_non_vf <- identify_pllv_non_vf %>%
    filter(is_pllv_episode) %>%
    group_by(mrn) %>%
    summarize(
      pllv_measurements = n(),
      .groups = 'drop'
    )
} else {
  patients_with_pllv_non_vf <- data.frame(mrn = character(), pllv_measurements = integer())
}

patient_classification_non_vf <- non_vf_summary %>%
  left_join(
    patients_with_blips_non_vf %>% select(mrn, n_blips),
    by = "mrn"
  ) %>%
  left_join(
    patients_with_pllv_non_vf %>% select(mrn, pllv_measurements),
    by = "mrn"
  ) %>%
  mutate(
    n_blips = replace_na(n_blips, 0),
    pllv_measurements = replace_na(pllv_measurements, 0),
    pattern = case_when(
      !ever_suppressed ~ "Never suppressed",
      n_blips > 0 & pllv_measurements > 0 ~ "Both blip and PLLV",
      n_blips > 0 & pllv_measurements == 0 ~ "Blips only",
      pllv_measurements > 0 & n_blips == 0 ~ "PLLV only",
      ever_suppressed & n_blips == 0 & pllv_measurements == 0 ~ "Stable suppression"
    )
  )

# === COMPARISON AMONG THOSE WHO ACHIEVED SUPPRESSION ===
comparison_summary <- bind_rows(
  patient_classification_vf %>%
    mutate(group = "Virologic Failure") %>%
    filter(ever_suppressed == TRUE),
  patient_classification_non_vf %>%
    mutate(group = "Non-VF") %>%
    filter(ever_suppressed == TRUE)
)

cat("\n=== SAMPLE SIZES ===\n")
cat("Total VF patients:", length(vf_mrns), "\n")
cat("  - Achieved VL <50:", sum(patient_classification_vf$ever_suppressed), "\n")
cat("  - Never achieved VL <50:", sum(!patient_classification_vf$ever_suppressed), "\n")
cat("Total Non-VF patients:", nrow(patient_classification_non_vf), "\n")
cat("  - Achieved VL <50:", sum(patient_classification_non_vf$ever_suppressed), "\n")
cat("  - Never achieved VL <50:", sum(!patient_classification_non_vf$ever_suppressed), "\n")

# Calculate proportions
group_proportions <- comparison_summary %>%
  group_by(group) %>%
  summarize(
    n_patients = n(),
    n_blips_only = sum(pattern == "Blips only"),
    n_pllv_only = sum(pattern == "PLLV only"),
    n_both = sum(pattern == "Both blip and PLLV"),
    n_stable = sum(pattern == "Stable suppression"),
    prop_blips_only = round(100 * n_blips_only / n_patients, 1),
    prop_pllv_only = round(100 * n_pllv_only / n_patients, 1),
    prop_both = round(100 * n_both / n_patients, 1),
    prop_stable = round(100 * n_stable / n_patients, 1),
    n_any_blip = sum(n_blips > 0),
    n_any_pllv = sum(pllv_measurements > 0),
    prop_any_blip = round(100 * n_any_blip / n_patients, 1),
    prop_any_pllv = round(100 * n_any_pllv / n_patients, 1),
    .groups = 'drop'
  )

print("\n=== COMPARISON: VF vs NON-VF GROUPS ===")
print("(Among patients who achieved VL <50)")
print(group_proportions)

# Verify totals
verification <- group_proportions %>%
  mutate(total = prop_blips_only + prop_pllv_only + prop_both + prop_stable)
cat("\nVerification - totals should equal 100%:\n")
print(verification %>% select(group, n_patients, total))

# Statistical tests
blip_table <- comparison_summary %>%
  mutate(has_blip = n_blips > 0) %>%
  count(group, has_blip) %>%
  pivot_wider(names_from = has_blip, values_from = n, values_fill = 0)

cat("\n=== ANY BLIPS CONTINGENCY TABLE ===\n")
print(blip_table)

blip_matrix <- as.matrix(blip_table[, -1])
rownames(blip_matrix) <- blip_table$group
if(all(dim(blip_matrix) == c(2, 2))) {
  blip_test <- fisher.test(blip_matrix)
  cat("\nFisher's Exact Test for Any Blips:\n")
  cat("p-value:", format.pval(blip_test$p.value, digits = 3), "\n")
  cat("Odds Ratio:", round(blip_test$estimate, 2), "\n")
  cat("95% CI:", round(blip_test$conf.int[1], 2), "-", round(blip_test$conf.int[2], 2), "\n")
}

pllv_table <- comparison_summary %>%
  mutate(has_pllv = pllv_measurements > 0) %>%
  count(group, has_pllv) %>%
  pivot_wider(names_from = has_pllv, values_from = n, values_fill = 0)

cat("\n=== ANY PLLV CONTINGENCY TABLE ===\n")
print(pllv_table)

pllv_matrix <- as.matrix(pllv_table[, -1])
rownames(pllv_matrix) <- pllv_table$group
if(all(dim(pllv_matrix) == c(2, 2))) {
  pllv_test <- fisher.test(pllv_matrix)
  cat("\nFisher's Exact Test for Any PLLV:\n")
  cat("p-value:", format.pval(pllv_test$p.value, digits = 3), "\n")
  cat("Odds Ratio:", round(pllv_test$estimate, 2), "\n")
  cat("95% CI:", round(pllv_test$conf.int[1], 2), "-", round(pllv_test$conf.int[2], 2), "\n")
}

# Visualizations
prop_data <- group_proportions %>%
  select(group, prop_blips_only, prop_pllv_only, prop_both, prop_stable) %>%
  pivot_longer(cols = starts_with("prop_"), 
               names_to = "outcome", 
               values_to = "proportion") %>%
  mutate(
    outcome = factor(outcome, 
                     levels = c("prop_stable", "prop_blips_only", "prop_pllv_only", "prop_both"),
                     labels = c("Stable suppression", "Blips only", "PLLV only", "Both"))
  )

p1 <- ggplot(prop_data, aes(x = group, y = proportion, fill = outcome)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = ifelse(proportion >= 3, paste0(proportion, "%"), "")), 
            position = position_stack(vjust = 0.5), 
            color = "white", fontface = "bold", size = 3.5) +
  scale_fill_manual(values = c("Stable suppression" = "#78B37F", 
                               "Blips only" = "#E6B267", 
                               "PLLV only" = "#FFBFD6",
                               "Both" = "#DB6B95")) +
  labs(
    title = "Characterizing Viral Load Patterns for People\n with and without VF",
    x = "Group",
    y = "Percentage (%)",
    fill = "Pattern"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  ) +
  scale_y_continuous(breaks = seq(0, 100, 20), limits = c(0, 100))

print(p1)

p1 <- ggplot(prop_data, aes(x = group, y = proportion, fill = outcome)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = ifelse(proportion >= 3, paste0(proportion, "%"), "")), 
            position = position_stack(vjust = 0.5), 
            color = "white", fontface = "bold", size = 3.5) +
  scale_fill_manual(values = c("Stable suppression" = "#78B37F", 
                               "Blips only" = "#E6B267", 
                               "PLLV only" = "#68BFD9",
                               "Both" = "#D96868")) +
  labs(
    title = "Characterizing Viral Load Patterns for People\n with and without VF",
    x = "Group",
    y = "Percentage (%)",
    fill = "Pattern"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  ) +
  scale_y_continuous(breaks = seq(0, 100, 20), limits = c(0, 100))

print(p1)

create_pptx(p1, pptx_path)


# Summary tables
summary_table <- group_proportions %>%
  select(group, n_patients, 
         `Stable n (%)` = n_stable, prop_stable,
         `Blips only n (%)` = n_blips_only, prop_blips_only,
         `PLLV only n (%)` = n_pllv_only, prop_pllv_only,
         `Both n (%)` = n_both, prop_both) %>%
  mutate(
    `Stable n (%)` = paste0(`Stable n (%)`, " (", prop_stable, "%)"),
    `Blips only n (%)` = paste0(`Blips only n (%)`, " (", prop_blips_only, "%)"),
    `PLLV only n (%)` = paste0(`PLLV only n (%)`, " (", prop_pllv_only, "%)"),
    `Both n (%)` = paste0(`Both n (%)`, " (", prop_both, "%)")
  ) %>%
  select(-prop_stable, -prop_blips_only, -prop_pllv_only, -prop_both)

print("\n=== SUMMARY TABLE (Mutually Exclusive Patterns) ===")
print(summary_table)

any_event_table <- group_proportions %>%
  select(group, n_patients,
         `Any Blip n (%)` = n_any_blip, prop_any_blip,
         `Any PLLV n (%)` = n_any_pllv, prop_any_pllv) %>%
  mutate(
    `Any Blip n (%)` = paste0(`Any Blip n (%)`, " (", prop_any_blip, "%)"),
    `Any PLLV n (%)` = paste0(`Any PLLV n (%)`, " (", prop_any_pllv, "%)")
  ) %>%
  select(-prop_any_blip, -prop_any_pllv)

print("\n=== SUMMARY TABLE (Any Blip / Any PLLV) ===")
print(any_event_table)

#### Proportion Test 
# === PROPORTION TESTS FOR BLIPS AND PLLV ===

# Create contingency tables from the comparison_summary data
print("\n=== STATISTICAL COMPARISON: VF vs NON-VF ===")
print("(Among patients who achieved VL <50)")

# 1. TEST FOR ANY BLIPS
cat("\n" , rep("=", 60), "\n", sep="")
cat("1. COMPARISON OF BLIP RATES\n")
cat(rep("=", 60), "\n", sep="")

blip_counts <- comparison_summary %>%
  mutate(has_blip = n_blips > 0) %>%
  group_by(group) %>%
  summarize(
    n_patients = n(),
    n_with_blips = sum(has_blip),
    n_without_blips = sum(!has_blip),
    prop_blips = round(100 * n_with_blips / n_patients, 1),
    .groups = 'drop'
  )

print(blip_counts)

# Create 2x2 table
blip_table <- comparison_summary %>%
  mutate(has_blip = n_blips > 0) %>%
  count(group, has_blip) %>%
  pivot_wider(names_from = has_blip, values_from = n, values_fill = 0)

print("\nContingency Table:")
print(blip_table)

# Fisher's Exact Test
blip_matrix <- as.matrix(blip_table[, -1])
rownames(blip_matrix) <- blip_table$group
colnames(blip_matrix) <- c("No Blip", "Blip")

blip_fisher <- fisher.test(blip_matrix)
cat("\nFisher's Exact Test for Blips:\n")
cat("  p-value:", format.pval(blip_fisher$p.value, digits = 4), "\n")
cat("  Odds Ratio:", round(blip_fisher$estimate, 2), "\n")
cat("  95% CI:", round(blip_fisher$conf.int[1], 2), "-", round(blip_fisher$conf.int[2], 2), "\n")

# Proportion Test
blip_prop_test <- prop.test(
  x = c(blip_counts$n_with_blips[blip_counts$group == "Virologic Failure"],
        blip_counts$n_with_blips[blip_counts$group == "Non-VF"]),
  n = c(blip_counts$n_patients[blip_counts$group == "Virologic Failure"],
        blip_counts$n_patients[blip_counts$group == "Non-VF"]),
  correct = TRUE
)

cat("\nTwo-Sample Proportion Test for Blips:\n")
cat("  Chi-squared:", round(blip_prop_test$statistic, 3), "\n")
cat("  p-value:", format.pval(blip_prop_test$p.value, digits = 4), "\n")
cat("  VF proportion:", round(blip_prop_test$estimate[1], 3), 
    "(", round(100*blip_prop_test$estimate[1], 1), "%)\n")
cat("  Non-VF proportion:", round(blip_prop_test$estimate[2], 3), 
    "(", round(100*blip_prop_test$estimate[2], 1), "%)\n")
cat("  95% CI for difference:", round(blip_prop_test$conf.int[1], 3), "to", 
    round(blip_prop_test$conf.int[2], 3), "\n")

# 2. TEST FOR ANY PLLV
cat("\n" , rep("=", 60), "\n", sep="")
cat("2. COMPARISON OF PLLV RATES\n")
cat(rep("=", 60), "\n", sep="")

pllv_counts <- comparison_summary %>%
  mutate(has_pllv = pllv_measurements > 0) %>%
  group_by(group) %>%
  summarize(
    n_patients = n(),
    n_with_pllv = sum(has_pllv),
    n_without_pllv = sum(!has_pllv),
    prop_pllv = round(100 * n_with_pllv / n_patients, 1),
    .groups = 'drop'
  )

print(pllv_counts)

# Create 2x2 table
pllv_table <- comparison_summary %>%
  mutate(has_pllv = pllv_measurements > 0) %>%
  count(group, has_pllv) %>%
  pivot_wider(names_from = has_pllv, values_from = n, values_fill = 0)

print("\nContingency Table:")
print(pllv_table)

# Fisher's Exact Test
pllv_matrix <- as.matrix(pllv_table[, -1])
rownames(pllv_matrix) <- pllv_table$group
colnames(pllv_matrix) <- c("No PLLV", "PLLV")

pllv_fisher <- fisher.test(pllv_matrix)
cat("\nFisher's Exact Test for PLLV:\n")
cat("  p-value:", format.pval(pllv_fisher$p.value, digits = 4), "\n")
cat("  Odds Ratio:", round(pllv_fisher$estimate, 2), "\n")
cat("  95% CI:", round(pllv_fisher$conf.int[1], 2), "-", round(pllv_fisher$conf.int[2], 2), "\n")

# Proportion Test
pllv_prop_test <- prop.test(
  x = c(pllv_counts$n_with_pllv[pllv_counts$group == "Virologic Failure"],
        pllv_counts$n_with_pllv[pllv_counts$group == "Non-VF"]),
  n = c(pllv_counts$n_patients[pllv_counts$group == "Virologic Failure"],
        pllv_counts$n_patients[pllv_counts$group == "Non-VF"]),
  correct = TRUE
)

cat("\nTwo-Sample Proportion Test for PLLV:\n")
cat("  Chi-squared:", round(pllv_prop_test$statistic, 3), "\n")
cat("  p-value:", format.pval(pllv_prop_test$p.value, digits = 4), "\n")
cat("  VF proportion:", round(pllv_prop_test$estimate[1], 3), 
    "(", round(100*pllv_prop_test$estimate[1], 1), "%)\n")
cat("  Non-VF proportion:", round(pllv_prop_test$estimate[2], 3), 
    "(", round(100*pllv_prop_test$estimate[2], 1), "%)\n")
cat("  95% CI for difference:", round(pllv_prop_test$conf.int[1], 3), "to", 
    round(pllv_prop_test$conf.int[2], 3), "\n")

# 3. TEST FOR EITHER BLIP OR PLLV
cat("\n" , rep("=", 60), "\n", sep="")
cat("3. COMPARISON OF ANY EVENT (BLIP OR PLLV) RATES\n")
cat(rep("=", 60), "\n", sep="")

either_counts <- comparison_summary %>%
  mutate(has_either = n_blips > 0 | pllv_measurements > 0) %>%
  group_by(group) %>%
  summarize(
    n_patients = n(),
    n_with_event = sum(has_either),
    n_without_event = sum(!has_either),
    prop_event = round(100 * n_with_event / n_patients, 1),
    .groups = 'drop'
  )

print(either_counts)

# Create 2x2 table
either_table <- comparison_summary %>%
  mutate(has_either = n_blips > 0 | pllv_measurements > 0) %>%
  count(group, has_either) %>%
  pivot_wider(names_from = has_either, values_from = n, values_fill = 0)

print("\nContingency Table:")
print(either_table)

# Fisher's Exact Test
either_matrix <- as.matrix(either_table[, -1])
rownames(either_matrix) <- either_table$group
colnames(either_matrix) <- c("No Event", "Event")

either_fisher <- fisher.test(either_matrix)
cat("\nFisher's Exact Test for Any Event:\n")
cat("  p-value:", format.pval(either_fisher$p.value, digits = 4), "\n")
cat("  Odds Ratio:", round(either_fisher$estimate, 2), "\n")
cat("  95% CI:", round(either_fisher$conf.int[1], 2), "-", round(either_fisher$conf.int[2], 2), "\n")

# Proportion Test
either_prop_test <- prop.test(
  x = c(either_counts$n_with_event[either_counts$group == "Virologic Failure"],
        either_counts$n_with_event[either_counts$group == "Non-VF"]),
  n = c(either_counts$n_patients[either_counts$group == "Virologic Failure"],
        either_counts$n_patients[either_counts$group == "Non-VF"]),
  correct = TRUE
)

cat("\nTwo-Sample Proportion Test for Any Event:\n")
cat("  Chi-squared:", round(either_prop_test$statistic, 3), "\n")
cat("  p-value:", format.pval(either_prop_test$p.value, digits = 4), "\n")
cat("  VF proportion:", round(either_prop_test$estimate[1], 3), 
    "(", round(100*either_prop_test$estimate[1], 1), "%)\n")
cat("  Non-VF proportion:", round(either_prop_test$estimate[2], 3), 
    "(", round(100*either_prop_test$estimate[2], 1), "%)\n")
cat("  95% CI for difference:", round(either_prop_test$conf.int[1], 3), "to", 
    round(either_prop_test$conf.int[2], 3), "\n")

# === SUMMARY TABLE OF ALL COMPARISONS ===
cat("\n" , rep("=", 60), "\n", sep="")
cat("SUMMARY OF ALL STATISTICAL TESTS\n")
cat(rep("=", 60), "\n", sep="")

summary_results <- data.frame(
  Outcome = c("Any Blips", "Any PLLV", "Any Event (Blip or PLLV)"),
  VF_Rate = c(
    paste0(blip_counts$n_with_blips[blip_counts$group == "Virologic Failure"], "/", 
           blip_counts$n_patients[blip_counts$group == "Virologic Failure"], 
           " (", blip_counts$prop_blips[blip_counts$group == "Virologic Failure"], "%)"),
    paste0(pllv_counts$n_with_pllv[pllv_counts$group == "Virologic Failure"], "/", 
           pllv_counts$n_patients[pllv_counts$group == "Virologic Failure"], 
           " (", pllv_counts$prop_pllv[pllv_counts$group == "Virologic Failure"], "%)"),
    paste0(either_counts$n_with_event[either_counts$group == "Virologic Failure"], "/", 
           either_counts$n_patients[either_counts$group == "Virologic Failure"], 
           " (", either_counts$prop_event[either_counts$group == "Virologic Failure"], "%)")
  ),
  NonVF_Rate = c(
    paste0(blip_counts$n_with_blips[blip_counts$group == "Non-VF"], "/", 
           blip_counts$n_patients[blip_counts$group == "Non-VF"], 
           " (", blip_counts$prop_blips[blip_counts$group == "Non-VF"], "%)"),
    paste0(pllv_counts$n_with_pllv[pllv_counts$group == "Non-VF"], "/", 
           pllv_counts$n_patients[pllv_counts$group == "Non-VF"], 
           " (", pllv_counts$prop_pllv[pllv_counts$group == "Non-VF"], "%)"),
    paste0(either_counts$n_with_event[either_counts$group == "Non-VF"], "/", 
           either_counts$n_patients[either_counts$group == "Non-VF"], 
           " (", either_counts$prop_event[either_counts$group == "Non-VF"], "%)")
  ),
  Fisher_p = c(
    format.pval(blip_fisher$p.value, digits = 3),
    format.pval(pllv_fisher$p.value, digits = 3),
    format.pval(either_fisher$p.value, digits = 3)
  ),
  Odds_Ratio = c(
    paste0(round(blip_fisher$estimate, 2), " (", 
           round(blip_fisher$conf.int[1], 2), "-", 
           round(blip_fisher$conf.int[2], 2), ")"),
    paste0(round(pllv_fisher$estimate, 2), " (", 
           round(pllv_fisher$conf.int[1], 2), "-", 
           round(pllv_fisher$conf.int[2], 2), ")"),
    paste0(round(either_fisher$estimate, 2), " (", 
           round(either_fisher$conf.int[1], 2), "-", 
           round(either_fisher$conf.int[2], 2), ")")
  ),
  Prop_Test_p = c(
    format.pval(blip_prop_test$p.value, digits = 3),
    format.pval(pllv_prop_test$p.value, digits = 3),
    format.pval(either_prop_test$p.value, digits = 3)
  )
)

colnames(summary_results) <- c("Outcome", "VF Rate", "Non-VF Rate", 
                               "Fisher's p", "OR (95% CI)", "Prop Test p")

summary_results


#### 11. SUMMARY TABLES FOR SUPPLEMENT ####
# TABLE SET 1 (full models)
t1_blip <- tbl_regression(fit_blip_final_1, exp = TRUE,
                          label = list(
                            viremic_at_initiation_refS ~ "Viremic at initiation",
                            age_yrs_scale10 ~ "Age (per 10 years)",
                            sex = "Sex",
                            race_eth ~ "Race/ethnicity",
                            bmi ~ "BMI",
                            cd4_at_initiation_scaled100 ~ "CD4 at initiation (per 100 cells/µL)",
                            dosing = "Dosing frequency",
                            percent_ontime = "Percentage of injections administered on time"))

t1_pllv <- tbl_regression(fit_pllv_final_1, exp = TRUE,
                          label = list(
                            viremic_at_initiation_refS ~ "Viremic at initiation",
                            age_yrs_scale10 ~ "Age (per 10 years)",
                            sex = "Sex",
                            race_eth = "Race/ethnicity",
                            bmi ~ "BMI",
                            cd4_at_initiation_scaled100 ~ "CD4 at initiation (per 100 cells/µL)",
                            dosing = "Dosing frequency",
                            percent_ontime = "Percentage of injections administered on time"))

t1_vf <- tbl_regression(fit_vf_final_1, exp = TRUE,
                        label = list(
                          viremic_at_initiation_refS ~ "Viremic at initiation",
                          age_yrs_scale10 ~ "Age (per 10 years)",
                          sex = "Sex",
                          race_eth ~ "Race/ethnicity",
                          bmi ~ "BMI",
                          cd4_at_initiation_scaled100 ~ "CD4 at initiation (per 100 cells/µL)",
                          dosing = "Dosing frequency",
                          percent_ontime = "Percentage of injections administered on time"))

tbl_merge(
  tbls = list(t1_blip, t1_pllv, t1_vf),
  tab_spanner = c("**Blips**", "**PLLV**", "**Virologic Failure**")
) %>%
  modify_caption("**Table. Adjusted odds ratios for virologic outcomes (parsimonious models)**")


# Check for separation
vars_to_check <- c("viremic_at_initiation_refS", "race_eth", "sex", "dosing")

# pLLV
dat_unique %>%
  select(pllv, all_of(vars_to_check)) %>%
  pivot_longer(-pllv, names_to = "variable", values_to = "value") %>%
  group_by(variable, value) %>%
  summarize(
    n = n(),
    n_outcome = sum(pllv == 1, na.rm = TRUE),
    pct = round(100 * n_outcome / n, 1),
    .groups = "drop"
  ) %>%
  arrange(variable, value) %>%
  print(n = Inf)

# VF
dat_unique %>%
  select(virologic_failure, all_of(vars_to_check)) %>%
  pivot_longer(-virologic_failure, names_to = "variable", values_to = "value") %>%
  group_by(variable, value) %>%
  summarize(
    n = n(),
    n_outcome = sum(virologic_failure == 1, na.rm = TRUE),
    pct = round(100 * n_outcome / n, 1),
    .groups = "drop"
  ) %>%
  arrange(variable, value) %>%
  print(n = Inf)


