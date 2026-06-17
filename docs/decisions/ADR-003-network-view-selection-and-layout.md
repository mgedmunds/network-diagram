# ADR-003: Network view selection and main page layout

**Status:** Accepted
**Date:** 2026-06-17

## Decision

Keep all three network views (Contexts network, Who visited where, Who infected whom). Replace the planned temporal view with an interactive timeline panel below the network diagram. Restructure the main page so the Dashboard shows only the network and timeline; move the epidemic curve and data tables to a separate Data tab. Add a Home landing page as the default on first load.

## Alternatives considered

- **Cut the Contexts network view** — considered but rejected; it offers a context-to-context perspective distinct from the bipartite view and is useful for identifying clusters of linked places
- **Hide "Who infected whom" when no contacts data present** — rejected in favour of always showing the view with an information alert; hiding tabs based on data state is confusing and prevents users from knowing the feature exists
- **Add a dedicated temporal / timeline view as a third network layout** — rejected; the time slider already handles date filtering, and a separate timeline view sitting alongside the network is more useful than replacing it
- **Keep epi curve and tables on the Dashboard** — rejected; the Dashboard was becoming cluttered; separating analytical outputs into a Data tab gives the network diagram room to breathe and makes the investigative workflow clearer

## Reasons

The Contexts network view answers a different question from the bipartite view ("which places are linked?" vs "which cases went where?") and should be retained. The "Who infected whom" view is always relevant — users need to know it exists even before contacts data is available. A timeline panel responding to node clicks was preferred over a standalone temporal view because it provides case- and context-specific detail on demand rather than requiring the user to switch tabs. The Home landing page provides a natural place for the upload widget and the PII warning, and sets expectations before the user sees any data.

## Consequences

- Three views are final; no further views should be added or removed without a new ADR
- The timeline panel is tightly coupled to node selection in visNetwork (`input$net_selected`); any change to node ID format (e.g. the `ctx::` prefix used in the bipartite view) must be reflected in `build_timeline_plot()` and `timeline_row_count()`
- The Home tab holds the `fileInput` widget; users must return to Home to change their uploaded file
- The Data tab is a natural location for any future analytical outputs (attack rates, generation time estimates, etc.)
