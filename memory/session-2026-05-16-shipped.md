---
name: session-2026-05-16-shipped
description: May 16 2026 session — Defense Matrix page + WoW rollout (6 trackers) + SRV×FBVelo scatter + Trend Visuals (5 trackers) + WoW-first reorder. Plus discovered percentile-pooling bug for multi-year individual leaderboards.
metadata: 
  node_type: memory
  type: project
  originSessionId: 86a79174-14a1-443b-b8cf-f8f80de50a37
---

## 🛑 RESUME-HERE BLOCK (last touched 2026-05-16 evening, VS Code closing)

User context was breaking, asked for a clean handoff before closing VS Code.

**All branches pushed clean. Latest HEADs:**

| Branch | HEAD | Latest |
|---|---|---|
| `feature/astros-intangibles` | `81c898e2` | fielding arm-range tooltip fix |
| `feature/pd-goals` | `4d911d9e` | two-tier percentile rule doc |
| `feature/bullpen-reports` | `6bfaaf48` | rule doc sync |
| `feature/barrelsville` | `228060c5` | postgame vba_con SQL fix |

**What's actually SHIPPED vs PENDING right now:**

- ✅ Fielding (OF+IF) percentile-pooling fix — `2d3d9da9`. Nunez Arm 87.5/80.6 now pools to ~87.5 in multi-year view (was wrongly 85.9 weighted-mean). **MEMORY.md "Fix not yet shipped" line is STALE — fix DID ship.**
- ✅ All 5 trackers got Trend Visuals tab + HOU-only/hide-non-HOU toggles.
- ✅ WoW tab added to all 6 trackers + WoW-first reorder. **Re-pin not yet done.**
- ✅ Defense Matrix page on PD Engine. **Pin not yet populated on Connect.**
- ✅ Org SRV×FBVelo scatter PDF script ready.
- ❌ Catcher percentile-pooling — same bug class, no fix shipped. ~6-8 hr port. DEFERRED.
- ❌ Work-laptop re-pins for WoW (Barrelsville ~1.5h, Arm Farm ~15-20h overnight, Intangibles ×3 ~7-10h).

**First three things to do next session:**

1. `git pull` on all 4 worktrees on work laptop
2. Run `python intangibles/scripts/pin_paa_eo_matrix.py --season 2026` (populates Defense Matrix pin)
3. Decision: kick off WoW re-pins overnight, OR ship catcher pooled fix first?

---

## What shipped (May 16 2026) — 5 work streams, ~25 commits across 4 branches

### 1. PD Engine Defense Matrix page (PR-style ship)
- **Pin CLI** (intangibles): `intangibles/scripts/pin_paa_eo_matrix.py` writes `zbridger/paa_eo_matrix_<season>` parquet pin. Commit `b43c9c6` on `feature/astros-intangibles`.
- **Loader** (pd-goals): `pd-goals/src/paa_eo_matrix_loader.py` reads the pin.
- **Page** (pd-goals): `pd-goals/pages/7_Defense_Matrix.py` renders the HOU MiLB matrix interactively. Renders an orange "pin not populated" banner with the exact CLI to fix if pin missing.
- **Landing card**: 5th nav card on `PD_Engine.py` ("DEFENSE MATRIX").
- **Manifest**: updated for new files.
- Commit `d7cfce5` on `feature/pd-goals`.

**Why pin bridge?** `paa_eo_matrix_data.py` imports `get_catcher_leaderboard` from intangibles' big catching module. Per `feedback_no_cross_worktree_imports.md` we can't import cross-worktree → pin is the canonical bridge (same pattern as `goals.csv`).

### 2. WoW rollout to all 6 affiliate trackers (3 parallel agents)
WoW (Week-over-Week) tabs added alongside existing MoM/YoY across every tracker. New `_WEEKLY_*` SQL queries, new pin schema bundle keys, new tab UI. Per `tracker-new-metric-checklist.md` (5-place discipline).

| Tracker | Branch | Commits |
|---|---|---|
| Barrelsville hitter | `feature/barrelsville` | `6e67e39`, `647662a`, `88ed8b0` |
| Arm Farm pitcher | `feature/bullpen-reports` | `2d8b81b`, `d541fbf`, `d073328`, `cde7235` |
| Intangibles BR | `feature/astros-intangibles` | `bc95207`, `35ef824` |
| Intangibles Fielding (OF+IF shared) | same | `26ea10b`, `ad323b3` |
| Intangibles Catcher | same | `f3d35b0`, `17be169` |

