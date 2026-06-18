# Data Entry Shiny App — Architecture & Design

**Phase 3a, Stage 2 (New Stage — Data Entry Interface)**

**Date:** 2026-06-18  
**Author:** Claude Code (with Matt Edmunds)  
**Status:** Design phase — ready for implementation

---

## Overview

A local Shiny app for outbreak data entry. Runs on user's machine; SQLite file stored in SharePoint folder. Supports concurrent multi-user entry (3–4 users). **Core innovation:** metadata-driven schema allows non-technical data managers to add custom fields mid-outbreak without developer involvement.

### Key Features

| Feature | How it works |
|---|---|
| **Dual-view entry** | Form view (one case, clean UI) + Spreadsheet view (all cases, bulk edits) |
| **Bulk date entry** | One-click "all weekdays" / "all dates" for visit_dates |
| **Runtime field extension** | Data manager adds fields to cases table via UI (no code changes) |
| **Dynamic validation** | Rules auto-applied in both form & spreadsheet views |
| **Local + SharePoint** | Data file on SharePoint; app runs locally; no data leaves SharePoint |
| **Concurrent access** | SQLite file locking; acceptable for outbreak timescales |
| **Soft-delete fields** | Removed fields hidden from UI; data preserved (audit trail) |
| **Export & sync** | Download .xlsx for main app; or directly read SQLite from main app |

---

## Database Schema

### Core Tables (Existing)

```sql
cases (
  case_id TEXT PRIMARY KEY,
  onset_date DATE NOT NULL,
  age_group TEXT,
  vaccination_status TEXT,
  case_status TEXT,
  created_at DATETIME,
  created_by TEXT,
  updated_at DATETIME,
  updated_by TEXT
);

contexts (
  context_id INTEGER PRIMARY KEY,
  context_name TEXT UNIQUE NOT NULL,
  context_type TEXT NOT NULL,
  created_at DATETIME,
  created_by TEXT
);

case_contexts (
  case_id TEXT NOT NULL,
  context_id INTEGER NOT NULL,
  PRIMARY KEY (case_id, context_id),
  FOREIGN KEY (case_id) REFERENCES cases(case_id),
  FOREIGN KEY (context_id) REFERENCES contexts(context_id)
);

visit_dates (
  case_id TEXT NOT NULL,
  context_id INTEGER NOT NULL,
  visit_date DATE NOT NULL,
  PRIMARY KEY (case_id, context_id, visit_date),
  FOREIGN KEY (case_id, context_id) REFERENCES case_contexts(case_id, context_id)
);

contacts (
  from TEXT NOT NULL,
  to TEXT NOT NULL,
  link_type TEXT NOT NULL,
  PRIMARY KEY (from, to),
  FOREIGN KEY (from) REFERENCES cases(case_id),
  FOREIGN KEY (to) REFERENCES cases(case_id)
);
```

### NEW: Metadata Tables (Schema Extension)

```sql
-- Stores field definitions for the cases table
field_definitions (
  field_id INTEGER PRIMARY KEY AUTOINCREMENT,
  field_name TEXT NOT NULL UNIQUE,
  table_name TEXT NOT NULL DEFAULT 'cases',  -- Start with cases only
  data_type TEXT NOT NULL,  -- 'text', 'date', 'integer', 'categorical'
  is_required BOOLEAN DEFAULT 0,
  validation_rule TEXT,  -- JSON
  display_order INTEGER,  -- Determines field order in form
  is_active BOOLEAN DEFAULT 1,  -- 0 = soft-deleted
  created_at DATETIME,
  created_by TEXT,
  deleted_at DATETIME,
  deleted_by TEXT
);

-- Audit log for field lifecycle
field_audit_log (
  audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
  field_name TEXT NOT NULL,
  action TEXT NOT NULL,  -- 'created', 'modified', 'deleted'
  old_value TEXT,
  new_value TEXT,
  user TEXT NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Example: Metadata for Custom Fields

When user creates a field "Occupation" with categorical validation:

```sql
INSERT INTO field_definitions (
  field_name, table_name, data_type, is_required, validation_rule, display_order, created_by
) VALUES (
  'occupation', 'cases', 'categorical', 0, 
  '{"allowed_values": ["Healthcare worker", "Food handler", "Teacher", "Community worker", "Other"]}',
  6,
  'Alice@health.nhs.uk'
);

