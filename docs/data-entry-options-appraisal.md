# Data Entry Options Appraisal

**Date:** 2026-06-18  
**Context:** Evaluating data entry methods for the network analysis tool (Phase 3, Stage 2)  
**Scope:** Comparing MS Excel (current), MS Access, and SQLite with bespoke Shiny interface

---

## Executive Summary

| Criterion | Excel | MS Access | SQLite + Shiny |
|---|---|---|---|
| **Concurrency** | Poor | Good | Excellent |
| **Many-many handling** | Manual workarounds | Native relationships | Normalised tables |
| **Bulk date entry** | Hard | Harder | Native |
| **Validation** | Limited | Good | Excellent |
| **Date filtering** | Manual | Manual | Automatic |
| **Context lookup + add new** | Formula-based | Native dropdown + append | Interactive form |
| **Multi-site readiness** | Low (silent paste errors) | Medium | High |
| **Setup speed** | Hours | Days | Weeks |
| **Ongoing maintenance** | Low (template-based) | Medium (schema drift) | High (developer-dependent) |
| **Reusability across outbreaks** | High (template versioning) | Medium (schema updates) | High (parametric design) |
| **Requires IT admin for deployment** | No (OneDrive) | Yes | No (Shiny Lite on GitHub Pages) |
| **Cost** | Free | Free | Free |
| **Learning curve** | Low | Medium | Low |

---

## Detailed Analysis

### Option 1: Microsoft Excel (Current Approach)

**Status:** Currently implemented. Five sheets (cases, contexts, case_contexts, visit_dates, contacts) with validation rules, named tables, and FK dropdowns.

#### Strengths
- **Fastest to deploy:** Template ready in hours; staff already familiar
- **No infrastructure:** Works offline; lives on OneDrive with SharePoint-approved governance
- **Easy schema evolution:** Add a column, update template; no database schema migration
- **Simple maintenance:** Non-technical staff can manage lookup tables and fix data errors
- **Familiar to NHS:** Excel is the default tool across most field teams

#### Critical Limitations

**Concurrency and data integrity:**
- No row-level locking; concurrent edits cause merge conflicts
- Paste-paste-paste bypasses validation (dropdowns); FK integrity not enforced on paste
- Risk: Team member pastes a case_id that doesn't exist in the cases sheet; app crashes or rows silently fail to join
- 1–3 concurrent users is manageable *if* they don't work on overlapping rows

**Many-many relationships:**
- Must manually create case_contexts rows for each case × context pair
- No cascade delete or referential integrity; orphaned rows accumulate
- No way to prevent a staff member accidentally linking a case to a non-existent context (except manual check)

**Bulk date entry (critical blocker):**
- No native batch operation
- Staff must manually type or copy-paste dates for each row
- For a case visiting 5 contexts with (say) 20 relevant dates each = 100 rows, each needing a date = tedious and error-prone
- Workarounds possible (VB macro, but risks IT approval) but fragile

**Date filtering around epidemiologically relevant period:**
- Dates column is free text; no conditional list of "dates to choose from"
- Staff must type or look up which dates are relevant; high error rate
- No mechanism to auto-populate "all weekdays" or "all dates" range

**Validation:**
- Data type validation works (date column rejects letters)
- But FK dropdowns are bypassable via paste; no hard constraint
- UID format (C-nnn) can be auto-numbered in template, but no check for duplicates if staff manually override

#### Verdict
**Good for Stage 1 (basic single-outbreak entry), poor for ongoing scale.**  
Best used as an **import format** for a cleaner system, not as the primary entry interface.

---

### Option 2: Microsoft Access

**Status:** Not currently in use; would require setup.

#### Strengths
- **Native relational model:** Relationships enforced in schema; cascade delete / referential integrity options
- **FK dropdowns:** Context dropdown enforces only valid context_ids; easy to add new contexts
- **Better concurrency than Excel:** Record-level locking; supports split FE/BE (backend on network share, frontend on user machines)
- **Familiar interface:** Similar to Excel but with forms and reports
- **NHS-friendly:** No special governance issues

#### Limitations

**Bulk date entry:**
- Repeating groups harder than in Excel; same manual row-by-row burden
- No native batch operation for "populate all weekday dates from date X to Y"

**Date filtering to epidemiologically relevant period:**
- Must be implemented via queries or VBA; not trivial
- No built-in parametric filtering based on onset_date

**Many-many relationships:**
- Native support through junction tables; better than Excel
- But still requires manual creation of junction table rows

**Complexity:**
- Requires a form design (even basic) to be non-expert-friendly
- IT approval may be needed for deployment (depends on trust)
- If forms are buggy or schema changes, non-technical staff cannot fix it

**Maintenance burden:**
- Schema changes (e.g. new field in cases) require form redesign
- If developer leaves, maintenance falls to whoever understands Access
- Risk of schema/form drift

