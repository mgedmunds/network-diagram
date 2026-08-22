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

- [ ] Excel template (tools/make_template.R) — expand the cases sheet into a usable master linelist, reorder columns into a logical case-management flow, and colour-code the headers. Approved column order and spec (requested: 2026-08-22):

  **Header colour:** maroon (`#800000` or similar) = fields the network tool reads; dark blue (existing `#2C3E50`) = external collection fields. Maroon set: `case_id`, `onset_date`, `age_group`, `gender`, `vaccination_status`, `case_status`, `likely_index_case`. All header names stay protected from editing (sheet protection already covers row 1); maroon headers must match exactly for upload.

  **Feasibility note:** app.R reads the cases sheet by column NAME (see `raw()`, ~app.R:1315), so extra columns are ignored safely — no app.R change, no upload risk. These new fields are external-only.

  **Approved column order (31 cols):**
  1. case_id [maroon, locked auto] · 2. CIMS_id · 3. forename · 4. surname · 5. date_of_birth [date] · 6. age [locked formula] · 7. age_group [maroon, locked formula] · 8. gender [maroon, dropdown] · 9. ethnicity [dropdown — ONS lookup] · 10. postcode · 11. utla [free text] · 12. report_date [date] · 13. onset_date [maroon, date] · 14. date_of_rash [date] · 15. exposure_window [locked formula, single col, date range "dd/mm/yyyy – dd/mm/yyyy", onset−21 to onset−7] · 16. infectious_period [locked formula, single col, onset−4 to onset+4] · 17. case_status [maroon, dropdown — shown as "Case confidence"] · 18. genotype [free text] · 19. confirmation_test_result [dropdown] · 20. vaccination_status [maroon, dropdown] · 21. vaccination_confirmation_method [dropdown] · 22. vaccination_notes [text] · 23. travel_history [dropdown Y/N/Unknown] · 24. travel_history_details [text] · 25. likely_index_case [maroon, dropdown] · 26. probable_epi_link [dropdown Y/N/Unknown] · 27. total_contacts [whole number] · 28. vulnerable_contacts [whole number] · 29. primary_context_type [maroon, dropdown — Lookups context types] · 30. contexts [locked derived formula] · 31. status [dropdown Open/Closed] · 32. date_closed [date]

  **Dropdown option lists:**
  - confirmation_test_result: Saliva IgM positive, Saliva IgM negative, Serum IgM positive, Serum IgM negative, PCR positive, PCR negative, Not tested, Pending
  - vaccination_confirmation_method: CHIS, GP, Occupational Health, Parent/guardian, Other, Unknown
  - travel_history: Yes, No, Unknown
  - probable_epi_link: Yes, No, Unknown
  - status: Open, Closed
  - ethnicity: ONS 2021 census category list (add as a new Lookups list; dropdown references it)
  - genotype: free text (no dropdown for now)

  **Calculated fields (locked, blue):** exposure_window and infectious_period are Excel formulas from onset_date using the FIXED measles defaults (inc 21–7, inf ±4). The tool's editable parameters do not flow back into the sheet — accepted limitation. Each is a single column showing a date range.

  **Also update:** example/demo row values for the new columns (fictional 20-case set); col_widths; locked/unlocked styling; date_cols; dropdown/validation lists; whole-number validation on the two contact-count fields; README (dropdown fields list, colour-key note explaining maroon vs blue, calculated-field note); and `docs/data-dictionary.md` (add all new fields marked "external collection — not read by the tool").

  *(requested: 2026-08-22)*

- [ ] Excel template + app schema — add `primary_context_type` to the cases sheet (folded into the reorder above as column 29, before `contexts`). DECIDED 2026-08-22: dropdown sourced from the Lookups context types; MAROON (the app reads it); "store only for now" — no view uses it yet (per user, avoids a speculative feature). This is a SCHEMA CHANGE, so in the same commit update: `app.R` (`make_demo_data()` to include the field + `raw()`/schema so it is ingested), the cases schema table in `CLAUDE.md`, `docs/data-dictionary.md` (mark as tool field, currently stored-not-used), and the template dropdown/formatting. *(requested: 2026-06-20; scoped 2026-08-22)*

- [ ] Upload confirmation box: add a succinct, reassuring privacy statement to the green success alert shown after a file is uploaded (`output$upload_summary`). It should make clear the data stayed on the user's device / in their browser and was not sent outside the organisation's IT infrastructure. Proposed wording (confirm against deployment before using): "Your file was read directly in your web browser on this device — it is not sent to any server and does not leave your organisation's IT environment." *(IMPORTANT — factual accuracy depends on deployment: TRUE for the Shinylive/GitHub Pages browser-only build (WebR); NOT true if the app is ever hosted on a Shiny server, where uploads go to that server. Word it to match the actual deployment model before release.)* *(requested: 2026-06-20)*

---

## Parked (needs decision or not urgent)

- [ ] UI: node selector resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour. Reassess once the move-to-sidebar item is done. *(requested: 2026-06-19)*

- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised. *(requested: 2026-06-18)*

- [ ] Candidate network — visit timing risk ranking: develop a ranking system for candidate transmission pairs based on timing and nature of shared context visits (infectious period overlap, exposure window, proximity of visit dates). Use this to tier or filter the candidate network list. Significant design work needed before implementation. *(requested: 2026-06-19)*
