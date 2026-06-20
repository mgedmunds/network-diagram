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

- [ ] Timeline legend (case selected): when a case is highlighted, the legend only shows "Visit date". Add "Exposure window", "Infectious period", and "Onset date" entries to the legend as well. *(requested: 2026-06-19)*

- [ ] Node selector: move the "Select node" dropdown from the network card header into the left sidebar, below the case status checkboxes. Dropdown must be wide enough to display 30 characters without truncating. *(requested: 2026-06-19)*

- [ ] Timeline card: rename "Expand" / "Collapse" button to "Maximise" / "Minimise" to match the Network window button wording. *(requested: 2026-06-19)*

- [ ] Onset date filter: add a "date from" and "date to" text entry field between the "Filter by onset date" label and the slider, so specific dates can be typed rather than only dragged. *(requested: 2026-06-19)*

- [ ] Data page: add a small filter-summary banner at the top of the page showing what the current filters are (date range, context types, case confidence). Add a note that filters are changed on the Network model tab. No sidebar restructure. *(requested: 2026-06-19)*

- [ ] Source data page: add a heading and brief plain-language description explaining what the tab shows. Also add the contexts table as a fourth table (currently missing). *(requested: 2026-06-19)*

- [ ] Line list table: increase height so that both column headings and the page-navigation controls are visible without scrolling, including when the horizontal scrollbar is present. *(requested: 2026-06-19)*

- [ ] Home page: after a file is uploaded, show a brief record count summary beneath the upload widget (number of cases, contexts, and visit dates loaded). Add a sentence pointing users to the Source Data tab to view all imported data. *(requested: 2026-06-19)*

---

## Parked (needs decision or not urgent)

- [ ] UI: node selector resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour. Reassess once the move-to-sidebar item is done. *(requested: 2026-06-19)*

- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised. *(requested: 2026-06-18)*

- [ ] Candidate network — visit timing risk ranking: develop a ranking system for candidate transmission pairs based on timing and nature of shared context visits (infectious period overlap, exposure window, proximity of visit dates). Use this to tier or filter the candidate network list. Significant design work needed before implementation. *(requested: 2026-06-19)*
