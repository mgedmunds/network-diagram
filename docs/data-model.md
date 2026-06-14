# Data Model — Working Notes

Phase 1 working document. Tracks decisions about what data the tool needs.

---

## Current schema

### linelist (one row per case)

| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | character | yes | unique identifier |
| `onset_date` | date | yes | drives time slider, epi curve, infectious-period logic |
| `age_group` | character | no | e.g. "0-4", "5-11", "12-17", "18+" |
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

- [ ] Should `age_group` use fixed bands or free text?
- [ ] Should `setting_type` be a fixed controlled list or free text?
- [ ] Do we need a `setting_id` separate from `setting_name` (e.g. if two settings share a name)?
- [ ] Should `visit_date` be required or remain optional?
- [ ] Is `vaccination_status` measles-specific or should it be generic?
- [ ] Do we need a `case_status` field (confirmed / probable / suspected case)?

## Decisions made

_Record decisions here as they are made, then move to a formal ADR if significant._

---

## Validation rules

_To be defined in Phase 1._

- `onset_date` must be a valid date
- `case_id` must be unique in linelist
- All `case_id` values in visits must exist in linelist
- `inc_min` must be less than `inc_max` (enforced in app parameters)

---

## Notes

