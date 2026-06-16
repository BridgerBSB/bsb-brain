---
name: dsl-org-split-design
description: "DSL organization split for affiliate trackers — SHIPPED 2026-05-27 on Barrelsville pilot incl. v2 dynamic GBL_CLUB_LKUP loader (all 30 orgs). Pending work-laptop verification + propagation decision."
metadata: 
  node_type: memory
  type: project
  originSessionId: 377feacf-7ccf-473f-8111-708fa7543bf1
---

# DSL Organization Split — SHIPPED on Barrelsville (May 27 2026)

**Status:** SHIPPED — Barrelsville pilot live on `feature/barrelsville`
commit `a4ed17ae`. Awaiting work-laptop pull + verification + propagation
decision.

**Spec doc (canonical):**
`bsb-wt-hitting/barrelsville/docs/plans/2026-05-27-dsl-org-split-design.md`

## What's shipped

DSL sub-team split toggle on Barrelsville Affiliate Tracker Org Rankings
tab. New "DSL" radio (Off / Split) appears at top of Org Rankings tab
when DSL is in the selected level set. "Split" expands DSL franchises
into one row per sub-team (HOU → "DSL - Blue" / "DSL - Orange"). Other
orgs with multi-team DSL get same treatment (fall back to "Team N"
label until GBL_CLUB_LKUP integration).

## Commits

| Worktree | Branch | Commit | What |
|---|---|---|---|
| bsb-wt-hitting | feature/barrelsville | `61add989` | Spec doc initial |
| bsb-wt-hitting | feature/barrelsville | `eab32f1c` | Spec doc lock |
| bsb-wt-hitting | feature/barrelsville | `a4ed17ae` | **v1 code ship** (hardcoded HOU labels) |
| bsb-wt-hitting | feature/barrelsville | `9bef3d8f` | Rule + graduation log sync |
| bsb-wt-hitting | feature/barrelsville | `a5262dda` | **v2 dynamic GBL_CLUB_LKUP loader** (all 30 orgs) |
| bsb-resources | feature/pd-goals | `5a96bcb9` | Rule + graduation log + discovery SQL v1 |
| bsb-resources | feature/pd-goals | `9500e605` | Discovery SQL: CLUB_LK column name fix |
| bsb-wt-bullpen | feature/bullpen-reports | `d9f4f320` | Rule + graduation log sync |
| bsb-wt-intangibles | feature/astros-intangibles | `6254543c` | Graduation log sync |

## Locked scope (do NOT extend without user direction)

- Pilot: Barrelsville hitter tracker ONLY
- Tab scope: Org Rankings tab ONLY (no per-player / monthly / postgame / KPI weekly)
- Pool definition unchanged (full DSL pool per `level-codes.md` two-layer rule)
- H/A orthogonal; R/L hand-split deferred
- Live DB v1 (no pin keys for split view)
- Cumulative SUM no-color: empty for hitter, architecture in place for future BR/Catcher/OF/IF propagation
- **v2 (May 27 2026 same session):** dynamic GBL_CLUB_LKUP load via `_load_dsl_team_labels()` (lru_cache, single DB hit per process). All 30 orgs' DSL sub-team names populate from `ACTIVE_FLG=1 AND LEVELOFPLAY_LK='DS'`. Schema verified: CLUB_LK varchar(15), CLUBNAME varchar(50). Last-word extraction handles "DSL Astros Blue" → "Blue", "DSL Dodgers Bautista" → "Bautista", etc. Hardcoded HOU dict (`_DSL_TEAM_LABELS_HOU_FALLBACK`) retained as safety fallback when DB lookup fails (FreeTDS hiccup, permission issue). Unknown team_ids still fall back to "Team N" placeholder.

## Files touched (Barrelsville hitter pilot)

| File | What changed |
|---|---|
| `barrelsville/src/tracker_data.py` | 6 org queries with `{team_select_*}` / `{team_group_*}` placeholders, `_get_single_level_dsl_split_org_stats` + `get_org_rankings_dsl_split` functions, `_DSL_TEAM_LABELS` dict + `_resolve_dsl_team_label` helper, `DSL_SPLIT_NO_COLOR_COLS` frozenset, `_compute_bat_speed_per_org` `groupby_keys` param |
| `barrelsville/pages/2_Affiliate_Tracker.py` | Import additions, `_load_org_rankings_dsl_split` cache loader, "DSL" radio toggle, conditional dispatch, ALL sub-tab org-column relabel, HOU sub-tab DSL row expansion |
| `.claude/rules/barrelsville.md` | New "Affiliate Tracker — DSL Organization Split" subsection (synced to 3 of 4 worktrees) |
| `.claude/rules/.graduation-log.md` | Top entry (synced to all 4 worktrees) |
| `sql-queries/dsl-split-discovery.sql` | Schema discovery for the v2 GBL_CLUB_LKUP integration |

