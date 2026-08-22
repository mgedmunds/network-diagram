# Amendment log

Add items here during app review. Claude reads this at session start and works
through the "Ready to action" list. Plain English, no special format needed.

**Conventions:**
- Each item is timestamped when requested and when completed.
- Completed items are removed from the list once the fix is committed; the completion
  date is recorded in the git commit message for traceability.
- Items are deleted from this file once done — use `git log` to see what was fixed and when.

---

## Ready to action

### Batch 2 — spreadsheet + lookups (requested 2026-08-22)

Decisions all settled in the 2026-08-22 session. Implement together. Items 1–3 and 5
touch `tools/make_template.R`; item 4 touches `app.R` (new Lookups read). Not yet started.

- [ ] **B2.1 Relax cases-sheet locking / editing.** Keep the six auto-formula columns
  locked (case_id, age, age_group, exposure_window, infectious_period, contexts) — DECIDED
  keep locked. Keep **row-deletion blocked** (row-position IDs) — DECIDED keep blocked.
  **Enable row and column resizing** (currently blocked by sheet protection — set
  `lockFormattingRows = FALSE`, `lockFormattingColumns = FALSE` on `protectWorksheet`).

- [ ] **B2.2 All categorical dropdowns → editable Lookups lists.** Retain categorical
  validation on every categorical field, but move each currently-hardcoded list onto its
  own editable column on the Lookups tab (same pattern as Setting Types / Ethnicity), with
  the dropdown reading it via `OFFSET`. Lists to move: gender, case_status (Case
  confidence), confirmation_test_result, vaccination_status,
  vaccination_confirmation_method, travel_history, probable_epi_link, status.
  (ethnicity + Setting Types already do this.) The Dropdowns tab becomes purely labelled
  list columns — the old "About this tab" instructions column is removed (see B2.9), so the
  editing guidance now lives only in the README. Update README dropdown-fields note.

- [ ] **B2.3 Add "Discarded" to the `status` list** → Open / Closed / Discarded (case
  management status; the "mark discarded instead of deleting the row" option). `status` is
  an external-only field — app does not read it.

- [ ] **B2.4 Lookups drive display order for the app-used lookups only.** MAROON-colour
  **two** Lookups columns — `Setting Types` (→ context_type / primary_context_type) and
  `Case confidence` (→ case_status) — with a note: *"These lists set the display order used
  by the network tool — don't rename the headers."* `app.R` gains one
  `read_excel(file, sheet = "Lookups")` and selects those two columns **by header name**
  (readxl can't address named tables/ranges — match by header, same contract as the maroon
  case columns). Category display order = row order in those columns. Fallbacks: if the
  Lookups sheet is absent, order by first-appearance in the data; if a data value isn't in
  the list, append it after the listed values (never hide it). Gender and Vaccination
  status lists stay DARK BLUE / not read by the app for now (DECIDED: don't include at
  present). Main app spot to change: the case_status filter (app.R:1410–1414), which
  currently intersects with a hardcoded `c("Confirmed","Probable","Possible")` and would
  otherwise drop new values like "Discarded".

- [ ] **B2.5 Pre-populate the derived `contexts` column (AD).** Write the validated
  contexts formula into AD2:AD1001 at generation time via `openxlsx::writeFormula(...,
  array = TRUE)` (CSE array formula — the Excel-2019-compatible TEXTJOIN/MATCH version, not
  the FILTER/XLOOKUP one). Keep the column locked + light-blue like the other derived
  fields. Removes the manual copy-paste step from the README.
  Formula: `IF(A2="","",IFERROR(TEXTJOIN("; ",TRUE,IF(ISNUMBER(MATCH(A2&contexts!$A$2:$A$1001,case_contexts!$A$2:$A$2001&case_contexts!$B$2:$B$2001,0)),contexts!$B$2:$B$1001,"")),""))`
  **RISK:** openxlsx array-formula writing has been unreliable here before (why the column
  is currently left manual) — must verify in RStudio + Excel that AD opens correct, not
  blank/0, after generation. If openxlsx can't write it cleanly, fall back to keeping the
  README paste instructions.