-- SQLite executes:
ALTER TABLE cases ADD COLUMN occupation TEXT;
```

---

## UI Architecture

### Tab Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│ Network Data Entry App                                        v1.42 │
├─────────────────────────────────────────────────────────────────────┤
│ [Home]  [Cases Entry]  [Contexts]  [Case-Context]  [Transmission]   │
│         [Admin: Field Manager]                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Tab 1: Home
- Info panel: "How to use this app" with workflow diagram
- Status display: "Connected to outbreak-data.db (SharePoint\...)"
- Quick stats: "X cases, Y contexts, Z case-context links"
- Last sync time (for concurrency awareness)

### Tab 2: Cases Entry (PRIMARY)

**Left Panel: View Selector**
```
◯ Form View (default)
◯ Spreadsheet View
```

#### **2a. Form View (One case at a time)**

Clean form with dynamic fields:

```
┌─ Cases Entry (Form View) ────────────────────────────┐
│                                                      │
│ Navigation: [◄ Previous] [C-042 / 100] [Next ►]     │
│ [Create New Case] [Delete] [Copy from...]            │
│                                                      │
│ Case ID:          C-042            [Auto-generated]  │
│ Onset Date:       2026-06-15       [Date picker]     │
│ Age Group:        [45-64 ▼]        [Dropdown]        │
│ Vaccination:      1 dose   [Dropdown]                │
│ Case Status:      Confirmed        [Dropdown]        │
│                                                      │
│ ┌─ Custom Fields ──────────────────────────────────┐ │
│ │ Occupation:     Healthcare worker [Dropdown]      │ │
│ │ Symptoms:       Rash, Fever, Cough [Checkboxes]   │ │
│ │ HCW Setting:    Hospital A        [Dropdown]      │ │
│ └──────────────────────────────────────────────────┘ │
│                                                      │
│ [Save] [Save & Next Case] [Cancel]                  │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Data flow:**
1. Fields pulled from `field_definitions` WHERE `is_active = 1` ORDER BY `display_order`
2. Validation rules applied on blur (client-side feedback) and on save (server-side validation)
3. Categorical fields = dropdowns; options parsed from validation_rule JSON
4. Required fields flagged with *; Save disabled until all required fields filled
5. On Save: INSERT/UPDATE cases table; INSERT audit log

**Benefits:**
- Enforced validation per field
- Clear, linear data entry workflow
- Training-friendly (field labels + help text)
- Good for new cases during outbreak peak

---

#### **2b. Spreadsheet View (All cases at once)**

DT (DataTables) widget with inline editing:

```
┌─ Cases Entry (Spreadsheet View) ──────────────────────┐
│ [Add Row] [Delete Selected] [Refresh]                 │
│ Filter: [________] Search: [________]                 │
├──────────────────────────────────────────────────────┤
│ Case ID │ Onset Date │ Age Group │ Vax │ Occ. │ ...   │
├─────────┼────────────┼───────────┼─────┼─────┼───────┤
│ C-001   │ 2026-06-10 │ 25-44     │ 2d  │ HCW │ ...   │
│ C-002   │ 2026-06-12 │ 5-12      │ 0   │ ---­ │ ...   │
│ C-003   │ 2026-06-15 │ 45-64     │ 1d  │ Food│ ...   │
│ ...                                                   │
└──────────────────────────────────────────────────────┘

Click cell to edit inline:
  C-001, Age Group cell → [25-44 ▼] dropdown auto-opens
  C-002, Occupation cell → [Healthcare worker | Food handler | Teacher | ...]
```

**Data flow:**
1. Load all cases from SQLite; render DT with inline editing enabled
2. Cell edit triggers validation (on blur)
3. Invalid entry: red cell background + error tooltip
4. Valid entry: cell background returns to normal; Save automatically queued
5. Concurrent edit detection: if user A saves, user B sees "Data refreshed" banner; spreadsheet reloads

**Benefits:**
- Bulk corrections fast
- Data review in one view
- Familiar to Excel users
- Good for spot-checking + cleanup phases

**Sync between Form & Spreadsheet views:**
- Same data; editing in form view immediately visible in spreadsheet view (if user switches)
- Last-writer-wins for concurrent edits on same row

---

### Tab 3: Contexts

Form + table view (similar pattern to Cases):
- **Form:** Create new context (context_name, context_type)
- **Table:** View all contexts; inline edit; delete

