# Project Status

Single source of truth for current project state.
Claude updates this at the end of every session. Read this first at the start of each session.

**Last updated:** 2026-06-23 (session 10)

---

## Current focus

**Phase 4 (Definitions, Tooltips & Help) in progress on branch `amendments-batch-1`. This session: removed the Data and Possible links tabs; rewrote the whole Reference tab (Definitions / How to use / Assumptions) around the manual, practitioner-entered model; cleaned up the schema (dropped the unused `contacts` sheet, documented `likely_index_case` as the single source of transmission links, ADR-006). All committed and pushed, NOT yet tested in RStudio or merged to main. Next: run the app in RStudio to read through the rewritten Reference tab; then reconcile the remaining data-dictionary drift (see decision register), and decide whether to PR `amendments-batch-1` into main.**

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

### Phase 3a — Data Entry
**Status: SUSPENDED — Shiny app approach abandoned; Excel template upgraded instead**

**Critical Discovery (2026-06-18):** Shiny app is NOT just for network data — it's the PRIMARY outbreak linelist management tool. All staff data (demographics, testing, outcomes) + network data (contexts, visits, transmission) in one system.

**Next action:** Run `source("tools/make_template.R")` in RStudio to generate the upgraded template; test with demo data; upload to Shinylive app to verify it reads the new fields correctly.

**NEW Architecture (2026-06-18):**
- **Two separate apps** (not one): Data Entry App (Shiny) + Network Analysis App (existing, both read same SQLite)
- **Nested form workflow** (not flat tabs): case → contexts → visit_dates; natural logical flow
- **10 core fields in Phase 1** (CONFIRMED): case_id, CIMS_id, forename, surname, DOB, gender, postcode, case_confidence, onset_date, vax_status
- **Extended fields deferred to Phase 2** (Phase 3b): date_of_rash, comments, ethnicity, utla, testing, outcomes, travel_history, vulnerable_contacts, etc.
- **Manual entry only** (no external linelist import in Phase 1): staff type all data directly
- **Nested forms with checklist** for multi-context entry + bulk date populate
- **Real-time sync** across concurrent users (3–4 simultaneous OK; SharePoint syncs SQLite changes)

**6-Week Timeline (2026-06-22 to 2026-08-09):**

| Milestone | Dates | Duration | Deliverable |
|---|---|---|---|
| **M1: Nested cases form + spreadsheet** | 2026-06-22 to 2026-07-05 | 2w | Form + spreadsheet view; demographic fields; soft-delete |
| **M2: Contexts + visits + bulk date populate** | 2026-07-06 to 2026-07-12 | 1w | Multi-select checklist; bulk dates (all/weekdays/weekends) |
| **M3: Transmission links + validation** | 2026-07-13 to 2026-07-19 | 1w | Contacts table; duplicate detection (case_id + CIMS_id); DOB/postcode validation |
| **M4: Search/filter + derived fields** | 2026-07-20 to 2026-07-26 | 1w | Filter by status/date; age auto-calc; Admin field manager UI |
| **M5: Roles/access + spreadsheet optimization** | 2026-07-27 to 2026-08-02 | 1w | Data entry staff / data manager / viewer roles; virtual scroll (500 cases); real-time sync testing |
| **M6: Testing + deployment** | 2026-08-03 to 2026-08-09 | 1w | Local deployment (3–4 concurrent users); documentation; data manager guide |
| **TARGET COMPLETION** | **2026-08-09** | **6w total** | **MVP complete; ready for first outbreak** |

**Design decision register:** [phase-3a-enhanced-design-decisions.md](phase-3a-enhanced-design-decisions.md)

**Stage 2 (Deferred):**

Excel template (no longer needed; direct data entry in Shiny).

