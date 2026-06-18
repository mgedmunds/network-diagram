# Pre-Build Checklist: What We Decided & What to Confirm

**Phase 3a ready to start, but 3 design questions need clarification before M1 (Core Entry Forms) begins.**

---

## What We Locked Down (11 Design Decisions)

### ✓ Access & Permissions
- **Field management:** Any data manager can create/delete fields (not admin-only)
- **User identification:** Windows domain login auto-detected (e.g., alice@health.nhs.uk)

### ✓ Data Lifecycle
- **Between outbreaks:** Archive full SQLite file; clear data tables; reuse field schemas
- **Audit logging:** Track field creation/deletion only (not routine data edits)

### ✓ Integration & Data Flow
- **Main app read:** Direct SQLite read (no export step; always fresh)
- **Unique constraints:** case_id AND CIMS_id both must be unique (error if duplicate)
- **Import function:** Yes — upload specific columns from main linelist to cases & contexts tables
- **Protected tables:** cases = extensible (core + custom); contexts = locked (no custom fields)

### ✓ Validation & UI
- **Field validation:** Data type + options (categorical) + required flag (no inter-field constraints)
- **Column customization:** Hybrid (admin default + user session override)
- **Deletion recovery:** Soft-delete cases (recoverable via Admin; is_deleted flag)

---

## What We Still Need to Confirm (Before M1 Starts)

### ❓ Question 1: CIMS_id Format & Generation

**Why it matters:** CIMS_id is a new core field in the cases table. Need to know:
- Is it auto-generated (like case_id: C-001, C-002) or manually entered?
- What is the format/pattern? (e.g., "CIMS-" prefix? numeric? alphanumeric?)
- Any validation rules? (e.g., must match a pattern, must be <20 chars?)

**How to answer:**
1. Check your existing outbreak linelist for CIMS_id format examples
2. Confirm with your team how they currently record CIMS_id

**Impact on build:**
- If auto-generated: M1 needs a formula (like case_id) 
- If manual: M1 adds a text input field with validation rule
- Affects import function: must handle CIMS_id from main linelist

---

### ❓ Question 2: Main Linelist Structure (For Import Function)

**Why it matters:** M1 includes an "Import from main linelist" function. Need to know what columns are available.

**How to answer:**
1. Export a sample of your main linelist (10–20 rows, with headers)
2. Identify which columns should map to the data entry app:
   - **Cases table:** case_id, CIMS_id, onset_date, age_group, vaccination_status, case_status — which of these are in the linelist?
   - **Contexts table:** Are context_name / context_type already recorded in the linelist? (or entered fresh in the app?)
3. Are there any required fields in the linelist that don't map to the app? (e.g., patient name, GP, lab result) — these can be excluded

**Impact on build:**
- Import function maps linelist columns → app tables (only named columns imported)
- If CIMS_id is in the linelist, import must handle it
- If contexts are pre-recorded in linelist, import can populate them automatically

---

### ❓ Question 3: Archive Procedure (For Phase 5 QA)

**Why it matters:** When an outbreak ends, you need a clear procedure to:
1. Backup the complete SQLite file (for records/audit)
2. Clear the data tables for the next outbreak
3. Preserve field definitions (schema) for reuse

**How to answer:**
1. During Phase 5 QA testing, we'll document a step-by-step procedure
2. You'll test it with demo data to confirm it works

**Impact on build:**
- Not urgent for M1–M4, but will be documented and tested before release
- Users will get a data manager guide with clear instructions

---

## Document Tree (For Reference)

```
docs/
├─ phase-3a-decision-summary.md       ← Executive overview
├─ phase-3a-design-decisions.md       ← This session's 11 decisions
├─ data-entry-shiny-design.md         ← Full technical architecture
├─ data-entry-options-appraisal.md    ← Why Shiny beat Excel/Access
├─ data-input.md                      ← Closed: Phase 3 questionnaire
│
├─ STATUS.md                          ← Updated with Phase 3a status
├─ CLAUDE.md                          ← Project conventions
│
├─ data-model.md                      ← Phase 1 schema
├─ data-dictionary.md                 ← Field-level reference
├─ data-flow.md                       ← Main app reactive chains
│
└─ decisions/
   ├─ ADR-001, ADR-002, ADR-003, ADR-004  ← Past decisions (main app)
   └─ (future: ADR-005 for Phase 3a design)
```

---

## Go/No-Go Checklist (Before M1 Starts)

- [ ] **CIMS_id format confirmed** — auto-generated or manual? format/validation rules?
- [ ] **Main linelist structure provided** — sample data + column mapping
- [ ] **GitHub repo ready** — branch feature/data-entry-shiny created?
- [ ] **Calendar blocked** — Matt available for async clarifications; Claude available full-time 5 weeks?
- [ ] **R/RStudio environment ready** — all packages installed locally?
- [ ] **SharePoint folder identified** — where will outbreak-data.db live?

---

## What Happens Next

### Immediate (This Week)
1. Answer the 3 open questions (Q1, Q2 above)
2. Create GitHub branch feature/data-entry-shiny
3. Set up local R environment (packages: shiny, RSQLite, DT, others from requirements.R)

### Week 1 (M1: Core Entry Forms)
- Create Shiny app structure (tabs, basic UI)
- Build cases entry form (Form + Spreadsheet views)
- Implement import function (main linelist → cases table)
- Integrate with local SQLite
- Basic validation (types, required fields)
- Deploy locally; test with demo data

### Weeks 2–5
- See [phase-3a-design-decisions.md](phase-3a-design-decisions.md) milestones M2–M5

---

## Key Contacts & Notes

- **GitHub:** main repo / feature/data-entry-shiny branch
- **Design docs:** All in `/home/claude-dev/projects/network-diagram/docs/`
- **Slack/Teams:** [Set comms channel for daily standups during 5-week sprint]

