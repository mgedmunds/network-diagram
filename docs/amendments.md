# Amendment log

Add items here during app review. Claude reads this at session start and works
through the "Ready to action" list. No categories needed — describe the problem
in plain English. Items are deleted once the fix is committed.

---

## Ready to action

- [ ] Bug: plotly deprecation warning on app startup — "Specifying width/height in layout() is now deprecated." Comes from the epi curve (ggplotly conversion). Fix by passing height via ggplotly() directly rather than layout().

---

## Parked (needs decision or not urgent)

- [ ] UI: node selector in toolbar resets to blank whenever the view or filters change. Could instead preserve the selection if the same node ID exists in the new view. Needs a decision on whether this is the desired behaviour.
- [ ] Docs: docs/erd.svg is no longer auto-generated (DiagrammeR removed). If the schema changes, it must be updated manually or regenerated via a separate script. Low priority until schema is finalised.
