---
name: always run a coverage audit after every cleanup sweep
description: Cleanup passes always miss at least one file — audit by grepping the symptom column across all worktrees before claiming complete
type: feedback
originSessionId: 0506d4f2-0a41-4377-8757-ea1a547d55b5
---
Every cleanup pass I've shipped this project has had at least one missed file. The pattern repeats: I make a sweep, claim complete, then a coverage-audit agent (or the user) finds 1-3 more places needing the fix.

**Examples this session (1B PL > 5.0 floor):**
- First sweep covered 4 files (br_tracker_data, br_data, br_kpi_data, org_kpi_data)
- Claimed complete + shipped
- Coverage audit found 3 more: `br_percentiles.py` (3 distribution queries), `snapshot_data.py` (player snapshot CTE), `compare_tracker_vs_org_kpi.py` (parity script)
- The percentile pool gap was the worst — production aggregations were filtered but the pool wasn't, so colored bars compared a clean value against a dirty distribution.

**How to apply:**
1. Do the cleanup sweep on the obvious files
2. **ALWAYS** spawn a coverage-audit agent to grep the affected column / SQL pattern across ALL worktrees, including:
   - `src/`, `scripts/`, `pages/`
   - Per-app + PD Goals + parity / comparison scripts
   - Percentile pool queries (`*_percentiles.py`) — easy to miss; they feed coloring
   - Snapshot / diagnostic scripts that mirror production
3. Apply the fix to the missed files in a follow-up commit
4. **Then** claim complete

The percentile pool case is particularly important: it's a separate SQL path from the production aggregation, but if the pool isn't gated the same way, you get clean values colored against a dirty distribution. This is a class of subtle bug that affects every metric with percentile coloring.

Audit pattern works for: filter changes, level-code policy changes, formula changes, gate threshold changes. Apply liberally — the cost of dispatching one read-only agent is much lower than shipping incomplete coverage.