Data manager ensures contexts are defined before case-context linking begins.

---

### Tab 4: Case-Context Links

Bulk entry for case_contexts + visit_dates:

```
┌─ Case-Context Links ──────────────────────────┐
│ Select Case:    [C-001 ▼]                     │
│                                               │
│ ┌─ Contexts Attended ─────────────────────┐ │
│ │ ☐ Hospital A (Healthcare setting)       │ │
│ │ ☐ Restaurant B (Food & Drink)           │ │
│ │ ☐ School C (Education)                  │ │
│ │ ☑ Gym D (Recreation)                    │ │
│ │ ☐ Shop E (Retail)                       │ │
│ └─────────────────────────────────────────┘ │
│                                               │
│ For selected context (Gym D):                 │
│ Onset Date: 2026-06-15                        │
│ Epi Window: 2026-05-25 to 2026-06-14          │
│ Infectious: 2026-06-15 to 2026-06-22          │
│                                               │
│ ┌─ Add Visit Dates ──────────────────────┐ │
│ │ Date Range: [2026-05-25] to [2026-06-22] │ │
│ │ Populate: [All Dates] [Weekdays Only]     │ │
│ │          [Weekends Only] [Custom Filter] │ │
│ │ [Preview: 23 dates] [Save All]            │ │
│ └─────────────────────────────────────────┘ │
│                                               │
│ [Back] [Save & Next Case]                     │
└───────────────────────────────────────────────┘
```

**Bulk date entry logic:**
```r
# Pseudo-code
populate_dates <- function(case_id, context_id, onset_date, inc_min, inc_max, inf_before, inf_after, mode) {
  exposure_start <- onset_date - inc_max
  exposure_end <- onset_date - inc_min
  infectious_start <- onset_date - inf_before
  infectious_end <- onset_date + inf_after
  
  date_range <- seq(exposure_start, infectious_end, by = "1 day")
  
  if (mode == "all") {
    dates <- date_range
  } else if (mode == "weekdays") {
    dates <- date_range[!weekdays(date_range) %in% c("Saturday", "Sunday")]
  } else if (mode == "weekends") {
    dates <- date_range[weekdays(date_range) %in% c("Saturday", "Sunday")]
  }
  
  # Insert all dates into visit_dates table
  for (d in dates) {
    INSERT INTO visit_dates VALUES (case_id, context_id, d)
  }
}
```

---

### Tab 5: Transmission Links

Form for contacts table:
- Select source case (dropdown)
- Select recipient case (dropdown, excluding source)
- Select link_type (Probable / Possible)
- Save

---

### Tab 6: Admin — Field Manager (Data Manager Only)

**Role-based access:** Only users in "data_manager" role can see this tab.

```
┌─ Admin: Manage Custom Fields ─────────────────┐
│                                               │
│ ┌─ Current Fields (Active) ─────────────────┐│
│ │ Field Name │ Type │ Order │ Actions      ││
│ ├────────────┼──────┼───────┼──────────────┤│
│ │ occupation │ cat  │ [6 △▽]│ [Edit] [Hide]││
│ │ symptoms   │ text │ [7 △▽]│ [Edit] [Hide]││
│ │ hcw_setting│ cat  │ [8 △▽]│ [Edit] [Hide]││
│ └────────────┴──────┴───────┴──────────────┘│
│                                               │
│ ┌─ Add New Field ──────────────────────────┐│
│ │ Field Name:     [___________________]    ││
│ │ Data Type:      [Text   ▼]               ││
│ │ Required?       ☐ Yes                    ││
│ │ Display Order:  [10]                     ││
│ │                                           ││
│ │ If Categorical:                          ││
│ │ Options (comma-separated):                ││
│ │ [Healthcare worker, Food handler, ...]   ││
│ │                                           ││
│ │ Help text (optional):                    ││
│ │ [_________________________________]      ││
│ │                                           ││
│ │ [Create Field] [Cancel]                  ││
│ └──────────────────────────────────────────┘│
│                                               │
│ ┌─ Hidden Fields (Soft-Deleted) ──────────┐│
│ │ Field Name │ Hidden By │ Date │ Restore ││
│ ├────────────┼───────────┼──────┼─────────┤│
│ │ old_field  │ Alice ... │ 6/18 │ [Restore] ││
│ └────────────┴───────────┴──────┴─────────┘│
│                                               │
└───────────────────────────────────────────────┘
```