**Deployment:**
- Must be installed on each workstation (or use Access Runtime)
- Licensing: Office 365 includes Access on Windows only; not on Mac or web
- Multi-site teams need BE on shared network or split FE/BE architecture (complex setup)

#### Verdict
**Incremental improvement over Excel for concurrent entry, but date manipulation remains awkward.  
Best suited if team already skilled in Access and forms; requires ongoing developer support.**

---

### Option 3: SQLite + Bespoke Shiny Interface (Recommended)

**Status:** Proposed. Would be built as a companion app in the same Shiny Lite deployment.

#### Strengths

**Relational integrity:**
- Four-table schema with enforced foreign keys
- Case exists before case_contexts rows can be added
- Context_id enforced as valid before case_contexts row created
- Orphaned rows impossible by design

**Date entry efficiency:**
- **Bulk populate button:** "Add all dates in range", "Weekdays only", "Weekends only"
- Date picker filtered to epidemiologically relevant window (computed from onset_date ± parameters)
- One click: all weekday dates from onset−21 to onset+7 added for that case × context
- Staff enter maybe 5–10 rows per case instead of 100+

**Context management:**
- Dropdown list of valid contexts
- Quick "add new context" form inline (context_name, context_type)
- No need to jump to another sheet or file
- New context immediately available in the dropdown

**Validation:**
- UID format enforced (C-nnn pattern)
- Duplicate UID check: app warns before save
- Date column: only dates accepted
- Integer fields: only integers accepted
- Automatic dedupe: if staff accidentally submit case_id=C-001 twice for same context, second is silently skipped

**Multi-site concurrency:**
- SQLite on backend (single file shared via OneDrive or GitHub)
- Shiny Lite app is stateless; each user loads their own copy in browser
- Simple conflict handling: last-write-wins (for single outbreak, acceptable; if audit trail needed, upgrade to Postgres later)

**Reusability:**
- Template approach: parameterise onset_date, inc_min/max, inf_before/after
- Same app used across different outbreaks by loading different datasets
- Easy schema evolution: add a column, validate in Shiny, append to SQLite

**Deployment:**
- Runs in browser (Shiny Lite); no installation required
- GitHub Pages deployment; accessible from any device with browser
- Offline capable: download SQLite, work offline, sync later
- No IT admin needed (Shiny Lite is a static file; GitHub Pages is free)

**IT Governance:**
- No patient-identifiable data in browser (PII filtered out before upload)
- SQLite file can be encrypted or protected on OneDrive
- Audit trail can be added later if needed (append-only log table)

#### Implementation Details

**Architecture:**
```
Data entry Shiny app (companion to main app)
├── Left panel: forms (cases, contexts, case_contexts, visit_dates)
├── Middle panel: table preview (live)
└── Right panel: validation checks + export

Data flow:
1. User loads app, selects dataset (Excel or SQLite)
2. Data entry staff fill cases sheet first (case_id, onset_date, ...)
3. Then contexts sheet (context_name, context_type)
4. Then case_contexts (select case, select context, save)
5. Then visit_dates (select case × context, set date range, click "weekdays", auto-populate)
6. Validation checks run live; errors show inline
7. Export as .xlsx (five sheets) for upload to main app
```

**Key Features:**

| Feature | How it works |
|---|---|
| **Bulk date entry** | Onset date + parameters auto-compute exposure/infectious window. Staff click "All dates in range" or "Weekdays only"; all rows created at once. |
| **Context dropdown + add** | Dropdown list from contexts table. "New context" button opens inline form (name + type); saves to table; resets dropdown. |
| **UID validation** | Text input with regex check: `C-\d{3,}` or `Ctxt-\d{3,}`. Duplicate check on save. |
| **Date format** | Datepicker widget; only valid dates selectable. |
| **FK enforcement** | case_id dropdown populated from cases table; only valid case_ids selectable. Same for context_id. |
| **Conflict resolution** | If two users add the same case_id concurrently, both edits merge (last write wins). On export, deduped automatically. |
| **Export** | Download as .xlsx (five sheets); upload to main app. |

#### Limitations

**Setup time:**
- Estimated 2–3 weeks for full Shiny implementation (forms, validation, bulk operations, export)
- With Claude Code assistance, likely 3–5 days in short sprints

**Developer dependency:**
- Requires R/Shiny skills to maintain (bug fixes, schema changes)
- If developer unavailable during outbreak, fixes are slower than Excel workarounds

**Offline workflow:**
- Easier to deploy offline than Access, but SQLite file must be synced manually (or via GitHub)
- Excel template still works as fallback if Shiny app is down

**Learning curve for specific features:**
- Bulk date populate is new concept; staff need brief training
- Minimal, but worth noting

#### Verdict
**Best option for reusable, multi-site, concurrent entry with strong validation.  
Recommended for this team and outbreak model.**

---

## Hybrid Approach (Alternative)

**Combination:** Excel for cases & contexts entry (fast, familiar), Shiny for case_contexts & visit_dates (efficient bulk date entry, validation).

