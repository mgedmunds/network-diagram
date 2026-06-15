# Data Dictionary

Field-level definitions for all tables in the Measles Outbreak Network Explorer schema.
For the entity-relationship diagram see `docs/erd.svg` (auto-generated when the app runs).

---

## cases

One row per confirmed or probable case.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `case_id` | character | PK | Yes | Yes | Unique case identifier. Used as the join key across all tables. Must be unique within the dataset. |
| `onset_date` | date | — | Yes | Yes | Symptom onset date. Drives the time slider, epidemic curve, and all epi-period derivations. Format: YYYY-MM-DD. |
| `age_group` | character | — | No | No | Age band. Fixed values: `<1 year`, `1–4 years`, `5–17 years`, `18–29 years`, `30–49 years`, `50+ years`. Aligned with UKHSA reporting practice and vaccination schedule milestones. |
| `vaccination_status` | character | — | No | No | Measles vaccination history at time of illness. Values: `Unvaccinated`, `1 dose`, `2 doses`, `Unknown`. |

---

## settings

One row per unique setting. Derived internally from `case_settings` on upload — not provided as a separate sheet in the xlsx.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `setting_name` | character | PK | Yes | Yes | Unique setting name. Natural primary key. A surrogate `setting_id` may be added in future if name collisions occur between genuinely distinct venues. |
| `setting_type` | character | — | Yes | Yes | User-defined categorical label describing the type of setting (e.g. `School`, `Household`, `Healthcare`). Not pre-coded — values are determined by the data entered. Drives node colour in the network and the setting-type filter. |

---

## case_settings

One row per case × setting combination. Bridging table between `cases` and `settings`.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `case_id` | character | PK + FK | Yes | Yes | Composite primary key. FK → `cases.case_id`. |
| `setting_name` | character | PK + FK | Yes | Yes | Composite primary key. FK → `settings.setting_name`. |
| `setting_type` | character | — | Yes | Yes | Denormalised copy of `settings.setting_type` for query convenience. Must be consistent with the settings table. |
| `has_other_visits` | logical | — | No | No | `TRUE` if the case visited this setting on dates that fall outside all epi windows. Specific dates for those visits are not recorded in `visit_dates`. Typically `TRUE` for household residents who are continuously present. |

---

## visit_dates

One row per epidemiologically relevant visit date for a given case × setting pair. Child table of `case_settings`.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `case_id` | character | PK + FK | Yes | Yes | Composite primary key. FK → `case_settings.case_id`. |
| `setting_name` | character | PK + FK | Yes | Yes | Composite primary key. FK → `case_settings.setting_name`. |
| `visit_date` | date | PK | Yes | Yes | Date of a visit that falls within or near the epi windows. One row per calendar day — a case visits a setting at most once per calendar day. Format: YYYY-MM-DD. |

### Derived field: `epi_category`

Not stored. Computed at runtime for each `visit_date` by comparing against `onset_date` using current parameter values. Recalculates automatically when parameters are changed — no data migration needed.

| Category | Condition | Epidemiological meaning |
|---|---|---|
| `Exposure window` | `onset − inc_max ≤ visit_date ≤ onset − inc_min` | Case may have been infected at this setting on this date |
| `Infectious period` | `onset − inf_before ≤ visit_date ≤ onset + inf_after` | Case may have infected others at this setting on this date |
| `Both` | Case has at least one date in the exposure window AND at least one date in the infectious period at this setting | Setting is relevant in both directions (e.g. household resident present across both windows) |
| `Neither` | Date falls outside all windows | Visit is recorded but not considered transmission-relevant |

**Edge aggregation rule:** Where a case × setting pair has multiple visit dates, the network edge takes the highest-priority category across all dates: Both > Infectious > Exposure > Neither.

**Default parameter values (measles):**

| Parameter | Default | Meaning |
|---|---|---|
| `inc_min` | 7 days | Minimum incubation period (exposure to onset) |
| `inc_max` | 21 days | Maximum incubation period (exposure to onset) |
| `inf_before` | 4 days | Days before onset during which the case is infectious |
| `inf_after` | 4 days | Days after onset during which the case is infectious |

With default measles parameters the exposure window and infectious period do not overlap (inc_min > inf_before), so `Both` can only arise from a case-setting pair that has dates spanning both windows across separate visits — typically a household where the resident was present before and during illness.

---

## contacts

One row per recorded transmission link. Optional sheet — if absent, suspected links may be derived from shared settings and timing.

| Field | Type | Key | Indexed | Required | Description |
|---|---|---|---|---|---|
| `from` | character | FK | Yes | Yes | Source case. FK → `cases.case_id`. |
| `to` | character | FK | Yes | Yes | Recipient case. FK → `cases.case_id`. |
| `link_type` | character | — | No | Yes | Strength of evidence: `Confirmed` (epidemiologically established) or `Suspected` (plausible based on timing and shared setting). |

---

## Validation rules

- `case_id` must be unique in `cases`
- `onset_date` must be a valid date
- `setting_name` must be unique in `settings`
- All `case_id` values in `case_settings` must exist in `cases`
- All `setting_name` values in `case_settings` must exist in `settings`
- All (`case_id`, `setting_name`) pairs in `visit_dates` must exist in `case_settings`
- `from` and `to` in `contacts` must both exist in `cases`
- `inc_min` < `inc_max` (enforced in the app parameters panel)
