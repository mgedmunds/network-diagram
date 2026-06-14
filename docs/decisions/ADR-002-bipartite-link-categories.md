# ADR-002: Bipartite network diagram link categories

**Status:** Accepted
**Date:** 2026-06-14

## Decision

The three visit categories in the bipartite network diagram will be labelled:
- **Visit during infectious period** — case was infectious at the time of the visit (possible source of transmission to others)
- **Visit during exposure window** — timing is compatible with the case having acquired infection at this setting
- **Outside both transmission windows** — visit falls outside both the infectious period and the exposure window; not considered epidemiologically relevant to transmission

## Alternatives considered

- "Infectious visit" / "Compatible exposure" / "Outside transmission window" — original labels; concise but inconsistent in style and unclear to non-epidemiologists
- "Infectious" / "Exposure" / "Other" — too terse for a non-technical audience

## Reasons

Consistent use of "visit" as the noun across all three categories. Plain-language descriptions that a non-epidemiologist can understand without needing to read the definitions page. Plural "windows" correctly reflects that there are two distinct windows (infectious period and exposure window).

## Consequences

Labels are longer — legend and tooltip text needs to accommodate this. "Outside both transmission windows" should be shortened to "Outside transmission windows" in space-constrained contexts (e.g. legend).
