---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# Schedule Types

| Code | Meaning | Notes |
|------|---------|-------|
| R | Regular season | Most common. **WARNING: junk levels also have R games** |
| S | Spring training | |
| E | Exhibition | `min` level has real E games |
| V | Veloz / bullpen sessions | `int`/V = DSL bullpens (real data) |
| I | Instrumented | Bullpen/practice sessions with tracking |

## Per-Project Filters
- **Postgame data queries:** R, S, E, V, I
- **Postgame percentile queries:** R only
- **PD Goals:** `sched_type IN ('E','R','S')` — config in `pd-goals/src/database.py`
- **GC2 production uses ONLY 'R'**

## BBC/WIN Pseudo Sched Types
Some apps implement `_build_sched_filter()` that creates virtual BBC (big league camp) and WIN (winter league) pseudo types from level_code + sched_type combinations. Same pattern used in Barrelsville and Intangibles.
