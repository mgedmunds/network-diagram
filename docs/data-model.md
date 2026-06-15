# Data Model — Working Notes

Phase 1 working document. Tracks decisions about what data the tool needs.

---

## Current schema

### linelist (one row per case)

| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | character | yes | unique identifier |
| `onset_date` | date | yes | drives time slider, epi curve, infectious-period logic |
| `age_group` | character | no | Fixed bands: "<1 year", "1–4 years", "5–17 years", "18–29 years", "30–49 years", "50+ years" |
| `vaccination_status` | character | no | "Unvaccinated", "1 dose", "2 doses", "Unknown" |

### visits (one row per case-setting visit)

| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | character | yes | foreign key to linelist |
| `setting_name` | character | yes | free text place name |
| `setting_type` | character | yes | School, Healthcare, Community, Household, Other |
| `visit_date` | date | no | if absent, visit timing classification is skipped |

### contacts (one row per transmission link — optional sheet)

| Field | Type | Required | Notes |
|---|---|---|---|
| `from` | character | yes | source case_id |
| `to` | character | yes | recipient case_id |
| `link_type` | character | yes | "Confirmed" or "Suspected" |

---

## Open questions

- [x] Should `age_group` use fixed bands or free text?
- [ ] Should `setting_type` be a fixed controlled list or free text?
- [ ] Do we need a `setting_id` separate from `setting_name` (e.g. if two settings share a name)?
- [ ] Should `visit_date` be required or remain optional?
- [ ] Is `vaccination_status` measles-specific or should it be generic?
- [ ] Do we need a `case_status` field (confirmed / probable / suspected case)?
- [ ] will categories provided by practitioner be used to describe exposure types (e.g. visit during infectious period), or should this be derived based on the data entered (e.g. using onset date and dates of visit. Will it be reasonable to expect practitioners to be able to categorise accurately for all case-setting interactions? Do we need an "unknown" options? May be best to use the practitioner assigned value and then use the data as a validation check for misclassification?
- [ ] How will dates attending settings be calculated? Are we able to automate so that each case only has to assess relevant dates for each setting (i.e. those where they could have been infected or were infectious. If using a data capture function of the tool itself, can it be used concurrently?
- [ ] When importing data from a line list, very few fields are needed. Specify which and naming conventions
- [ ] Come up with data flow diagram
- [ ] Create a data dictionary
- [ ] Create relational Data model showing relational information

## Decisions made

_Record decisions here as they are made, then move to a formal ADR if significant._

**`age_group` — fixed bands 
Six bands aligned with vaccination schedule, school settings, and UKHSA reporting practice: `<1 year`, `1–4 years`, `5–17 years`, `18–29 years`, `30–49 years`, `50+ years`. 

---

## Validation rules

_To be defined in Phase 1._

- `onset_date` must be a valid date
- `case_id` must be unique in linelist
- All `case_id` values in visits must exist in linelist
- `inc_min` must be less than `inc_max` (enforced in app parameters)

---

## Notes

