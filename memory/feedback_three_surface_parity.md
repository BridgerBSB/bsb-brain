---
name: Three-surface parity for catcher metric changes
description: Any catcher metric/filter/aggregation change MUST propagate across all 3 surfaces — tracker, KPI weekly, PD-Goals org KPI. User explicitly enforced this Apr 18.
type: feedback
originSessionId: e2d2b6df-6311-4657-b5f8-4f791ab09783
---
When changing ANY catcher metric (filter, gate, formula, weighting, sign, range), you MUST audit ALL 3 surfaces and propagate consistently:

1. **Affiliate tracker** — `intangibles/src/catching_tracker_data.py` + `catching_tracker_page.py`
2. **KPI weekly** — `intangibles/src/c_kpi_data.py` + `c_kpi_report.py`
3. **PD-Goals org KPI report** — `pd-goals/src/org_kpi_data.py` + `org_kpi_report.py`

**Why:** User compares values across all 3 and any divergence = bug. Single-surface fixes leak silent metric drift between views. CLAUDE.md blocking rule #11 covers app↔report parity; this extends it to the 3-surface catcher case.

**How to apply:**
- Before committing a metric change to ANY of the 3, grep the other 2 for the same query/filter/formula and apply the same fix
- If the fix is a Python helper (e.g. `_get_baserunner_advance_rv`), check that all 3 surfaces use the SAME function (import vs duplicate copies)
- For filter changes (`pv.pitch_id > 0`, `ev.c_id IS NOT NULL`, ranges, etc.), grep ALL 3 files for the affected table and confirm the filter is present consistently
- For aggregation changes (weight columns, percentile filters, base pool), check both per-catcher AND org-level queries in each surface

**Surface-specific reminders:**
- Tracker has 2 code paths per metric: org tab + per-catcher leaderboard. Both need the fix.
- KPI weekly has 2 paths: monthly chart query + per-catcher player table query. Both may need the fix.
- PD-Goals has 1 query per metric (single-pass, all levels). Simpler but still needs same logic.

**User's exact phrasing (Apr 18 2026):** "EVERYTIME WE UPDATE ONE OF THESE 3 the subsequent should follow"
