# Phase 3a — Enhanced Design Decisions (Turn 2)

**Date:** 2026-06-18 (Session continued)  
**Status:** Critical architectural clarifications; scope & timing adjusted

---

## Major Scope Correction: Shiny is the PRIMARY Outbreak Linelist

**Previous understanding:** Shiny app is for network-specific data entry only (case-context-visit relationships). Manual data entry + limited fields.

**NEW understanding:** Shiny app IS the primary outbreak linelist management tool. It stores ALL outbreak data (demographics, testing, outcomes, contexts, visits, transmission).

**Impact:** Phase 1 scope significantly larger than initially estimated. Requires 2-phase approach within Phase 3a.

---

## Phase 1 (Weeks 1–3): MVP — Essential Fields + Nested Workflow

### Fields in Phase 1 (CONFIRMED 2026-06-18)

**Cases table (10 core fields):**
- case_id (auto C-001, C-002...)
- CIMS_id (manually entered, alphanumeric, no length/format restrictions)
- forename (text, required)
- surname (text, required)
- date_of_birth (date, required)
- age (auto-calculated from DOB + onset_date at save; read-only display)
- gender (dropdown, optional)
- postcode (text, optional; UK format validation)
- case_confidence (dropdown: Confirmed, Probable, Possible; required)
- date_of_onset (date, required)
- vaccination_status (dropdown: Unvaccinated, 1 dose, 2 doses, Unknown; optional)

**System fields (auto-managed, not user-editable):**
- created_by, created_at, updated_by, updated_at (audit trail)
- is_deleted (soft-delete flag)

**Contexts table:**
- context_id, context_name, context_type
- (no custom fields; locked structure)

**case_contexts table:**
- case_id, context_id (composite PK)

**visit_dates table:**
- case_id, context_id, visit_date

**contacts table:**
- from, to, link_type (Probable/Possible)

### Workflow (Nested Form Structure)

```
Home / Cases tab
├─ List of cases (spreadsheet view with search/filter)
├─ [Create New Case] button
│
When viewing/editing a case:
├─ Case form (demographics, health info)
├─ [Save Case]
│
├─ Below case form: "Contexts for this case"
│  ├─ List of contexts already linked to this case
│  ├─ [Add contexts] → checklist of all contexts
│  │   (user multi-select contexts)
│  └─ For each selected context: prompt for visit_dates
│      ├─ [All dates] [Weekdays] [Weekends] [Custom range]
│      └─ [Save visit dates]
│
└─ [Transmission links] section
   ├─ Link this case to other cases
   └─ [From this case] [To this case] [Link type dropdown]
```

