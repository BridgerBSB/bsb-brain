---
name: Prefer direct pv.* columns over JOINs when same data is reachable both ways
description: When implementing SQL helpers that need a column, GREP for that column on Pitches_View FIRST. Adding a JOIN for handedness / hand-of-pitcher / etc. when pv.pitcher_throws / pv.bat_side already exists is a performance footgun. Pin matrix scaling makes this matter.
type: feedback
originSessionId: 5de55ffe-8c6f-460b-a14d-68a74c52a701
---
When a query needs pitcher hand, batter hand, or any other player-attribute
column, GREP `Astros.Pitches_View` first for a `pv.<thing>` direct column
BEFORE assuming a JOIN to `Astros.Players` is required. Pitches_View is
denormalized — many player attributes are flattened onto every pitch row.

**Verified pv columns (no JOIN needed for these):**
- `pv.pitcher_throws` — pitcher's throwing hand (L/R)
- `pv.bat_side` — batter's hitting side (L/R) — note: NOT `b_side`
- `pv.pitcher_id`, `pv.batter_id`, `pv.c_id` — player IDs
- (More — grep before adding any JOIN)

**Why this matters at scale:**
Adding `LEFT JOIN Astros.Players p_pitcher ON pv.pitcher_id =
p_pitcher.groundcontrol_id` to a query that's already aggregating across
Pitches_View + Events_View + Schedule_View + Hits + Pitches_Grades +
Projections_Pitches_Grades + (org bridge tables) makes SQL Server
optimizer add a 7th-table cost to every combo. On the consolidated
catcher tracker query — which already JOINs 6+ tables for one slice — that
extra JOIN can 3-5x the wall-clock, especially when the result fans out
across pin-matrix combos (9 H/A × Hand permutations).

**Why:** May 3 2026, handedness rollout. Catcher tracker agent added 27
LEFT JOINs to `Astros.Players` for handedness when `pv.pitcher_throws`
was directly available on Pitches_View. Catcher per-combo wall-clock
ballooned from ~5 min to ~25 min on re-pin (~20h total backfill estimate).
Other 3 trackers (Barrelsville, Arm Farm, BR) used `pv.*` columns
directly and ran ~3-5x faster. Same data, no JOIN, same correctness —
just less work for the optimizer. Catcher fix swapped to `pv.pitcher_throws`,
ran ~3-5x faster after. Commits: original `3119f84`, fix `ca8bb6e`.

**How to apply:**
- Before adding ANY JOIN to a tracker / KPI / postgame query, GREP
  `Astros.Pitches_View` columns first. If the data is already on `pv`,
  use it. If not, then JOIN.
- When pattern-matching from another tracker's code, verify the JOIN is
  actually NECESSARY in the new context — not just present in the
  reference impl. Different queries hit different combinations of base
  tables; what works fine in `br_data.py` (which is light on metric
  parallelism) can be a perf killer in `catching_tracker_data.py` (heavy
  fan-out per slice).
- Pin-matrix-aware: if a JOIN slows ONE query by 2 seconds, that's nothing.
  If it slows EVERY query in a 9-permutation matrix that runs across 7
  levels, that's 9 × 7 × 2 = 126 extra seconds per refresh, every time.
  Foundation-layer cost compounds.

**Tripwire:** if I'm about to type `LEFT JOIN Astros.Players` (or any
player-attribute table) in a tracker / KPI query, STOP and grep for the
column on `pv` first. JOIN only if the column genuinely isn't on
Pitches_View.

**Related:**
- `feedback_no_design_doc_column_assertions.md` — the broader
  "grep before typing column names" principle
- CLAUDE.md Blocking Rule #1 — "NEVER guess DB column names"
- `tracker-parquet-pins.md` §5.14 — JOIN audit rule
