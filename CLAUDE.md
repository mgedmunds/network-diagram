# Measles Outbreak Network Explorer — Project Brief for Claude

## What this is

An interactive R Shiny dashboard for visualising a measles outbreak as a network.
The primary users are **public health / outbreak investigation teams** who are not
technically trained. Everything must be explainable to a non-statistician.

The tool takes structured outbreak data (linelist, visits, contacts) and produces
interactive network diagrams showing how cases and contexts are connected, alongside
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

Five sheets (from `.xlsx` upload or demo data). Full field-level definitions are in `docs/data-dictionary.md`; ERD is in `docs/erd.svg`.

### cases — one row per case
| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | character | yes | unique identifier; PK |
| `onset_date` | date | yes | drives time slider, epi curve, infectious-period logic |
| `age_group` | character | no | fixed bands: `<1 year`, `1–4 years`, `5–17 years`, `18–29 years`, `30–49 years`, `50+` |
| `vaccination_status` | character | no | `Unvaccinated`, `1 dose`, `2 doses`, `Unknown` |

### contexts — one row per context
| Field | Type | Required | Notes |
|---|---|---|---|
| `context_id` | integer | yes | surrogate PK; join key throughout |
| `context_name` | character | yes | human-readable name |
| `context_type` | character | yes | user-defined categorical (not pre-coded) |

### case_contexts — one row per case × context combination
| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | character | yes | PK + FK → cases |
| `context_id` | integer | yes | PK + FK → contexts |
| `has_other_visits` | logical | no | TRUE = continuous presence outside epi windows (e.g. household) |

### visit_dates — one row per epi-relevant visit date
| Field | Type | Required | Notes |
|---|---|---|---|
| `case_id` | character | yes | PK + FK → case_contexts |
| `context_id` | integer | yes | PK + FK → case_contexts |
| `visit_date` | date | yes | one row per calendar day |

`epi_category` is derived at runtime (never stored): `Exposure window`, `Infectious period`, `Both`, `Neither`.

### contacts — one row per recorded transmission link (optional)
| Field | Type | Required | Notes |
|---|---|---|---|
| `from` | character | yes | source case_id; FK → cases |
| `to` | character | yes | recipient case_id; FK → cases |
| `link_type` | character | yes | `Confirmed` or `Suspected` |

---

## Network views

Three views selectable from a dropdown in the network card header:

| View | ID | Description |
|---|---|---|
| Contexts network | `"projection"` | Places linked by shared cases; edge weight = shared cases |
| Who visited where | `"bipartite"` | Cases × contexts; edges coloured by visit timing category (see ADR-002) |
| Who infected whom | `"contacts"` | Transmission links from contacts sheet or derived from timing |

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

Derived rule for suspected transmission links (Who infected whom view): onset gap must be between
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
| `DiagrammeR` | ERD schema diagram in Reference tab |

---

## Conventions — always follow these

- **UI components:** use `bslib` cards (`card()`, `card_header()`, `card_body()`),
  `layout_columns()`, and `layout_sidebar()`. Do not use raw Bootstrap divs for
  layout unless bslib has no equivalent.
- **Tooltips:** use the `info()` helper (defined near the top of app.R) for all ⓘ
  icon tooltips. Use `hdr()` for card headers that need a tooltip.
- **Context colours:** use `colour_map(types)` to assign colours from `CONTEXT_PALETTE`. Do not hardcode hex colours for context types anywhere else. Context types are dynamic (user-defined), so colours must be assigned at runtime.
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
- Do not change the `CONTEXT_PALETTE` colours or their order
- Do not alter the dev panel task list (DEV_TASKS) without being asked

---

## Git workflow

- Branch `main` is the stable baseline
- Feature work goes on named branches (e.g. `data-entry-forms`, `phase-2-views`)
- Commit after each logical unit of work with a clear message
- Push branches to GitHub; open a PR to merge into `main` when a phase is complete

## Project management

- **GitHub Issues** — task tracking, bugs, decisions to make. One issue per task.
- **Obsidian** — installed on Windows, vault points at `C:\Users\mgedmunds\projects\network-diagram`
- **`docs/` folder** — working notes and architecture decisions, lives in the repo so Claude can read it
  - `docs/data-model.md` — Phase 1 working notes, open questions, field decisions
  - `docs/data-dictionary.md` — full field-level reference for all tables
  - `docs/erd.svg` — schema diagram, auto-generated when the app starts
  - `docs/network-types.md` — Phase 2 working notes, view decisions
  - `docs/decisions/` — ADRs for significant decisions (use TEMPLATE.md)
- Windows Obsidian and WSL Claude Code stay in sync via `git pull` / `git push`
- Windows repo is at `C:\Users\claude-dev\projects\network-diagram`; RStudio pull sometimes needs `git fetch origin && git merge origin/main` in the Terminal tab if the remote cache is stale

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
