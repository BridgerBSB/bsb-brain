---
name: No guessing columns in standalone scripts
description: BLOCKING — when writing standalone/diagnostic scripts, MUST grep existing code for column names before writing SQL, not just for main data modules
type: feedback
---

Never guess DB column names in standalone scripts either — the "NEVER guess" rule applies to ALL SQL, not just data modules.

**Why:** Wrote `camera_angle` instead of `angle` for Video_Network in error_diagnostic.py. The correct column was used in 4+ existing files (of_postgame_data.py, if_postgame_data.py, br_data.py) AND documented in DATABASE_REFERENCE.md line 1348. Failed to check either source.

**How to apply:** Before writing ANY SQL — even in throwaway diagnostic scripts — grep the codebase for existing queries that use that table. `Grep "Video_Network" src/` would have instantly shown `vn_{a}.angle`. This takes 5 seconds and prevents a round-trip to the work laptop for a fix.
