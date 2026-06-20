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

- [ ] Timeline panel (below the network diagram): (1) Normal view — keep the current initial height; when a case or context is selected and the plot extends beyond the bottom of the panel, show a single vertical scrollbar on the right (no duplicate scrollbar). (2) Maximise button — instead of filling the whole screen, grow the panel upward from the bottom just enough to fit the whole graph (including title and any horizontal scrollbar) within the window so no vertical scrollbar is needed; cap at viewport height (scrolls only if the graph is taller than the screen). *(requested: 2026-06-20)*

---

## Parked (needs decision or not urgent)

- [ ] UI: node selector resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour. Reassess once the move-to-sidebar item is done. *(requested: 2026-06-19)*

- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised. *(requested: 2026-06-18)*

- [ ] Candidate network — visit timing risk ranking: develop a ranking system for candidate transmission pairs based on timing and nature of shared context visits (infectious period overlap, exposure window, proximity of visit dates). Use this to tier or filter the candidate network list. Significant design work needed before implementation. *(requested: 2026-06-19)*
