# Phase 3a Data Entry Shiny App — Decision Summary

**Date:** 2026-06-18  
**Status:** Decision locked; design complete; ready for implementation  
**Timeline:** 5 weeks (5 × 1-week phases)

---

## The Decision

**SQLite + Bespoke Shiny Interface (Local Deployment + SharePoint Data Storage)**

You asked: *Can we build a Shiny app that lets non-technical data managers add fields mid-outbreak without coding?*

**Answer:** Yes. And it will be the best fit for your outbreak model.

---

## Why This Approach

### Critical Requirements Met ✓

| Requirement | How Shiny Solves It |
|---|---|
| **Concurrent 3–4 user entry from multiple sites** | SQLite file locking + stateless Shiny frontend. No special infrastructure needed. SharePoint handles cloud storage. |
| **Many-many relationships** (cases ↔ contexts, cases ↔ cases) | Normalized SQLite schema with foreign key enforcement. No manual workarounds. |
| **Bulk date entry** | One-click "all dates", "weekdays only", "weekends only". Auto-filtered to epi window based on onset_date. Major efficiency win. |
| **Date filtering to epi window** | Onset_date + parameters auto-compute exposure & infectious periods. Date picker restricted to relevant range. |
| **Editable context list + validation** | Dropdown from contexts table; inline "add new" form. New context immediately available. |
| **Non-technical field addition mid-outbreak** | Metadata-driven UI. Data manager adds field via form (name, type, options). No code changes. Field appears in data entry form + main analysis app automatically. |
| **Local + SharePoint (no data leaves SharePoint)** | App runs on user's machine; SQLite file stored in SharePoint folder. Data governance maintained. No third-party cloud services. |
| **Reusable across organisms** | Parametric design + runtime schema extension. Same app, different outbreaks. |

### Why Not Excel or Access?

| Problem | Excel | Access | SQLite+Shiny |
|---|---|---|---|
| Concurrent edit conflicts | High risk (paste bypass) | Medium | None (enforced FK) |
| Bulk date population | Manual row-by-row | Manual row-by-row | One-click ✓ |
| Editable validation categories | Formula-based, fragile | UI-based, better | UI-based + metadata ✓ |
| Mid-outbreak schema changes | Requires developer | Limited (form changes) | Self-service UI ✓ |
| Infrastructure needed | None | None | None ✓ |
| IT approval | Not needed | May be needed | Not needed ✓ |

---

## Architecture Highlights

### Database
- **4 core tables:** cases, contexts, case_contexts, visit_dates (+ optional contacts)
- **2 metadata tables:** field_definitions (stores custom field specs), field_audit_log (tracks lifecycle)
- **Local SQLite file** stored in SharePoint folder
- **Concurrent access:** File locking handles 3–4 simultaneous users; last-write-wins for conflicts (acceptable for outbreak timescale)

### UI: Dual-View Entry

#### Form View
- Clean, one case at a time
- Enforced validation per field
- Context dropdown with inline "add new"
- Bulk date populate buttons (all dates / weekdays / weekends)
- Linear workflow, training-friendly

#### Spreadsheet View
- All cases in editable table
- Familiar Excel-like interface
- Inline cell editing with validation
- Good for bulk corrections & data review
- Both views sync to same SQLite

### Runtime Field Extension (Data Manager Role)

```
Data manager → Admin tab → "Add Field" form
├─ Field name: "Occupation"
├─ Data type: categorical
├─ Options: "Healthcare worker, Food handler, Teacher, Other"
└─ Display order: [6]

↓ Save

✓ SQLite ALTER TABLE cases ADD COLUMN occupation TEXT
✓ field_definitions table stores validation rule
✓ "Occupation" field appears in data entry form (both views)
✓ Main analysis app auto-discovers field; adds to data table
```

No developer involvement. Data manager self-service. Field appears instantly.

---

## Design Decisions (Locked)

| Decision | Choice | Rationale |
|---|---|---|
| **Field extension scope** | Cases table only (Phase 1) | Start simple; contexts & case_contexts can extend in Phase 2 |
| **Categorical options input** | Comma-separated text | Simpler UI than option picker; users type "Option1, Option2, Option3" |
| **Field creation UX** | Auto-appear on create | No approval step; faster iteration mid-outbreak |
| **Field removal** | Soft-delete (hidden, not removed) | Data preserved; audit trail; rollback possible via Restore button |
| **Concurrent field creation** | Error + retry | If two users try to create same field, second gets error; must try again with different name |
| **Multi-user conflicts** | Last-write-wins | For 3–4 users in 2–4 week outbreak: acceptable. Upgrade to optimistic locking if needed later. |
| **Display order** | Integer + sort UI (△▽) | Simple reordering; drag-drop can come in Phase 2 UX polish |

---

## Implementation Roadmap

### 5 weeks, 5 × 1-week phases

