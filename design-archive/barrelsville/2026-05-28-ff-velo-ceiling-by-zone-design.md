# FF/FT Velo Ceiling by Zone Height — Per-Hitter Heatmap

**Status:** Design locked 2026-05-28. v1 = batch PDF, app integration deferred.
**Worktree:** `bsb-wt-hitting/barrelsville`, branch `feature/barrelsville`.

---

## CURRENT STATUS — PAUSED (June 8 2026), awaiting feedback

**The chart is shipped + iterated on `feature/barrelsville`. We're pausing here
and waiting on Farm Director + hitting coordinator feedback before doing more.**
Resume = pick the per-band gate (below) and revisit the deferred items.

### What changed since the v1 lock (these SUPERSEDE the locked table below)
- **Bands: 5 → 3** (top / middle / bottom third) — larger per-cell sample. (was #6)
- **Velo buckets: 1 mph → 2 mph** (90-91 … 100-101 = 6 columns). (was #7)
- **Baseline scope: global FF/FT → in-grid (Shadow height bands + 90-101 mph).**
  Apples-to-apples: each cell is graded vs his contact on *comparable* fastballs,
  not all fastballs anywhere (out-of-zone chases used to drag the bar down). (was #4)
- **`--batter <gc_id>` flag** for single-hitter runs (default = whole-org batch,
  same shape as `hitter_analysis.py`).
- **PDF bottom-text overlap fixed** + plain-language labels (says "his own FF/FT
  average", not the jargon word "baseline").
- **Ceiling marker row bug fixed** — the orange marker was being drawn one band
  too low (Band 1's ceiling landed on Band 2, Band 3's fell below the grid).

### One OPEN decision — the per-band gate (not yet chosen)
Per-cell 10-swing min is still in place, so thin bands + high-velo edges grey out
and ceilings are often capped by sample, not skill. Three options on the table:
- **(A) band-level gate, no per-cell grey** *(recommended; band min ~20 swings)*
- (B) just lower the per-cell min 10 → 6
- (C) cumulative-from-bottom ceiling
Needs the user's pick on resume.

### Still deferred (unchanged, revisit after feedback)
- Horizontal (`plate_x`) gate — currently height-only; a fastball at the right
  height but off the plate laterally still counts.
- Bands off measured `sz_top`/`sz_bot` instead of the height-derived ABS zone.
- Streamlit app integration.
- Per-pitch-type (FF vs FT) + platoon (vs LHP/RHP) splits.
- On-PDF legend/key box (offered, not built — explainer lives in Slack for now).

### Files + run
- Data: `barrelsville/src/velo_ceiling_data.py`
- Script: `barrelsville/scripts/generate_velo_ceiling_heatmap.py`
- Whole org: `python barrelsville/scripts/generate_velo_ceiling_heatmap.py`
- One guy: `... --batter <gc_id>` (Daudet 252859, Schiavone 218498)
**Recovery:** Original brainstorming session 2026-05-27 (transcript
`8e707411-f247-45bb-919f-627a1b5b3c15.jsonl`) crashed mid-design before
sample-min was settled. This doc finishes the four open items and locks
everything end-to-end so the next crash doesn't lose the work.

---

## The question we're answering

For each hitter, what's the highest FF/FT velocity they can still handle
at each height-fifth of the strike zone? "Handle" = their Contact% in that
(band × velo) cell stays at-or-above their own global FB Contact% baseline.

The output: one heatmap per hitter, 5 horizontal bands × ~12 velo bins,
with a "ceiling" line drawn per band at the highest velo bucket where
they still pull their average contact rate.

---

## 13 locked decisions

| # | Decision | Locked value |
|---|---|---|
| 1 | SZ variant | A — per-hitter (`get_batter_zone_bounds()`, hitter's actual height) |
| 2 | Visual shape | Heatmap + threshold-line callout per band |
| 3 | Success metric | Contact% relative to hitter's own baseline |
| 4 | Baseline scope | Global per hitter (one number, pooled across whole scope) |
| 5 | Vertical extent | Tango Shadow (wider than ABS) |
| 6 | Vertical split | 5 equal-height horizontal bands |
| 7 | Velo bucket grain | 1 mph integer bins |
| 8 | Velo range | 90–101 mph (12 bins). Pitches outside dropped from grid. |
| 9 | Ceiling rule | Permissive — highest qualifying velo bin per band, gaps below allowed |
| 10 | Sample-min per cell | 10 swings |
| 11 | Threshold gate | cell Contact% ≥ hitter's global FB Contact% (any drop = degraded) |
| 12 | Pitch types | FF + FT pooled |
| 13 | Output / scope | Batch PDF of all hitters, current season, all levels combined. `--batter` flag for single-hitter test. `--seasons` flag for multi-season pool. |

---

## Architecture

```
barrelsville/
├── src/
│   └── velo_ceiling_data.py        # NEW data layer
│       └── get_velo_ceiling(batter_id, seasons, level_codes, min_swings=10)
│           → returns (df_60cells, baseline_contact_pct)
└── scripts/
    └── generate_velo_ceiling_heatmap.py     # NEW batch CLI
        --batter <gc_id>            # optional, default = all qualifying MiLB hitters
        --seasons 2026 [2025 …]     # default = current calendar year
        --levels aaa aax afa afx rok dsl   # default = all MiLB (DSL included)
        --min-swings 10             # default cell qualifier
        --min-total-swings 100      # min total FF+FT swings to publish a heatmap
        --output <path>             # default = barrelsville/reports/Velo_Ceiling_<seasons>_<date>.pdf
```

Scope **excludes MLB** (different talent pool would skew the
"what they can handle" question). DSL included per user direction
2026-05-28.

---

## Per-hitter DataFrame shape (60 rows)

| col | dtype | notes |
|---|---|---|
| `batter_id` | int | gc_id |
| `band_idx` | int 1–5 | 1 = top of Tango Shadow, 5 = bottom |
| `band_z_lo` / `band_z_hi` | float | feet, per-hitter from `get_batter_zone_bounds()` |
| `velo_bin` | int | 90, 91, … 101 |
| `n_swings` | int | swings in this cell |
| `contact_pct` | float | (swings − whiffs) / swings — canonical Ctct% per `gc2-metrics.md` |
| `qualifies` | bool | `n_swings ≥ 10 AND contact_pct ≥ baseline` |
| `is_ceiling` | bool | this cell is the ceiling for its band |

Plus a scalar `baseline_contact_pct` per hitter — their global FF+FT
Contact% across the same (seasons × levels) scope.

---

## Data flow & SQL

1. **Pull every FF+FT swing** the hitter took across the scope:
   - `pitch_type IN ('FF','FT')`
   - `did_swing = 1`
   - `pitch_id > 0`
   - `sched_type = 'R'`
   - `level_code IN <selected>` via `_build_level_filter` / `_apply_level_codes`
   - `YEAR(sched_date) IN <selected>`
   - Exclude `pitch_result IN ('intentional_ball','pitch_out')`
   - Standard bunt exclusion via `hit_trajectory_id NOT IN (2,3,4) OR NULL`
2. **Per-pitch row** carries: `batter_id`, `plate_z`, `release_speed`,
   `is_whiff` (canonical = `did_swing=1 AND pitch_result_id IN WHIFF_CODES`).
3. **Python binning**:
   - Look up batter height → `abs_zone_bounds(height_ft)` → Tango Shadow
     Z extent (`shadow_z_lo`, `shadow_z_hi`).
   - Split that extent into 5 equal bands (each ~4.5″ for a 6'0″ hitter).
   - Assign each swing to `(band_idx, velo_bin = floor(release_speed))`.
   - Drop swings outside band Z extent (above/below Shadow).
   - Drop swings outside `[90, 101]` velo range.
4. **Group by** `(batter_id, band_idx, velo_bin)` → `n_swings`, `n_whiffs`,
   `contact_pct`.
5. **Compute baseline** per hitter: their global Contact% across the same
   FF+FT scope (NOT band-restricted, NOT velo-restricted — every FF+FT
   swing in scope counts).
6. **Mark qualifying cells**: `n_swings ≥ 10 AND contact_pct ≥ baseline`.
7. **Find ceiling per band**: highest `velo_bin` where `qualifies = True`.
   Permissive — cells above the ceiling that fail don't downgrade it;
   cells below the ceiling that fail don't downgrade it either. The
   ceiling is just the **max qualifying bin** per band.

---

## PDF layout

Mirror `hitter_analysis.py` chrome — landscape 11×8.5, one hitter per
page, footer with name + level + season + n.

Per hitter:
- Left half: heatmap. X-axis = velo bins 90–101, Y-axis = band 1–5 (top
  to bottom). Cell color = Contact% on a diverging colorscale anchored
  at baseline (white = at baseline, red below, green above). Cells with
  `n < min_swings` rendered grey ("insufficient sample") with the small
  N number inscribed.
- Overlay: ceiling line drawn per band as a vertical bracket at the
  ceiling velo's right edge. Bands with NO qualifying cell show
  "no ceiling" annotation at the right margin.
- Right half: small reference table —
  - Hitter name, level(s), seasons, total FF+FT swings, baseline Contact%
  - Per-band breakdown: ceiling velo, n_swings in band, qualifying cells

Skip hitters with fewer than `--min-total-swings` (default 100) total
FF+FT swings in scope. Logged but not rendered.

---

## Canonical pieces reused (not re-derived)

- `barrelsville/src/database.py` — `_BIP_FILTER`, `_WHIFF_CODES`,
  `_build_level_filter`, `_apply_level_codes`
- `barrelsville/src/plots.py` — `abs_zone_bounds(height_ft)` for Tango
  Shadow Z extent
- `barrelsville/src/postgame_data.py` — `_lookup_batter_height()`,
  `get_batter_zone_bounds(batter_id)`
- Standard SZ variant A height-source flow per `sz-planning-prompts.md`
- Canonical Contact% formula per `gc2-metrics.md` —
  `(swings - whiffs) / swings`

---

## Out of scope for v1

- Per-pitch-type splits (FF vs FT separately)
- Per-platoon splits (vs LHP / vs RHP)
- Vertical bands relative to ABS instead of Tango Shadow
- Streamlit app page
- Comparison to org or league baseline
- Cross-season trend ("his ceiling climbed from 94 to 97 between 2024
  and 2026") — possible later via `--seasons` flag aggregation
- BIP outcome metrics (xwOBA, Damage%) per cell — only Contact% in v1
- Wilson confidence-interval gates (offered during brainstorm, rejected
  in favor of hard sample-min)

---

## Future iteration paths (do not build now)

1. Streamlit page integration — Postgame tab or Affiliate Tracker
2. xwOBA / Damage% second-layer heatmap (same grid, different color)
3. FF vs FT split when sample supports it
4. Comparison overlay — "MLB avg ceiling at this height/age cohort"
5. Trend animation across multiple seasons