**Log:**
- 2026-06-16 — Data input questionnaire started (docs/data-input.md)
- 2026-06-16 — Questionnaire completed; Excel + Access ruled out in favour of Shiny
- 2026-06-17 — Shinylive PoC run (branch shinylive-poc): all packages confirmed available in WebR
- 2026-06-17 — Deployment approach decided: Shinylive + GitHub Pages; ADR-004 written
- 2026-06-18 — Full options appraisal completed (docs/data-entry-options-appraisal.md)
- 2026-06-18 — SQLite + Shiny with metadata-driven schema extension chosen (Phase 3a, single-stage, local deployment)
- 2026-06-18 — User clarifications locked (design decisions):
  - Local app + SharePoint storage (no data leaves SharePoint; SQLite file in SharePoint folder)
  - Drop Excel; go straight to Shiny for data entry (no interim Excel template stage)
  - Non-technical user can add custom fields mid-outbreak (metadata-driven UI; data manager role)
  - Dual-view entry: form view (one case, enforced validation) + spreadsheet view (all cases, bulk edits)
  - Concurrent edits: 3–4 simultaneous users OK; last-write-wins conflict resolution
  - Field extension scope: cases table only (Phase 1); contexts & case_contexts can extend later
  - Categorical validation: comma-separated text input ("Healthcare worker, Food handler, Other")
  - Field lifecycle: auto-appear on create (no approval); soft-delete on removal (data preserved)
- 2026-06-18 — Detailed architecture & design doc written (docs/data-entry-shiny-design.md)
- 2026-06-18 — Implementation roadmap: 5 weeks (5 × 1-week phases: forms, metadata schema, dynamic UI, validation, deployment)
- 2026-06-18 — Phase 3 working notes (docs/data-input.md) closed with final decision locked
- 2026-06-18 — Pre-build design decisions questionnaire completed (11 critical design decisions locked)
- 2026-06-18 — CIMS_id added as core field (unique constraint; locked; no deletion/rename)
- 2026-06-18 — Soft-delete schema added (is_deleted flag on cases & field_definitions; recoverable via Admin)
- 2026-06-18 — Import function confirmed: upload main linelist extracts to populate cases/contexts
- 2026-06-18 — Phase 3a design decisions doc written (phase-3a-design-decisions.md)
- 2026-06-18 — Phase 3a + Phase 4 PARALLEL execution confirmed (both start together, not sequential)
- 2026-06-18 — Ready to begin Phase 3a.1 (Core entry forms)
- 2026-06-18 — MAJOR DISCOVERY: Shiny app is PRIMARY linelist tool (not just network data)
- 2026-06-18 — Scope expanded: 11 core fields in Phase 1 (demographics + onset_date + vax + case_confidence + comments)
- 2026-06-18 — Extended fields deferred to Phase 2: ethnicity, utla, testing, outcomes, travel, contacts, etc.
- 2026-06-18 — Architecture: Two separate Shiny apps (Data Entry + Network Analysis, both read same SQLite)
- 2026-06-18 — Workflow: Nested forms (case → contexts → visits), not flat tabs
- 2026-06-18 — Data entry: manual only, no import function in Phase 1
- 2026-06-18 — Context entry: multi-select checklist → then add dates for each
- 2026-06-18 — Timeline extended: 5 weeks → 6 weeks (MVP with Phase 1 fields)
- 2026-06-18 — Detailed design doc written (phase-3a-enhanced-design-decisions.md)
- 2026-06-18 — visit_relevance workflow clarified: manual selection (not derived), stored at case_contexts level, staff select AFTER adding visit_dates (preferred flow), epi windows shown as reference, editable after entry
- 2026-06-18 — Phase 1 field priority CONFIRMED: 10 core case fields (case_id, CIMS_id, forename, surname, DOB, gender, postcode, case_confidence, onset_date, vax_status) + all 3 related tables (case_contexts, visit_dates, contacts); date_of_rash and comments moved to Phase 2
- 2026-06-18 — M1–M6 START DATE LOCKED: Monday 2026-06-22; TARGET COMPLETION: 2026-08-09 (6 weeks total)
- 2026-06-18 (session 6) — Architecture review: Shiny data entry app suspended. Power Apps ruled out (no Business 365 on dev laptop). R-Portable reviewed and understood but Excel+SharePoint chosen as simpler, lower-risk path for first outbreak.
- 2026-06-18 (session 6) — Excel template upgraded: cases extended to 11 fields (CIMS_id, forename, surname, date_of_birth, onset_date, age formula, gender, postcode, case_status, vaccination_status); CIMS_id duplicate detection (amber highlight); Date Helper tab added for bulk visit_date generation; README updated; data-dictionary.md updated.
- 2026-06-18 (session 6) — link_type field options changed from Confirmed/Suspected to Probable/Possible throughout app.R and all docs.
- 2026-06-19 (session 7) — Timeline contacts view fixed: shows selected case + direct transmission neighbours. Race condition on data load fixed (empty input$types now treated as all types). Node selector moved from network card header to sidebar toolbar (custom selectInput synced via JS events). Timeline scrollbar fix (max-height, overflow-y). Timeline button renamed Expand/Collapse → Maximise/Minimise (in amendments log, not yet coded).
- 2026-06-19 (session 7) — FK validation error on direct Excel template upload fixed: IDs derived from row position when formula cells unreadable; blank pre-sizing rows filtered in raw().
- 2026-06-19 (session 7) — Amendment log set up (docs/amendments.md). 15 ready-to-action items and 3 parked items logged with timestamps. Amendment workflow added to startup.md and CLAUDE.md.
- 2026-06-19 (session 7) — Global CLAUDE.md updated: added batch-amendment planning rule and batch-sessions minimise-interruptions rule.
- 2026-06-19 (session 7) — Security review of settings.local.json: removed Bash(git *) and Bash(git push *); added Bash(git fetch *), Bash(git pull *), Bash(git merge *). Git push now always prompts. Pending decision: narrow powershell.exe * (see decision register).
- 2026-06-19 (session 7) — Amendment batch (15 items) ready to run next session — all clarifying questions answered.
- 2026-06-20 (session 8) — Security overhaul of Claude Code permissions. Changes: (1) removed `powershell.exe *` entirely — was added for one-off Obsidian setup, no longer needed; (2) removed broad `Read(//mnt/c/Users/mgedmunds/**)` — replaced by specific project and R paths already present; (3) added `settings.local.json` to `.gitignore` to prevent personal paths being committed; (4) restructured permissions into two tiers — global baseline in `~/.claude/settings.json` (read-only git ops, grep, web search) and project-specific in `settings.local.json` (R runtimes, Windows paths, git add/commit); (5) removed 5 stale one-off permissions (awk, xargs, chmod+x, two mkdir commands); (6) added global deny list blocking git reset, checkout --, clean, and rebase across all projects; (7) narrowed Windows read from `projects/**` to `projects/network-diagram/**`; (8) created `docs/permissions-guide.md` — plain-English explanation of every permission with risk levels and review checklist.
- 2026-06-20 (session 8 continued) — Further security improvements: (1) switched default model to `claude-opus-4-8` globally; (2) enabled bubblewrap sandbox mode — filesystem sandboxing now active, blocks bash access to personal Windows folders; (3) removed bare `Rscript *` permissions (broken by sandbox — R still works via explicit `Rscript.exe` and `cmd.exe` paths); (4) installed `socat` for network sandboxing — **pending: configure `allowedDomains` allowlist next session** (reminder saved to memory).

