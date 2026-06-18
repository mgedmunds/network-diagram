# ADR-005: Excel on SharePoint for data entry (Shiny data entry app suspended)

**Status:** Accepted  
**Date:** 2026-06-18

## Decision

Use an Excel workbook hosted on SharePoint as the data entry interface for outbreak data; staff upload the completed `.xlsx` to the Shinylive visualisation app to analyse it.

## Alternatives considered

- **Shiny + SQLite, R-Portable launcher** — the preferred technical solution (strongest validation, bulk date entry, FK enforcement, concurrent writes). Ruled out because the launcher requires a `.bat` file that may be blocked by NHS Group Policy, and deployment to non-R users on NHS machines adds friction that cannot be tested or resolved from the developer's personal laptop.
- **Shiny + SQLite on shinyapps.io** — ruled out because patient data would leave the NHS network, which is a likely Information Governance / DSPT blocker.
- **Microsoft Power Apps + SharePoint Lists** — native to the NHS M365 ecosystem; would work well for non-R users. Ruled out because Power Apps development requires a Business 365 account, which the developer does not have on their personal laptop. Claude Code cannot interact with the Power Apps studio. This path cannot be built or tested in the current dev environment.
- **Shiny + SQLite, Shinylive deployment** — ruled out at a technical level: Shinylive runs in a browser sandbox and cannot write to any file on disk or a network share. Suitable for the read-only visualisation app only.

## Reasons

Excel is the only data entry option that can be:

1. **Developed and tested entirely on the developer's personal laptop** using Claude Code and RStudio, with no dependency on NHS IT infrastructure or licensed cloud services.
2. **Used by non-R NHS staff** with no installation — the workbook opens in desktop Excel or Excel Online via SharePoint.
3. **Stored within the NHS SharePoint governance boundary** — no patient data leaves the organisation's environment.
4. **Built to a useful standard quickly** — the existing `make_template.R` script already produces a structured, validated workbook; the Phase 1 field upgrades were a single session of work.

The most significant capability lost relative to the Shiny app is bulk visit-date entry. This is partially mitigated by the Date Helper tab in the upgraded template (generates up to 60 consecutive dates for a case × context pair; weekends shaded for easy exclusion; copy-paste to visit_dates). The remaining manual overhead is accepted as a trade-off for the simpler, more deployable solution.

## Consequences

- **Paste bypasses validation.** Excel data validation (dropdowns, date checks) is enforced on manual entry but not on paste. Staff must be briefed not to paste raw data into validated columns. FK integrity (case_id, context_id cross-references) is not enforced at the database level — errors will surface when the file is uploaded to the app.
- **No row-level audit trail.** SharePoint provides file-level version history but not a record of who entered or changed individual rows. Acceptable for outbreak timescales; would be a gap for longer-term surveillance use.
- **No concurrent-write protection.** SharePoint co-authoring handles simultaneous edits to different rows acceptably, but two users editing the same row simultaneously will produce a last-write-wins conflict with no warning. With 3–4 users, the risk is low if staff work on separate cases.
- **Date entry remains more manual than the Shiny design.** The Date Helper tab reduces the burden substantially but does not eliminate it. For large outbreaks (>100 cases, >10 contexts each) this may become a bottleneck; at that scale revisiting the R-Portable launcher approach would be warranted.
- **The Shiny data entry app design (Phase 3a docs) is preserved** in `docs/` and remains a viable upgrade path if the IT/deployment constraints change in future outbreaks.