**Pin matrix growth (per tracker, per year)**:
- Barrelsville: 46 → 64 keys
- Arm Farm: 45 → 63 keys (handedness × H/A)
- Intangibles BR: 45 → 63 keys
- Intangibles Fielding: 15 → 21 (no handedness)
- Intangibles Catcher: 45 → 63 keys

**Work-laptop full re-pin** needed for each tracker (~1.5h Barrelsville, ~15-20h Arm Farm, ~7-10h Intangibles combined). NOT done yet — overnight job.

### 3. Org SRV × FB Velo scatter PDF
- SQL: `sql-queries/org-srv-fbvelo-scatter.sql` (on `feature/pd-goals`)
- Script: `bullpen-report/scripts/generate_org_srv_fbvelo_scatter.py` (canonical home — Arm Farm)
- 2-panel side-by-side (2025 left, 2026 right), 30 dots per panel, HOU orange star, navy others
- SQL inlined as `_SQL` constant — self-contained, no cross-branch sql-queries/ dep
- Final commits: `01c02af2` (Arm Farm move), `5cafece0` (SRV label fix — see `feedback_srv_is_stuff_relative_to_velocity.md`)

### 4. Trend Visuals — interactive in-app version (5 trackers, 3 parallel agents)
NEW top-level tab on every affiliate tracker page. 2 sub-tabs (Org Rankings + Individual), 2 user-selectable axes (X+Y dropdowns populated with all metric + info columns). Pooled panel top, per-level panels stacked below when 2+ levels selected.

| Tracker | Default axes | Commit |
|---|---|---|
| Barrelsville hitter | `Dmg%` × `Avg EV` | `7754cb48` on `feature/barrelsville` |
| Arm Farm pitcher | `SRV` × `FB Velo` | `216ba390` on `feature/bullpen-reports` |
| Intangibles BR | `1B Prim` × `SB%` | `2d58cb8d` on `feature/astros-intangibles` |
| Intangibles Fielding | OF: `TopSpd × Arm`, IF: `React × Arm` | `19ff6457` |
| Intangibles Catcher | `NetK × Pop 2B` | `cc1ce760` |

**No new SQL, no pin changes** — pure presentation on top of existing cached `get_*_leaderboard` / `get_org_rankings` data.

### 5. WoW-first reorder (Trends sub-tab order)
Flipped all trackers so WoW auto-opens as default Trends sub-tab (was MoM). Commits `9faf11f5` (Arm Farm) + `0debc4e8` (Intangibles 3 trackers). Barrelsville already had it. Pure UI, no re-pin.

---

## THE PERCENTILE-POOLING ARCHITECTURE (READ THIS FIRST IF /clear HAPPENS)

The rule is two-tier and the same shape regardless of selection scope:

