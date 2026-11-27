# ADR-002: Who visited where — visit timing categories

**Status:** Accepted
**Date:** 2026-06-14

## Decision

Four visit timing categories for the Who visited where view:

- **Present — during infectious period** — case visited this context while infectious; may have transmitted infection to others there
- **Present — during exposure window** — case visited this context during their exposure window; may have acquired infection there
- **Present — during both windows** — visit falls within both the infectious period and the exposure window (possible when parameters overlap)
- **Present — outside both windows** — visit is not considered relevant to either acquiring or transmitting infection

## Alternatives considered

- "Visit(s) during infectious period" etc. — the `(s)` construct is awkward to read
- "Infectious visit" / "Compatible exposure" / "Outside transmission window" — original labels; inconsistent style, unclear to non-epidemiologists
- "Visits include infectious period" — accurate but verbose
- "Present — during both" / "Present — during neither" — asymmetric; "neither" is correct but reads coldly

## Reasons

"Present" describes the case-context relationship without implying a single visit. The dash separator gives consistent visual rhythm across all four labels. "Outside both windows" is more intuitive than "neither". Four categories rather than three correctly handles the edge case where parameter changes cause the infectious period and exposure window to overlap.

## Consequences

- Requires a fourth colour/style in the Who visited where legend
- The `build_bipartite()` function must classify visits into four categories, not three
- Parameters where `inc_min < inf_before` will produce "both windows" visits — this should be flagged to the user

---

## Addendum — fifth category "Unknown" and Neither recolour (2026-11-27, B4.1)

**Status:** Accepted · amends the decision above (original four categories and their meanings stand).

### What changed

A fifth `exposure_relevance` value, **Unknown**, is added for links where the
investigator has not yet assessed the relevance (distinct from **Neither**, which
is a positive judgement that the link is not transmission-relevant). The Excel
template's `exposure_relevance` dropdown now offers `Infectious period, Exposure
window, Both, Neither, Unknown`.

The edge styling in the *Who visited where* view also changes:

| Category | Before | After |
|---|---|---|
| Infectious period | red arrow → context | *(unchanged)* |
| Exposure window | blue arrow → case | *(unchanged)* |
| Both | purple ↔ | *(unchanged)* |
| **Neither** | grey **dashed** line | **solid black** line |
| **Unknown** | *(did not exist)* | grey **dashed** line |

### Reasons

An investigation is rarely complete the moment a link is recorded. Collapsing
"not yet looked at" into "Neither" overstated certainty — a reader could not tell
a deliberate *not relevant* from an *unreviewed* link. Giving the **dashed / faded**
treatment to **Unknown** (the provisional state) and a **solid** line to **Neither**
(a settled judgement) matches the visual intuition that dashed = tentative. Black
for Neither keeps it clearly "on the diagram but inert", separate from the three
coloured transmission-relevant categories.

### Consequences

- The Who visited where legend now has **five** entries (Neither solid black,
  Unknown grey dashed added).
- `build_bipartite()` edge logic treats the four named categories as solid and
  **any other value — Unknown or an unrecognised entry — as grey dashed** with an
  "awaiting practitioner judgement" tooltip. This makes the view robust to
  non-template uploads.
- `exposure_relevance` is a stored, practitioner-entered value; `Unknown` does not
  participate in the legacy "highest-priority category" aggregation rule.
- Reference/Definitions text and `docs/data-dictionary.md` updated to list five
  categories.
