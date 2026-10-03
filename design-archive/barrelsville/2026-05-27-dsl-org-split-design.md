# DSL Organization Split — Affiliate Tracker Design Spec

**Date:** 2026-05-27
**Pilot worktree:** `feature/barrelsville` (Barrelsville hitter tracker)
**Status:** DESIGN COMPLETE — ready for build (post /clear, use superpowers)
**Author:** Claude (via design discussion with user)

---

## Problem statement

In `Astros.Schedule_View`, every DSL game carries `gc2_level_code='dsl'`,
but the franchise has multiple sub-team affiliates that play under
distinct identities — for HOU that's **DSL Astros Blue** (club_id 599)
and **DSL Astros Orange** (club_id 10000055). Many other orgs have
similar splits (Dodgers Bautista/Mega, Cardinals Red/Blue, etc.).

Today's affiliate tracker Org Rankings tab aggregates all DSL games
under one org row per franchise. Coordinators want a way to **split
DSL franchises into their individual sub-teams** to compare per-team
development on the Org Rankings tab, while keeping percentile coloring
honest (against the full DSL pool).

---

## Locked decisions (no further discussion needed)

| # | Decision | Rationale |
|---|---|---|
| 1 | **Pilot tracker: Barrelsville hitter** | Start narrow, iterate. Don't roll all 5 trackers at once. |
| 2 | **Cumulative SUM percentile coloring: DISABLED when DSL split active** | Splitting halves the sample → SUM values are smaller per row → comparing to a non-split pool's cumulative distribution is misleading. Show literal values, no color. |
| 3 | **Avg / P-metric (P10, P95, P99, etc.) percentile coloring: ENABLED** | These are intensive metrics that don't scale with sample. Per-sub-team rate/percentile vs full DSL pool is meaningful and what coordinators want to see. |
| 4 | **Pool semantics: percentiles always computed against the full DSL pool** | No per-sub-team pool. Coloring shows "how is this team doing vs the pack." Pool DEFINITION unchanged per `level-codes.md` BLOCKING rules. |
| 5 | **H/A interaction: orthogonal** | DSL split works independently of the H/A toggle. Each sub-team row gets its own H/A breakdown when H/A is active. |
| 6 | **R/L (handedness) split: DEFERRED to a follow-up** | v1 ships without it. Re-evaluate after DSL split is stable. |
| 7 | **Pin caching: live DB initially** | Don't pre-build pin keys for the split view in v1. Revisit if performance hurts. The split query adds one grouping column, not a fundamentally heavier scan. |
| 8 | **Other orgs with multiple DSL teams: same treatment** | Each gets its own row in the split view. Not HOU-only. |
| 9 | **UI placement: new "DSL" toggle button next to ALL / Home / Away on Org Rankings tab** | Only enabled when DSL is in the user's selected level set. Off by default. |
| 10 | **Tab scope: Org Rankings tab ONLY** | NOT applied to: per-player leaderboard, monthly trends, league pools, KPI weekly, postgame, anything else. |
| 11 | **HOU sub-tab shape: Option X (per-affiliate, DSL → 2 rows = 8 total)** | Verified May 27 2026 by reading `pages/2_Affiliate_Tracker.py:1930-1934`. Current HOU sub-tab is already a 7-row per-affiliate breakdown ranked vs each level's 30-org pool; DSL split simply expands the DSL row into Blue + Orange rows. |
| 12 | **Row labeling: `"HOU - Blue"` / `"HOU - Orange"`** | Derived as `f"{org_abbrev} - {short_team_suffix}"` where `short_team_suffix` is the **last word** of `MLB_eBis.GBL_CLUB_LKUP.team_name` (e.g. "DSL Astros Blue" → "Blue", "DSL Dodgers Bautista" → "Bautista"). Fits existing ORG column width; scans well. |
| 13 | **ALL view ordering: sort by metric (default)** | DSL sub-team rows scatter throughout the 45–60 row leaderboard naturally. User can click ORG column header to group Blue/Orange adjacent for direct comparison. No special grouping logic. |

---

## Concrete shape — HOU sub-tab before/after

### BEFORE (current behavior, verified `pages/2_Affiliate_Tracker.py:1930-1934`)

