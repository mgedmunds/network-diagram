# ADR-004: Shinylive + GitHub Pages for deployment

**Status:** Accepted
**Date:** 2026-06-17

## Decision

Deploy the Network Explorer as a Shinylive app via GitHub Pages, combined with the existing OneDrive Excel template (Stage 1) for data collection. The app runs entirely in the user's browser with no server required.

## Alternatives considered

- **Posit Connect (NHS-hosted server)** — the original plan for Stage 2. Blocked on IT approval with no confirmed timeline. Would enable concurrent in-browser data entry and persistent shared records, but requires ongoing server infrastructure and IT ownership.
- **Local R / RStudio only** — works but limits the tool to staff with R installed. Excludes non-technical HPT staff from viewing the dashboard.

## Reasons

A proof-of-concept (branch `shinylive-poc`) confirmed that all ten R packages used in the app load successfully in WebR (WebAssembly), including `readxl` which was the main risk. This removes the primary technical uncertainty.

The key benefits over the alternatives:

- **No IT approval needed.** GitHub Pages is free and requires no NHS infrastructure. The app can be published or taken down in minutes.
- **Accessible to non-technical staff.** Any HPT staff member with the URL can open the dashboard in a browser. No R installation, no account, no login.
- **Data privacy by design.** Uploaded data never leaves the user's browser. No patient data touches a server.
- **Fits the outbreak workflow.** Data is compiled from the Excel template once or twice daily and uploaded to the app. Real-time concurrent editing is not a requirement for the current use case.
- **Two concurrent outbreaks** are handled naturally — each outbreak has its own named Excel file on OneDrive; users upload whichever is relevant. If needed, separate app instances can be deployed from separate branches.

Posit Connect remains the right answer if requirements change to include concurrent shared data entry. This decision does not close that door.

## Consequences

- **Data entry remains Excel-based (Stage 1).** The OneDrive Excel template is the data collection mechanism. There is no server-side persistent storage.
- **Manual upload step.** Users download the current Excel file from OneDrive and upload it to the app each session. This is slightly more friction than a server-hosted app with live data.
- **GitHub repo must be public** for GitHub Pages to work on the free plan. The repo contains only app code and synthetic demo data — no patient data is committed.
- **No real-time shared state.** Two users viewing the same outbreak simultaneously each load their own independent copy. Changes one user makes (e.g. adjusting parameters) are not visible to the other.
- **Versioning fallback needed.** The current commit-count version number requires `git` in PATH, which will not work when the app is running in WebR. A static fallback (e.g. a hardcoded version string updated at release) is needed before the main app is exported.
- **Stage 2 (in-browser data entry with shared records) remains blocked** until a server solution is available. Shinylive does not replace that requirement.
