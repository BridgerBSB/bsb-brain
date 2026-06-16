---
name: CSC Column Clarification (Brodie)
description: called_strike_chance vs called_strike_chance_mlb — level-adjusted vs MLB model, per Adam Brodie Apr 16 2026
type: reference
originSessionId: b5e9f755-892e-4c02-951f-332b939f0e3d
---
Adam Brodie (Apr 16 2026) clarified:

- `called_strike_chance` = level-adjusted model, describes called-strike behavior at that level. Works for ALL levels including MLB.
- `called_strike_chance_mlb` = MLB model. Same as `called_strike_chance` for MLB games. For MiLB it applies MLB zone standards.
- Neither is updated for ABS. GC2 hasn't done anything for ABS yet.
- `called_strike_chance` is the universal/preferred column.

**Current state across apps:**
- Intangibles catcher modules + PD Goals org_kpi_data.py NetK: already use `called_strike_chance`
- Everything else (Arm Farm, Barrelsville, PD Goals stats/percentiles, sql-queries/): still on `called_strike_chance_mlb`
- No urgency to migrate — functionally equivalent for MLB, very similar for MiLB
