# Tracker Parquet Pins — Daily Refresh Strategy for Current Season (parent section 11)

> **Extracted from `tracker-parquet-pins.md` 2026-05-19** to keep the
> parent rule under the article-recommended discoverability threshold.
> Parent has section pointers to this file. Auto-loaded with the parent
> on any tracker-related Python edit.

---

## 11. Daily refresh for current season (2026 strategy)

Pinning frozen historical years (2022-2025) is solved — pin once,
forget. Current-season data (2026 right now) changes daily. Without
some refresh strategy the pin gets stale within hours.

This section captures the strategy and code sketch from the Apr 25-26
2026 architecture conversation. Read before implementing any daily
refresh — there are three layers in increasing scope and complexity.

### 11.1. Why full daily re-pin from a laptop is dead-on-arrival

Lessons from the 2024 OF + IF rebuilds:
- 1-3 hours per app on stable network; 4-7+ hours on flaky VPN
- 6 trackers × 2/day = 12-30 hours of DB time. Won't fit.
- TCP drops on multi-hour idle connections kill the run
- Single failure leaves a sparse pin (see §10)
- All of this is fundamentally a *user-laptop-network* problem, not a
  query-cost problem. Connect → GCSQL02 is internal and stable.

### 11.2. The three-step ladder

Increasing scope. Try Step 1 first; only escalate if it isn't enough.

#### Step 1 — Schedule the existing CLI on Posit Connect (zero new code)

Most likely "good enough" answer.

- Deploy the existing `pin_*_tracker_seasons.py` CLI as Connect content
  via `rsconnect-python`.
- Set Connect schedule: daily at 2-4 AM (off-hours).
- Connect's network to GCSQL02 is internal. The same query that drops
  TCP after 4 hours on home VPN typically completes in 1-3 hours on
  Connect without dropping.
- Connect provides logging, retries, alerts.

Pros:
- Zero code change. Reuses the proven CLI.
- Eliminates the user-laptop-network failure mode entirely.
- Matches existing PD Goals pin schedule pattern (`pin_goals.py`).

Cons:
- Each app's full re-pin still takes 1-3 hours; long unattended.
- Failed nightly = stale pin until next attempt.
- DB load is heavy during the refresh window.

**Verdict:** START HERE. If a Connect-scheduled nightly refresh succeeds
reliably for 2-3 weeks, you are done. Don't build anything else.

#### Step 2 — Append-only daily incremental (when Step 1 isn't enough)

Nick Arrivo's idea, codified.

The script (pseudo-code):

```python
# scripts/refresh_tracker_pin_daily.py (or per-app variant)
from datetime import date

CURRENT_YEAR = date.today().year
LOOKBACK_DAYS = 3  # safety margin for late-arriving data

# Load existing pin (must already exist from prior full build)
existing = load_tracker_bundle(domain, CURRENT_YEAR)

# Find fielders/players who played in the last N days
active_ids = sql_query(active_ids_sql, lookback=LOOKBACK_DAYS, year=CURRENT_YEAR)

# Re-run per-fielder queries scoped to active set only
fresh_fielders = get_fielder_leaderboard(
    domain=domain, season=CURRENT_YEAR,
    fielder_ids=active_ids,  # NEW SUBSET FILTER
)
fresh_monthly_fielders = get_monthly_fielder_stats(
    domain=domain, seasons=[CURRENT_YEAR],
    fielder_ids=active_ids,
)

# Merge: replace rows for active IDs, keep everything else as-is
def merge_by_id(existing_df, fresh_df, key_col):
    keep = existing_df[~existing_df[key_col].isin(active_ids)]
    return pd.concat([keep, fresh_df], ignore_index=True)

existing["fielders_all"] = merge_by_id(existing["fielders_all"], fresh_fielders, "fielder_id")
existing["monthly_fielders_all"] = merge_by_id(
    existing["monthly_fielders_all"], fresh_monthly_fielders, "fielder_id"
)
# (Same for _home / _away variants)

# Org rollups: re-query in full (small, fast — ~30 orgs × ~6 levels)
existing["orgs_all"] = get_org_rankings(domain=domain, season=CURRENT_YEAR)
existing["monthly_orgs_all"] = get_monthly_org_stats(domain=domain, seasons=[CURRENT_YEAR])
existing["yearly_orgs_all"] = get_yearly_org_stats(domain=domain, seasons=[CURRENT_YEAR])
# (Same for H/A)

write_tracker_bundle(domain, CURRENT_YEAR, existing)
```

