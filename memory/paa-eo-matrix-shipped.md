---
name: paa-eo-matrix-shipped
description: HOU MiLB PAA/EO matrix one-off — combined-roster matrix PDF shipped May 15 2026 on feature/astros-intangibles. Per-row level coloring against current PP_MASTER level pool. Future integration into PDF or app open.
metadata: 
  node_type: memory
  type: project
  originSessionId: 97c57f3c-78da-49d3-85ac-9bb55bda7857
---

# HOU MiLB PAA/EO Matrix — shipped 2026-05-15

One-off PDF: ONE combined matrix of every HOU MiLB defender (rostered
at AAA / AA / A+ / A / FCL / DSL per PP_MASTER). Built on
`feature/astros-intangibles` worktree. User signoff: "Boom. That's
perfect."

**Final commit on feature/astros-intangibles:** `2293f1d` (proportional
ax_height + 40 rows/page). Earlier sequence:
- `24d8f4f` initial per-level pages (PAA/EO + cumulative NetK, plottable)
- `ee91065` roster filter + cross-level aggregation
- `3d15502` combined matrix + 35 rows/page pagination
- `2293f1d` bumped to 40 rows/page + proportional ax_height for partial last page

## Files

| Role | Path |
|---|---|
| Data layer | `intangibles/src/paa_eo_matrix_data.py` |
| Script + PDF | `intangibles/scripts/generate_paa_eo_matrix.py` |
| Manifest | `intangibles/manifest.json` (added `src/paa_eo_matrix_data.py`) |

## What it produces

One PDF — portrait letter, 40 rows/page (partial last page proportional).
Pages share identical headers / footers.

Layout per row: `Player | Level | # Pos | 1B | 2B | 3B | SS | LF | CF | RF | C`.

- `# Pos` = integer count of distinct positions the player manned this
  year (non-null cells across the 8 position columns). Catcher-only = 1,
  IF/OF utility = 2+, true super-utility = 5+. Plain int, no coloring.
  Width narrow (0.4) so metric cells keep their space.

- Each row = one HOU MiLB defender currently rostered at one of the 6
  MiLB levels per PP_MASTER. MLB-rostered HOU drop (Dezenzo case).
- Row stats = cross-level aggregated (Max Holy A+→AA shows combined
  contribution per position).
- Level column = every level the player appeared at this year,
  slash-joined low-to-high (`A+/AA`, `A/A+/AA`, etc).
- Cell color = within-level percentile vs all-30-orgs at the PLAYER'S
  CURRENT PP_MASTER level. Two rows with the same numeric SS PAA/EO
  can color differently when sitting at different current levels.
- Sort = SS PAA/EO desc, NaNs last (ties broken by player name asc).
- C column = cumulative NetK (sum across MiLB levels caught at).

## Run command

```powershell
cd C:\Users\zbridger\bsb-wt-intangibles\astros-intangibles
git pull
cd intangibles
python scripts/generate_paa_eo_matrix.py
# Output: intangibles/reports/<YYYY-MM-DD>_paa_eo_matrix.pdf
```

CLI flags: `--season YYYY` (defaults to current year), `--output PATH`
to override PDF path. R-season hardcoded in SQL.

## Methodology — key facts to surface in any future iteration

- **Cross-level aggregation is mathematically valid**: the
  `guts.PAA_EO_Position_Calibration` JOIN is keyed on
  `(pos_id, positional, season)` only — NO level join. So paa_cal and
  expected_outs are level-additive and paa_eo re-derives as
  `SUM(paa_cal) / SUM(expected_outs)`. Same additive math
  `_aggregate_dcbp` already does within a single level.
- **Per-row coloring against current-level pool** is a deliberate
  tradeoff. A Max Holy on the AA page shows his combined A+/AA stats
  but colored against the AA-only pool. Mild over-color risk if the
  prior level was much easier. User accepted explicitly when prompted.
- **Levels played string** built from the DCBP per-level query + the
  per-level catcher iteration, union'd per player, sorted by
  `_LEVEL_RANK` and slash-joined.
- **PP_MASTER current-level filter** uses the same
  `_PP_MASTER_LEVEL_MAP` (ml→mlb, 3a→aaa, 2a→aax, 1a→afa, 1f→afx,
  r→rok, ds→dsl) and inactive-status exclusion list as
  `database.get_active_roster_ids`. Implemented as its own helper
  (`get_hou_current_levels`) because we need the inverse map
  (gc_id → level) for per-row coloring lookup, not the per-level set.

## Plottable rendering details worth remembering

- Hidden index column (width=0.001, fontsize=0, color=white) keeps the
  pandas index from rendering.
