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

*(Batch 4 — B4.1–B4.4 — implemented 2026-11-27 on branch `amendments-batch-4`; now in "Awaiting verification" below.)*

---

## Awaiting verification

- [ ] **Timeline shows epi windows without visit dates** (2026-11-27, on
  `amendments-batch-4`, commit `97894b5`). The timeline no longer blanks when a node has no
  visit dates — it falls back to `case_contexts` links to draw the onset date and the
  exposure/infectious windows (derived from onset + the epi parameters), omitting the visit
  dots. Verify: with the no-visit-dates file, select a **case** → timeline shows one row per
  linked context with the coloured windows + dashed onset line, no grey dots; select a
  **context** → one row per linked case with windows + onset. Then load a file *with* visit
  dates and confirm the dots and layout are unchanged.

- [ ] **Empty visit_dates crash fix** (2026-11-27, on `amendments-batch-4`, commit
  `57612a7`). An uploaded file with an **empty visit_dates sheet** crashed the app silently
  (readxl typed the 0-row sheet's `case_id`/`context_id` as logical → the `flat_visits()`
  `left_join` failed on incompatible key types inside an observer → session teardown). Fix:
  coerce all four tables' join keys to character after reading; plus an upload-summary note
  when no visit dates are present. Verify: upload a file with cases + contexts +
  case_contexts populated but **visit_dates empty** → app loads, network draws, amber "no
  visit dates yet" note shows; then add visit dates → full behaviour returns.

- [ ] **Batch 4 (B4.1–B4.4)** — implemented and committed on `amendments-batch-4`
  (2026-11-27, based on `coding-standards-tidyverse`), not yet tested in RStudio/Excel.
  Verify: (B4.2) the per-sheet "Instructions" links are gone from the template and the
  README reads cleanly; (B4.3) the contexts sheet has a 4th `context_notes` free-text
  column that greys out with the rest of the row until `context_id` is entered;
  (B4.1) the `case_contexts` `exposure_relevance` dropdown now offers `Unknown`, and in
  the app's *Who visited where* view **Neither = solid black** and **Unknown = grey
  dashed**, with both in the floating legend; (B4.4) with **no file uploaded** the
  Network model / Source data / timeline show "Upload your outbreak data on the Home tab
  to begin." instead of rendering (no errors), and uploading the template still works.
  Run `tools/make_template.R` in RStudio first (confirm it regenerates clean), then
  `shiny::runApp()`.

- [ ] **Upload privacy statement** — implemented on branch `amendments-privacy-statement`
  (2026-08-22). `app.R` now shows "your file was read directly in your web browser … does
  not leave your organisation's IT environment" in the upload-success box ONLY when running
  under WebR (`IS_BROWSER_ONLY`, detected via `R.version$os == "emscripten"`). Fail-safe:
  silent on normal R. NOTE: in **local RStudio it will NOT appear** (that is correct — it is
  not the browser build); to actually see it, check the **deployed Shinylive build**. Verify:
  (1) local RStudio — app runs, upload works, no privacy line; (2) Shinylive — line appears.

- [ ] **Batch 2 (B2.1–B2.9)** — implemented and committed on `amendments-batch-2`
  (2026-08-22), not yet tested in RStudio/Excel. Verify: template regenerates; Dropdowns
  tab lists + maroon headers; cases dropdowns work; row/column resizing; and **especially
  B2.5** — contexts column. RESOLVED 2026-08-22: auto-fill abandoned (both array and
  AGGREGATE versions came out blank — openxlsx can't reliably write array formulas). AD is
  now left blank; the README has a one-off manual paste (CSE `TEXTJOIN`/`MATCH`, confirmed
  working by the user). Verify the README steps read clearly. Then run the app and confirm
  category ordering follows the Dropdowns lists.

- [ ] **Batch 3** — implemented and committed on `amendments-batch-2` (2026-08-22), not yet
  tested. B3.1 filter + B3.2 sort enabled on cases/contexts; header + `case_id` column
  frozen on cases. B3.3 = ADR-007: `case_id`/`context_id` now manual UIDs. Verify in Excel:
  a duplicate or wrong-format ID turns red (flagged, not rejected — openxlsx has no custom
  validation); the rest of a row greys out until its ID is entered; sort + filter work; and the ID dropdowns on
  case_contexts/visit_dates list only the real cases/contexts. FIXED 2026-08-22: the ID
  dropdowns listed ~1,000 blank rows because their `OFFSET` used `COUNTA` (which counts the
  pre-sized empty-string cells); switched to `COUNTIF(range,"?*")`, which counts only cells
  with real text. Re-verify the pickers now show only entered IDs. Confirm the demo data
  (with real C-### / Ctxt-### IDs) still uploads and the app reads it.

---

## Parked (needs decision or not urgent)

- [ ] **Epi-window anchor date — symptom onset vs rash onset (epi correctness — CHECK).**
  `exposure_window` and `infectious_period` are currently calculated from `onset_date`
  (symptom onset) — both in the template formulas (col M) and in the app's timeline / epi-
  window logic (the inc/inf parameters are applied relative to `onset_date`). Measles
  guidance usually anchors the **infectious period on RASH onset** (commonly 4 days before
  to 4 days after rash), and incubation is often measured to rash onset too — so
  `date_of_rash` (col N) may be the correct anchor, possibly for both windows.
  **DECISION NEEDED:** confirm against UKHSA measles guidance which date each window should
  use (the two windows may differ). If rash onset: switch the template formulas from M to N
  and update the app's epi-window logic, with a sensible fallback to symptom onset where
  rash date is missing. Likely warrants an ADR once decided. *(raised 2026-08-22)*

- [ ] UI: node selector resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour. Reassess once the move-to-sidebar item is done. *(requested: 2026-06-19)*

- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised. *(requested: 2026-06-18)*

- [ ] Candidate network — visit timing risk ranking: develop a ranking system for candidate transmission pairs based on timing and nature of shared context visits (infectious period overlap, exposure window, proximity of visit dates). Use this to tier or filter the candidate network list. Significant design work needed before implementation. *(requested: 2026-06-19)*
