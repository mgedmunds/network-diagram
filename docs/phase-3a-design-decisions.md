# Phase 3a — Pre-Build Design Decisions

**Date:** 2026-06-18  
**Status:** Design decisions locked; ready for implementation

---

## Scope Decisions

| Decision | Answer | Implication |
|---|---|---|
| **Phases** | Together: Phase 3a + Phase 4 in parallel | Start both Monday; schedule check-ins at end of each week |
| **Interim data collection** | No Excel template needed | Users wait for Shiny app; no interim workaround |

---

## Access & Permissions

| Decision | Answer |
|---|---|
| **Field management** | Any data manager can create and delete fields (multiple people, full permissions) |
| **Role definition** | Windows domain login auto-detected; updated_by field stores user (e.g., Alice@health.nhs.uk) |

---

## Data Lifecycle

| Decision | Answer | Implication |
|---|---|---|
| **Between outbreaks** | Archive data: keep field_definitions, clear cases/contexts/case_contexts/visit_dates tables | At end of outbreak: backup SQLite file. Start new outbreak: reset data tables, reuse field schemas |
| **Audit logging** | Field lifecycle only (create/modify/delete fields); no routine data edit logging | Tracks who added/removed fields and when; less performance overhead |

---

## Integration & Data Flow

| Decision | Answer |
|---|---|
| **Main app integration** | Direct read: both apps read the same SQLite file (no export needed; always fresh) |
| **Unique ID validation** | case_id: unique (error on duplicate); CIMS_id: unique (error on duplicate) — both core fields, locked |
| **Import from linelist** | Upload function: specific tables/table columns from main dataset; import targets cases & contexts |
| **Protected vs extensible** | cases: core fields locked, custom fields allowed; contexts: locked completely (core fields + type values only) |

---

## Table Schema Changes (Locked)

### Cases Table (Core Fields)

| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | text | yes | Format: C-nnn; auto-generated; unique |
| **`cims_id`** | **text** | **yes** | **NEW: CIMS identifier; must be unique; locked** |
| `onset_date` | date | yes | Drives epi window calculations |
| `age_group` | text | no | Dropdown: 0–4, 5–12, 13–44, 45–64, 65+ |
| `vaccination_status` | text | no | Dropdown: Unvaccinated, 1 dose, 2 doses, Unknown |
| `case_status` | text | no | Dropdown: Confirmed, Probable, Possible |
| `created_at` | datetime | auto | System-generated |
| `created_by` | text | auto | Windows login (auto-detected) |
| `updated_at` | datetime | auto | Updates on every change |
| `updated_by` | text | auto | Windows login on every change |
| `is_deleted` | boolean | auto | 0 = active; 1 = soft-deleted (recoverable) |
| **[Custom fields added via Admin UI]** | **[type varies]** | **[per field]** | **Comma-separated options for categorical** |

### Contexts Table (Locked)

No custom fields allowed. Structure fixed:
- `context_id` (int, PK)
- `context_name` (text, unique)
- `context_type` (text; can extend values)

### New Column: Soft-Delete

Both cases and contexts (and implicitly case_contexts/visit_dates via FK) support soft-delete:
```sql
ALTER TABLE cases ADD COLUMN is_deleted BOOLEAN DEFAULT 0;
```

Soft-deleted records hidden from UI but recoverable via Admin panel.

---

## Validation Rules

| Decision | Answer |
|---|---|
| **Custom field validation** | Data type + options (for categorical) + required/optional flag; no inter-field constraints; simple date validation only |
| **Date fields** | Valid date format; no min/max constraints (Phase 1); can add constraints in Phase 2 |
| **Duplicate detection** | Error on duplicate case_id; Error on duplicate CIMS_id (prevents save) |

---

## User Experience

| Decision | Answer | Implication |
|---|---|---|
| **Column customization** | Hybrid: admin sets default order; users can hide/reorder per session (not saved) | Admin defines column order in field_definitions (display_order); spreadsheet view honors it but allows per-session override |
| **Data export** | Both: .xlsx export + SQLite file backup | Export button in app exports both formats |

---

## Implementation Priorities (Phase 3a Sequencing)

### M1: Core Entry Forms (Week 1)
- Cases form (Form + Spreadsheet views)
- Contexts form
- Import function: upload Excel/CSV from main linelist → populate cases/contexts tables
- Basic validation (types, required fields)
- **Add:** CIMS_id field to cases; unique constraint + error message

### M2: Many-Many Forms (Week 2)
- case_contexts entry with context dropdown
- visit_dates form with bulk populate

### M3: Dynamic UI (Week 3)
- Epi window calculation
- Bulk populate (all/weekdays/weekends)
- Admin UI for adding fields (type + options + required flag)

### M4: Validation + Soft-Delete (Week 4)
- Unique constraint checking (case_id, CIMS_id)
- Soft-delete implementation (is_deleted flag; hide from UI; Restore button in Admin)
- Error messages for violations

### M5: Deployment + QA (Week 5)
- Multi-user concurrency testing
- Data export (.xlsx + SQLite)
- User guide + data manager guide
- Archive procedure (end of outbreak)

---

## Open Questions (For Later Phases)

1. **CIMS_id auto-generation:** Should CIMS_id be auto-generated or entered manually? (Assume manual for now; refine after Phase 1.)
2. **Fuzzy matching for duplicates:** Should Phase 2 add fuzzy name/address matching to suggest likely duplicates? (Defer to Phase 3b.)
3. **Date constraints in custom fields:** Can data managers set "date must be after onset_date" constraints? (Defer to Phase 2.)
4. **Offline mode:** Should app work offline (local sync, upload on reconnect)? (Defer to Phase 3b.)
5. **Contexts import:** Should contexts be importable from the main linelist, or only created in the app? (Assume: both importable and creatable for now.)

---

## Risk Register (Updated)

| Risk | Mitigation | Owner |
|---|---|---|
| **CIMS_id format unknown** | Confirm format with team before build; default to text field (no auto-generation) | Matt |
| **Soft-delete recovery complexity** | Admin panel has Restore button; audit log tracks who soft-deleted what | Claude |
| **Column reordering per-session not saved** | Acceptable UX for Phase 1; save to user preferences in Phase 2 if needed | Claude |
| **Archive procedure unclear** | Document step-by-step at end of Phase 5 QA | Matt + Claude |

---

## Next Steps

1. **Confirm CIMS_id details:** Format, auto-generation rules, validation patterns
2. **Confirm linelist structure:** Which columns should the import function support?
3. **Confirm column display defaults:** What order should cases form show fields?
4. **Schedule:** Phase 3a.1 starts [DATE]; target completion [DATE]
5. **Resource:** Claude Code full-time, 5 weeks

