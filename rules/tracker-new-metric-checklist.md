---
paths:
  - "**/*tracker*.py"
  - "**/pin_*.py"
---
# Tracker New Metric — Checklist (BLOCKING)

**Non-percentile metrics: 5 places. Percentile metrics (P01, P10, P25,
P75, P95, P99, etc.): 7 places** — adds raw_obs SQL + pooled compute
helper to enforce `rules/pooled-percentile-pattern.md`.

Skip ANY one and the metric goes NULL silently in specific views OR
drifts on multi-level/multi-year (percentile case). May 8 2026 session
shipped today's metrics with three of the five places covered, then had
to ship 4 follow-up commits as user testing surfaced each gap one by
one.

This rule prevents that. **Before claiming a metric is "done," walk this
checklist explicitly.** Each item maps to a specific view that will go
NULL or drift if you skip it.

---

## The five places

When adding any new metric (or modifying an existing one's scope), every
checkbox below must be confirmed. Each maps to a specific user-visible
failure if skipped.

```
┌──────────────────────────────────────────┬─────────────────────────────┐
│ 1. Per-batter SQL query                  │ Skipped → metric NULL on    │
│    (e.g., _POC_QUERY in tracker_data.py) │   per-batter leaderboard    │
├──────────────────────────────────────────┼─────────────────────────────┤
│ 2. LEADERBOARD_COLS tuple entry +        │ Skipped → metric not        │
│    METRIC_KEYS / HIGHER_IS_BETTER_MAP    │   selectable; coloring      │
│                                          │   wrong (defaults True)     │
├──────────────────────────────────────────┼─────────────────────────────┤
│ 3. _PITCH_WEIGHTED_KEYS / _PA_WEIGHTED   │ Skipped → metric NULL on    │
│    _KEYS in the page _combine_multi_     │   players at 2+ levels      │
│    level (or k_bb_pct-style re-derive)   │   (HOU vs HOU + HOU vs Lvl) │
├──────────────────────────────────────────┼─────────────────────────────┤
│ 4. Page-side org enrichment block        │ Skipped → metric NULL in    │
│    (_enrich_X + per-(org,level,season)   │   Org Rankings tab          │
│    np.average loop)                      │                             │
├──────────────────────────────────────────┼─────────────────────────────┤
│ 5. Monthly variant SQL query             │ Skipped → metric not        │
│    (e.g., _MONTHLY_POC_QUERY)            │   selectable in Trends tab  │
│    + wire into _get_single_level_monthly │                             │
└──────────────────────────────────────────┴─────────────────────────────┘
```

Plus two pin-related concerns documented in `tracker-parquet-pins.md`:

```
┌──────────────────────────────────────────┬─────────────────────────────┐
│ 6. Stale-pin shim in get_batter_         │ Skipped → KeyError when pin │
│    leaderboard / get_org_rankings        │   bundle missing the column │
│    (`for col in (...): if col not in    │   (pre-this-commit pins)    │
│    _pinned.columns: _pinned[col] = NaN`) │                             │
├──────────────────────────────────────────┼─────────────────────────────┤
│ 7. Re-pin all PINNED_YEARS               │ Skipped → frozen-year pins  │
│    (work laptop, full backfill)          │   show NaN until refreshed  │
│    + redeploy connect_pins/              │   2026 reverts to NaN every │
│                                          │   6 hrs without redeploy    │
└──────────────────────────────────────────┴─────────────────────────────┘
```

**PERCENTILE METRICS ONLY** — places 8 + 9 enforce pooled-percentile pattern. See `pooled-percentile-pattern.md` for the canonical 5-piece implementation.

```
┌──────────────────────────────────────────┬─────────────────────────────┐
│ 8. Raw observation SQL query             │ Skipped → multi-level views │
│    (_RAW_<METRIC>_QUERY +                │   silently drift via        │
│    PREFIX_RAW_<METRIC> + ALL_<DOMAIN>_   │   weighted-mean approx.     │
│    PREFIXES + _try_pin_raw_obs gate)     │   Nunez Arm case: 86.0 wrong│
│                                          │   vs 87.2 true pooled.      │
├──────────────────────────────────────────┼─────────────────────────────┤
│ 9. Pooled compute helper + parity diag   │ Skipped → no verification   │
│    (_compute_pooled_indiv/org_from_raw_  │   that the new path matches │
│    obs + scripts/diag_pooled_parity.py)  │   existing SQL within tol.  │
│                                          │   Math regression ships to  │
│                                          │   prod, caught months later │
│                                          │   by coach filing parity bug│
└──────────────────────────────────────────┴─────────────────────────────┘
```

Plus the existing places 6 + 7 STILL apply (stale-pin shim + re-pin), now with new raw_obs columns in the shim.

---

## Worked example — May 8 2026 PoC / xBA / VBA

The flow that should have happened on a single commit, but ended up
spanning ~4 commits because the checklist wasn't internalized:

| Step | What | Should be in commit | What actually happened |
|---|---|---|---|
| 1 | `_POC_QUERY`, `_VBA_QUERY`, xba_contrib in `_XWOBA_QUERY` | First metric commit | ✅ done in `6e6dc30` |
| 2 | LEADERBOARD_COLS tuple entries | First metric commit | ✅ done in `6e6dc30` |
| 3 | `_PITCH_WEIGHTED_KEYS` += {vba_con, poc_depth_in} | First metric commit | ❌ skipped → multi-level NULL → fixed in `b3e1278` (after user noticed) |
| 4 | `_enrich_poc` + `_enrich_vba` page blocks | First metric commit | ⚠️ partial — PoC enriched but NOT VBA in `6e6dc30` → VBA org NULL → fixed in `b3e1278` |
| 5 | Monthly variant SQL queries | First metric commit | ❌ skipped → Trends dropdown filtered out → still TODO at session end |
| 6 | Stale-pin shim | First metric commit | ✅ done in `85c76ae` (1 hr later, after user got KeyError) |
| 7 | Re-pin all years + redeploy `connect_pins/` | After SQL change | ✅ done eventually but spread across multiple TCP-drop retries |

**Five separate commits to deliver one feature**, three of them
shipping bugs the user had to find. The five-place checklist would have
caught all of them in the first pass.

---

## How to actually use this checklist

When you're about to commit a new metric, **physically read each line
of this rule before clicking commit**. Don't trust your memory — today's
session proved that.

For each of the 5 places:
1. **Locate the file** (the per-app rules file usually points to it)
2. **Locate the existing analog** — find the closest already-working metric and read its implementation. e.g., adding "VBA at contact"? Look at `aa_con` because they have the same shape (per-batter SCV mean, hib=None, pitch-weighted org rollup).
3. **Mirror the analog exactly** — same naming convention, same weighting pattern, same enrichment shape.
4. **Verify locally** if possible — load a recent pin, simulate the multi-level combine on a known multi-level player (e.g., a hitter who played AAA and AA in the same year), confirm the metric value isn't NaN.

The "pick the closest analog" step is the safety net. Today's bug class
was: VBA followed AACon's data-layer pattern but I forgot AACon was
itself missing from `_PITCH_WEIGHTED_KEYS` — so mirroring AACon
inherited AACon's bug. **When you're mirroring an analog, also check
that the analog is COMPLETE through all 5 places.** If the analog has
a gap, fix the analog AND yours together.

---

## App-specific file locations

### Barrelsville (`feature/barrelsville`)

| Place | File | Function/var |
|---|---|---|
| 1 | `barrelsville/src/tracker_data.py` | `_POC_QUERY`, `_VBA_QUERY`, `_XWOBA_QUERY`, `_BS_QUERY`, etc. |
| 2 | `barrelsville/src/tracker_data.py` | `LEADERBOARD_COLS` tuple |
| 3 | `barrelsville/pages/2_Affiliate_Tracker.py` | `_PITCH_WEIGHTED_KEYS`, `_PA_WEIGHTED_KEYS`, `_combine_multi_level` k_bb_pct re-derive |
| 4 | `barrelsville/pages/2_Affiliate_Tracker.py` | `_enrich_aa` / `_enrich_poc` / `_enrich_vba` blocks in org enrichment loop |
| 5 | `barrelsville/src/tracker_data.py` | `_MONTHLY_POC_QUERY`, `_MONTHLY_VBA_QUERY`, monthly xba in `_MONTHLY_PA_QUERY`/`_MONTHLY_XWOBA_QUERY` |
| 6 | `barrelsville/src/tracker_data.py` | `get_batter_leaderboard`, `get_org_rankings` stale-pin shim block |
| 7 | `barrelsville/scripts/pin_tracker_seasons.py` + `barrelsville/connect_pins/deploy.ps1` | `python scripts/pin_tracker_seasons.py` (full); then `.\connect_pins\deploy.ps1` |

### Arm Farm (`feature/bullpen-reports`) — analogous

| Place | File | Function/var |
|---|---|---|
| 1 | `bullpen-report/src/tracker_data.py` | per-pitcher SQL queries |
| 2 | `bullpen-report/src/tracker_data.py` | `LEADERBOARD_COLS` |
| 3 | `bullpen-report/pages/3_Affiliate_Tracker.py` | `_PITCH_WEIGHTED_KEYS` / `_PA_WEIGHTED_KEYS` / `_combine_multi_level` |
| 4 | `bullpen-report/pages/3_Affiliate_Tracker.py` | org enrichment blocks |
| 5 | `bullpen-report/src/tracker_data.py` | monthly variant queries |
| 6 | `bullpen-report/src/tracker_data.py` | pin stale shim in `get_pitcher_leaderboard` etc. |
| 7 | `bullpen-report/scripts/pin_*` + `bullpen-report/connect_pins/` | re-pin + redeploy |

### Intangibles (`feature/astros-intangibles`) — same shape across BR / OF / IF / Catcher

| Place | File |
|---|---|
| 1 | `intangibles/src/{br,fielding,catching}_tracker_data.py` |
| 2 | same as place 1 |
| 3 | `intangibles/src/{br,fielding,catching}_tracker_page.py` `_combine_multi_level` |
| 4 | same as place 3 (org enrichment) |
| 5 | data module monthly queries |
| 6 | data module pin shim |
| 7 | `intangibles/scripts/pin_*_tracker_seasons.py` + `intangibles/connect_pins_*/` |

---

## Verification commands (run after every metric add)

### After SQL change (places 1, 5)
```powershell
# Multi-level player verification — pick someone known to have played at 2+ levels
python -c "
from src.tracker_data import get_batter_leaderboard
df = get_batter_leaderboard(level_codes=['mlb','aaa'], season=2025, min_pa=1)
multi = df[df.duplicated('batter_id', keep=False)].sort_values('batter_id')
print(multi[['player_name','level','pa','<NEW_METRIC>']].head(20))
"
```

### After page change (places 3, 4)
- Open Streamlit tracker locally / on Connect
- Select 2+ levels in sidebar → check that new metric column has values for multi-level players (not NaN)
- Switch to Org Rankings tab → check HOU row has a value for new metric (not NaN/—)
- Switch to Trends tab (if monthly query also added) → check new metric appears in dropdown

### After pin re-run (place 7)
```powershell
python -c "
from src.tracker_pins import load_tracker_bundle
b = load_tracker_bundle(2025)
df = b['batters_all']
print(f'{len(df)} rows, has_<NEW>={\"<NEW>\" in df.columns}, non-null={df.get(\"<NEW>\", df.iloc[:,0]).notna().sum()}')
"
```

---

## What NOT to do

- **Don't claim a feature is "done" after only updating place 1.** Today's bug class. Walk the full checklist before commit.
- **Don't mirror an analog without verifying the analog is complete.** AACon was the analog for VBA, but AACon itself was missing from `_PITCH_WEIGHTED_KEYS` — mirroring inherited the bug. Always verify the analog is complete through all 5 places, fix it if not, then mirror.
- **Don't skip place 6 (stale-pin shim).** Even if you plan to re-pin immediately after, the shim must be in place — if it's not, the page crashes between "deploy Streamlit with new metric" and "pin job finishes 2 hours later."
- **Don't skip place 5 (monthly query) "for now."** It's the most often skipped because it requires more SQL work, but the Trends tab is a major user-facing surface. If you must defer, OPEN A TASK explicitly tracking the gap, don't just leave it implicit.
- **Don't ship a metric across only the per-batter and pin paths.** Org Rankings + Trends are the views that surface gaps. They're equally important to QA.
- **Don't trust "well I added it to LEADERBOARD_COLS, it should work."** LEADERBOARD_COLS is the SCHEMA, not the IMPLEMENTATION. Adding it there only makes it selectable; it doesn't compute it.

---

## Cross-references

- `streamlit-tracker-column-pinning.md` — Streamlit-side rule (pixel widths + 60% threshold)
- `database-tcp-retry.md` — pin job resilience (transient TCP recovery)
- `tracker-parquet-pins.md` — pin schema, stale-pin shim §6, sparse-pin recovery §10, daily refresh §11

---

## Bug history

- **May 8 2026** — Barrelsville session shipped PoC, xBA, VBA, OCtct% org-level. Initial commit `6e6dc30` covered places 1, 2, 4 (partial). Subsequent commits filled gaps as user found them:
  - `85c76ae` — added stale-pin shim (place 6) after KeyError
  - `bb440a4` — fixed coloring on hib=None metrics (place 2 nuance)
  - `b3e1278` — added missing keys to `_PITCH_WEIGHTED_KEYS` + `_PA_WEIGHTED_KEYS` + VBA enrichment (places 3, 4)
  - `bfd9cc0` — added monthly variants `_MONTHLY_SCV_QUERY` + `_MONTHLY_POC_QUERY` + `_MONTHLY_XWOBA_QUERY` (place 5 partial — BS, AACon, VBA, PoC, xwOBA, xSLG, xBA)
  - `c2ebeea` — closed last 2 monthly gaps: gcOBA + wRC+ + wOBA via new `_MONTHLY_SWING_DIST_QUERY` + Python derivations mirroring season-grain. **All 15 default metrics now in MoM Trends.**
  - `648a08b` — added `ibb` to `_MONTHLY_PA_QUERY` SELECT (was using ibb=0 approximation; user caught it; fixed for exact monthly wOBA)
- This rule was written mid-session (after `b3e1278`) to prevent the same shape of partial-shipment on future metric work.

### Sub-pattern from `648a08b` — pull ALL PA components in monthly queries

When writing a monthly variant of a season query, **don't omit
"unused-by-existing-metric" columns** like `ibb`. Future derived metrics
(monthly wOBA, wRC+) need them, and "I'll add it when needed" turns into
"I shipped a wOBA approximation because the column wasn't there." Match
the season query's SELECT list exactly unless you have a specific
reason to drop a column.

Concretely for monthly PA queries: include `ibb` even if no metric
USES it yet. Same for any other low-cost column the season query
already returns.