## What's next (next session)

### 1. Work-laptop pull + test

```bash
cd C:\Users\zbridger\bsb-wt-hitting
git pull
# Either run Streamlit locally, or rsconnect redeploy
```

### 2. User verification checklist

- DSL toggle hidden when DSL not in selected levels
- DSL toggle visible + functional when DSL in selected levels
- ALL sub-tab: 30+ rows when split on (DSL only); sort by metric scatters Blue/Orange; sort by ORG column groups them
- HOU sub-tab: 8 rows when split on (6 affiliates + DSL Blue + DSL Orange)
- H/A toggle still works (orthogonal to split)
- Other orgs' DSL teams render as "Team N" placeholder (until v2)

### 3. Discovery SQL (work laptop, optional)

`sql-queries/dsl-split-discovery.sql` validates schema for v2
GBL_CLUB_LKUP integration. Run on work laptop, paste results to
Claude — if mlbam.teams + GBL_CLUB_LKUP shape matches what's expected,
v2 swaps hardcoded HOU dict for dynamic 30-org lookup.

### 4. Propagation decision (after verification)

Roll to other 4 trackers? Each would replicate the same 6-file +
checklist pattern:
- Arm Farm (pitcher)
- Intangibles BR (runners)
- Intangibles OF + IF (fielding — shares `fielding_tracker_data.py`)
- Intangibles Catcher

Each needs its own `DSL_SPLIT_NO_COLOR_COLS` populated (BR adds SB/CS,
Fielding adds OAA/PAA cumulative, Catcher adds NetK/FramRAA/BlockRAA).

## Known limitations (post-v2)

1. ~~**Team labels hardcoded for HOU only.**~~ **RESOLVED v2 (`a5262dda`)** — dynamic GBL_CLUB_LKUP load covers all 30 orgs. Hardcoded HOU dict retained as safety fallback. Unknown team_ids (no GBL row, no HOU fallback match) render as "Team N".
2. **Pool semantics interpretation.** When split is on with single-level DSL, percentiles are computed against the displayed 30+ row set (not the unsplit 30-org pool). User may want stricter "vs unsplit 30-org pool" semantics — flagged for v3 if desired.
3. **Multi-level OR multi-year + split.** `aggregate_org_across_levels` collapses sub-team rows back into one row per org. Effectively means split is only visible in the single-level-DSL + single-year case. Documented in inline comments.

## What NOT to do

- Don't extend split to other tabs without explicit user direction (only Org Rankings)
- Don't add a per-sub-team percentile pool (pool stays full-DSL)
- Don't ship to BR/Catcher/OF/IF until pilot validated
- Don't suppress coloring on rate/avg/P-metric columns — only cumulative SUMs
- Don't drop the `{team_select_*}` / `{team_group_*}` placeholder passthrough in `_get_single_level_org_stats` — defaults to empty strings (zero behavior change for non-split path); removing breaks the format() calls
- Don't try to split DSL into Blue/Orange purely from level_code — they share `gc2_level_code='dsl'`. Split via `team_id` from `mlbam.teams` (and v2 GBL_CLUB_LKUP for labels)

## Cross-refs

- `.claude/rules/barrelsville.md` — "Affiliate Tracker — DSL Organization Split" subsection
- `.claude/rules/level-codes.md` — DSL/FCL canonical, two-layer pool separation rule
- `.claude/rules/org-board.md` — HOU DSL club_ids (599 Blue, 10000055 Orange) + GBL_CLUB_LKUP usage
- `pd-goals/pages/5_Org_Board.py::load_global_club_map()` — reference impl for GBL_CLUB_LKUP loading
- `sql-queries/dsl-split-discovery.sql` — v2 GBL_CLUB_LKUP integration discovery query

**Session that produced this ship:** 2026-05-27 — same session as the
postgame `--level rok/dsl` SELECT-alias + Live AB admit-mask shipment.
Both DSL-related fixes came out of the same DSL-clarification arc.
