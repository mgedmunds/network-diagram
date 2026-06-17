# Project Status

Single source of truth for current project state.
Claude updates this at the end of every session. Read this first at the start of each session.

**Last updated:** 2026-06-17

---

## Current focus

**Phase 2 is closed. Next priorities are Phase 4 (Definitions & Tooltips) and the Stage 1 data entry guide.**
Both can now proceed in parallel.

---

## Development areas

### Phase 1 — Data Model & Schema
**Status: Complete**

**Next action:** None. Phase closed.

**Log:**
- 2026-06-12 — Initial app created with basic network views
- 2026-06-13 — Source data tab added; bipartite visit classification started
- 2026-06-15 — Four-table relational schema implemented (cases, settings, case_settings, visit_dates)
- 2026-06-15 — Surrogate key `setting_id` added; tables normalised
- 2026-06-15 — Reference tab added with ERD and data dictionary
- 2026-06-15 — Schema decisions recorded; CLAUDE.md and data-model.md updated
- 2026-06-16 — `case_status` field added to cases; case confidence filter added to sidebar
- 2026-06-16 — Settings renamed to Contexts throughout app, docs, and template
- 2026-06-16 — `visit_relevance` moved to case_contexts; `has_other_visits` and `epi_category` removed
- 2026-06-16 — CLAUDE.md and data-model.md updated to reflect finalised schema
- 2026-06-17 — Phase closed; docs/data-dictionary.md and docs/erd.svg confirmed current

---

### Phase 2 — Network Diagram Types
**Status: Complete**

**Next action:** None. Phase closed.

**Decisions made (2026-06-17):**
- [x] Keep the Contexts network view (`projection`)
- [x] "Who infected whom" always visible; info alert shown when no contacts data is present
- [x] No temporal view — replaced by an interactive timeline panel below the network diagram
- [x] Default landing page (Home tab) shown on first load, with upload widget and PII warning

**Log:**
- 2026-06-12 — Three network views present in initial app
- 2026-06-14 — Views renamed to plain-language labels (Contexts network, Who visited where, Who infected whom)
- 2026-06-14 — ADR-001 written: visNetwork chosen as rendering library
- 2026-06-14 — ADR-002 written: bipartite visit category labels agreed
- 2026-06-14 — Bipartite view updated: directional arrows, distinct colours, fourth "both windows" category
- 2026-06-15 — Bipartite legend updated to SVG arrows; "both" category detection fixed
- 2026-06-15 — Onset date slider changed to a date range (start + end)
- 2026-06-15 — Richer hover tooltips added to Who infected whom view
- 2026-06-17 — Four view decisions made (see above)
- 2026-06-17 — Home landing page added as default tab; upload widget and PII warning included
- 2026-06-17 — Dashboard restructured: network diagram + timeline panel; epi curve and tables moved to Data tab
- 2026-06-17 — Interactive timeline panel added: Gantt-style chart responds to node selection; shows exposure window, infectious period, onset date, and visit dates
- 2026-06-17 — "Who infected whom" now always shown; info alert displayed when no contacts data available
- 2026-06-17 — ADR-003 written; phase closed

---

### Phase 3 — Data Collection Interface
**Status: Stage 1 mostly complete; Stage 2 blocked on IT decision**

**Next action:** Write Stage 1 data entry guide (1–2 pages for field teams). Phase 2 is now decided so the guide can reference the views that will ship. Matt to raise Posit Connect availability with IT to unblock Stage 2.

**Stage 1 — Excel template:**

| Item | Done? |
|---|---|
| File upload restored in app | Yes |
| Excel template with 5 sheets | Yes |
| Data validation (dates, dropdowns, integers) | Yes |
| Named Excel tables matching schema | Yes |
| Auto-generated IDs (C-nnn / Ctxt-nnn) with FK dropdowns | Yes |
| Data entry guide for field teams | **No** |

**Stage 2 — Built-in Shiny data entry:** Blocked on NHS-hosted Posit Connect availability. Cannot start until IT confirms.

