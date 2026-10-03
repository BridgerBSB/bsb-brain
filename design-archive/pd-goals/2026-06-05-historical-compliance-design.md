# Historical / Former-Period Goal Compliance — Design (PLANNED)

Status: **NOT BUILT.** Documented Jun 5 2026 as the next feature for the
Goal Compliance tab. Do not build until there are real multi-period goal
rows in goals.csv to look back on (premature otherwise).

## Problem

Goal Compliance today only shows the **current** state: roster-driven,
each player evaluated over their latest started goal period, pin rebuilt
every 6h (overwrites the prior pin — no history kept). There is no way to
look back at a closed goal period (e.g. "how did everyone do in the
Apr–May cycle?").

## Prerequisite (already in place as of Jun 5 2026)

- **Retention convention** (documented in `.claude/rules/pd-goals.md`
  → Goal Compliance → DATA RETENTION CONVENTION): old goal rows are
  NOT deleted; each new period is appended as a new row with its own
  `start_date`/`end_date`. Released players also stay on the sheet.
- **Date-aware selection** (`compliance.py`): already picks the latest
  started period, so retained old rows are inert for "now."

Without retained multi-period rows, there is nothing to look back on —
which is why this is gated on real historical data existing first.

## What needs building

1. **Period picker on the tab.** A selector (e.g. a dropdown of distinct
   `(start_date → end_date)` windows present in goals.csv, plus a
   "Current" default). Drives which period the matrix + table reflect.

2. **Selection targeting a chosen period.** `compute_compliance` (or a
   variant) takes a target window and selects each player's goal row
   whose window matches/overlaps the chosen period, instead of always
   "latest started." Keep the current "latest" path as the default.

3. **goals.csv-driven player universe for historical periods (the key
   wrinkle).** The current path drives the player list from the CURRENT
   roster (`get_roster()` / PP_MASTER). A player released since a past
   period is gone from the roster but SHOULD appear in that past
   period's board. For a historical view, drive the universe from
   goals.csv rows active in the chosen window instead of the roster.
   - Their stats for that window still exist in the DB (they played then).
   - `player_type` (P/H) + `position_category` are needed for the metric
     fetch + matrix bucketing. The current roster supplies these today;
     for released players we need another source — options: store
     `player_type`/`position_category` on the goal row at entry time, or
     cache a roster snapshot per pin, or look them up from PP_MASTER
     history. Decide at build time.
   - `level` (for the Level row in the matrix) likewise needs a snapshot
     or last-known value for released players.

4. **Historical pin storage.** Either:
   - Archive a dated pin snapshot each cycle (`pd_compliance_<season>_<window>`), OR
   - Compute historical periods on demand (live SQL, slower) since they're
     viewed rarely.
   Snapshot-per-cycle is cleaner for repeat viewing; on-demand avoids pin
   sprawl. Decide based on how often historical views get used.

## Out of scope / deferred decisions

- Whether to show released players' CURRENT-period board at all (they're
  correctly absent today). This feature is about PAST periods only.
- Exact period-picker UX (free date range vs enumerated cycles).
- Whether to backfill historical pins for cycles already lost (can't —
  no retained rows existed before the convention; history starts now).

## Cross-references

- `.claude/rules/pd-goals.md` → Goal Compliance — Tab (behavior invariants
  + retention convention)
- `pd-goals/src/compliance.py` — current compute + selection + pin paths
- `pd-goals-batch-always-fallback.md` (memory) — the most-recent-period
  fallback philosophy this mirrors
