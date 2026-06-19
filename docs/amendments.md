# Amendment log

Add items here during app review. Claude reads this at session start and works
through the "Ready to action" list. No categories needed — describe the problem
in plain English. Items are deleted once the fix is committed.

---

## Ready to action

- [ ] Bug: plotly deprecation warning on app startup — "Specifying width/height in layout() is now deprecated." Comes from the epi curve (ggplotly conversion). Fix by passing height via ggplotly() directly rather than layout().

- [ ] Timeline legend (case selected): when a case is highlighted, the legend only shows "Visit date". Add "Exposure window", "Infectious period", and "Onset date" entries to the legend as well.

- [ ] Node selector: move the "Select node" dropdown from the network card header into the left sidebar, below the case status checkboxes. Dropdown must be wide enough to display 30 characters without truncating.

- [ ] Timeline card: rename "Expand" / "Collapse" button to "Maximise" / "Minimise" to match the Network window button wording.

- [ ] Onset date filter: add a "date from" and "date to" text entry field between the "Filter by onset date" label and the slider, so specific dates can be typed rather than only dragged.

- [ ] Data page: add a small filter-summary banner at the top of the page showing what the current filters are (date range, context types, case confidence). Add a note that filters are changed on the Network model tab. No sidebar restructure.

- [ ] Source data page: add a heading and brief plain-language description explaining what the tab shows. Also add the contexts table as a fourth table (currently missing). Confirm whether all uploaded data is represented — answer: yes, except contexts is not currently shown.

- [ ] Epi curve: add an option (dropdown) to colour-code bars by case attribute — vaccination status, gender, or case confidence. One grouping at a time.

- [ ] Terminology: rename "case status" / "Case status" to "case confidence" / "Case confidence" everywhere in the app UI, sidebar, tooltips, data dictionary, and Excel template (column heading, dropdown label, README). The underlying field name case_status in the data schema is unchanged — display labels only.

- [ ] Line list table: increase height so that both column headings and the page-navigation controls are visible without scrolling, including when the horizontal scrollbar is present.

- [ ] Epi curve: add a dynamic descriptive title covering time, place, and person — e.g. include the active date range if filtered, any active context filter, and the case confidence selection (e.g. "Confirmed and probable cases"). Add a label to the x-axis.

- [ ] Home page: after a file is uploaded, show a brief record count summary beneath the upload widget (number of cases, contexts, and visit dates loaded). Add a sentence pointing users to the Source Data tab to view all imported data.

- [ ] Rename "Dashboard" to "Network model" throughout — nav tab label and all in-app references.

- [ ] Reference tab: move the Definitions, How to use, and Assumptions & parameters pages out of the top navigation bar and into the Reference tab as sub-tabs (alongside the existing data dictionary tabs). Reduces top-nav clutter and groups all supporting content in one place.

---

## Parked (needs decision or not urgent)

- [ ] UI: node selector resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour. (Note: linked to the move-to-sidebar item above — reassess once that is done.)

- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised.

- [ ] Candidate network — visit timing risk ranking: develop a ranking system for candidate transmission pairs based on timing and nature of shared context visits (infectious period overlap, exposure window, proximity of visit dates). Use this to tier or filter the candidate network list. Significant design work needed before implementation — assess highest-risk visit combinations, agree a ranking approach, then decide what to flag on the candidate network.