| Selection scope | Individual tier (one player's value) | Org tier (30 players → 1 org value) |
|---|---|---|
| 1 yr, 1 lvl | Pool his raw obs in that scope → his P-value | Weighted-mean of every player's individual P-value |
| Multi yr, 1 lvl | **Pool his raw obs across ALL selected years** | Weighted-mean of every player's individual P-value |
| 1 yr, multi lvl | **Pool his raw obs across ALL selected levels** | Weighted-mean of every player's individual P-value |
| Multi yr, multi lvl | **Pool his raw obs across ALL (year × level) combos** | Weighted-mean of every player's individual P-value |

**Individual = ALWAYS pool raw obs.** Whatever scope is selected, his entire pool of throws → one true P99.
**Org = ALWAYS weighted-mean of individuals.** Weighted by per-metric n_obs (n_arm for arm_strength, n_react for react, etc.) per `multi-level-rollup.md`. Prevents starter-dominance.

The org-tier rule in `multi-level-rollup.md` ("per-player weighted avg, NEVER direct pool") applies ONLY to org tier. Individual tier is supposed to be fully pooled — same as `get_player_all_time_bests` (MIN/MAX), `*_postgame_percentiles.py` (PERCENTILE_CONT season-wide), and the now-fixed fielding tracker individual leaderboard.

### What today's fix (`2d3d9da9`) did
Made the FIELDING (OF+IF) tracker individual leaderboard ALWAYS pool, regardless of scope (was weighted-meaning per-(year, level) percentiles when multi-year/multi-level was selected). Org tier unchanged — still weighted-means individuals (correctly). Both tiers now done in ONE pooled SQL pass with `per_fielder` + `org_agg` CTEs.

### What CATCHER still has wrong
Same individual-tier weighted-mean bug. Worse problem: no pooled SQL function exists in `catching_tracker_data.py` at all. To fix, the pooled SQL pattern needs to be built from scratch (~6-8 hr). Same architecture (`per_catcher` CTE → `org_agg` CTE) just hasn't been ported yet. **NOT shipped this session.**

### What BR / Hitter / Pitcher do
- BR: AVG metrics (lead distance) — additive, math-equivalent to pooled. No fix needed.
- Hitter / Pitcher: rate metrics (K%, BB%, FF Velo) — re-derive from SUM(numer)/SUM(denom). Math-equivalent to pooled. No fix needed.
- Only percentile metrics need the pooled-individual fix. Fielding shipped, catcher pending.

## BUG DISCOVERED THIS SESSION — Percentile pooling for individual multi-year (BLOCKING TODO)

User's example: **Alejandro Nunez (IF)**
- 2025 Arm: 87.5 mph
- 2026 Arm: 80.6 mph
- Combined display (2025+2026 selected): **85.9 mph** — a weighted-mean number that doesn't exist physically in his throws

### Root cause
`fielding_tracker_page.py::_combine_multi_level` (line 889) handles both multi-level AND multi-year rollup for the individual leaderboard. For percentile metrics (Arm P99, React P25, TopSpd P95, Exch P10), it does:
```python
w_col = "comp_throws"   # hardcoded (line 946) — should be n_arm per multi-level-rollup.md
row[arm_strength] = (vals * weights).sum() / weights.sum()
```
Weighted mean of per-(year, level) percentiles ≠ percentile of pooled raw obs. **Not "cosmetic drift" — actual ~5+ mph delta from truth in cases like Nunez.**

### Where pooling IS done correctly (only ONE place)
`fielding_tracker_data.py::_get_pooled_org_stats` — fielding ORG view, single-year multi-level. SQL `PERCENTILE_CONT OVER (PARTITION BY fielder_id)` with `level_code IN (...)`. ✅ correct per-fielder pooling, then weighted-avg to org.

### Where pooling ISN'T done (everywhere else)
- Fielding individual leaderboard, ANY multi (level OR year)
- Fielding org rankings, multi-year
- Catcher EVERYTHING — no pooled SQL function exists in `catching_tracker_data.py` at all
- (BR uses AVG not percentile → math-equivalent to pooled; no fix needed)
- (Hitter/Pitcher org metrics are rates from SUM/SUM → already correct)

### Architecture user confirmed (per `multi-level-rollup.md` "Org Rollup for P-metrics"):
| Tier | What | Method |
|---|---|---|
| Individual | One player across his obs | POOL raw obs → his actual P-value |
| Org | 30+ players collapsed | Weighted-mean of individual pooled values, by per-player n_obs |

Org tier is INTENTIONALLY weighted-mean (not pool-of-all-throws) to prevent top thrower dominance. Documented + correct in `_get_pooled_org_stats`.

### Fix effort (revised after re-reading code)
- **Fielding (OF+IF) — extend pooled SQL to accept `season IN (...)` + add individual leaderboard path**: ~4-6 hr. ONE data-layer file (`fielding_tracker_data.py`) + page wiring. Fixes Nunez AND multi-year org rollup at the same time.
- **Catcher — port the pooled pattern from scratch**: ~6-8 hr. No `_get_pooled_*` exists today; whole pattern needs adding.
- **All in for fielding + catcher, individual + org, multi-level + multi-year**: ~12-16 hr. Agent-doable in parallel dispatches.

### Pin matrix impact
Zero — pooled SQL runs on-demand against live DB (raw obs aren't pinned). ~5-10s cold-load per selection, cached.

### Fix shipped — commit `2d3d9da9` on `feature/astros-intangibles`
- New per-fielder pooled SQL templates (`_INDIV_POOLED_TRACKING_QUERY` + DCBP + Games) + 3 new per-org pooled templates extended for multi-year
- New helpers: `_build_year_filter`, `_build_scope_filter`, `_build_pooled_tracking_query`, `_build_pooled_nontracking_query`
- New public function `get_indiv_leaderboard_pooled(domain, level_codes, seasons, ...)`
- Extended `_get_pooled_org_stats` + `get_org_rankings_pooled` to accept `season: int OR List[int]` — backward-compat dispatch on `isinstance(season, (list, tuple))` at line 3350
- Page: `_load_indiv_leaderboard_pooled` cached loader; `_combine_multi_level` takes new `use_pooled=True` arg that reads pooled DF via closure to override P-metric cells only (SUM metrics unchanged)
- Scope guards: `use_pooled=False` passed at Yearly tab line 2820 + Trend Visuals per-level panels line 3519 (those iterate over scope subsets where pooled override is wrong)
- Trigger: pooled fires when `len(seasons) > 1 OR len(level_codes) > 1` (extended from previous "multi-level only")
- **Tier 1 6-term gate preserved** in both `_INDIV_POOLED_TRACKING_QUERY:1474` and `_ORG_POOLED_TRACKING_AGG_QUERY:1693`
- Pin behavior: ON-DEMAND live DB, cached `@st.cache_data(ttl=64800)`. Pins NOT touched, no re-pin needed.

### Expected Nunez post-fix
Arm with 2025+2026 selected jumps from 85.9 → close to 87.5 (his hardest 2025 throws still hold the top 1% of pooled 2025+2026).

### Out of scope (deferred)
- **Catcher** — same fix needed; no pooled SQL exists in `catching_tracker_data.py` at all. ~6-8 hr follow-up. User deferred this session.
- **BR** — uses AVG not percentile; no fix needed (additive math is equivalent to pooled).

## Trend Visuals Individual TOGGLES — added late session

User request: 2 independent checkbox toggles on the Individual sub-tab of Trend Visuals across all 5 trackers:
1. "HOU only" — filter `df["org"] == "HOU"`
2. "Hide non-HOU labels" — keep all dots, blank labels for non-HOU dots

Both default OFF. Widget keys per-tracker (`_barr`, `_armfarm`, `_br`, `_fielding_of`/`_fielding_if`, `_catcher`).

**Status when last update written:**
- Barrelsville: ✅ shipped — commit `525d6daf` on `feature/barrelsville`
- Arm Farm: ✅ shipped — commit `22d337d7` on `feature/bullpen-reports`
- Intangibles BR: ✅ shipped — commit `55e55673` on `feature/astros-intangibles`
- Intangibles Fielding (OF+IF shared, domain-keyed widgets): ✅ shipped — commit `d253ea7a`
- Intangibles Catcher: ✅ shipped — commit `6843d056`

**ALL 5 trackers have toggles now.** Pull + redeploy each Streamlit app on work laptop. No re-pin needed (pure UI).

---

## LATE-SESSION CLEANUPS (after main work landed)

### Two-tier architecture graduated to rules (synced 4 worktrees)
- `feature/pd-goals` `4d911d9e`, `feature/barrelsville` `1398989b`, `feature/bullpen-reports` `6bfaaf48`, `feature/astros-intangibles` `13bece3a`
- Added "TWO-TIER ARCHITECTURE FOR PERCENTILE METRICS" section to top of `.claude/rules/multi-level-rollup.md`. The table:

| Scope | Individual tier | Org tier |
|---|---|---|
| Any (1×1, multi-yr, multi-lvl, compound) | Pool raw obs → P-value | Weighted-mean of individuals by per-metric n_obs |

- Individual = ALWAYS pool. Org = ALWAYS weighted-mean of individuals.
- Graduation log entry appended to `.claude/rules/.graduation-log.md` (bottom of file — wrong position per newest-first convention but content correct; can reorder next session).

### DCBP debug log removed (`a0ebe3a8` on `feature/astros-intangibles`)
- Killed the "DCBP Debug Log" expander at bottom of Fielding tracker Leaderboard tab
- Removed 7 `.append()` write-side calls
- One fail-path notice converted from `_DCBP_DEBUG.append` → `print()` (Connect logs only)
- `_DCBP_DEBUG` constant in `fielding_tracker_data.py` left as harmless dead code (can sweep later)

### Tooltip arm-range fix (`81c898e2` on `feature/astros-intangibles`)
- Fielding tracker Arm Strength + Comp Thr tooltips previously said "60-94 IF / 60-100 OF" (those are GC2's filter cutoffs, not ours)
- Now correctly say **"70-108 IF / 75-108 OF"** — matches our SQL (`fielding_tracker_data.py:1601` BETWEEN arm_lo AND arm_hi)
- Catcher tooltips (60-94) untouched — catcher's range really IS 60-94 per `fielding.md`
- Snapshot report still has stale "60-94" tooltip — flagged for next session

---

## RESIDUAL ISSUE — Trend Visuals per-level panels (compound multi-level × multi-year only)

Trend Visuals Individual tab per-level panels use `use_pooled=False` to avoid misapplying the multi-pool DF (which is keyed on full selected scope per fielder) to a single-level slice.

**Correct for:** 1 year × 2+ levels (per-level panels are single-scope, nothing to pool).
**Residual bug for:** 2+ years × 2+ levels — within a per-level panel (e.g. AAA panel) values are weighted-meaned across years instead of pooled.

Same bug class as the main one, only fires on this one sub-surface in compound selection. Pooled panel above it + main leaderboard + org views are all correct.

**Fix scope:** ~1-2 hr (add per-(level, multi-year) pooled fetch per panel). Deferred — not blocking, low-traffic.

---

## STILL DEFERRED — Catcher percentile fix
Same bug as fielding had (weighted-mean of per-(year/level) percentiles at individual tier). No `_get_pooled_*` function exists at all in `catching_tracker_data.py` — pattern needs porting from fielding. ~6-8 hr.

---

## FINAL COMMIT TIMELINE (May 16 2026)

In order of landing:

| Commit | Branch | What |
|---|---|---|
| `b43c9c6` | astros-intangibles | Defense Matrix pin CLI |
| `d7cfce5` | pd-goals | Defense Matrix page + loader + landing card |
| `01c02af2` | bullpen-reports | SRV × FB Velo scatter (canonical home) |
| `5cafece0` | bullpen-reports | SRV label fix |
| `6e48891a` | pd-goals | SRV scatter deletion (moved to Arm Farm) |
| WoW × 6 trackers | 3 branches | 13 commits (see WoW section above) |
| `9faf11f5` + `0debc4e8` | bullpen + intangibles | WoW-first reorder |
| `7754cb48` + `216ba390` + `2d58cb8d` + `19ff6457` + `cc1ce760` | 3 branches | Trend Visuals × 5 trackers |
| `2d3d9da9` | astros-intangibles | **Percentile pooling fix** (the big one) |
| `525d6daf` + `22d337d7` + `55e55673` + `d253ea7a` + `6843d056` | 3 branches | Trend Visuals toggles × 5 trackers |
| `4d911d9e` + `1398989b` + `6bfaaf48` + `13bece3a` | all 4 | Two-tier architecture graduated to rules |
| `a0ebe3a8` | astros-intangibles | DCBP debug log removed |
| `81c898e2` | astros-intangibles | Tooltip arm-range fix |

~37 commits across 4 branches, 7 background agents dispatched + landed clean, 1 manual percentile-pooling fix shipped, 1 manual rules graduation, 2 manual late-session cleanups. Memory + rules + graduation log all synced.

**SAFE TO /clear.** Everything is in git + memory file. Next session loads this file first.

---

## Misc this session

- **SRV ≠ "Stuff Release Velocity"** — see new `feedback_srv_is_stuff_relative_to_velocity.md`. I invented the wrong long form on the scatter PDF; user caught it; relabeled to just "SRV" in commit `5cafece0`. Memory file says: never invent long-form expansions; just use the abbreviation.
- **PAA/EO matrix combined PDF** — shipped earlier this session, then iterated 4x (added Level col, # Pos col, position-count distribution title page). Final commit `35c442d` on `feature/astros-intangibles`. See `paa-eo-matrix-shipped.md`.
- **Xavier Neyens weekly PAA/EO + React SQL** — `sql-queries/xavier-neyens-weekly-paa-eo.sql` (commit `f8cd6d7` on `feature/pd-goals`). 3 columns: week_start | week_end | paa_eo | react | n_react. React caveats: IF-only (pos 3-6), Tier 1 6-term gate, HawkEye sparsity, P25 from small per-week samples is noisy.

---

## All branches pushed, all worktrees clean. Pending user actions:

| Action | Where | Cost |
|---|---|---|
| Pull all 4 worktrees on work laptop | `git pull` × 4 | 1 min |
| Pin Defense Matrix | `python intangibles/scripts/pin_paa_eo_matrix.py --season 2026` | ~3-5 min |
| Run SRV × FB Velo scatter PDF | `python bullpen-report/scripts/generate_org_srv_fbvelo_scatter.py` | <1 min |
| WoW full re-pin (Barrelsville) | `python scripts/pin_tracker_seasons.py` | ~1.5-2 hr |
| WoW full re-pin (Arm Farm) | `python scripts/pin_tracker_seasons.py` | ~15-20 hr (overnight!) |
| WoW full re-pin (Intangibles ×3) | run 3 pin scripts in sequence | ~7-10 hr |
| Redeploy each Streamlit app | per app deploy path | 5-10 min |
| **Decision: ship percentile-pooling fix now or after re-pin?** | user input | — |
