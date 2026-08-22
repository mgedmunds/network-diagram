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

- [ ] Upload confirmation box: add a succinct, reassuring privacy statement to the green success alert shown after a file is uploaded (`output$upload_summary`). It should make clear the data stayed on the user's device / in their browser and was not sent outside the organisation's IT infrastructure. Proposed wording (confirm against deployment before using): "Your file was read directly in your web browser on this device — it is not sent to any server and does not leave your organisation's IT environment." *(IMPORTANT — factual accuracy depends on deployment: TRUE for the Shinylive/GitHub Pages browser-only build (WebR); NOT true if the app is ever hosted on a Shiny server, where uploads go to that server. Word it to match the actual deployment model before release.)* *(requested: 2026-06-20)*

---

## Awaiting verification

- [ ] **Batch 2 (B2.1–B2.9)** — implemented and committed on `amendments-batch-2`
  (2026-08-22), not yet tested in RStudio/Excel. Verify: template regenerates; Dropdowns
  tab lists + maroon headers; cases dropdowns work; row/column resizing; and **especially
  B2.5** — that the `contexts` column (AD) fills correctly in Excel rather than showing
  blank/0 (openxlsx array-formula write is the known risk). If B2.5 fails, fall back to the
  README recovery-formula note. Then run the app and confirm category ordering follows the
  Dropdowns lists.

- [ ] **Batch 3** — implemented and committed on `amendments-batch-2` (2026-08-22), not yet
  tested. B3.1 filter + B3.2 sort enabled on cases/contexts; header + `case_id` column
  frozen on cases. B3.3 = ADR-007: `case_id`/`context_id` now manual UIDs. Verify in Excel:
  typing a duplicate or wrong-format ID is rejected; a pasted duplicate turns red; the rest
  of a row greys out until its ID is entered; sort + filter work; and the ID dropdowns on
  case_contexts/visit_dates list only the real cases/contexts (not 1,000 blanks). Confirm
  the demo data (with real C-### / Ctxt-### IDs) still uploads and the app reads it.

---

## Parked (needs decision or not urgent)

- [ ] UI: node selector resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour. Reassess once the move-to-sidebar item is done. *(requested: 2026-06-19)*

- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised. *(requested: 2026-06-18)*

- [ ] Candidate network — visit timing risk ranking: develop a ranking system for candidate transmission pairs based on timing and nature of shared context visits (infectious period overlap, exposure window, proximity of visit dates). Use this to tier or filter the candidate network list. Significant design work needed before implementation. *(requested: 2026-06-19)*