---

### Deployment — Shinylive + GitHub Pages
**Status: App loads in browser — GitHub Actions deployment in progress**

**Next action:** Confirm GitHub Actions build passes and app is live at mgedmunds.github.io/network-diagram. Then check for any runtime rendering issues (plotly deprecation warning on epi curve).

**Checklist:**

| Item | Done? |
|---|---|
| PoC: confirm all packages work in WebR | Yes |
| ADR-004 written | Yes |
| Version number fallback (no git in WebR) | Yes |
| GitHub repo made public / Pro account | Yes (Pro) |
| GitHub Pages enabled (source: GitHub Actions) | Yes |
| GitHub Actions workflow added for main app | Yes |
| DiagrammeR removed (WebSocket crash in WebR) | Yes |
| App loads locally in browser | Yes |
| Main app live on GitHub Pages | Pending — check Actions tab |

**Log:**
- 2026-06-17 — PoC deployed locally; all packages confirmed (shinylive-poc branch)
- 2026-06-17 — ADR-004 written; Shinylive + GitHub Pages approach accepted
- 2026-06-18 — Multiple build failures resolved: openxlsx (clean export dir), ggplot2 (added explicitly), DiagrammeR (WebSocket crash, removed entirely), missing closing paren (bracket error from DiagrammeR removal)
- 2026-06-18 — App confirmed loading locally at http://localhost:8085 with demo data

---

### Phase 4 — Definitions, Tooltips & Help
**Status: In progress (branch `amendments-batch-1`)**

