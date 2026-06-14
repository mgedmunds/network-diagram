# ADR-001: Use visNetwork for network rendering

**Status:** Accepted
**Date:** 2026-06-14

## Decision

Use the `visNetwork` R package for all interactive network diagrams.

## Alternatives considered

- `ggraph` + `plotly` — good for static/semi-interactive plots but limited click/hover interactivity
- `networkD3` — interactive but less Shiny-friendly and fewer layout options
- `visNetwork` — wraps vis.js, native Shiny output, supports hover tooltips, node selection, physics simulation, and legend

## Reasons

- `visNetworkOutput` integrates directly with Shiny reactive inputs (node selection feeds back via `input$net_selected`)
- Hover tooltips support HTML formatting, which is needed for case/setting summaries
- Physics-based layout (Barnes-Hut) handles variable-size outbreak networks without manual positioning
- Maximise/minimise and highlight-on-click features work out of the box

## Consequences

- Layout algorithms limited to what vis.js provides (Barnes-Hut, Kamada-Kawai, hierarchical)
- Performance degrades with very large networks (200+ nodes) — acceptable for outbreak investigation scale
- Styling is controlled via vis.js options rather than ggplot2 grammar
