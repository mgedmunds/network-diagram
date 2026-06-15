# Network Diagram Types — Working Notes

Phase 2 working document. Tracks research and decisions about which network views to include.

---

## Views currently in the app

Internal IDs in parentheses — these are the values used in `input$view` in app.R.

### 1. Settings network (`projection`)
**What it shows:** Places connected by shared cases. Edge weight = number of shared cases.
**Epi purpose:** See which venues are linked through common cases — useful for identifying transmission clusters across settings.
**Status:** In app, keep/cut decision pending.

### 2. Who visited where (`bipartite`)
**What it shows:** Cases (dark dots) and settings (coloured squares) as separate node types. Each edge is a visit, coloured by timing relative to the case's infectious period and exposure window.
**Epi purpose:** Shows multi-setting cases directly and highlights which visits were epidemiologically relevant. See ADR-002 for visit category definitions.
**Status:** In app, keep/cut decision pending.

### 3. Who infected whom (`contacts`)
**What it shows:** Directed links from source case to recipient. Links from contacts sheet or derived from shared settings + timing.
**Epi purpose:** Who-infected-whom. Most directly useful for outbreak investigation.
**Status:** In app, keep/cut decision pending.

---

## Open questions

- [ ] Is the Settings network view adding value or is it redundant with Who visited where?
- [ ] Should Who infected whom always be shown, or only when contacts data is present?
- [ ] Is a temporal view worth adding, and if so does it replace the time slider or sit alongside it?
- [ ] What is the right default view when the app first loads?

## Decisions made

_Record decisions here as they are made, then move to a formal ADR if significant._

---

## Notes

