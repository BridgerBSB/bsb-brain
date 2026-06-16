# Tracker "Stat (Rank)" → AgGrid Numeric Sort + DSL Label Fix (PORTING SPEC)

Two fixes shipped together on the **Barrelsville hitter** affiliate tracker
(June 2026) that MUST be ported to the other 4 trackers. This file is the
exact, mappable spec. Barrelsville is the reference implementation — **copy
its code verbatim and adapt the helper/symbol names to each tracker.**

Pilot status: SHIPPED + user-liked on Barrelsville. Other 4 = TODO.
**No repins anywhere** — both fixes are pure display / live-DB.

Pairs with `tracker-stat-rank-display.md` (the st.dataframe-era Stat (Rank)
mode — still governs the OTHER 3 modes) and `tracker-save-screen.md` (the
open Save-Screen-with-AgGrid problem, below).

---

## PART A — AgGrid numeric sort for "Stat (Rank)" mode

### Problem
`Stat (Rank)` is the DEFAULT tracker display mode (boss request). Each metric
cell is a STRING like `"9.8% (12)"`. `st.dataframe` sorts a column by its
underlying cell value — a string — so it sorts **lexicographically**:
`"98.0"` lands above `"100.0"` because `'9' > '1'`. The other 3 modes
(`Stat`, `Rank`, `Percentile`) store numeric cells and sort fine.