- Metric cells have a `bbox` (boxstyle="round,pad=0.25") with
  facecolor="#FFFFFF" default. Post-render walks each cell and sets
  `cell.text.get_bbox_patch().set_facecolor(color)` based on the row's
  current_level pool.
- `_fix_null_bbox(tab)` after the table hides bbox patches on `—`/empty
  cells.
- Proportional ax_height for partial last page (May 15 fix):
  `ax_height = _AX_FULL_HEIGHT * (n_rows + 1) / (ROWS_PER_PAGE + 1)`
  with `ax_bottom = _AX_TOP - ax_height`. Keeps physical row size
  identical across full + partial pages. Without this fix, plottable
  auto-fills the ax and a 10-row final page renders rows ~4× taller
  than full pages.

## Design iterations (user-driven)

The build went through 4 user-driven shape changes in one session:

1. Initial: 6 per-level pages, all HOU defenders with plays at that
   level, plottable.
2. Roster filter + cross-level aggregation: only show players currently
   rostered at the page's level, aggregate stats across every level
   they played at. (User direction: "do not list a player if they had
   played at the level [but moved], list them if they currently play
   there.")
3. ONE combined matrix instead of 6 per-level pages. Level column added.
   35 rows/page pagination. (User direction: "no level exclusive shit.")
4. Final: 40 rows/page + proportional last-page ax_height. (User
   noticed last-page rows ballooned because plottable filled the ax.)

## App integration plan — LOCKED (2026-05-16)

**Target:** Intangibles app, `feature/astros-intangibles` worktree, as
a NEW top-level Streamlit page (numbering TBD — likely
`intangibles/pages/5_Defense_Matrix.py` or similar).

**Why Intangibles (not PD Engine):**
- All source modules already live in that worktree
  (`paa_eo_matrix_data.py`, `fielding_tracker_data.py`,
  `catching_tracker_data.py`, the PP_MASTER roster helper).
- `feedback_no_cross_worktree_imports.md` rules out putting it in
  PD Engine even though PD Engine also surfaces fielding org views.
- Mental model: this is a fielding view; Intangibles owns fielding.

**Why a new top-level page (not a tab on Catching/Fielding):**
The matrix spans IF + OF + C — it doesn't fit inside any single
existing page. Adding a 5th top-level page is the right tradeoff.

**Open shape questions for the build session** (do not ship without
deciding):

1. **Filters on the page?**
   - Season selector (default current year via `datetime.now().year`)
   - Optional level multi-select (e.g., hide DSL/FCL by default, show
     full when toggled)
   - Or: render exactly what the PDF shows with no controls

2. **Sortable columns?**
   - `st.dataframe` gives Streamlit-native sort on every column
     (coach can resort by 2B PAA/EO) but loses per-row level coloring
   - Plottable-rendered version preserves coloring but loses sort
   - Hybrid (Plotly Table or custom HTML) preserves both but ~2-3x code

**Data layer ready as-is.** `build_combined_matrix(season)` returns
the full displayed DataFrame including the hidden `current_level`
column for the coloring-pool lookup. Per-level pool fetchers
(`get_fielding_paa_eo_pool`, `get_catcher_netk_pool`) cache cleanly
behind `@st.cache_data`. No new SQL needed.

**Do not preemptively ship** — wait for user to OK the two open
questions, then build.

## What NOT to do

- Don't reintroduce per-level page splits. User explicitly killed that
  in iteration 3.
- Don't drop the `_fix_null_bbox(tab)` call — empty cells will show
  their default white bbox and the layout looks broken.
- Don't switch to a fixed ax_height for partial pages — the
  proportional math is the fix.
- Don't simplify by coloring every row against a single global pool.
  Per-row current-level pool lookup is load-bearing.
- Don't relax the MiLB-only roster filter to include MLB-rostered HOU
  players (Dezenzo case). User explicitly wanted them dropped.

## Cross-references

- `.claude/rules/three-surface-parity.md` — the PAA/EO + NetK metrics
  this matrix surfaces also live in tracker + KPI weekly + PD-Goals
  org KPI. Any future change to the metric definition propagates to
  all three plus this matrix.
- `.claude/rules/multi-level-rollup.md` — `_aggregate_dcbp` and the
  iron rule on weighting; cross-level aggregation here mirrors the
  weighting math from there.
- `.claude/rules/fielding.md` — Tier 1 gate semantics (matrix uses
  `HAVING SUM(out_prob) > 0` as the implicit gate).
- `intangibles/src/snapshot_report.py` — reference impl for the
  plottable + percentile coloring + `_fix_null_bbox` pattern.
- `barrelsville/scripts/generate_amateur_vs_pro.py` — sibling one-off
  for the cover/footer banner style.