- [ ] **B2.6 Rename the `Lookups` tab to `Dropdowns`.** Update every reference: all
  `OFFSET(Lookups!…)` dropdown formulas, the ethnicity/context-type OFFSET refs, the
  `createNamedRegion(sheet = "Lookups", … name = "ContextTypes")` call, the new
  `read_excel(file, sheet = "Lookups")` in app.R (B2.4), and all README text. Also update
  `docs/data-dictionary.md` / `CLAUDE.md` mentions.

- [ ] **B2.7 README overhaul.** Rewrite the README tab as a mix of plain-English prose and
  bullet lists (currently almost all bullets). Specific changes:
  - **Add a "Purpose of this spreadsheet" section** (prose): it is the main linelist for
    reporting of measles cases; can also be used alongside case management systems for the
    management of cases; fields highlighted in **maroon** can be used alongside a network
    analysis tool to visualise transmission pathways.
  - **Rework the "Dropdown fields" section** into instructions on how the lists on the
    Dropdowns tab are used to edit the categorical values available in the main case list.
    Say which lists are used by the network tool (Setting Types → context_type; Case
    confidence → case_status) and that editing those affects the **display order** in the
    tool. Warn that **if any option is renamed, existing linelist entries must be updated
    manually** to match (a rename does not propagate to cells already filled in).
  - **Add a "Records management" section:** cases should **not be deleted** from the list;
    instead set their `status` to **Discarded**, which can then be filtered out.
  - **Add a "Calculated fields" section** with descriptive text, and move the relevant
    calculated/auto-generated bullets out of the current RULES section into it (case_id,
    context_id, age, age_group, exposure_window, infectious_period, contexts).
  - **Remove the current "LOOKUPS TAB — managing context types" section** (superseded by
    the reworked Dropdown-fields instructions and the rename).

- [ ] **B2.8 "Instructions" link on each data sheet (Option B).** Add a locked,
  non-editable "Instructions" hyperlink on cases, contexts, case_contexts, visit_dates
  (not README), placed in the header row **immediately to the right of the last column**,
  jumping to that table's section in the README. Sits outside the data table so the data
  pull-in is unchanged (app reads by name, ignores the extra cell). Build with
  `openxlsx::makeHyperlinkString(sheet = "README", row = <section row>, col = 1, text =
  "Instructions")` written via `writeFormula`. DEPENDS ON B2.7 — needs the final README
  section row numbers as link targets. (Option A — a visible top-left banner row above the
  headers, needing `skip = 1` in the four app reads and a full row-shift in the template —
  DEFERRED; user may add later.)

- [ ] **B2.9 Remove the "About this tab" instructions column** from the Dropdowns tab
  (currently column B on the Lookups tab). The tab becomes purely labelled list columns;
  the editing guidance moves to the README (B2.7). Update `lookup_instructions` /
  `setColWidths` accordingly.

---

- [ ] Upload confirmation box: add a succinct, reassuring privacy statement to the green success alert shown after a file is uploaded (`output$upload_summary`). It should make clear the data stayed on the user's device / in their browser and was not sent outside the organisation's IT infrastructure. Proposed wording (confirm against deployment before using): "Your file was read directly in your web browser on this device — it is not sent to any server and does not leave your organisation's IT environment." *(IMPORTANT — factual accuracy depends on deployment: TRUE for the Shinylive/GitHub Pages browser-only build (WebR); NOT true if the app is ever hosted on a Shiny server, where uploads go to that server. Word it to match the actual deployment model before release.)* *(requested: 2026-06-20)*

---

## Parked (needs decision or not urgent)

- [ ] UI: node selector resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour. Reassess once the move-to-sidebar item is done. *(requested: 2026-06-19)*

- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised. *(requested: 2026-06-18)*

- [ ] Candidate network — visit timing risk ranking: develop a ranking system for candidate transmission pairs based on timing and nature of shared context visits (infectious period overlap, exposure window, proximity of visit dates). Use this to tier or filter the candidate network list. Significant design work needed before implementation. *(requested: 2026-06-19)*
