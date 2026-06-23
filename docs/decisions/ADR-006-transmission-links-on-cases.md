# ADR-006: Transmission links recorded on cases via `likely_index_case`; `contacts` sheet dropped

**Status:** Accepted
**Date:** 2026-06-23

## Decision

Transmission links shown in the "Who infected whom" view are sourced solely from
the `likely_index_case` field on the **cases** sheet (one recorded source per
case). The separate `contacts` sheet (`from` / `to` / `link_type`) and any
timing-derived candidate links are removed from the schema and documentation.

## Alternatives considered

- **Reinstate the `contacts` sheet in the app** — wire code to read `from`/`to`/
  `link_type`. Rejected: it duplicates `likely_index_case`, creating two places to
  record the same fact, and the sheet was documented but never actually read by
  the app.
- **Keep both `likely_index_case` and `contacts`** — rejected: ambiguous source of
  truth, extra data-entry burden, and reconciliation logic with no clear benefit.
- **Reinstate timing-derived candidate links** (the old "Possible links" view) —
  rejected: the team chose practitioner-recorded links over derivation (the
  Possible links view was removed earlier this phase), and derivation risks
  presenting plausible-but-unverified pairs as findings.

## Reasons

`likely_index_case` matches how the investigation team actually records an index
case — one judged source per case, on the same row as the case. It gives a single
source of truth, lowers data-entry burden, and the `contacts` sheet it replaces
was dead schema (never read by `app.R`). Dropping it removes documentation drift,
not functionality.

## Consequences

- Only **one** named source per case is supported. Recording multiple candidate
  sources, or distinguishing `Probable` vs `Possible` link strength, is no longer
  possible. If multi-source or evidence-strength is needed later, a
  `contacts`-style table would have to be reintroduced (superseding this ADR).
- The incubation/infectious parameters remain (timeline shading and as a reference
  when the investigator records each visit's relevance), but no longer drive any
  derived links.
- `docs/erd.svg` and any remaining references to a five-table schema are now out of
  date. The ERD is no longer auto-generated (DiagrammeR removed, see ADR-004), so
  it must be regenerated manually if the diagram is needed.
- The wider data-dictionary drift (cases demographic fields, and the
  relevance field named variously `visit_relevance` / `epi_category` /
  `exposure_relevance` and wrongly marked "derived") is **not** addressed here and
  remains to be reconciled in a separate decision.