| Phase | Deliverable | Key Features |
|---|---|---|
| **M1 (Week 1)** | Core entry forms | Cases, contexts, case_contexts forms; visit_dates form; basic validation (types, required fields) |
| **M2 (Week 2)** | Many-many relationships | Context dropdown (FK enforced); add new context form; visit_dates bulk populate buttons |
| **M3 (Week 3)** | Dynamic UI + epi window | Onset_date + parameter-driven window calculation; date picker restricted to relevant dates; bulk populate (all/weekdays/weekends) |
| **M4 (Week 4)** | Validation + metadata schema | Client-side validation (JS, real-time feedback); server-side validation (R, on Save); field_definitions table + Admin UI for adding fields |
| **M5 (Week 5)** | Deployment + QA | Multi-user concurrency testing (3–4 users simultaneous); conflict handling; user guide; data manager guide; rollback procedures |

**Total: 35 developer days; 5 weeks elapsed.**

---

## Deployment

### Local Machine + SharePoint

```
User's Windows machine
├─ R + RStudio (pre-installed)
├─ Shiny app (R script; checked into GitHub)
└─ OneDrive / SharePoint folder
   └─ outbreak-data.db (SQLite file; synced)
```

**To run:**
1. `git clone` repo to local machine
2. `source('app.R')` in RStudio; click "Run App"
3. Shiny app loads in browser at `localhost:8085`
4. SQLite file accessed at `C:\Users\[user]\OneDrive\[site-name]\outbreak-data.db`

**Multi-user sync:**
- Each user runs app on their own machine
- All connect to same SQLite file (via OneDrive sync)
- App polls for changes; refreshes if data updated by another user

**No IT infrastructure needed.** No Posit Connect, no central server, no admin approval.

---

## Governance & Risk

| Aspect | Mitigation |
|---|---|
| **Data leaving SharePoint** | Never. SQLite file lives in SharePoint folder; app runs locally. |
| **Concurrent edit conflicts** | SQLite file locking + last-write-wins. Acceptable for outbreak. Upgrade to Postgres if needed later. |
| **User creates bad field definition** | Preview of parsed options before Save; help text; rollback (soft-delete). |
| **SQLite file locked during sync** | Automatic retry with backoff. Banner: "Database locked; retrying..." |
| **Field accidentally hidden mid-outbreak** | Soft-delete means data preserved. Restore button in Admin tab (audit log shows who hid it & when). |
| **Main app can't find custom field** | Main app reads metadata table on startup. Auto-discovers all active fields. No code changes. |

---

## Success Criteria

| Criterion | Target |
|---|---|
| **Non-technical user can add field** | Data manager creates field in <2 min via UI (no R/SQL knowledge needed) |
| **Bulk date entry speed** | 20 visit dates per case-context added in 1 click |
| **Form ↔ Spreadsheet sync** | Changes visible in other view within 10 seconds |
| **Concurrent edits** | 3–4 simultaneous edits; no data loss; conflicts merge gracefully |
| **Validation** | 100% of export data meets constraints (FK integrity, data types, format) |
| **Outbreak adaptability** | New fields added mid-outbreak; main app auto-discovers; no code deploy |

---

## Assumptions & Constraints

| Item | Assumption | Implication |
|---|---|---|
| **Concurrent users** | Max 3–4 simultaneous | If >5, recommend Postgres backend (post-MVP) |
| **Data volume** | 50–200 cases, 10–30 contexts | SQLite sufficient; if >500 cases consider upgrade |
| **Data manager skill** | Intermediate data skills (comfortable with Excel, basic SQL concepts) | Training needed; provide field manager guide |
| **Network connectivity** | Reliable during outbreak | No offline-first mode (Phase 1). Can add sync-on-reconnect later. |
| **Outbreak duration** | 2–4 weeks peak data entry | File locking + last-write-wins acceptable for this timescale |
| **Reusability** | Schema similar across outbreaks (cases, contexts, transmission) | If schema varies wildly, metadata approach needs more abstraction |

---

## Next Steps

### Before Starting Implementation

1. **Confirm go-ahead** — Does this design meet your needs? Any changes to locked decisions?
2. **Prioritisation** — Should Phase 3a start immediately, or after Phase 4 (Definitions)?
3. **Interim data collection** — For this outbreak: continue using Excel template, or wait for Shiny app?
4. **Resource** — Confirm Claude Code availability for 5-week sprint?

### Phase 3a.1 Kick-Off

Once confirmed:
1. Set up development branch (`feature/data-entry-shiny`)
2. Create initial Shiny structure (tabs, basic UI)
3. Build cases entry form (Form + Spreadsheet views)
4. Integrate with local SQLite
5. Deploy locally on user's machine; test with demo data

---

## Key Contacts & Docs

| Item | Location |
|---|---|
| **Options appraisal** | [data-entry-options-appraisal.md](data-entry-options-appraisal.md) |
| **Full architecture & design** | [data-entry-shiny-design.md](data-entry-shiny-design.md) |
| **Schema definitions** | [data-model.md](data-model.md) |
| **Phase tracking** | [STATUS.md](STATUS.md) |
| **Requirements questionnaire** | [data-input.md](data-input.md) (closed; decision locked) |

---

## Questions?

See [data-entry-shiny-design.md](data-entry-shiny-design.md) for:
- Detailed database schema (field_definitions, field_audit_log)
- UI wireframes (form view, spreadsheet view, Admin panel)
- Validation architecture (client + server)
- Concurrency & conflict handling
- Main app integration (auto-discovery of custom fields)
- Known risks & mitigations

