# Phase 3a M1 — Nested Form Wireframe

**Date:** 2026-06-18  
**Purpose:** Detailed UI layout for nested case entry form (before M1 coding starts)

---

## Overall Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Data Entry App — Network Diagram                        [Menu] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [ Cases ] [ Contexts ] [ Reports ]                            │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Cases List (Spreadsheet View)                              │ │
│ ├─────────────────────────────────────────────────────────────┤ │
│ │ [+ New Case]  [Search: _____] [Filter: Status ↓]           │ │
│ │                                                             │ │
│ │ case_id │ CIMS_id │ Forename │ Surname │ DOB │ Onset │ ⋮ │ │
│ │ ────────┼─────────┼──────────┼─────────┼─────┼───────┤    │ │
│ │ C-001   │ NHS123  │ John     │ Smith   │ ...│ 2026  │    │ │
│ │ C-002   │ NHS456  │ Jane     │ Doe     │ ... │ 2026  │    │ │
│ │ C-003   │ NHS789  │ Bob      │ Jones   │ ... │ 2026  │    │ │
│ │ [scroll to see more]                                        │ │
│ │                                                             │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

[Click on a row → opens nested form panel on right or modal]
```

---

## Nested Form Panel (Right Sidebar or Modal) — EDITING ONE CASE

### **SECTION 1: CASE FORM** (Top)

```
┌────────────────────────────────────────────────┐
│ CASE ENTRY FORM                          [✕] │
├────────────────────────────────────────────────┤
│                                                │
│ Case ID: C-001 (auto-generated, read-only)    │
│                                                │
│ CIMS ID: [NHS123____________] *required       │
│          ⚠ Must be unique                      │
│                                                │
│ Name                                           │
│ ├─ Forename: [John________________] *required │
│ └─ Surname:  [Smith_______________] *required │
│                                                │
│ Date of Birth: [DD/MM/YYYY________] *required │
│                Age (auto): 42 years            │
│                                                │
│ Gender: [Dropdown ↓________________]           │
│         ├─ Not stated                          │
│         ├─ Male                                │
│         ├─ Female                              │
│         └─ Other                               │
│                                                │
│ Postcode: [SW1A_1AA_______________] optional  │
│           (UK format validation)               │
│                                                │
│ Case Confidence: [Dropdown ↓_______] *required│
│                  ├─ Confirmed                  │
│                  ├─ Probable                   │
│                  └─ Possible                   │
│                                                │
│ Date of Onset: [DD/MM/YYYY________] *required │
│                (validates: must be ≤ today)   │
│                                                │
│ Vaccination Status: [Dropdown ↓____] optional │
│                     ├─ Unvaccinated            │
│                     ├─ 1 dose                  │
│                     ├─ 2 doses                 │
│                     └─ Unknown                 │
│                                                │
│ [SAVE CASE] [CANCEL]                          │
│                                                │
└────────────────────────────────────────────────┘
```

**Validation indicators:**
- Red border + error message below field if invalid
- Green checkmark if valid (optional, for UX polish)
- Required fields marked with `*`

---

### **SECTION 2: CONTEXTS FOR THIS CASE** (Below case form)

Appears **after case is saved** (don't show until case_id exists).

```
┌────────────────────────────────────────────────┐
│ CONTEXTS FOR THIS CASE (C-001)                 │
├────────────────────────────────────────────────┤
│                                                │
│ Linked Contexts:                               │
│ ┌────────────────────────────────────────────┐ │
│ │ Healthcare worker                      [✕] │ │
│ │ • Visit dates: 2026-06-01, 2026-06-02     │ │
│ │ • visit_relevance: Exposure window        │ │
│ │ [EDIT] [DELETE]                           │ │
│ └────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────┐ │
│ │ School                                 [✕] │ │
│ │ • Visit dates: 2026-06-03 to 2026-06-10   │ │
│ │ • visit_relevance: Infectious period      │ │
│ │ [EDIT] [DELETE]                           │ │
│ └────────────────────────────────────────────┘ │
│                                                │
│ [+ Add Context] ← opens context select modal   │
│                                                │
└────────────────────────────────────────────────┘
```

**[+ Add Context] Modal:**

```
┌────────────────────────────────────────────────┐
│ SELECT CONTEXTS FOR THIS CASE                  │
├────────────────────────────────────────────────┤
│                                                │
│ ☐ Healthcare worker                           │
│ ☐ School                                       │
│ ☐ Food handler                                 │
│ ☐ Public transport worker                      │
│ ☐ Retail worker                                │
│ ☐ Care home resident                           │
│ ☐ Prison staff                                 │
│ ☐ [Other — add new context]                    │
│                                                │
│ [NEXT] [CANCEL]                               │
│                                                │
└────────────────────────────────────────────────┘

