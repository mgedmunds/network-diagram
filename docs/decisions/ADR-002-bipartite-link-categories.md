# ADR-002: Bipartite network diagram visit categories

**Status:** Accepted
**Date:** 2026-06-14

## Decision

Four visit categories for the bipartite network diagram:

- **Present — during infectious period** — case visited this setting while infectious; may have transmitted infection to others there
- **Present — during exposure window** — case visited this setting during their exposure window; may have acquired infection there
- **Present — during both windows** — visit falls within both the infectious period and the exposure window (possible when parameters overlap)
- **Present — outside both windows** — visit is not considered relevant to either acquiring or transmitting infection

## Alternatives considered

- "Visit(s) during infectious period" etc. — the `(s)` construct is awkward to read
- "Infectious visit" / "Compatible exposure" / "Outside transmission window" — original labels; inconsistent style, unclear to non-epidemiologists
- "Visits include infectious period" — accurate but verbose
- "Present — during both" / "Present — during neither" — asymmetric; "neither" is correct but reads coldly

## Reasons

"Present" describes the case-setting relationship without implying a single visit. The dash separator gives consistent visual rhythm across all four labels. "Outside both windows" is more intuitive than "neither". Four categories rather than three correctly handles the edge case where parameter changes cause the infectious period and exposure window to overlap.

## Consequences

- Requires a fourth colour/style in the bipartite legend
- The `build_bipartite()` function must classify visits into four categories, not three
- Parameters where `inc_min < inf_before` will produce "both windows" visits — this should be flagged to the user
