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

Five-table schema (cases, contexts, case_contexts, visit_dates, contacts) is finalised.
Excel template with validation, named tables, and auto-generated IDs is built and working.

- `docs/data-dictionary.md` — full field reference
- `docs/erd.svg` — auto-generated on app start
- `docs/data-model.md` — closed working notes

**Next action:** None. Phase closed.

---

### Phase 2 — Network Diagram Types
**Status: In progress — decisions needed from Matt**

All three views exist in the app and work. Keep/cut decisions are not made.

**Open questions — Matt to answer by running the app:**
- [ ] Keep or cut the Contexts network view (`projection`)? Is it adding value over the bipartite view?
- [ ] Show "Who infected whom" always, or only when contacts data is present?
- [ ] Add a temporal view? If so, does it replace the time slider or sit alongside it?
- [ ] What should the default view be when the app first loads?

Once answered: Claude writes ADR, updates CLAUDE.md, closes phase.

- `docs/network-types.md` — working notes (open)
- `docs/additional-features.md` — candidate future views

---

### Phase 3 — Data Collection Interface
**Status: Stage 1 mostly complete; Stage 2 blocked on IT decision**

**Stage 1 — Excel template (done except data entry guide)**

| Item | Done? |
|---|---|
| File upload restored in app | Yes |
| Excel template with 5 sheets | Yes |
| Data validation (dates, dropdowns, integers) | Yes |
| Named Excel tables matching schema | Yes |
| Auto-generated IDs (C-nnn / Ctxt-nnn) with FK dropdowns | Yes |
| Data entry guide for field teams | **No** |

Next action: write the data entry guide (1–2 pages). Waiting until Phase 2 closes so the guide can reference only the views that will ship.

**Stage 2 — Built-in Shiny data entry (blocked)**

Requires NHS-hosted Posit Connect. Cannot start until IT confirms availability.
Action: Matt to raise with IT.

- `docs/data-input.md` — closed working notes, full decision rationale

---

### Phase 4 — Definitions, Tooltips & Help
**Status: Not started**

Blocked until Phase 2 closes — can't finalise tooltips for views that may be cut.

---

### Phase 5 — Epi Parameters & Assumptions
**Status: Not started**

Parameters panel exists with measles defaults. Still needed: input validation, citations, and plain-language descriptions for each parameter.

---

### Phase 6 — UI & UX Polish
**Status: Not started**

---

### Phase 7 — Pre-Release Cleanup
**Status: Not started**

Dev panel (Dev Panel tab, `dev_progress.json`, `action_tracker.json`) must be removed before release.

---

## Decision register

Claude logs assumptions and decision points here during sessions.
Matt reviews and clears entries at the start of the next session.

| Date | Area | Assumption or question | Reviewed? |
|---|---|---|---|
| 2026-06-17 | Schema | `data-model.md` memory referred to `settings` / `case_settings` table names — app.R and CLAUDE.md use `contexts` / `case_contexts`. Memory updated to reflect current naming. | Yes |

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
