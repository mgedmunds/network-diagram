# Data Dictionary

Field-level definitions for all tables in the Measles Outbreak Network Explorer schema.
For the entity-relationship diagram see `docs/erd.svg` (auto-generated when the app runs).

---

## cases

One row per case. The two required fields are `case_id` and `onset_date`; all others are optional but recommended. Fields marked *(derived)* are auto-calculated in the Excel template and should not be typed manually.

The `cases` sheet doubles as a working linelist. Columns are listed below in template order. **Tool?** = Yes means the network tool reads the field (maroon header in the template); No means it is collected for the linelist but not used by the tool (dark blue header).

Every categorical field takes its dropdown options from a column on the **Dropdowns** tab (one editable list per field), so the allowed values can be edited per outbreak. Two of those lists — `Setting Types` (→ `context_type` / `primary_context_type`) and `Case confidence` (→ `case_status`) — are also read by the tool: the order of their values sets the display order of those categories in the app, and are marked with maroon headers on the Dropdowns tab.

| Field | Type | Key | Required | Tool? | Description |
|---|---|---|---|---|---|
| `case_id` | character | PK | Yes | Yes | Unique case identifier, **manually entered** (ADR-007), pattern `C-001`, `C-002` … Duplicate or wrong-format IDs are flagged red by conditional formatting (openxlsx has no custom validation). Join key across all tables. |
| `CIMS_id` | character | — | No | No | Reference number from CIMS or equivalent national surveillance system. Must be unique; template highlights duplicates in amber. |
| `forename` | character | — | No | No | Case forename. |
| `surname` | character | — | No | No | Case surname. |
| `date_of_birth` | date | — | No | No | Date of birth. Used to calculate age at onset. Format: DD/MM/YYYY in template. |
| `age` | integer | — | No | No | *(derived)* Age in whole years at onset. Auto-calculated in template from `date_of_birth` and `onset_date`; when `onset_date` is blank it falls back to `report_date` (which is always known), so age still computes for cases without a recorded onset. Do not type manually. |
| `age_group` | character | — | No | Yes | *(derived)* UKHSA age band from `age`: `<1 year`, `1–4 years`, `5–17 years`, `18–29 years`, `30–49 years`, `50+ years`. Auto-calculated in template. |
| `gender` | character | — | No | Yes | Values: `Male`, `Female`, `Other`, `Unknown`. |
| `ethnicity` | character | — | No | No | ONS 2021 census category. Dropdown sourced from the Ethnicity list on the Dropdowns tab. |
| `postcode` | character | — | No | No | UK postcode. Free text; no format enforcement. |
| `utla` | character | — | No | No | Upper-tier local authority. Free text. |
| `report_date` | date | — | No | No | Date the case was reported/notified. Format: DD/MM/YYYY. |
| `onset_date` | date | — | Yes | Yes | Symptom onset date. Drives the time slider and timeline, and is the reference point for the infectious period and exposure window. Format: DD/MM/YYYY in template. |
| `date_of_rash` | date | — | No | No | Date of rash onset. Format: DD/MM/YYYY. |
| `exposure_window` | character | — | No | No | *(derived)* Date range 21 to 7 days before `onset_date` (measles incubation default). Auto-calculated text range in template; uses fixed defaults (does not follow the app's editable parameters). |
| `infectious_period` | character | — | No | No | *(derived)* Date range 4 days before to 4 days after `onset_date` (measles default). Auto-calculated text range in template; uses fixed defaults. |
| `case_status` | character | — | No | Yes | Case confidence — how firmly the case is classified. Values: `Confirmed`, `Probable`, `Possible`. Displayed in the UI as "Case confidence"; field name remains `case_status`. |
| `genotype` | character | — | No | No | Measles genotype (e.g. `B3`, `D8`). Free text. |
| `confirmation_test_result` | character | — | No | No | Values: `Saliva IgM positive`, `Saliva IgM negative`, `Serum IgM positive`, `Serum IgM negative`, `PCR positive`, `PCR negative`, `Not tested`, `Pending`. |
| `vaccination_status` | character | — | No | Yes | Measles vaccination history at time of illness. Values: `Unvaccinated`, `1 dose`, `2 doses`, `Unknown`. |
| `vaccination_confirmation_method` | character | — | No | No | How vaccination status was confirmed. Values: `CHIS`, `GP`, `Occupational Health`, `Parent/guardian`, `Other`, `Unknown`. |
| `vaccination_notes` | character | — | No | No | Free-text notes on vaccination history. |
| `travel_history` | character | — | No | No | Any relevant travel. Values: `Yes`, `No`, `Unknown`. |
| `travel_history_details` | character | — | No | No | Free-text detail where `travel_history` is Yes. |
| `likely_index_case` | character | FK | No | Yes | `case_id` of the case recorded as the likely source of infection for this case. Self-reference → `cases.case_id`. Drives the arrows in the "Who infected whom" view; one source per case. Template highlights it red if set to the case's own ID. |
| `probable_epi_link` | character | — | No | No | Whether a probable epidemiological link to another case is known. Values: `Yes`, `No`, `Unknown`. |
| `total_contacts` | integer | — | No | No | Number of contacts identified for the case. Whole number ≥ 0. |
| `vulnerable_contacts` | integer | — | No | No | Number of those contacts who are clinically vulnerable. Whole number ≥ 0. |
| `primary_context_type` | character | — | No | Yes | The context type most associated with the case (e.g. `School`, `Household`). Dropdown from the Dropdowns tab (Setting Types list). Read from the workbook and stored on `cases`, but not yet used by any view ("store only"). |
| `contexts` | character | — | No | No | *(derived)* Semi-colon list of context names linked to the case in `case_contexts`. Column AD starts blank; the user pastes a CSE (`Ctrl+Shift+Enter`) `TEXTJOIN`/`MATCH` formula into AD2 once and copies down (steps + formula on the README tab). Auto-fill was abandoned — openxlsx cannot reliably write array formulas. Not used by the app (it derives links from `case_contexts` directly). |
| `status` | character | — | No | No | Case management status. Values: `Open`, `Closed`, `Discarded`. Set to `Discarded` instead of deleting a ruled-out case (deleting a row renumbers position-based IDs). External-only — not read by the tool. |
| `date_closed` | date | — | No | No | Date the case was closed. Format: DD/MM/YYYY. |

---

## contexts

One row per unique context. Provided as a dedicated `contexts` sheet in the xlsx upload.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `context_id` | character | PK | Yes | Yes | Primary key, **manually entered** (ADR-007), pattern `Ctxt-001`, `Ctxt-002` … Duplicate or wrong-format IDs are flagged red by conditional formatting. Join key in `case_contexts` and `visit_dates`. |
| `context_name` | character | — | No | Yes | Human-readable name for the context. Free text; should be unique within the dataset. |
| `context_type` | character | — | Yes | Yes | User-defined categorical label describing the type of context (e.g. `School`, `Household`, `Healthcare`). Not pre-coded — values are determined by the data entered. Drives node colour in the network and the context-type filter. |

---

## case_contexts

One row per case × context combination. Bridging table between `cases` and `contexts`.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `case_id` | character | PK + FK | Yes | Composite primary key. FK → `cases.case_id`. |
| `context_id` | integer | PK + FK | Yes | Composite primary key. FK → `contexts.context_id`. |

> `context_name`, `context_type`, and `visit_relevance` are not stored here — they are joined or derived at runtime.

---

## visit_dates

One row per epidemiologically relevant visit date for a given case × context pair. Child table of `case_contexts`.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `case_id` | character | PK + FK | Yes | Yes | Composite primary key. FK → `case_contexts.case_id`. |
| `context_id` | integer | PK + FK | Yes | Yes | Composite primary key. FK → `case_contexts.context_id`. |
| `visit_date` | date | PK | Yes | Yes | Date of a visit that falls within or near the epi windows. One row per calendar day — a case visits a context at most once per calendar day. Format: YYYY-MM-DD. |

### Derived field: `epi_category`

Not stored. Computed at runtime for each `visit_date` by comparing against `onset_date` using current parameter values. Recalculates automatically when parameters are changed — no data migration needed.

| Category | Condition | Epidemiological meaning |
|---|---|---|
| `Exposure window` | `onset − inc_max ≤ visit_date ≤ onset − inc_min` | Case may have been infected at this context on this date |
| `Infectious period` | `onset − inf_before ≤ visit_date ≤ onset + inf_after` | Case may have infected others at this context on this date |
| `Both` | Case has at least one date in the exposure window AND at least one date in the infectious period at this context | Context is relevant in both directions (e.g. household resident present across both windows) |
| `Neither` | Date falls outside all windows | Visit is recorded but not considered transmission-relevant |

**Edge aggregation rule:** Where a case × context pair has multiple visit dates, the network edge takes the highest-priority category across all dates: Both > Infectious > Exposure > Neither.

**Default parameter values (measles):**

| Parameter | Default | Meaning |
|---|---|---|
| `inc_min` | 7 days | Minimum incubation period (exposure to onset) |
| `inc_max` | 21 days | Maximum incubation period (exposure to onset) |
| `inf_before` | 4 days | Days before onset during which the case is infectious |
| `inf_after` | 4 days | Days after onset during which the case is infectious |

With default measles parameters the exposure window and infectious period do not overlap (inc_min > inf_before), so `Both` can only arise from a case-context pair that has dates spanning both windows across separate visits — typically a household where the resident was present before and during illness.

---

## Validation rules

- `case_id` must be unique in `cases`
- `onset_date` must be a valid date
- `context_id` must be unique in `contexts`
- All `case_id` values in `case_contexts` must exist in `cases`
- All `context_id` values in `case_contexts` must exist in `contexts`
- All (`case_id`, `context_id`) pairs in `visit_dates` must exist in `case_contexts`
- `likely_index_case` in `cases`, where set, must reference an existing `case_id` and must not equal the case's own `case_id`
- `inc_min` < `inc_max` (enforced in the app parameters panel)
