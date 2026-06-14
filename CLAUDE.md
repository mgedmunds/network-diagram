# Measles Outbreak Network Explorer — Project Brief for Claude

## What this is

An interactive R Shiny dashboard for visualising a measles outbreak as a network.
The primary users are **public health / outbreak investigation teams** who are not
technically trained. Everything must be explainable to a non-statistician.

The tool takes structured outbreak data (linelist, visits, contacts) and produces
interactive network diagrams showing how cases and settings are connected, alongside
an epidemic curve, network metrics, and editable epidemiological parameters.

This is currently a **working prototype under active development**. It is not yet
deployed for real use. Development is tracked via the in-app Dev Panel tab (to be
removed before release — task 7.4).

---

## Current development phase

Working through a 7-phase plan. Check the Dev Panel tab in the running app or
`dev_progress.json` for current status. Phases run roughly in order:

1. Data Model & Schema — define required fields, validation, data dictionary
2. Network Diagram Types — decide which views to keep, document their epi purpose
3. Data Collection Interface — manual entry forms, export
4. Definitions, Tooltips & Help — consistent, plain-language explanations throughout
5. Epi Parameters & Assumptions — validate defaults, add citations, input validation
6. UI & UX Polish — layout, accessibility, performance
7. Pre-Release — cleanup, final review, remove dev panel

---

## Repository structure

```
app.R                  # Single-file Shiny app — all UI and server code
dev_progress.json      # Dev panel task statuses and notes (auto-generated, gitignored candidate)
action_tracker.json    # Action tracker entries (auto-generated, gitignored candidate)
docs/decisions/        # Architecture Decision Records (ADRs) — create when needed
CLAUDE.md              # This file
```

The app is intentionally a single file (`app.R`) for now. Do not split into
`ui.R` / `server.R` or a module structure unless explicitly asked — it adds
navigation overhead during rapid prototyping.

---

## Data model

Three input sheets (from `.xlsx` upload or demo data):

### linelist — one row per case
| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | character | yes | unique identifier |
| `onset_date` | date | yes | drives time slider, epi curve, infectious-period logic |
| `age_group` | character | no | e.g. "0-4", "5-11", "12-17", "18+" |
| `vaccination_status` | character | no | e.g. "Unvaccinated", "1 dose", "2 doses", "Unknown" |

### visits — one row per case-setting visit
| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | character | yes | foreign key to linelist |
| `setting_name` | character | yes | free text place name |
| `setting_type` | character | yes | one of: School, Healthcare, Community, Household, Other |
| `visit_date` | date | no | if absent, visit timing classification is skipped |

### contacts — one row per recorded transmission link (optional sheet)
| Field | Type | Required | Notes |
|---|---|---|---|
| `from` | character | yes | source case_id |
| `to` | character | yes | recipient case_id |
| `link_type` | character | yes | "Confirmed" or "Suspected" |

> **Note:** The data model is still being finalised in Phase 1. Do not add new
> fields or change column names without confirming first.

---

## Network views

Three views selectable from a dropdown in the network card header:

| View | ID | Description |
|---|---|---|
| Settings ↔ settings | `"projection"` | Bipartite projection onto settings; edge weight = shared cases |
| Cases × settings | `"bipartite"` | True bipartite; edges coloured by infectious/exposure/other |
| Case-to-case | `"contacts"` | Transmission links from contacts sheet or derived from timing |

**Which views to keep is an open decision (Phase 2).** Do not add new views or
remove existing ones without being asked.

---

## Epidemiological parameters (measles defaults)

All editable live in the "Assumptions & parameters" tab:

| Parameter | Default | Meaning |
|---|---|---|
| `inc_min` | 7 days | Incubation period minimum (exposure → onset) |
| `inc_max` | 21 days | Incubation period maximum |
| `inf_before` | 4 days | Infectious period: days before onset |
| `inf_after` | 4 days | Infectious period: days after onset |

Derived rule for suspected case-to-case links: onset gap must be between
`(inc_min - inf_before)` and `(inc_max + inf_after)` days.

---

## R packages in use

| Package | Purpose |
|---|---|
| `shiny` | App framework |
| `bslib` | Bootstrap 5 UI components (cards, layout, tooltips) |
| `visNetwork` | Interactive network diagrams (wraps vis.js) |
| `igraph` | Network metric calculation (degree, betweenness) |
| `plotly` / `ggplot2` | Epidemic curve |
| `DT` | Interactive data tables |
| `dplyr`, `tidyr`, `purrr`, `tibble` | Data wrangling |
| `readxl` | Excel file import |
| `lubridate` | Date handling |
| `jsonlite` | Dev panel / action tracker JSON persistence |

---

## Conventions — always follow these

- **UI components:** use `bslib` cards (`card()`, `card_header()`, `card_body()`),
  `layout_columns()`, and `layout_sidebar()`. Do not use raw Bootstrap divs for
  layout unless bslib has no equivalent.
- **Tooltips:** use the `info()` helper (defined near the top of app.R) for all ⓘ
  icon tooltips. Use `hdr()` for card headers that need a tooltip.
- **Setting colours:** always use the `setting_colours` named vector. Do not
  hardcode hex colours for setting types anywhere else.
- **Reactive pattern:** keep data loading in `raw()`, filtering in `filtered()`,
  network building in `netdata()`. Do not add new top-level reactives for data
  that fits this chain.
- **Demo data:** the `make_demo_data()` function must always return valid data
  matching the current schema. Update it whenever the schema changes.
- **Single file:** all code stays in `app.R` until explicitly asked to split.
- **Dev panel code:** clearly marked with `# ---- Dev panel` and
  `# ---- Action tracker` section comments. Do not interleave with main app logic.

---

## Conventions — never do these without being asked

- Do not split `app.R` into modules or separate files
- Do not change the bslib theme (`flatly`) or Bootstrap version (5)
- Do not add new R package dependencies without flagging it
- Do not refactor working code as part of a bug fix or feature addition
- Do not add explanatory comments describing *what* code does — only *why* if the
  reason is non-obvious
- Do not change the `setting_colours` palette
- Do not alter the dev panel task list (DEV_TASKS) without being asked

---

## Git workflow

- Branch `main` is the stable baseline
- Feature work goes on named branches (e.g. `control-panel`, `data-entry-forms`)
- Commit after each logical unit of work with a clear message
- Push branches to GitHub; open a PR to merge into `main` when a phase is complete
- `dev_progress.json` and `action_tracker.json` may be worth adding to `.gitignore`
  once a decision is made — they are machine-written and will create noisy diffs

---

## Key design principles

1. **Non-technical users first.** Every label, tooltip, and summary sentence must be
   understandable without a statistics background. Avoid jargon; when unavoidable,
   define it in the Definitions tab.
2. **Epidemiological correctness.** The tool is used during real outbreak
   investigations. Do not simplify in a way that could mislead an investigator.
3. **Parameters visible, not hidden.** The infectious and incubation period defaults
   are shown and editable. The logic behind derived links is documented. Nothing
   should happen silently.
4. **Prototype discipline.** Features are added one phase at a time. Do not jump
   ahead to Phase 3 work while Phase 1 is open.
