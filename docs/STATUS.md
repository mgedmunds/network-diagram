# Project Status

Single source of truth for current project state.
Claude updates this at the end of every session. Read this first at the start of each session.

**Last updated:** 2026-06-17

---

## Current focus

**Phase 2 network view decisions are the active bottleneck.**
Four questions need answers before Phase 2 can close and Phase 4 can start.
Matt needs to open the running app, try each view, and answer them (see Phase 2 below).

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
**Status: In progress — decisions needed from Matt**

**Next action:** Matt to open the running app, review each view, and answer the four open questions below. Once answered, Claude writes the ADR and closes the phase.

**Open questions:**
- [ ] Keep or cut the Contexts network view (`projection`)? Is it adding value over the bipartite view?
- [ ] Show "Who infected whom" always, or only when contacts data is present?
- [ ] Add a temporal view? If so, does it replace the time slider or sit alongside it?
- [ ] What should the default view be when the app first loads?

**Log:**
- 2026-06-12 — Three network views present in initial app
- 2026-06-14 — Views renamed to plain-language labels (Contexts network, Who visited where, Who infected whom)
- 2026-06-14 — ADR-001 written: visNetwork chosen as rendering library
- 2026-06-14 — ADR-002 written: bipartite visit category labels agreed
- 2026-06-14 — Bipartite view updated: directional arrows, distinct colours, fourth "both windows" category
- 2026-06-15 — Bipartite legend updated to SVG arrows; "both" category detection fixed
- 2026-06-15 — Onset date slider changed to a date range (start + end)
- 2026-06-15 — Richer hover tooltips added to Who infected whom view
- 2026-06-17 — Keep/cut decisions identified as active bottleneck; added to STATUS.md

---

### Phase 3 — Data Collection Interface
**Status: Stage 1 mostly complete; Stage 2 blocked on IT decision**

**Next action:** Write Stage 1 data entry guide (1–2 pages for field teams). Waiting until Phase 2 closes so the guide references only the views that will ship. Matt to raise Posit Connect availability with IT to unblock Stage 2.

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
**Status: Not started — blocked on Phase 2**

**Next action:** Start once Phase 2 closes. Cannot finalise tooltips for views that may be cut.

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
**Status: Not started**

**Next action:** Not yet scoped. Begin after Phase 4.

**Log:**
- 2026-06-12 — Maximise/Minimise button added to network card
- 2026-06-12 — Network view selector moved from sidebar to card header dropdown
- 2026-06-12 — Tooltip clipping fix; word wrap added

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
| `docs/data-model.md` | Phase 1 working notes | Closed |
| `docs/data-input.md` | Phase 3 working notes and data entry decision | Closed |
| `docs/network-types.md` | Phase 2 working notes | Open |
| `docs/additional-features.md` | Candidate future views | Open |