Active-IDs SQL pattern:

```sql
SELECT DISTINCT groundcontrol_id
FROM Astros.Tracking_Defensive_Metrics tdm
JOIN Astros.Schedule_View sv ON tdm.sched_id = sv.sched_id
WHERE sched_date >= DATEADD(day, -:lookback, GETDATE())
  AND YEAR(sched_date) = :year
  AND sv.sched_type = 'R'
```

Required code changes (per app):
- Add `fielder_ids` (or `batter_ids`, `pitcher_ids`) parameter to
  every per-player `get_*` function.
- That parameter must add a `WHERE groundcontrol_id IN (...)` clause
  at the SQL level (NOT Python-side filter — that defeats the purpose).
- Merge helper for replace-by-id semantics.
- Test plan: compare append-output vs full-rebuild-output for the
  same date range on a known game-day.

Time estimate per app: **~5-15 minutes** vs. 1-3 hours for full re-pin.
Daily becomes trivial. Twice-daily is reasonable.

Edge cases the implementation must handle:
- **Promotion / demotion** mid-season: a fielder's level changes.
  Active-IDs query catches them by groundcontrol_id; the per-fielder
  query returns rows for whichever level(s) they played at. Merge
  replaces ALL their rows across levels.
- **Player added mid-season**: groundcontrol_id is new. Append, not
  replace.
- **Game postponed / replayed**: the same sched_id may have new data
  later. Lookback window (3 days) handles this.
- **Percentile drift**: a fielder who didn't play yesterday still has
  yesterday's percentile in the pin. Their percentile was relative to
  the full pool when last computed — if other fielders' data shifted,
  their relative rank may have drifted slightly. Acceptable for daily,
  but full re-pin weekly catches it.

Connect deployment: same pattern as Step 1 — deploy the daily script
as Connect-scheduled content, run at 4 AM and/or 4 PM if twice-daily.

#### Step 3 — DB-side materialized table (long-term, cross-app)

The right architecture for the 5-year horizon.

- Push to Brodie / IT to maintain `Astros.TrackerMetrics_Daily` (or
  similar) refreshed by SQL Server Agent overnight.
- All apps query the materialized table directly — no per-app pin
  layer for current year.
- Solves three-surface parity bugs at the same time: postgame, KPI
  weekly, PD-Goals all read the same canonical numbers.
- Eliminates Step 1 + Step 2 entirely for the current season.

When to push for this:
- Step 2 is in production and you are maintaining 6× of the
  `fielder_ids` parameter + merge logic.
- Cross-app drift bugs keep biting (see `rules/three-surface-parity.md`
  bug history).
- Brodie / IT have bandwidth.

This is the long-term cleanup. Not immediate.

### 11.3. Decision flow

```
Need daily 2026 refresh?
    -> Step 1: Schedule full CLI on Connect
        Connect refresh succeeds reliably for 2-3 weeks?
            yes -> DONE — daily refresh works
            no  -> Step 2: Append-only daily incremental
                Cross-app drift painful?
                    no  -> DONE — Step 2 covers daily
                    yes -> Step 3: Push for DB materialized table
```

### 11.4. Critical rules for daily refresh implementation

1. **NEVER refresh a year that's not the current year.** Frozen years
   (2022-2025) stay pinned-once. Only run daily refresh for
   `date.today().year`.
