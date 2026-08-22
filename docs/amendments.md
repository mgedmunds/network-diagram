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

- [ ] **Contexts column — switch to manual paste instead of auto-fill (user preference).**
  Alternative to the current auto-populated `AGGREGATE` formula (B2.5 / commit 09c3f90):
  leave column AD blank in the generated template and instead put the contexts array
  formula in the README with step-by-step paste instructions — user pastes it into AD2,
  presses **Ctrl+Shift+Enter** (array entry — note: NOT Ctrl+Alt+Enter), then copies AD2
  down. Rationale (user): simpler to understand, matches a previous version.
  **DECISION FIRST:** test the auto `AGGREGATE` version — it should fill AD with no user
  action at all (no paste, no CSE), which is simpler for end users, so this may be
  unnecessary. If the manual approach is still preferred, implement by: removing the
  generated AD formula from `make_template.R`, and restoring a README paste section with the
  CSE `TEXTJOIN`/`MATCH` formula. *(requested: 2026-08-22)*

- [ ] Upload confirmation box: add a succinct, reassuring privacy statement to the green success alert shown after a file is uploaded (`output$upload_summary`). It should make clear the data stayed on the user's device / in their browser and was not sent outside the organisation's IT infrastructure. Proposed wording (confirm against deployment before using): "Your file was read directly in your web browser on this device — it is not sent to any server and does not leave your organisation's IT environment." *(IMPORTANT — factual accuracy depends on deployment: TRUE for the Shinylive/GitHub Pages browser-only build (WebR); NOT true if the app is ever hosted on a Shiny server, where uploads go to that server. Word it to match the actual deployment model before release.)* *(requested: 2026-06-20)*

---

## Awaiting verification

- [ ] **Batch 2 (B2.1–B2.9)** — implemented and committed on `amendments-batch-2`
  (2026-08-22), not yet tested in RStudio/Excel. Verify: template regenerates; Dropdowns
  tab lists + maroon headers; cases dropdowns work; row/column resizing; and **especially
  B2.5** — that the `contexts` column (AD) fills correctly in Excel. NOTE: the first array
  version came out blank (openxlsx doesn't write the array flag reliably); it was reworked
  to an ordinary `AGGREGATE`-based formula (no Ctrl+Shift+Enter, shows up to 10 contexts).
  Re-verify AD now populates. Then run the app and confirm category ordering follows the
  Dropdowns lists.

- [ ] **Batch 3** — implemented and committed on `amendments-batch-2` (2026-08-22), not yet
  tested. B3.1 filter + B3.2 sort enabled on cases/contexts; header + `case_id` column
  frozen on cases. B3.3 = ADR-007: `case_id`/`context_id` now manual UIDs. Verify in Excel:
  a duplicate or wrong-format ID turns red (flagged, not rejected — openxlsx has no custom
  validation); the rest of a row greys out until its ID is entered; sort + filter work; and the ID dropdowns on
  case_contexts/visit_dates list only the real cases/contexts (not 1,000 blanks). Confirm
  the demo data (with real C-### / Ctxt-### IDs) still uploads and the app reads it.

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