**Key features:**
- No flat tabs (cases → contexts → case_contexts); instead nested forms
- Natural logical flow: enter case, add contexts for that case, add dates for each context
- Checklist for multi-context selection (efficient bulk-add)
- Prevents data entry in illogical sequence (e.g., can't add visit dates before case exists)

### Data Entry (Manual Only, No Import in Phase 1)

- All cases entered manually in Shiny app (not imported from external linelist)
- Staff type case_id, CIMS_id, forename, surname, DOB, etc.
- No import function in Phase 1 (can add in Phase 3b if needed)

### Validation (Phase 1)

- **Duplicate check:** case_id and CIMS_id must be unique; BLOCK save if duplicate detected (error message)
- **DOB:** must be before onset_date
- **Postcode:** UK format validation (optional field, but if filled, validate)
- **case_confidence:** required dropdown (not free text)
- **age:** auto-calculated at save from DOB + onset_date; displayed but not editable

### UI & UX (Phase 1)

- **Form view:** One case at a time (current design)
- **Spreadsheet view:** All cases in virtual-scrolling table (not paginated)
- **Search/filter:** Filter by case_id, CIMS_id, case_confidence, date_range
- **Column customization:** Admin sets display_order in field_definitions; users can override per session (not saved)
- **Comments field:** Free text for staff to add notes (e.g., "Awaiting contact details", "Lab result pending")

### Data Visibility

- **Real-time:** When Alice enters a case, Bob sees it immediately on refresh (both apps read same SQLite via SharePoint sync)
- **Concurrency:** 3–4 simultaneous users; SQLite file locking handles write conflicts

### Export (Phase 1)

- Single download button: exports full SQLite file (all cases, contexts, visits, transmission) as .sqlite for backup
- Also exports as .xlsx (five sheets) for ad-hoc review/sharing

### Backup & Persistence

- **Backup:** SharePoint handles all versioning & snapshots (daily + weekly retention); app does NOT manage backups
- **Recovery:** Soft-deleted cases recoverable via Admin panel; users see "Restore" button on deleted records

### Roles & Access Control (Phase 1)

| Role | Permissions |
|---|---|
| **Data Entry Staff** | Create/edit cases, contexts, visits; cannot delete; cannot add custom fields |
| **Data Manager** | All of above + delete/restore cases, add/delete custom fields, manage field definitions |
| **Viewer** (optional) | Read-only access to all data; cannot edit |

Identified via Windows domain login (auto-detected email).

### Estimated Phase 1 Effort

| Milestone | Effort | Deliverable |
|---|---|---|
| **M1: Nested case form + spreadsheet view** | 2w | Cases entry with form + spreadsheet; demographic fields; soft-delete; role-based access |
| **M2: Contexts + case-contexts + visit-dates** | 1w | Context management; multi-select checklist; bulk date populate |
| **M3: Transmission links + validation** | 1w | Contacts table entry; duplicate detection; DOB/postcode validation; comments field |
| **M4: Search/filter + derived fields** | 1w | Filter by status, date range, search; age auto-calc; Admin field manager UI |
| **M5: Testing + deployment** | 1w | Local testing (3–4 concurrent users); documentation; data manager guide |
| **Total** | **6 weeks** | MVP complete; ready for first outbreak |

---

## Phase 2 (Later, ~2–3 weeks): Extended Fields + Reporting

**Deferred to Phase 3b:**
- date_of_rash (optional secondary timeline)
- comments (free-text staff notes / flags)
- ethnicity, utla, confirmation_test_type, date_reported
- travel_history (yes/no + destination field)
- vaccination_status_confirmation_method, vaccination_notes
- number_of_vulnerable_contacts, total_contacts
- primary_context, primary_context_type (derived from contexts)
- epi_link_identified, ofk_status
- Advanced reporting (filtered exports, custom reports)
- Fuzzy duplicate detection (name matching)
- Offline mode + sync-on-reconnect
- Inter-field constraints (e.g., date_confirmed must be >= onset_date)

---

## Architecture Changes

### Two Separate Apps (Not One)

**Data Entry App:** (`data-entry-app.R`)
- Manages all outbreak linelist data (cases, contexts, visits, transmission)
- Nested workflow; all entry forms
- Roles: Data Entry Staff, Data Manager, Viewer
- Local deployment on user's machine; SQLite in SharePoint folder

**Network Analysis App:** (`network-analysis-app.R`, existing)
- Reads same SQLite file (direct connection via SharePoint folder)
- Displays network diagrams, epi curves, transmission links
- No editing; read-only
- Stays as currently deployed (Shinylive + GitHub Pages)

**Both apps share:**
- Same SQLite file (outbreak-data.db in SharePoint)
- Same schema (cases, contexts, case_contexts, visit_dates, contacts + metadata tables)
- Real-time sync (changes in data entry app immediately visible in network app)

---

## Clarifications on Open Questions (From Q&A)

| Question | Answer |
|---|---|
| **Phase 1 field priority (CONFIRMED 2026-06-18)** | 10 core case fields (case_id, CIMS_id, forename, surname, DOB, gender, postcode, case_confidence, onset_date, vax_status) + all 3 related tables (case_contexts, visit_dates, contacts); date_of_rash & comments → Phase 2 |
| **CIMS_id format** | Manually entered, alphanumeric, no format/length restrictions |
| **Data entry source** | Manual entry only (no import from external linelist in Phase 1) |
| **Nested vs flat forms** | Nested preferred (case → contexts → dates logical flow) |
| **Multi-context entry** | Checklist (select multiple contexts at once, then add dates for each) |
| **Duplicate detection** | BLOCK save on duplicate case_id or CIMS_id (strict enforcement) |
| **Derived fields** | age calculated from DOB + onset_date at save time |
| **Search/filter** | Yes, spreadsheet view includes filters and search |
| **Export** | Single download (SQLite + .xlsx); no complex filtered reports in Phase 1 |
| **Backup** | SharePoint handles all versioning; app does not manage backups |
| **Scale** | Up to 500 cases; spreadsheet uses virtual scroll (not pagination) |
| **Real-time visibility** | Yes, changes immediately visible on refresh across all users |
| **Performance** | <2 seconds for spreadsheet load/filter at 500 cases |

---

## Schema Changes (Phase 1)

No comments column in Phase 1. Schema includes:

Used for staff notes (flags, action items, etc.).

---

## Risk Register (Updated)

| Risk | Mitigation |
|---|---|
| **Phase 1 scope expanded (6w vs 5w)** | Accept 6-week timeline for MVP; Phase 2 fields deferred |
| **No import function may slow setup** | Acceptable; manual entry is straightforward for <500 cases |
| **Nested forms more complex than flat** | Worth the UX benefit (natural workflow); test with users early |
| **SQLite at 500 cases** | Virtual scrolling + indexing on frequently-filtered columns |
| **Real-time sync over SharePoint** | May see 1–2 sec delay if network slow; acceptable for outbreak timescale |

---

## Visit_Relevance Workflow (Session Clarification)

**Storage Location:** visit_relevance is stored in case_contexts table (one value per case-context pair, not per individual visit_date).

**Manual Selection:** Staff manually select visit_relevance when linking a case to a context. Not auto-derived from epi parameters.

**Workflow Timing (Preferred, Not Enforced):**
1. Staff adds case (demographics, health info)
2. Staff adds context to case (from existing context list)
3. Staff adds visit_dates for that case-context pair (using bulk populate buttons)
4. Staff selects visit_relevance for that case-context pair (after seeing the dates they entered)

**Rationale:** Seeing the actual visit_dates first allows staff to make an informed manual judgment about relevance category.

**Reference Info:** When staff select visit_relevance, the app displays epi window parameters (e.g., "Exposure: June 1–10 | Infectious: June 11–18") to guide their choice.

**Values:** One of four categories:
- Exposure window
- Infectious period
- Both
- Neither

**Editability:** visit_relevance can be changed after initial entry (no lock).

**Implementation Location:** M2–M3 (visit_dates + case_contexts section of nested form).

---

## Next Steps

1. **Confirm Phase 1 scope:** Are these 11 fields in the right priority? Any must-haves to add?
2. **Nested form wireframe:** Should we create a detailed wireframe of the nested entry form before M1 starts?
3. **GitHub branch:** Create feature/data-entry-app branch and set up initial structure?
4. **Schedule:** 6 weeks starting when?