| Advantage | Disadvantage |
|---|---|
| Staff familiar with Excel for basic data | Two tools to manage; context list stays sync'd manually |
| Shiny entry form for complex relationships | Requires R/Shiny deployment |
| Reduced Shiny scope = faster build | Excel paste-paste still risks FK errors on basic tables |

**Verdict:** Not recommended. Marginal improvement in speed vs full Shiny; adds complexity.

---

## Comparison Matrix (Complete)

| Criterion | Excel | Access | SQLite + Shiny |
|---|---|---|---|
| **Concurrency (1–3 users, multi-site)** | 4/10 (risky) | 7/10 (ok) | 10/10 (native) |
| **Many-many handling** | 4/10 (manual) | 7/10 (native) | 10/10 (enforced) |
| **Bulk date entry** | 2/10 (tedious) | 3/10 (harder) | 10/10 (one click) |
| **Date filtering to epi window** | 2/10 (manual) | 2/10 (manual) | 10/10 (automatic) |
| **Context validation + add new** | 6/10 (dropdown) | 8/10 (native) | 10/10 (inline form) |
| **Setup speed** | 10/10 (hours) | 7/10 (days) | 5/10 (weeks) |
| **Ongoing maintenance** | 9/10 (low) | 6/10 (medium) | 7/10 (medium) |
| **Reusability** | 8/10 (template) | 6/10 (schema changes) | 9/10 (parametric) |
| **IT approvals** | 10/10 (none) | 8/10 (some) | 10/10 (none, Lite) |
| **Cost** | 0 | 0 | 0 |
| **Total** | **56/100** | **63/100** | **89/100** |

---

## Recommendation

### Primary: SQLite + Bespoke Shiny Interface
- Solves all critical date entry and validation problems
- Supports multi-site concurrent entry with low conflict risk
- Deploys to GitHub Pages (no IT infrastructure needed)
- Reusable across outbreaks with minimal template updates
- Implementation effort is justified by reusability and operational risk reduction

### Fallback: Excel (Current)
- Continue using Excel for this outbreak if Shiny is not ready
- Data entry staff aware of paste risks; manual spot-checks on FK integrity
- Once Shiny is ready, switch for next outbreak

### Not Recommended: MS Access
- Solves some problems (many-many, concurrency) but not the critical ones (date entry, filtering)
- Adds maintenance burden without proportional benefit
- Access Runtime licensing complexity for multi-site teams

---

## Implementation Roadmap (SQLite + Shiny)

### Phase 3a — Data Entry Shiny App (New)
**Est. effort: 10–15 developer days (3–4 weeks in 3-day sprints)**

| Milestone | Effort | Dependencies |
|---|---|---|
| **M1: Basic forms** (cases, contexts, read-only case_contexts/visit_dates) | 2–3d | Main app repo set up ✓ |
| **M2: Many-many forms** (case_contexts entry with context dropdown) | 2–3d | M1 complete |
| **M3: Visit dates bulk entry** (date range + populate options) | 3–4d | M2 complete |
| **M4: Validation layer** (UID format, duplicates, FK checks, inline errors) | 2–3d | M1–M3 complete |
| **M5: Export to .xlsx** (five sheets, named tables) | 1–2d | M4 complete |
| **M6: Deployment to Shiny Lite** (GitHub Pages alongside main app) | 1–2d | M5 complete |
| **M7: User guide + QA** | 1–2d | M6 complete |

**Approx. timeline:** 12–17 days of developer time; 4–5 weeks elapsed (3-day sprints).

### Phase 3b — Data Entry Guide (Stage 1)
**Est. effort: 1–2 days**

- Screencast: Excel template usage (cases & contexts entry)
- Written guide: Each sheet, validation rules, common errors
- Transition guide: How to hand off to Shiny app once built

### Phase 4 onward
- Main app features (Definitions, Assumptions, etc.) continue in parallel

---

## Key Assumptions

1. **Outbreak duration:** Assumed 2–4 week peak data entry period, then tail-off. SQLite handles this cycle well.
2. **Data volume:** Assumed 50–200 cases, 10–30 contexts. If >500 cases, may need Postgres (post-Shinylive).
3. **Team skill:** Data entry staff = basic Excel; data manager = intermediate data skills. Shiny UI designed for non-technical users.
4. **Concurrency:** Up to 3 simultaneous users entering data. If >5, upgrade conflict handling (optimistic locking, cloud database).
5. **Reusability:** Assumed future outbreaks share similar schema (cases, contexts, visits, transmission). If schema varies widely, template approach needs more abstraction.

---

## Next Steps

1. **Confirm approach:** Agree to SQLite + Shiny recommendation, or request detailed analysis of alternative?
2. **Prioritisation:** Should data entry app (M1–M7) start immediately, or after Phase 4 (Definitions)?
3. **Interim solution:** Continue using Excel template for this outbreak while Shiny is built?
4. **Resource:** Confirm Claude Code assistance available for Shiny build?