**Actions:**

| Action | What it does |
|---|---|
| **Create Field** | INSERT into field_definitions; ALTER TABLE cases ADD COLUMN |
| **Edit Field** | Update display_order; (can't change name/type post-creation — would risk data loss) |
| **Hide Field** | UPDATE field_definitions SET is_active = 0; field disappears from form/spreadsheet; data preserved |
| **Restore Field** | UPDATE field_definitions SET is_active = 1; field reappears |
| **Change Display Order** | Reorder triangles (△▽); UPDATE display_order for multiple fields at once |

**Validations:**
- Field name must be unique (error if duplicate attempted during concurrent creates → "Error: Field already exists. Please try a different name.")
- Field name must be valid SQL identifier (alphanumeric + underscore; warn user if contains spaces)
- Categorical options: comma-separated; trim whitespace; warn if duplicates

---

## Validation Architecture

### Validation Rules (Stored as JSON)

**Example 1: Text field (required, no special rules)**
```json
{
  "field_name": "case_id",
  "field_type": "text",
  "is_required": true,
  "pattern": "^C-\\d{3,}$",
  "error_message": "Must be C- followed by 3+ digits"
}
```

**Example 2: Categorical (required)**
```json
{
  "field_name": "occupation",
  "field_type": "categorical",
  "is_required": false,
  "allowed_values": ["Healthcare worker", "Food handler", "Teacher", "Community worker", "Other"],
  "error_message": "Please select from the list"
}
```

**Example 3: Date field**
```json
{
  "field_name": "onset_date",
  "field_type": "date",
  "is_required": true,
  "min_date": "2026-01-01",
  "error_message": "Onset date must be a valid date"
}
```

### Validation Flow

**Client-side (immediate feedback):**
1. User types/selects in form or edits cell in spreadsheet
2. On blur/change, Shiny JS validates against stored rule
3. Red cell background + tooltip if invalid
4. Green border if valid

**Server-side (on Save):**
1. Re-validate all fields (defence against client-side bypass)
2. Check FK integrity: case_id exists in cases table
3. Check business logic: e.g. onset_date ≤ visit_dates
4. If valid: INSERT/UPDATE + log to audit table
5. If invalid: return error message; highlight problem field in UI

---

## Concurrency & Conflict Handling

### Scenario: Two users edit same case simultaneously

```
13:00 Alice loads case C-001 (Form View)
13:01 Bob loads case C-001 (Spreadsheet View)
13:02 Alice changes Age Group to "25-44" → Saves
13:03 Bob changes Vaccination to "1 dose" → Saves
      ├─ SQLite writes age_group = "25-44"
      └─ SQLite writes vaccination_status = "1 dose"
      Result: Both changes merged ✓ (different columns)

13:05 Alice changes Occupation to "Healthcare" → Saves
13:06 Bob changes Occupation to "Food handler" → Saves
      ├─ SQLite writes occupation = "Healthcare" (Alice)
      ├─ SQLite writes occupation = "Food handler" (Bob)
      └─ Bob's write overwrites Alice's ✓ (acceptable for outbreak timescale)
      Banner shown to both: "Data updated; please refresh"
```

**Conflict resolution:** Last-write-wins. For outbreak data entry (peaks 2–3 weeks), acceptable. If high-consequence data needed audit trail, upgrade to Postgres later.

**Notification:**
- App polls database every 5 sec for changes (last_modified timestamp per row)
- If row changed by another user: banner "Data in this record has been updated. [Refresh]"
- User clicks Refresh; form/table reloads with latest values

---

## Main Analysis App Integration

The main network analysis app reads from the same SQLite file:

```r
# main app loads custom fields dynamically
field_defs <- dbGetQuery(con, "SELECT * FROM field_definitions WHERE is_active = 1")

# Build UI columns dynamically
output$cases_table <- renderDT({
  col_names <- c("case_id", "onset_date", "age_group", "vaccination_status", 
                 field_defs$field_name)
  query <- paste0("SELECT ", paste(col_names, collapse = ", "), " FROM cases")
  dbGetQuery(con, query)
})
```

**Result:** New field added in data entry app → immediately visible in main app's data table view. No code changes needed.

---

## Implementation Roadmap

### Phase 3a.1: Core Entry Forms (1 week)
- [ ] Cases form (Form + Spreadsheet view)
- [ ] Contexts form
- [ ] Case-context + visit_dates form
- [ ] Transmission form
- [ ] Validation on basic fields (onset_date, age_group, vax status)
- [ ] Export to .xlsx with 5 named sheets

### Phase 3a.2: Metadata Schema (1 week)
- [ ] Create field_definitions and field_audit_log tables
- [ ] Admin tab for field creation UI
- [ ] ALTER TABLE cases ADD COLUMN on field create
- [ ] Display order reordering (△▽ UI)
- [ ] Soft-delete (Hide/Restore actions)
- [ ] Concurrent field creation error handling

### Phase 3a.3: Dynamic Form Generation (1 week)
- [ ] Read field_definitions on app startup
- [ ] Form builder: render input widgets based on data_type + validation_rule
- [ ] Spreadsheet builder: DT columns dynamically generated
- [ ] Categorical options parsed from JSON validation_rule
- [ ] Help text / tooltips per field

### Phase 3a.4: Validation Layer (1 week)
- [ ] Client-side validation (JS) for real-time feedback
- [ ] Server-side validation (R) on Save
- [ ] FK integrity checks (case_id, context_id exist)
- [ ] Business logic validation (dates, counts, etc.)
- [ ] Error messages + highlighting
- [ ] Audit logging (who changed what, when)

### Phase 3a.5: Deployment & QA (1 week)
- [ ] Local deployment (user's machine)
- [ ] SharePoint folder configuration
- [ ] Multi-user concurrency testing (3–4 simultaneous users)
- [ ] User guide + field manager guide
- [ ] Rollback procedures (soft-delete recovery)

**Total: 5 weeks (35 days developer time)**

---

## Questions & Assumptions

### Scope Clarifications
1. **Field extension only on cases table for Phase 1?** Yes — contexts & case_contexts can extend in Phase 2.
2. **Categorical field options always comma-separated (no UI option picker)?** Yes — simpler for Phase 1.
3. **Display order a simple integer reorder (△▽ buttons)?** Yes — drag-drop could be Phase 2 UX polish.

### Governance & Roles
1. **Who can create fields?** Only "data_manager" role users (TBD: how to define roles — file, env var, or UI?).
2. **Can anyone delete a field?** No — only data managers. Deletion is soft-delete (Hide action).
3. **Audit trail scope:** Track field creation/deletion, but not every data edit (too noisy). Data edits already tracked via updated_by/updated_at columns.

### Technical Assumptions
1. **Data file location:** `C:\Users\[username]\OneDrive\[SharePoint site name]\outbreak-data.db` — will Shiny be able to read/write to OneDrive reliably? (Windows file locking should handle it; SQLite's journal mechanism robust.)
2. **Concurrent users:** Assume 3–4 max; if >5, recommend Postgres.
3. **Network connectivity:** No requirement for offline mode Phase 1. Could add later (local sync → OneDrive pull on reconnect).

---

## Known Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| **User creates bad categorical options** | Form unusable if options misparsed | Show preview of parsed options before Save; allow edit before confirm |
| **Concurrent field creation (same name)** | Confusion; unclear which field was created | Error message + retry; atomic transaction ensures only one wins |
| **Data loss if field deleted mid-outbreak** | Staff sees field, then suddenly it's gone | Soft-delete (hidden, not removed); Restore button in Admin tab; audit log shows who hid it when |
| **SQLite file locked during backup** | Brief write failures | Users see "Database is locked; please retry in 10 seconds"; auto-retry with exponential backoff |
| **Form/spreadsheet view out of sync** | User confusion | Refresh button in both views; banner notification when data changes; 5-sec polling |

---

## Success Criteria

| Criterion | Target |
|---|---|
| **Non-technical user can add field** | Data manager creates new field in <2 min via UI (no code changes) |
| **Bulk date entry speed** | Population of 20 dates per case-context in 1 click |
| **Form + spreadsheet sync** | Changes in one view appear in other within 10 seconds |
| **Concurrent users** | 3 simultaneous edits without data loss; conflicts merge or last-write-wins gracefully |
| **Validation accuracy** | 100% of data in SQLite export meets schema constraints + business rules |
| **Outbreak adaptability** | Schema modified mid-outbreak; main analysis app auto-discovers fields; no code changes |