(After NEXT, user proceeds to visit_dates form for each selected context)
```

---

### **SECTION 3: VISIT DATES FOR EACH CONTEXT** (Sub-form after context selected)

Appears **after context(s) selected**. Shows one context at a time, or tabbed interface if multiple.

```
┌────────────────────────────────────────────────┐
│ VISIT DATES: Healthcare worker (C-001)         │
├────────────────────────────────────────────────┤
│                                                │
│ Visit Date Range (optional; leave blank for   │
│ single dates below):                           │
│ From: [DD/MM/YYYY_] To: [DD/MM/YYYY_]         │
│                                                │
│ Populate buttons (quick entry):                │
│ [All days in range] [Weekdays only]            │
│ [Weekends only] [Clear all]                    │
│                                                │
│ Individual Visit Dates:                        │
│ ┌────────────────────────────────────────────┐ │
│ │ 2026-06-01  [Remove]                       │ │
│ │ 2026-06-02  [Remove]                       │ │
│ │ 2026-06-07  [Remove]                       │ │
│ └────────────────────────────────────────────┘ │
│                                                │
│ [+ Add Single Date]                            │
│                                                │
│ visit_relevance (categorize this visit):       │
│ [Dropdown ↓________________] *after dates OK  │
│ ├─ Exposure window                             │
│ ├─ Infectious period                           │
│ ├─ Both                                         │
│ └─ Neither                                      │
│ ⓘ Epi windows: Exp: 2026-05-27–06-06 |        │
│   Inf: 2026-06-08–06-15                       │
│                                                │
│ [SAVE] [CANCEL]                               │
│                                                │
└────────────────────────────────────────────────┘
```

**Logic:**
- Range populate buttons pre-fill individual dates (user can remove/add manually)
- visit_relevance dropdown shows only after at least one date is entered
- Epi windows displayed as reference (read-only info)

---

### **SECTION 4: TRANSMISSION LINKS** (Bottom, if space allows; or separate tab)

Appears **after case is saved**.

```
┌────────────────────────────────────────────────┐
│ TRANSMISSION LINKS FOR THIS CASE (C-001)       │
├────────────────────────────────────────────────┤
│                                                │
│ This case infects (FROM):                      │
│ ┌────────────────────────────────────────────┐ │
│ │ C-001 → C-003 (Probable)               [✕] │ │
│ │ C-001 → C-004 (Possible)               [✕] │ │
│ └────────────────────────────────────────────┘ │
│                                                │
│ This case infected by (TO):                    │
│ ┌────────────────────────────────────────────┐ │
│ │ C-002 → C-001 (Probable)               [✕] │ │
│ └────────────────────────────────────────────┘ │
│                                                │
│ [+ Add Link]                                   │
│                                                │
└────────────────────────────────────────────────┘
```

**[+ Add Link] Modal:**

```
┌────────────────────────────────────────────────┐
│ ADD TRANSMISSION LINK                          │
├────────────────────────────────────────────────┤
│                                                │
│ This case (C-001):                             │
│ ☐ Infected to  ☒ Infected by                  │
│   (FROM)         (TO)                          │
│                                                │
│ Other case: [Search: C-___________]            │
│ Results:                                       │
│ ├─ C-002 (John Smith, onset: 2026-06-01)      │
│ ├─ C-003 (Jane Doe, onset: 2026-06-02)        │
│ └─ C-004 (Bob Jones, onset: 2026-06-03)       │
│                                                │
│ Link Type: [Dropdown ↓________________]        │
│ ├─ Probable                                    │
│ └─ Possible                                    │
│                                                │
│ [SAVE] [CANCEL]                               │
│                                                │
└────────────────────────────────────────────────┘
```

---

## Flow Diagram (M1 Implementation)

```
[New Case Button]
     ↓
