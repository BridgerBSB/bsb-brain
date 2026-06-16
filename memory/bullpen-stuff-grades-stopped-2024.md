---
name: Bullpen SRV grades stopped after 2024
description: stuffrelvel_grade_2080 stopped populating on sched_type='B' (bullpen) pitches after 2024 — so bullpen-sourced SRV is not viable for current-season metrics
type: project
originSessionId: 37f28d48-32a3-491a-ad39-6a762bf664f1
---
Verified Apr 20 2026 via diagnostic query against Astros.Pitches_View joined on Schedule_View, grouping by (sched_type, year): `stuffrelvel_grade_2080` has near-zero coverage on `sched_type='B'` (bullpen session) pitches after 2024. Game pitches ('R') still populate normally.

**Why:** Unclear — stuff-grading pipeline on bullpens appears to have been turned off. Not a data-bug, looks intentional.

**How to apply:**
- Any future "derive SRV from bullpens for more sample / rehab pitchers / early-season stability" ask is a dead end for 2025+ data unless someone flips the pipeline back on.
- For pre-2024 historical bullpen SRV analysis, the data is there.
- V (DSL/veloz) sched_type should be verified separately — may or may not have the same issue.

**Diagnostic query location:** Written ad-hoc Apr 20; recreate via `SELECT sched_type, year, COUNT(*), SUM(CASE WHEN stuffrelvel_grade_2080 IS NOT NULL THEN 1 ELSE 0 END) FROM Astros.Pitches_View pv JOIN Astros.Schedule_View sv ...` if needed.

**Related:** SRV (aliased `stuff_plus` in code) is currently sourced from game pitches only via `pitcher_kpi_data.py:509` — `AVG(pv.stuffrelvel_grade_2080)` with default sched_types=['R']. No change needed; this memory is just so we don't re-propose bullpen as a source.