`st.dataframe` **cannot** numeric-sort a combined "value (rank)" cell: the
formatter is scalar-only (can't append rank) and the sort uses the underlying
scalar. Zero-padding breaks on negatives (PAA/RAA/wRC+). **AgGrid is the only
clean fix** — its `valueFormatter` receives the whole row, so the cell stays
NUMERIC (correct sort) while displaying "value (rank)" pulled from sibling
fields.

### The pattern (surgical — AgGrid ONLY in Stat (Rank))
Other modes keep their EXACT existing `st.dataframe` path. Every metric-table
render site is gated:

```python
if at_display_mode == "Stat (Rank)" and _AGGRID_AVAILABLE:
    _render_stat_rank_aggrid(display_df, source_df, ranked_df, metric_keys,
                             highlight_hou=..., qualified_mask=..., key="...")
else:
    # ── existing st.dataframe block, byte-identical ──
```

### Resilient import (top of the page module)
```python
try:
    from st_aggrid import AgGrid, JsCode, GridUpdateMode
    _AGGRID_AVAILABLE = True
except Exception:
    _AGGRID_AVAILABLE = False
```
If `streamlit-aggrid` fails to import on Connect, Stat (Rank) falls back to
the (lex-sorting) st.dataframe path — **no crash**. This is mandatory.

### Dependency
Add to that tracker app's `requirements.txt`:
```
streamlit-aggrid>=1.0.5,<1.2.0
```
The Connect manifest pulls deps from requirements.txt (no packages block to
edit). The page file is already in the manifest `files` allow-list.

### The helper — canonical source
`barrelsville/pages/2_Affiliate_Tracker.py :: _render_stat_rank_aggrid`
+ module constants `_AGG_VALUE_FORMATTER`, `_AGG_CELL_STYLE`,
`_AGG_INFO_NUM_FORMATTER`, `_AGG_INFO_BOLD_STYLE`, `_AGG_INFO_WIDTHS`,
`_AGG_NUMERIC_INFO`. **Copy these verbatim**, then adapt symbol names to the
target tracker (`_METRIC_KEY_TO_LABEL`, `HIGHER_IS_BETTER_MAP`, `_get_bg_color`,
`_stat_fmt_string` — every tracker has equivalents; names may differ).

How it works:
- Metric column `field` = the **numeric value** (so AgGrid numeric-sorts it).
- Hidden sibling fields per metric: `{label}__disp` (Python-formatted value
  string), `{label}__rank`, `{label}__bg` (hex precomputed via the tracker's
  `_get_bg_color`/`percentile_to_color`).
- ONE generic `valueFormatter` JsCode for all metric cols reads
  `params.colDef.field` and returns `disp + " (" + rank + ")"` (or `"-"`).
- ONE generic `cellStyle` JsCode sets `backgroundColor` from `__bg` and
  `fontWeight:bold` if `__hou`.

### THREE gotchas — every port MUST include all three (each was a shipped bug)
1. **Explicit height, NEVER `domLayout="autoHeight"`.** autoHeight mis-measures
   the iframe on first paint AND on mode-switch remount → bottom rows clipped
   until an interaction. Use `height = 30 + len(data)*30 + 18` (header +
   rows*rowHeight + chrome) passed to `AgGrid(height=...)`. Commit `eb9d138f`.
2. **NaN-safe numeric info formatter.** `PA`/`AB`/`Pitches`/`Age` are
   `numericColumn`s; a NaN (any partial/initial-load frame OR DSL sub-team
   row) renders AgGrid's literal `"Invalid Number"`. Coerce those cols with
   `pd.to_numeric(..., errors="coerce")` + attach `_AGG_INFO_NUM_FORMATTER`
   (blank on null/NaN/non-finite; integer except Age 1dp). General, not
   DSL-only. Commit `9f145dbf`.
3. **Bold HOU rows on INFO columns too.** The metric `cellStyle` bolds HOU
   rows, but info cols (Org/PA/AB/Pitches) need their own `_AGG_INFO_BOLD_STYLE`
   cellStyle or the row looks un-bolded vs Stat mode (which bolds the whole
   row). `__hou` is only set when `highlight_hou`; `startswith("HOU")` also
   catches both DSL-split sub-team rows. In commit `0f728992`.

Plus: `allow_unsafe_jscode=True`, `theme="streamlit"`,
`fit_columns_on_grid_load=False`, `update_mode=GridUpdateMode.NO_UPDATE`,
unique `key=` per render site, `suppressFieldDotNotation: True`.

### Which tables convert (per tracker)
Only the **sortable metric leaderboards** — every render site that currently
does `_apply_percentile_bg(df.style, ...).format(...)` → `st.dataframe(...)`.
**Leave the Level Pools reference panel on st.dataframe** (never sorted).

Grep recipe per tracker page to find the sites:
```
grep -n "st.dataframe" <tracker_page>.py     # then keep the styled metric-table ones
```

| Tracker | Page file | Notes |
|---|---|---|
| Barrelsville hitter | `barrelsville/pages/2_Affiliate_Tracker.py` | **DONE (reference)** — 4 sites: HOU sub, HOU-vs, Org ALL, HOU 7-row |
| Arm Farm pitcher | `bullpen-report/pages/3_Affiliate_Tracker.py` | TODO |
| Intangibles BR | `intangibles/src/br_tracker_page.py` | TODO |
| Intangibles Fielding (OF+IF) | `intangibles/src/fielding_tracker_page.py` | TODO (powers both via render("OF")/("IF")) |
| Intangibles Catcher | `intangibles/src/catching_tracker_page.py` | TODO |

Each tracker's `_build_*_display` / `_apply_percentile_bg` / info-column set /
metric-label map differ — adapt, don't assume Barrelsville's columns. BR has
cumulative SUM cols (`DSL_SPLIT_NO_COLOR_COLS`), Catcher/Fielding have their
own; the helper already skips coloring for non-`HIGHER_IS_BETTER_MAP` metrics.

---

## PART B — DSL split labels keyed on MLBAM team_id (NOT GBL_CLUB_LKUP.CLUB_LK)

### Problem
With DSL split ON, the Org Rankings tab rendered every org's DSL row as
`"ORG - Team <id>"` (e.g. `"HOU - Team 601"` / `"Team 5005"`), including HOU —
the "DSHOUB/DSASOR" short names were never actually live.

Root cause: the DSL split GROUPS by **MLBAM `team_id`** (`mt.team_id` →
601 = DSL Astros Blue, 5005 = DSL Astros Orange), but `_load_dsl_team_labels`
+ the hardcoded fallback were keyed on **`GBL_CLUB_LKUP.CLUB_LK`**
(599 Blue / 10000055 Orange) — a DIFFERENT id space with no bridge column —
so nothing matched → "Team N".

### Resolved data (`sql-queries/dsl-team-label-mismatch.sql`, commit `15275d9a`)
- `MLBAM.Teams` (`league='DSL'`): `team_id` 601 → `name` "DSL Astros Blue",
  5005 → "DSL Astros Orange". `name` is the real club name and is keyed on
  the SAME team_id the split groups on → resolves for all 30 orgs.
- `GBL_CLUB_LKUP.CLUB_LK` 599/10000055 do NOT equal MLBAM team_id; no
  mlbam-id column to join on.

### Fix (per tracker `*_tracker_data.py`)
Rewrite `_load_dsl_team_labels()` to source from `MLBAM.Teams` keyed on
`team_id`, latest-season name wins; re-key the HOU fallback. Canonical:
`barrelsville/src/tracker_data.py` (commit `0f728992`):
```python
sql = "SELECT team_id, name, season FROM MLBAM.Teams WHERE league = 'DSL' AND name IS NOT NULL"
# best[team_id] = name with max season ; returns {team_id: name}
_DSL_TEAM_LABELS_HOU_FALLBACK = {601: "DSL Astros Blue", 5005: "DSL Astros Orange"}
```
`_resolve_dsl_team_label(team_id)` is unchanged (still: dynamic → HOU
fallback → "Team N"). Live-DB, no repin.

Per-tracker copies to fix (identical GBL-keyed helper in each):
`bullpen-report/src/tracker_data.py`, `intangibles/src/br_tracker_data.py`,
`intangibles/src/fielding_tracker_data.py`,
`intangibles/src/catching_tracker_data.py`. Verify each has the same helper
before editing.

---

## Rollout checklist (per tracker)
1. Add `streamlit-aggrid>=1.0.5,<1.2.0` to that app's `requirements.txt`.
2. Copy the import block + AgGrid helper + constants; adapt symbol names.
3. Gate every styled metric-table `st.dataframe` site (Part A). Leave Level
   Pools as st.dataframe.
4. Apply the Part B DSL helper fix in that app's `*_tracker_data.py`.
5. Syntax-check: `python -c "import ast; ast.parse(open(FILE,encoding='utf-8').read())"`.
6. Commit + push on that worktree's feature branch.
7. User pulls + redeploys + verifies (sort, height, no Invalid Number, HOU
   bold, DSL "Blue/Orange", Save Screen).

---

## OPEN — Save Screen with AgGrid (afterthought, AFTER rollout)
The 💾 Save Screen button (`tracker-save-screen.md`) uses `window.print` on
the page DOM. AgGrid renders in an iframe and virtualizes rows, so print may
clip / capture poorly. UNSOLVED — to be tackled after the 5-tracker rollout.
Candidate directions: AgGrid `domLayout` print mode, an AgGrid CSV/Excel
native export instead of print, or forcing all rows into DOM before print.
Do NOT block the rollout on this.

---

## What NOT to do
- **Don't** use `domLayout="autoHeight"` — first-load/remount clip. Explicit height.
- **Don't** convert the Level Pools panel (never sorted; fussiest coloring).
- **Don't** bold metric cells only — info cols need the bold cellStyle too.
- **Don't** leave numeric info cols without the NaN-safe formatter ("Invalid Number").
- **Don't** drop the `try/except` import + `_AGGRID_AVAILABLE` gate — the
  fallback is the safety net if the dep isn't on Connect.
- **Don't** touch the other 3 display modes — they sort fine; keep their
  st.dataframe paths byte-identical.
- **Don't** key DSL labels on `GBL_CLUB_LKUP.CLUB_LK` — use `MLBAM.Teams.name`
  keyed on `team_id` (the split's grouping key).
- **Don't** assume Barrelsville's columns/symbol names — each tracker differs.
- **Don't** repin for either fix — both are display/live-DB only.

---

## Bug history
- **June 2026** — Barrelsville pilot. `ee64426b` (AgGrid pilot) → `eb9d138f`
  (explicit height) → `9f145dbf` (Invalid Number) → `0f728992` (HOU bold +
  DSL labels). DSL diagnostic `15275d9a`. Status memory:
  `memory/tracker-aggrid-stat-rank-status.md`.

## Cross-references
- `tracker-stat-rank-display.md` — Stat (Rank) mode + the other 3 modes (st.dataframe).
- `tracker-save-screen.md` — Save Screen (the open AgGrid-iframe problem).
- `streamlit-tracker-column-pinning.md` — st.dataframe pinning (AgGrid uses
  native `pinned:'left'`, no 60% threshold issue).
- `tracker-new-metric-checklist.md` — per-tracker file map.
- `barrelsville.md` — DSL Organization Split feature.
