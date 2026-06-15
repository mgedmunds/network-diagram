# Network Diagram Types — Working Notes

Phase 2 working document. Tracks research and decisions about which network views to include.

---

## Views currently in the app

### 1. Settings ↔ settings (projection)
**What it shows:** Places connected by shared cases. Edge weight = number of shared cases.
**Epi purpose:** See which venues are linked through common cases — useful for identifying transmission clusters across settings.
**Status:** In app, keep/cut decision pending.

### 2. Cases × settings (bipartite)
**What it shows:** Cases (dark dots) and settings (coloured squares) as separate node types. Each edge is a visit.
**Epi purpose:** Shows multi-setting cases directly. Edge colour indicates whether visit was during infectious period (red), compatible exposure window (orange), or neither (grey).
**Status:** In app, keep/cut decision pending.

### 3. Case-to-case (transmission links)
**What it shows:** Directed links from source case to recipient. Links from contacts sheet or derived from shared settings + timing.
**Epi purpose:** Who-infected-whom. Most directly useful for outbreak investigation.
**Status:** In app, keep/cut decision pending.

---




## Candidate additional views

### Temporal network
Cases as nodes, positioned on a timeline by onset date. Edges drawn when timing is compatible with transmission.
- Adds a time dimension not visible in static layouts
- Could replace or complement the time slider

### Ego network
Focused view centred on a single selected case or setting, showing only its direct connections.
- Useful for drilling into a complex network
- Could be implemented as a filter on existing views rather than a new view

### Spatial / geographic
Cases or settings plotted on a map, edges drawn between linked nodes.
- Requires postcode / coordinates data not currently in the schema
- Significant additional data collection burden

---

## Open questions

- [ ] Is the settings-to-settings (projection) view adding value or is it redundant with bipartite?
- [ ] Should case-to-case always be shown, or only when contacts data is present?
- [ ] Is a temporal view worth adding, and if so does it replace the time slider or sit alongside it?
- [ ] What is the right default view when the app first loads?

## Decisions made

_Record decisions here as they are made, then move to a formal ADR if significant._

---

## Notes

