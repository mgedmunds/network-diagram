# Data Dictionary

Field-level definitions for all tables in the Measles Outbreak Network Explorer schema.
For the entity-relationship diagram see `docs/erd.svg` (auto-generated when the app runs).

---

## cases

One row per case. The two required fields are `case_id` and `onset_date`; all others are optional but recommended. Fields marked *(derived)* are auto-calculated in the Excel template and should not be typed manually.

| Field | Type | Key | Required | Description |
|---|---|---|---|---|
| `case_id` | character | PK | Yes | Unique case identifier. Auto-generated in template as C-001, C-002 … based on row position. Join key across all tables. |
| `CIMS_id` | character | — | No | Reference number from CIMS or equivalent national surveillance system. Must be unique; template highlights duplicates in amber. |
| `forename` | character | — | No | Case forename. |
| `surname` | character | — | No | Case surname. |
| `date_of_birth` | date | — | No | Date of birth. Used to calculate age at onset. Format: DD/MM/YYYY in template. |
| `onset_date` | date | — | Yes | Symptom onset date. Drives the time slider, epidemic curve, and all epi-period derivations. Format: DD/MM/YYYY in template. |
| `age` | integer | — | No | *(derived)* Age in whole years at onset date. Auto-calculated from `date_of_birth` and `onset_date` in template. Do not type manually. |
| `gender` | character | — | No | Values: `Male`, `Female`, `Other`, `Unknown`. Available as an epidemic-curve grouping option. |
| `postcode` | character | — | No | UK postcode. Free text; no format enforcement. |
| `case_status` | character | — | No | Case confidence — how firmly the case is classified. Values: `Confirmed`, `Probable`, `Possible`. Displayed in the UI as "Case confidence"; field name remains `case_status`. |
| `vaccination_status` | character | — | No | Measles vaccination history at time of illness. Values: `Unvaccinated`, `1 dose`, `2 doses`, `Unknown`. |

---

## contexts

One row per unique context. Provided as a dedicated `contexts` sheet in the xlsx upload.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `context_id` | integer | PK | Yes | Yes | Surrogate primary key. Unique integer assigned to each context. Used as the join key in `case_contexts` and `visit_dates`. |
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

## contacts

One row per recorded transmission link. Optional sheet — if absent, possible links may be derived from shared contexts and timing.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `from` | character | FK | Yes | Yes | Source case. FK → `cases.case_id`. |
| `to` | character | FK | Yes | Yes | Recipient case. FK → `cases.case_id`. |
| `link_type` | character | — | No | Yes | Strength of evidence: `Probable` (epidemiologically established) or `Possible` (plausible based on timing and shared context). |

---

## Validation rules

- `case_id` must be unique in `cases`
- `onset_date` must be a valid date
- `context_id` must be unique in `contexts`
- All `case_id` values in `case_contexts` must exist in `cases`
- All `context_id` values in `case_contexts` must exist in `contexts`
- All (`case_id`, `context_id`) pairs in `visit_dates` must exist in `case_contexts`
- `from` and `to` in `contacts` must both exist in `cases`
- `inc_min` < `inc_max` (enforced in the app parameters panel)