```
Level   | Pitches | PA  | AB  | <metric cols>
MLB     |   ...   | ... | ... | each colored vs MLB's 30-org pool
AAA     |   ...   | ... | ... | each colored vs AAA's 30-org pool
AA      |   ...   | ... | ... | each colored vs AA's 30-org pool
A+      |   ...   | ... | ... | each colored vs A+'s 30-org pool
A       |   ...   | ... | ... | each colored vs A's 30-org pool
FCL     |   ...   | ... | ... | each colored vs FCL's 30-org pool
DSL     |   ...   | ... | ... | each colored vs full DSL pool
```
Sidebar level filter intentionally ignored — all 7 rows always render.

### AFTER (with DSL split toggle ON)

```
Level         | Pitches | PA  | AB  | <metric cols>
MLB           |   ...   | ... | ... | unchanged
AAA           |   ...   | ... | ... | unchanged
AA            |   ...   | ... | ... | unchanged
A+            |   ...   | ... | ... | unchanged
A             |   ...   | ... | ... | unchanged
FCL           |   ...   | ... | ... | unchanged
DSL - Blue    |   ...   | ... | ... | colored vs full DSL pool (cumulative SUM cols → no color)
DSL - Orange  |   ...   | ... | ... | colored vs full DSL pool (cumulative SUM cols → no color)
```
8 rows. Only the DSL row changes. All other 6 affiliate rows unchanged.

---

## UI sketch

```
┌─ Org Rankings tab ──────────────────────────────────────┐
│                                                          │
│  Scope:  [ ALL ] [ HOU ]                                │
│                                                          │
│  H/A:    [ All ] [ Home ] [ Away ]                      │
│                                                          │
│  DSL:    [ Off ] [ Split ]    ← NEW; only visible when  │
│                                  DSL is in selected      │
│                                  levels                  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Org           | Metric A | Metric B | ... | etc. │   │
│  │───────────────┼──────────┼──────────┼─────┼──────│   │
│  │ HOU           |   .350   |   28.5   | ... |      │   │  ← ALL view, DSL Off
│  │ ATH           |   .342   |   27.1   | ... |      │   │
│  │ ...                                              │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  When DSL split is ON (and ALL view active):            │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Org           | Metric A | Metric B | ... | etc. │   │
│  │───────────────┼──────────┼──────────┼─────┼──────│   │
│  │ HOU - Blue    |   .355   |   29.1   | ... |      │   │  ← Split: each DSL
│  │ HOU - Orange  |   .345   |   27.8   | ... |      │   │     team gets a row
│  │ ATH - Sox     |   .350   |   28.2   | ... |      │   │
│  │ ATH - Stripes |   .335   |   26.5   | ... |      │   │
│  │ ...                                              │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

**Cumulative SUM cells** (NetK, OAA, FramRAA, BlockRAA, SB count, etc.)
render as **plain numbers, no background color** when DSL split is on.
Rate/avg/P-metric cells keep their normal red→green percentile coloring.

---

## Data layer mechanics

### Current grouping (today)
```sql
GROUP BY UPPER(mt.org_abbrev)
```

### DSL-split grouping (new)
```sql
GROUP BY
    UPPER(mt.org_abbrev),
    CASE WHEN sv.gc2_level_code = 'dsl' THEN mt.team_id END,
    CASE WHEN sv.gc2_level_code = 'dsl' THEN mt.team_name END