**Next action:** Read through the rewritten Reference tab in RStudio (text-only, low risk). Then reconcile the remaining data-dictionary drift (see decision register) before treating Phase 4 docs as final.

**Log:**
- 2026-06-13 — Definitions page added to app; infectious period wording clarified across tooltips
- 2026-06-23 (session 10) — Removed the Data tab (epi curve + line list) and Possible links tab; code archived to `archive/removed-pages.R`; pre-removal snapshot tagged `pre-page-removal-2026-06-22` (commit e96347e).
- 2026-06-23 (session 10) — Rewrote the full Reference tab around the manual (practitioner-entered) model (commit b5120ef): Definitions regrouped (core blocks / visit relevance categories / transmission terms / network measures / epi periods); Assumptions reframed as "what the tool shows vs does not calculate" with the three-view build logic consolidated as canonical, and the derived-link / auto-classification sections removed; How to use reduced to per-view pointers and the removed epidemic-curve section deleted; stale epi-curve mentions removed from the data-dictionary tooltips.
- 2026-06-23 (session 10) — Schema cleanup (ADR-006): dropped the unused `contacts` sheet from `CLAUDE.md` and `docs/data-dictionary.md`; documented `likely_index_case` (self-FK on cases) as the single source of transmission links, with a validation rule. Excel template needed no change (never had a contacts sheet; `likely_index_case` already present).
- 2026-06-23 (session 10) — Amendment log tidied: cleared the two completed "Ready to action" items (timeline scrollbar/maximise, metrics pop-out); items 1 (template primary context type column) and 3 (upload privacy line) confirmed still outstanding.

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
- 2026-06-17 — Timeline panel redesigned: case-selected shows epi windows as full-height background shapes; context-selected shows per-case segments; visit dots only for selected context
- 2026-06-17 — Timeline fixed at 30vh with scroll; row height fixed at 36px via layout(height); daily gridlines with weekly labels
- 2026-06-17 — Expand/Collapse button added to timeline card header (position:fixed toggle, same pattern as network Maximise)
- 2026-06-17 — Network legend replaced: visLegend side panel removed, replaced with floating HTML overlay so network uses full canvas width
- 2026-06-17 — RStudio git issue resolved: cloned repo to C:/Users/claude-dev/projects/network-diagram; Documents/ copy was stale and unconnected
- 2026-06-17 — Network legend merged with bipartite edge-direction key into single floating overlay (top-left, below node selector dropdown)
- 2026-06-17 — visLegend side panel removed; network fills full card width
- 2026-06-17 — Network height set to 60vh
- 2026-06-17 — Timeline: cases sorted by onset date (ascending) in context-selected view
- 2026-06-20 (session 9) — Amendment batch of 15 items completed on branch `amendments-batch-1` (6 commits, Groups A–F). NOT yet merged or pushed — awaiting RStudio test. Items: add `gender` field + epi-curve colour-by grouping; rename "Case status"→"Case confidence" (display only, field name unchanged); rename "Dashboard"→"Network model"; move Definitions/How to use/Assumptions into Reference tab as sub-tabs; epi-curve dynamic title + x-axis label; remove deprecated plotly layout height (from timeline layout calls, not the epi curve as originally logged); timeline button Expand/Collapse→Maximise/Minimise; fix case-selected timeline legend (zero-length traces were dropped — now NA-y single-point traces); move node selector to sidebar; typeable From/To onset date fields synced to slider; Data-tab filter banner; Source data heading + Contexts table; line-list card min-height; Home post-upload record summary.
- 2026-06-20 (session 9) — Two items need visual confirmation in RStudio: (a) case-selected timeline legend now shows all four entries; (b) line-list headers + pager visible with horizontal scrollbar.
- 2026-06-23 (session 10) — Page removal completed on `amendments-batch-1` (commit e96347e, local only): removed the **Data** tab (epi curve + filtered line list + filter banner) and the **Possible links** tab (derived candidate links). Removed code parked in `archive/removed-pages.R` (not sourced); pre-removal snapshot tagged `pre-page-removal-2026-06-22`. Network metrics table kept (already relocated to the Network model slide-out panel). Stale help/definitions text referencing the Possible links page cleaned up. NOT yet tested in RStudio or pushed. **Open follow-up:** the "derived-link rule" paragraph in Assumptions & parameters help (app.R ~L649) still says "the tool draws a possible link…" — no longer true now derived links are gone; needs rewording (inc/inf parameters still drive the timeline shading, so the params themselves stay).

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
| 2026-06-17 | RStudio | RStudio was running app from Documents/network-diagram (unmanaged copy). Fixed by cloning to projects/network-diagram. Ensure RStudio always opens from that location. | No |
| 2026-06-17 | Versioning | Commit-count version number requires git in PATH — will not work in WebR. Needs a static fallback before Shinylive deployment. Action: fix before exporting main app. | No |
| 2026-06-17 | Deployment | Shinylive + GitHub Pages accepted (ADR-004). GitHub repo must be made public for free GitHub Pages. No patient data in repo — only app code and synthetic demo data. | Yes — using Pro account, repo stays private |
| 2026-06-18 | Deployment | plotly deprecation warning on startup: "Specifying width/height in layout() is now deprecated." Harmless but should be fixed — pass height to ggplotly() differently. | Yes — fixed session 9 (#1). Source was the timeline layout(height=) calls, not the epi curve; height already set on the plotlyOutput container, so layout height removed. |
| 2026-06-18 | Deployment | DiagrammeR permanently removed from app. ERD reference diagram (docs/erd.svg) still exists in repo but is no longer auto-generated on app startup. If schema changes, erd.svg must be updated manually or via a separate script. | No |
| 2026-06-18 | Phase 3a | CIMS_id format: Is it auto-generated or manually entered? What is the format/validation? | Deferred — Shiny app suspended; CIMS_id is free-text in Excel template for now |
| 2026-06-18 | Phase 3a | Main linelist structure: Which columns should the import function support? Which are optional? | Deferred — no import function in Excel approach |
| 2026-06-18 | Phase 3a | Archive procedure: Step-by-step workflow to backup and reset SQLite between outbreaks | Deferred — not applicable to Excel approach |
| 2026-06-18 | Architecture | Data entry approach: Excel on SharePoint (upload .xlsx to Shinylive viz app). Shiny data entry app suspended. Reasons: Shinylive can't write files; R-Portable viable but adds complexity; Power Apps requires Business 365 account not available on dev laptop. Excel is lower-risk for first outbreak. | Yes — session 6 |
| 2026-06-19 | Permissions | Security review of settings.local.json completed. `Bash(git *)` and `Bash(git push *)` removed — git push now prompts. `Bash(python3 *)`, `Bash(Rscript *)`, `Bash(powershell.exe *)` retained — accepted risk for local dev. Pending decision: narrow `powershell.exe *` to `powershell.exe -NoProfile -NonInteractive *` (would cover all actual usage, block interactive session). Resume this decision next session. | Yes — session 8: powershell.exe removed entirely (was one-off Obsidian task) |
| 2026-06-20 | Permissions | Full security overhaul completed (session 8). See log entry below. No outstanding decisions. | Yes |
| 2026-06-23 | Schema | `contacts` sheet dropped; `likely_index_case` (self-FK on cases) is the single source of transmission links. See ADR-006. | Yes — session 10 |
| 2026-06-23 | Schema | Data-dictionary drift NOT yet reconciled: (1) `cases` schema in CLAUDE.md predates the demographic fields (CIMS_id, forename, surname, date_of_birth, age, postcode) now in data-dictionary.md and the template; (2) the case-context relevance field is named variously `visit_relevance` (CLAUDE.md), `epi_category` (data-dictionary.md) and `exposure_relevance` (app.R), and is documented as *derived* but is actually *stored/manually entered*. Needs one reconciliation pass + decision on the canonical name. | No |

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
| `docs/decisions/ADR-004` | Shinylive + GitHub Pages deployment approach | Accepted |
| `docs/decisions/ADR-005` | Excel on SharePoint for data entry; Shiny data entry app suspended | Accepted |
| `docs/decisions/ADR-006` | Transmission links on cases (`likely_index_case`); `contacts` sheet dropped | Accepted |
| `docs/data-model.md` | Phase 1 working notes | Closed |
| `docs/data-input.md` | Phase 3 working notes and data entry decision | Closed |
| `docs/network-types.md` | Phase 2 working notes | Closed — see ADR-003 |
| `docs/additional-features.md` | Candidate future views | Open |