[Case Form: demographics]
     ↓
[SAVE CASE] → case_id auto-generated
     ↓
[Show Context Selection] (checkbox modal)
     ↓
[For each context selected:
   → Show visit_dates form
   → After ≥1 date: show visit_relevance dropdown
   → SAVE context + dates + relevance]
     ↓
[Show Transmission Links section] (optional M1)
     ↓
[Case complete; refresh spreadsheet view]
```

**Phase 1 (M1) Priority:** Case form + spreadsheet view + context checklist  
**Phase 2 (M2):** Visit dates + bulk populate + visit_relevance  
**Phase 3 (M3):** Transmission links + validation + error handling

---

## Spreadsheet View Details

### Column Order (Admin-set defaults)

1. case_id (locked width ~80px)
2. CIMS_id (~100px)
3. Forename (~120px)
4. Surname (~120px)
5. DOB (~100px)
6. Gender (~80px)
7. Postcode (~100px)
8. case_confidence (~120px, color-coded: Green=Confirmed, Yellow=Probable, Red=Possible)
9. onset_date (~100px)
10. vaccination_status (~120px)

### Actions

- **Click row** → Open nested form panel (right sidebar)
- **Right-click row** → Context menu: Edit | Delete | Duplicate
- **Header sort** → Sort by any column (remembers sort state per session)
- **Header filter** → Show filter dropdowns per column
- **Search box** → Global search across all visible columns
- **Virtual scroll** → Loads 50 rows at a time; smooth scroll to 500+ cases

### Column Customization (per session)

- User can drag column headers to reorder (not saved)
- User can hide column (button per column header; not saved)
- Reset to defaults button

---

## Error States & Validation Feedback

### Case Form Validation (Real-time)

| Field | Rule | Error Message |
|---|---|---|
| CIMS_id | Unique | "⚠ Case with CIMS_id 'NHS123' already exists" |
| Forename | Not empty | "⚠ Forename is required" |
| Surname | Not empty | "⚠ Surname is required" |
| DOB | Valid date, before onset_date | "⚠ DOB must be before onset date" |
| Postcode | UK format (if filled) | "⚠ Postcode format invalid (e.g., SW1A 1AA)" |
| case_confidence | Not empty | "⚠ Case confidence is required" |
| onset_date | Valid date, not in future | "⚠ Onset date must be today or earlier" |

### Visit Dates Validation

| Field | Rule | Error Message |
|---|---|---|
| visit_date | Valid date, after DOB, before/around onset_date (soft) | "ⓘ Visit date is before case onset (unusual; OK to confirm)" |
| visit_relevance | Not empty (if ≥1 date) | "⚠ Select visit relevance before saving" |

---

## Accessibility Notes

- Tab order: Case form fields → [SAVE] → Contexts section → Links section
- All dropdowns keyboard-navigable (arrow keys, Enter to select)
- Error messages announced via ARIA live region
- Color not sole indicator (e.g., case_confidence uses text + color)

---

## Next Steps

1. Confirm wireframe structure with user (any changes?)
2. M1 build begins: implement case form + spreadsheet (2 weeks)
3. M2 build: context checklist + visit dates (1 week)
4. M3 build: transmission links + validation (1 week)