```

`team_id` and `team_name` come from `MLBAM.Teams` (JOIN on `team_id =
ev1.batting_team_id` per the standard org-tenure pattern). For non-DSL
games, the CASE returns NULL → all those rows roll up under the org
row as before. For DSL games, each (org, team_id) tuple gets its own
row.

### Row count after the split
- Non-DSL orgs (everyone has 1 row per non-DSL level) — unchanged
- DSL orgs with 1 DSL team — 1 row (same as today)
- DSL orgs with 2+ DSL teams — N rows

For the ALL view that's roughly **30 base org rows + ~15–25 extra DSL
sub-team rows** for orgs with multiple DSL teams.

### Two query paths, NOT a runtime branch

Cleanest implementation: separate function for the split path. Existing
function stays unchanged for the default (no-split) view. New function
(name TBD, candidate: `get_org_rankings_dsl_split(...)`) carries the
extra grouping keys.

The UI toggle decides which function to call. No shared SQL that
"sometimes splits, sometimes doesn't" — keeps each path simpler to read
+ debug.

### Pool definition stays untouched

The percentile pool used for coloring is built by
`barrelsville/src/postgame_percentiles.py` (or equivalent for the
tracker — TBD verify which file). That file routes through
`_build_level_filter('dsl')` → `WHERE sv.gc2_level_code = 'dsl'` →
pools all DSL pitches together. No change here. Per `level-codes.md`
two-layer-separation rule, pool definition is invariant.

---

## Display layer

### File expected to need edits

| File | Likely scope |
|---|---|
| `barrelsville/src/tracker_data.py` | Add `get_org_rankings_dsl_split()` (or similar) + helper to look up team_name from GBL_CLUB_LKUP |
| `barrelsville/pages/2_Affiliate_Tracker.py` | Add DSL toggle button; conditional dispatch to split path; suppress coloring on SUM columns when split is on |
| Possibly `barrelsville/src/tracker_pins.py` | Decide whether the split path uses the pin or always live-DB. v1: live-DB. |

### Cumulative column detection

Need a clear list of which Barrelsville tracker columns are cumulative
SUMs (the ones whose percentile coloring gets suppressed). At minimum
for hitter:
- (rare on hitter side — most hitter tracker columns are rates or
  averages, not cumulative SUMs. Need to enumerate at build time.)

For other trackers if/when this propagates:
- Catcher: NetK, FramRAA, BlockRAA, SB count, CS count
- BR: SB, CS, 1→3, 2→H, FT3, S2H counts
- Fielding (OF/IF): OAA, PAA cumulative

Build step: grep `LEADERBOARD_COLS` in `tracker_data.py` + identify
each column's metric type. The "is-cumulative" list goes in a
constant near the other tracker config.

---

## Behavior details

### When DSL is NOT in the selected level set
DSL toggle button is **hidden or disabled** (greyed out). Splitting
doesn't apply.

### When DSL IS in the selected level set but DSL toggle is OFF
Current behavior. Unchanged. HOU's DSL row sums Blue+Orange together.

### When DSL toggle is ON, ALL view
DSL franchises split into sub-team rows. Non-DSL orgs unchanged.
Leaderboard length grows. Cumulative columns lose coloring.

### When DSL toggle is ON, HOU view (Option X — pending Q1 confirmation)
HOU's DSL row → 2 rows (Blue + Orange). HOU view becomes 8 rows
(MLB / AAA / AA / A+ / A / FCL / DSL-Blue / DSL-Orange). Cumulative
columns lose coloring for DSL rows; other rows keep normal coloring.

### Interaction with H/A toggle
- ALL view + DSL split + H/A=Home → each sub-team's Home games only
- ALL view + DSL split + H/A=Away → each sub-team's Away games only
- Pool stays full-DSL (not Home-DSL or Away-DSL)

### Interaction with sched_type filter (R/S/E/V/I)
Independent. Whatever sched_types pass through the data also pass
through the split view.

### Interaction with R/L split (deferred)
Not in v1. When R/L lands, it should be similarly orthogonal.

---

## Build-time checklist (for the next session post-/clear)

All design questions are LOCKED. The next session should /clear, invoke
`superpowers:brainstorming` only if a build-time question genuinely
needs refinement (most don't — this spec is complete), then execute:

1. **Identify cumulative SUM columns** in `LEADERBOARD_COLS` for
   Barrelsville hitter — enumerate which lose coloring on the DSL
   split view. (For hitter most cols are rates/avgs/P-metrics, so the
   list is small. Grep `LEADERBOARD_COLS` + classify each col by
   metric kind.)
2. **Identify the team-name lookup mechanism** — `MLB_eBis.GBL_CLUB_LKUP`
   keyed on `club_id`. Decide: SQL JOIN inline in
   `get_org_rankings_dsl_split()` vs Python-side merge on a cached
   `{team_id: team_name}` mapping. Reference impl in
   `pd-goals/pages/5_Org_Board.py::load_global_club_map()`.
3. **Implement `get_org_rankings_dsl_split()`** in `tracker_data.py`
   mirroring the existing `get_org_rankings()` query with the
   additional grouping keys (see Data layer mechanics section). Same
   filter args, same H/A param, same hand-split param. Returns a
   superset of rows with new `dsl_team_id` + `dsl_team_label` cols
   (NULL for non-DSL rows).
4. **Add `DSL_SPLIT_NO_COLOR_COLS` constant** in `tracker_data.py` or
   `pages/2_Affiliate_Tracker.py` listing cumulative SUM column keys.
   For hitter pilot the list is small (likely empty or just `xwoba_n` /
   `pa` counters if exposed). Confirm at grep time.
5. **Wire the UI toggle** in `pages/2_Affiliate_Tracker.py` — new
   button next to ALL/Home/Away on Org Rankings tab. Visible only
   when DSL is in `selected_level_codes`. Off by default.
6. **Conditional dispatch in `tab_org`:** when toggle ON, call
   `get_org_rankings_dsl_split()`; when OFF, current code path
   unchanged.
7. **Conditional coloring suppression** in `_apply_percentile_bg` (or
   wrapper) — when split is ON, skip background coloring for any col
   in `DSL_SPLIT_NO_COLOR_COLS`.
8. **HOU sub-tab handling** — when split ON, the DSL row in the 7-row
   loop expands into 2+ rows (one per DSL sub-team for HOU). All
   other rows unchanged. Cumulative cols on the DSL rows lose color;
   other rows keep coloring.
9. **Test** with a known DSL date — Blue and Orange should show
   distinct values on HOU sub-tab + ALL sub-tab; FCL/AAA/etc.
   unchanged; coloring suppressed on SUM columns of DSL rows only;
   sort by metric on ALL view scatters Blue/Orange naturally; sort by
   ORG column groups them under their parent org.
10. **Document in `barrelsville.md`** + add a graduation log entry.
11. **Decide on propagation:** after Barrelsville pilot is stable, do
    we roll to Arm Farm, Catcher, OF, IF, BR? Get user direction.

---

## What NOT to do

- **Don't ship to all 5 trackers in one PR.** Barrelsville first; learn,
  then propagate.
- **Don't add a per-sub-team percentile pool.** Pool definition is
  full-DSL only. This is enforced by `level-codes.md` BLOCKING rule.
- **Don't suppress coloring on rate/avg/P-metric columns.** Only
  cumulative SUM columns lose coloring on the split view. Rates and
  percentile-derived metrics retain their normal coloring.
- **Don't show the DSL toggle when DSL is not in the selected level
  set.** No-op UI confuses users.
- **Don't extend split logic to per-player leaderboard, monthly
  trends, or league pools in v1.** Org Rankings tab ONLY.
- **Don't build a pin for the split view in v1.** Live DB. Re-evaluate
  if it's slow.
- **Don't try to split DSL into Blue/Orange purely from level_code.**
  They share `level_code='rok'` AND `gc2_level_code='dsl'`. The split
  is via `team_id` (or team_name) from MLBAM.Teams + GBL_CLUB_LKUP.
- **Don't break the existing default view.** The new split path is
  additive — toggle OFF must return today's exact behavior.

---

## References

- `.claude/rules/level-codes.md` — DSL vs FCL canonical pattern,
  two-layer separation BLOCKING rule for pool definition
- `.claude/rules/org-board.md` — Initial mapping of HOU DSL club_ids
  (599 = Blue, 10000055 = Orange) + GBL_CLUB_LKUP usage
- `.claude/rules/barrelsville.md` — Affiliate Tracker architecture
  (will receive a new "DSL Split" subsection at build time)
- `.claude/rules/three-surface-parity.md` — relevant if split ever
  propagates to KPI weekly / org KPI (it won't in v1)

---

## Status checklist

- [x] User aligned on cumulative-SUM no-color rule
- [x] User aligned on Barrelsville pilot scope
- [x] User aligned on R/L deferred
- [x] User aligned on H/A orthogonal
- [x] User aligned on pool semantics (full DSL pool)
- [x] Q1: HOU view shape — Option X locked (verified `pages/2_Affiliate_Tracker.py:1930-1934`)
- [x] Q2: Row labeling — superseded by ITERATION below
- [x] Q3: ALL view ordering — sort by metric (default), user clicks ORG column to group
- [x] Build approval received (May 27 2026)
- [x] Build complete (Barrelsville hitter, May 27 2026)
- [x] User-verified working in deployed app (May 27 2026)
- [ ] Performance pin work (DSL split + percentile pools — see "Open work" below)
- [ ] Propagation to other 4 trackers

---

## Iteration history (May 27 2026, post-ship)

| Commit | What changed |
|---|---|
| `a4ed17ae` | **v1 ship.** Hardcoded HOU labels (599→"Blue", 10000055→"Orange"). Last-word style. |
| `9bef3d8f` | Rule + graduation log sync |
| `a5262dda` | **v2: dynamic GBL_CLUB_LKUP loader.** Replaced hardcoded dict with lazy `_load_dsl_team_labels()` covering all 30 orgs. Still last-word style ("HOU - Blue"). |
| `f960168e` | **Iteration 1: full CLUBNAME labels + HOU bold on sub-team rows.** Switched from last-word to full `CLUBNAME` ("HOU - DSL Astros Blue"). Changed `_apply_percentile_bg` HOU mask from `.eq("HOU")` to `.str.startswith("HOU")` so DSL-split sub-team rows bold like other HOU rows. |

---

## Open work — pin coverage (NOT YET STARTED)

User reports the DSL split path takes WAY too long on multi-year selections. Root cause:

**Today's pin coverage in `tracker_pins.py`:**

| Bucket | Pinned? |
|---|---|
| `batters` / `monthly_batters` / `weekly_batters` (per-batter) | YES |
| `orgs` / `monthly_orgs` / `weekly_orgs` / `yearly_orgs` (per-org, non-split) | YES |
| `league_distributions` — but **ONLY** 3 metrics: `bb_pct`, `k_bb_pct`, `wrc_plus` | YES (incomplete) |
| **All other percentile pools** (Whiff%, Ctct%, Chase%, Barrel%, Damage, Avg EV, Bat Speed, SwDec, xwOBA, gcOBA, PoC, etc.) | **NO — live DB per (level, season)** |
| **DSL split path** (`get_org_rankings_dsl_split`) | **NO — live DB by design v1** |

**Two pin extensions needed:**

1. **Pin the DSL split path** — add `orgs_dsl_split` bundle key (+ monthly/weekly if needed). Pin CLI computes once per (level, year, H/A, hand), app reads pin. ~5–10 min/year added to pin run.
2. **Pin all percentile pools** — extend `league_distributions` from 3 metrics to ~25 (every column in `_LEAGUE_DIST_METRICS` + visible pool metrics). Pin CLI computes per (level, year). ~10–20 min/year added to pin run.

Both are pure pin schema extensions, no SQL math changes. Both require a full pin re-run to populate the new bundle keys. Existing pins lack the new keys → first read falls through to live DB until re-pin completes.

**Recommendation:** Ship both in one commit (shared pin CLI infrastructure, single re-pin run covers both). 7-place checklist per `rules/tracker-new-metric-checklist.md` applies — handle in a fresh session given the scope.

---

## Propagation plan — other 4 trackers

After Barrelsville pilot validated and pin coverage stable, replicate to the other 4 affiliate trackers. Per-tracker file inventory:

### 1. Arm Farm (pitcher) — `bsb-wt-bullpen/bullpen-report/`

| Role | File |
|---|---|
| Data layer | `bullpen-report/src/tracker_data.py` |
| UI | `bullpen-report/pages/3_Affiliate_Tracker.py` |
| Pin schema | `bullpen-report/src/tracker_pins.py` |
| Pin CLI | `bullpen-report/scripts/pin_tracker_seasons.py` |

**Cumulative SUM cols** (for `DSL_SPLIT_NO_COLOR_COLS`): TBD — likely none for pitcher (most are rates / averages / P-metrics).

### 2. Intangibles BR — `bsb-wt-intangibles/astros-intangibles/intangibles/`

| Role | File |
|---|---|
| Data layer | `intangibles/src/br_tracker_data.py` |
| UI | `intangibles/src/br_tracker_page.py` |
| Pin schema | `intangibles/src/tracker_pins.py` |
| Pin CLI | `intangibles/scripts/pin_br_tracker_seasons.py` |

**Cumulative SUM cols (DSL_SPLIT_NO_COLOR_COLS):** `sb`, `cs`, `ft3` (1→3), `s2h` (2→H), `n_pa`, `bases_on`.

### 3. Intangibles OF + IF (shared via `fielding_tracker_*`) — same worktree

| Role | File |
|---|---|
| Data layer (shared) | `intangibles/src/fielding_tracker_data.py` |
| UI (shared, dispatches OF/IF) | `intangibles/src/fielding_tracker_page.py` |
| Pin schema | `intangibles/src/tracker_pins.py` (shared) |
| Pin CLI | `intangibles/scripts/pin_fielding_tracker_seasons.py` |

**Cumulative SUM cols (DSL_SPLIT_NO_COLOR_COLS):** `oaa`, `paa_cal` (cumulative PAA), `comp_plays` (volume), `total_plays`.

### 4. Intangibles Catcher — same worktree

| Role | File |
|---|---|
| Data layer | `intangibles/src/catching_tracker_data.py` |
| UI | `intangibles/src/catching_tracker_page.py` |
| Pin schema | `intangibles/src/tracker_pins.py` (shared) |
| Pin CLI | `intangibles/scripts/pin_catching_tracker_seasons.py` |

**Cumulative SUM cols (DSL_SPLIT_NO_COLOR_COLS):** `total_netk` (NetK), `fram_raa` (FramRAA), `block_raa` (BlockRAA), `surpp` (SurPP if it's stored as cumulative), `n_sba_events`, `n_depth_pitches`.

### Per-tracker replication checklist (mechanical port)

For each of the 4 trackers, mirror the Barrelsville pattern. Each takes roughly 1–2 hours assuming straightforward queries:

1. **6 org queries** — add `{team_select_src}` / `{team_group_src}` placeholders (+ `{team_select_alias}` / `{team_group_alias}` for any CTE-style queries). Default to empty strings for existing callers.
2. **Add `_get_single_level_dsl_split_org_stats()`** — clone of the tracker's existing `_get_single_level_org_stats` with split placeholder values + merges on `(org, dsl_team_id)`.
3. **Add `get_org_rankings_dsl_split()` wrapper** — dispatches DSL to split helper, other levels to existing one.
4. **Add `DSL_SPLIT_NO_COLOR_COLS` constant** — listing the cumulative SUM cols (per table above).
5. **Reuse `_DSL_TEAM_LABELS_HOU_FALLBACK` + `_load_dsl_team_labels()` + `_resolve_dsl_team_label`** — copy verbatim from Barrelsville's `tracker_data.py`. Module-local, no shared module needed.
6. **UI toggle** — same pattern in each `*_tracker_page.py` (or top-level `pages/N_Affiliate_Tracker.py`). New "DSL" radio above Org Rankings tab content when 'dsl' in `selected_level_codes`.
7. **Cache loader** — `_load_org_rankings_dsl_split` parallel to existing `_load_org_rankings`. Live DB initially; after pin work, switches to pin-first.
8. **HOU sub-tab DSL row expansion** — only applicable for trackers that have an Org Rankings HOU sub-tab (verify per tracker).
9. **HOU bold mask** — same `.str.startswith("HOU")` fix in each tracker's `_apply_percentile_bg` equivalent.
10. **Test in dev** before deploying.

### Three-surface parity gotcha

Per `rules/three-surface-parity.md`, the catcher/OF/IF/BR metrics live in THREE surfaces: tracker, KPI weekly, PD-Goals org KPI. **DSL split is a tracker-ONLY feature** — does NOT propagate to KPI weekly or PD-Goals. Pool definitions must stay unchanged across all three surfaces (full DSL pool, not per-sub-team pool).

### What gets pinned per tracker

If we decide to pin DSL split (after Barrelsville pin work proves the pattern), each tracker gets a new `orgs_dsl_split` bundle key per (year, H/A, hand). Pin CLI extends; pin re-run required per tracker.
- [ ] Documented in `barrelsville.md` + graduation log
- [ ] Propagation decision made
