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

- [ ] Excel template (tools/make_template.R): add a "primary context type" column to the cases sheet, placed at a logical position next to the other context-related columns (currently `likely_index_case` and `contexts`, columns M–N). Update the column headers, example row, column widths, the locked/dropdown formatting, and the README/notes and data dictionary to match. *(Clarify when actioned: should it be a dropdown of the Lookups context types, free text, or derived? Does the app need to read it, i.e. add to the cases schema?)* *(requested: 2026-06-20)*

- [ ] Upload confirmation box: add a succinct, reassuring privacy statement to the green success alert shown after a file is uploaded (`output$upload_summary`). It should make clear the data stayed on the user's device / in their browser and was not sent outside the organisation's IT infrastructure. Proposed wording (confirm against deployment before using): "Your file was read directly in your web browser on this device — it is not sent to any server and does not leave your organisation's IT environment." *(IMPORTANT — factual accuracy depends on deployment: TRUE for the Shinylive/GitHub Pages browser-only build (WebR); NOT true if the app is ever hosted on a Shiny server, where uploads go to that server. Word it to match the actual deployment model before release.)* *(requested: 2026-06-20)*

---

## Parked (needs decision or not urgent)

- [ ] UI: node selector resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour. Reassess once the move-to-sidebar item is done. *(requested: 2026-06-19)*

- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised. *(requested: 2026-06-18)*

- [ ] Candidate network — visit timing risk ranking: develop a ranking system for candidate transmission pairs based on timing and nature of shared context visits (infectious period overlap, exposure window, proximity of visit dates). Use this to tier or filter the candidate network list. Significant design work needed before implementation. *(requested: 2026-06-19)*