2. **NEVER append duplicate rows.** Always replace-by-id. Use a stable
   key (`fielder_id`, `groundcontrol_id`) and `~isin(active_ids)` to
   filter the existing data first.
3. **NEVER skip org rollup re-computation.** Per-fielder rows merge
   well; org-level rollups are weighted aggregations of per-fielder
   data. They MUST recompute in full each refresh. They are cheap
   (~30 orgs × 6 levels = small query).
4. **NEVER let percentile metrics drift indefinitely.** Schedule a
   weekly full re-pin (Sunday 2 AM) even when daily incremental is
   running. Insurance against creeping drift.
5. **ALWAYS write-then-rename for pin updates.** Don't risk a partial
   write being read mid-update. Connect's pins API handles this if
   you call `write_tracker_bundle` (which uses `pin_write` —
   atomic). Never partial-write directly.
6. **ALWAYS guard against running incrementally on top of a sparse
   pin.** If §10 sparse-pin signs are present, run §10 recovery FIRST.
   Incremental on top of sparse just propagates the sparseness.
7. **ALWAYS log the refresh outcome.** Connect logs are checkable.
   Print row counts before/after, time taken, failed slices. Future
   debugging depends on this.

### 11.5. What requires support beyond the trackers

The hybrid / append pattern works for trackers because they are
season-aggregated leaderboards. Other apps have different shapes:

| App | Shape | Pin pattern |
|---|---|---|
| Tracker | Season leaderboard | Append-by-fielder-id + org re-rollup |
| Postgame | Per-game per-player | Per-game pin keyed on sched_id. Append by sched_id. |
| Gamelog reports | Per-player time series | Append by (gc_id, sched_date). |
| KPI weekly | Per-week aggregate | Re-run from scratch weekly (small query) |

Step 3 (materialized table) addresses all four with a single source.
Step 2 patterns can be ported per-app as needed.

### 11.6. Operational status as of Apr 26 2026

Current pin state across worktrees:

| App | 2022 | 2023 | 2024 | 2025 | 2026 |
|---|---|---|---|---|---|
| Barrelsville (hitter) | LIVE | LIVE | LIVE | LIVE | not pinned, live DB |
| Arm Farm (pitcher) | not started | not started | not started | not started | not started |
| Intangibles OF | LIVE | LIVE | **rebuilding** (slow) | LIVE | not pinned, live DB |
| Intangibles IF | LIVE | LIVE | partial (sparse, see §10) | LIVE | not pinned, live DB |
| Intangibles BR | not started | not started | not started | not started | not started |
| Intangibles Catcher | not started | not started | not started | not started | not started |

OF 2024 in particular has been the persistent failure case — the
single year that takes longer than the others (8-10+ hr observed)
and drops TCP repeatedly on home VPN. Likely a row-count outlier or
a bad partition. Will resolve once Connect-scheduled refresh runs
on stable infra.

### 11.7. Reference: PD Goals pin schedule (working precedent)

PD Goals already pins `goals.csv` to Connect via `pd-goals/scripts/pin_goals.py`.
That script runs on the work laptop today, but the pattern is
identical to what we'd schedule on Connect:
- `CONNECT_API_KEY` env var
- `pin_write` to atomic write
- All apps read the new pin immediately

When implementing Step 1 above, model the Connect deploy on PD Goals'
existing schedule. There's nothing pin-specific that's harder for
trackers — it's just a longer-running script.

### 11.8. Transition Report — different pattern entirely

`pd-goals/src/transition_pins.py` documents a different in-app
submission pattern: a Streamlit form writes to a parquet pin
directly from a user-triggered submit handler, no daily refresh
required. Full pattern lives in `rules/in-app-submission.md`. Useful
read for understanding pins-as-storage but NOT a template for tracker
daily refresh. Trackers are read-many, the transition report is
write-many. Different architectures.

---
