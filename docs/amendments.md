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

### Batch 4 — template tweaks (requested 2026-08-22, not started)

- [ ] **B4.1 Add "Unknown" to `exposure_relevance`** (case_contexts sheet). Dropdown is
  currently hardcoded `"Infectious period,Exposure window,Both,Neither"` in
  `make_template.R`; add `Unknown`. CHECK the app's edge-categorisation/colour logic in
  `app.R` handles an unrecognised value gracefully (likely treat `Unknown` like `Neither` /
  no transmission-relevant edge) and update it if needed, plus the data-dictionary
  `exposure_relevance` values.

- [ ] **B4.2 Remove the "Instructions" link** to the right of each data sheet (added as B2.8
  last session). Remove the `instr_link()` helper + its four calls in `make_template.R`
  (and the now-unused `readme_row_*` lookups if nothing else uses them). The README section
  headings can stay. (User reversed the B2.8 decision.)

- [ ] **B4.3 Add a `context_notes` column** to the contexts sheet (free text). Update
  `make_template.R`: headers `c("context_id","context_name","context_type","context_notes")`,
  col_widths, demo data, unlocked styling, the blank-row grey-out range, and the
  `ContextsRange` named region (cols 1:3 -> 1:4). App reads contexts by column name so the
  extra column is safe (no app change needed). Add the field to `docs/data-dictionary.md`.

- [ ] Upload confirmation box: add a succinct, reassuring privacy statement to the green success alert shown after a file is uploaded (`output$upload_summary`). It should make clear the data stayed on the user's device / in their browser and was not sent outside the organisation's IT infrastructure. Proposed wording (confirm against deployment before using): "Your file was read directly in your web browser on this device — it is not sent to any server and does not leave your organisation's IT environment." *(IMPORTANT — factual accuracy depends on deployment: TRUE for the Shinylive/GitHub Pages browser-only build (WebR); NOT true if the app is ever hosted on a Shiny server, where uploads go to that server. Word it to match the actual deployment model before release.)* *(requested: 2026-06-20)*

---

## Awaiting verification

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