**Log:**
- 2026-06-16 — Data input working notes and requirements questionnaire started (docs/data-input.md)
- 2026-06-16 — Questionnaire completed; REDCap and Google Sheets ruled out; two-stage hybrid approach decided
- 2026-06-16 — Posit Connect vs local deployment comparison written
- 2026-06-16 — File upload restored in app for Stage 1 Excel import
- 2026-06-16 — Stage 1 Excel template generator built (make_template.R)
- 2026-06-16 — Data validation added to template (dates, dropdowns, integers)
- 2026-06-16 — Named Excel tables added; template sheets formatted
- 2026-06-16 — Auto-generated IDs (C-nnn / Ctxt-nnn) added; 1000 rows pre-filled
- 2026-06-16 — Cross-sheet FK dropdowns added (case_id and context_id lists)
- 2026-06-16 — Upload validation error messages improved with corrective guidance
- 2026-06-16 — docs/data-input.md closed; decision and requirements documented

---

### Phase 4 — Definitions, Tooltips & Help
**Status: Not started — unblocked now Phase 2 decisions are made**

**Next action:** Start once ADR-003 is written and Phase 2 is formally closed.

**Log:**
- 2026-06-13 — Definitions page added to app; infectious period wording clarified across tooltips

---

### Phase 5 — Epi Parameters & Assumptions
**Status: Not started**

**Next action:** Parameters panel exists with measles defaults. Still needed: input validation, citations, and plain-language descriptions for each parameter.

**Log:**
- 2026-06-12 — Parameters panel present in initial app with measles defaults (inc 7–21 days, inf ±4 days)

---

### Phase 6 — UI & UX Polish
**Status: Not started (some Phase 2-driven changes already applied)**

**Next action:** Not yet scoped. Begin after Phase 4.

**Log:**
- 2026-06-12 — Maximise/Minimise button added to network card
- 2026-06-12 — Network view selector moved from sidebar to card header dropdown
- 2026-06-12 — Tooltip clipping fix; word wrap added
- 2026-06-17 — App title changed to "Network explorer"; version number added (commit-count based, auto-increments on push)
- 2026-06-17 — Explanatory comments added throughout app.R for readability

---

### Phase 7 — Pre-Release Cleanup
**Status: Not started**

**Next action:** Remove Dev Panel tab, dev_progress.json, and action_tracker.json before release.

**Log:**
- 2026-06-14 — Dev panel and action tracker removed from app (later restored — check current state)

---

## Decision register

Claude logs assumptions and decision points here during sessions.
Matt reviews and clears entries at the start of the next session.

| Date | Area | Assumption or question | Reviewed? |
|---|---|---|---|
| 2026-06-17 | Schema | Memory referred to `settings`/`case_settings` table names — current naming is `contexts`/`case_contexts`. Memory updated. | Yes |
| 2026-06-17 | Versioning | Commit-count approach requires git in PATH when R starts. Works in RStudio local; may need fallback when deploying to Posit Connect. | No |
| 2026-06-17 | Phase 2 | ADR-003 written and phase closed. | Yes |

---

## Docs & diagrams index

| Document | Purpose | Currency |
|---|---|---|
| `CLAUDE.md` | Project conventions, schema summary, package list | Current |
| `docs/STATUS.md` | This file — current project state | Current |
| `docs/data-flow.md` | Reactive chain diagram and key functions | Current |
| `docs/data-dictionary.md` | Full field-level reference for all 5 tables | Current |
| `docs/erd.svg` | Schema entity-relationship diagram | Auto-generated |
| `docs/decisions/ADR-001` | Why visNetwork was chosen for rendering | Accepted |
| `docs/decisions/ADR-002` | Bipartite link category definitions | Accepted |
| `docs/decisions/ADR-003` | Network view selection and main page layout | Accepted |
| `docs/data-model.md` | Phase 1 working notes | Closed |
| `docs/data-input.md` | Phase 3 working notes and data entry decision | Closed |
| `docs/network-types.md` | Phase 2 working notes | Closed — see ADR-003 |
| `docs/additional-features.md` | Candidate future views | Open |
