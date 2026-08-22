# ADR-007: `case_id` and `context_id` are manually-entered unique IDs, not auto-generated surrogates

**Status:** Accepted
**Date:** 2026-08-22

## Decision

`case_id` (cases sheet) and `context_id` (contexts sheet) are **manually entered**
by the user as essential unique IDs, following a fixed pattern (`C-001`,
`Ctxt-001`). They are no longer auto-generated in the Excel template by a
row-position formula (`"C-"&TEXT(ROW()-1,"000")`). The template enforces the
pattern and uniqueness through data validation and highlights problems with
conditional formatting.

## Alternatives considered

- **Auto-generate via row-position formula (the previous approach)** — a formula
  in every pre-sized row produced `C-001 … C-1000`. Rejected: it filled ~980 empty
  rows with phantom IDs (messy), the IDs were tied to row position so the sheet
  could not be sorted without scrambling them, and the linking dropdowns listed all
  1,000 (mostly blank) values.
- **Conditional auto-generation** — same formula but blank until the row has data.
  Rejected in favour of manual entry: still position-bound (no sorting), and still
  a formula the user cannot override with a local numbering scheme.
- **Auto-generate a persistent ID on row creation (VBA macro)** — rejected:
  macros are not acceptable for the intended government/NHS environment.

## Reasons

- **Sorting becomes safe.** Static, user-entered IDs do not change when rows are
  reordered; every other column's formula uses same-row references, so the sheet
  can now be filtered *and* sorted. (See batch 3.)
- **Clean sheet and dropdowns.** Empty rows are genuinely blank, so the ID columns
  show only real records, and the `case_id` / `context_id` dropdowns on
  `case_contexts` and `visit_dates` can list only entered records via
  `OFFSET`/`COUNTA`.
- **Local numbering flexibility.** Teams can use their own scheme within the
  `C-###` / `Ctxt-###` pattern rather than a fixed formula output.
- **No macros.** Pattern and uniqueness are enforced with plain data validation
  (`COUNTIF(...) < 2` plus a pattern check), which rejects duplicates/malformed
  IDs as they are typed; a red conditional-format highlight catches duplicates
  introduced by pasting (validation does not run on paste).

## Consequences

- The user must enter every `case_id` and `context_id`; Excel cannot hard-block a
  totally blank ID without a macro, so the template greys out the rest of a row
  until its ID is entered, as a visual prompt.
- The dropdowns assume records are entered **top-down with no empty rows in the
  middle** (`OFFSET`/`COUNTA` reads a contiguous block from the top). This was
  already the workbook convention.
- Deleting a row no longer renumbers other IDs (they are static), but deletion is
  still discouraged — set `status` to `Discarded` instead (see the README).
- `docs/data-dictionary.md` no longer describes `context_id` as an auto-generated
  surrogate; both IDs are documented as manual, required, unique.
- The app (`raw()`) already reads whatever IDs are present and only falls back to
  generating them when the whole column is empty, so no app change is required.
