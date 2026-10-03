# Arm Farm (bullpen-report/) — CLAUDE.md

## In-Progress Feature: Matchup Pitch Optimizer

Third tab in `pages/4_Pitching_Advance.py`. Recommends top 2 pitch×zone
combos per count bucket for a specific pitcher vs hitter matchup.

### Status (as of 2026-06-05)
- [x] Count bucket scheme: Early (0-0,1-0,1-1) / Ahead (0-1,0-2,1-2,2-2) / Behind (2-0,2-1,3-0,3-1,3-2)
- [x] Integrated (pitch_type × zone) scoring — NOT greedy
- [x] 3-zone Ahead display (0-2=red, 1-2=orange, 2-2=yellow) with distinct-zone guarantee
- [x] Heatmap: blue=pitcher winning, red=hitter winning (dynamic per-cell normalization)
- [x] Zone numbering 1-17 (fixed pitcher's-view coords)
- [x] In-zone labels: horizontal thirds (Upper/Middle(Horz)/Lower) + vertical thirds (Outer/Middle(Vert)/Inner) — platoon-aware
- [x] OOZ labels: Up, Down, In, Away, Up-And-In, Up-And-Away, Low-And-In, Down-And-Away
- [x] PDF export via `generate_optimizer_pdf_bytes` (zone drawn first, labels from heatmap)
- [x] App and PDF always show identical RVs (single recs computation, no random subsampling)
- [x] Rehab pitcher inclusion: ML-level pitchers included only if their last game was at the selected affiliate level
- [x] Roster cache: 600s TTL (uniform with rest of app)

---

## Zone System

**17 fixed zones in pitcher's view (LEFT = 1B side):**

```
     10 | 11 | 12          ← above zone (OOZ)
       ___________
  17  | 1  2  3  |  13     Zone 13 = right OOZ (inside to RHH)
      | 4  5  6  |         Zone 17 = left  OOZ (inside to LHH)
      | 7  8  9  |
       -----------
     16 | 15 | 14          ← below zone (OOZ)
```

**In-zone scoring uses 6 BANDS (not 9 cells):**
- Rows (horizontal thirds): `upper` (1-3), `mid_h` (4-6), `lower` (7-9)
- Cols (vertical thirds): `glove` (1,4,7), `mid_v` (2,5,8), `arm` (3,6,9)

**Labels (bat-side aware for columns):**
- `upper` → Upper Third | `mid_h` → Middle Third (Horz) | `lower` → Lower Third
- `mid_v` → Middle Third (Vert)
- RHH: `glove` → Outer Third, `arm` → Inner Third
- LHH: `glove` → Inner Third, `arm` → Outer Third

**OOZ zone number ↔ label** (RHH example):
10=Up-And-Away, 11=Up, 12=Up-And-In, 13=In, 14=Low-And-In,
15=Down, 16=Down-And-Away, 17=Away (all flip for LHH)

---

## Eligibility Rules (`_eligible_third_ids`)

```
RHP arm OOZ = {12,13,14}   LHP arm OOZ = {10,16,17}
up_ooz = {10,11,12}

Breaking balls (SL/CU/KC/CS/ST/SV/SC) + CH/FS — ALL counts:
  forbidden = {"upper"} | arm_shadow | up_ooz
CH/FS additionally:
  forbidden += glove_shadow_ooz  (RHP: {16,17}; LHP: {13,14})
  → changeups NEVER go glove-side OOZ

Early/Behind: in-zone only ({upper,mid_h,lower,glove,mid_v,arm} - forbidden)
Ahead 0-2/1-2: OOZ only ({10..17} - forbidden), fallback to general if OOZ sparse
Ahead 0-1/2-2: all zones except mid_v (- forbidden)
```

---

## Scoring Architecture

**`_compute_zone_rv_scores`** (data module):
- Builds NW surfaces: `p_surf` (pitcher RE288 rv) and `h_surf` (hitter RE288 rv)
- Combined = `p_surf − h_surf` (negative = pitcher winning = blue)
- Grid: 80×80, bandwidth 0.35 ft, NO random subsampling (deterministic)
- Returns sorted list `[(zone_id, combined_rv, n_pitches), ...]`

**`get_matchup_recommendations`** returns `(recs, all_pitches)`:
- `recs`: top-2 `(pitch_type, zone)` pairs per bucket ranked by `loc_rv`
- `all_pitches`: all ranked combos with zone labels (for sidebar summary)
- Same recs reused for PDF — no second call, no RV discrepancy

**Ahead 3-zone heatmap**: pre-computes general ranking, then assigns distinct zones
per count (0-2 tries OOZ first, falls back to general; `used_zones` set prevents stacking)

---

## Key Files

| File | Role |
|---|---|
| `src/advance_pitching_data.py` | `get_matchup_recommendations`, `_compute_zone_rv_scores`, `_OPT_ZONE_RECTS`, `_band_id_to_label_data`, `_thirds_label`, rehab pitcher logic |
| `src/advance_pitching_report.py` | `_eligible_third_ids`, `_score_thirds`, `_draw_third_highlights`, `_band_id_to_label`, `_draw_optimizer_heatmap`, `_make_zone_fig`, `_opt_zone_figcoords`, `generate_optimizer_pdf_bytes` |
| `pages/4_Pitching_Advance.py` | `_render_opt_grid`, `_render_opt_per_hitter`, PDF download |
| `sql-queries/mlb-rv-by-pitch-zone-count.sql` | MLB 2025 gcperf rv by pitch/zone/count/split reference query |

---

## Blocking Rules That Apply

1. **PDF-last** — PDF block sits below all `st.*` calls
2. **Dual-query path** — app and CLI/PDF use same recs (no separate recompute)
3. **Coordinate convention** — `plate_x` raw catcher's view in data; flipped in report
4. **`SCOPE_SCHED_TYPES = "('R','S','E')"`** — do not change
5. **No random subsampling in `_compute_zone_rv_scores`** — deterministic NW
6. **Zone labels must match heatmap**: text uses `zone_labels.get("best")` from `_draw_optimizer_heatmap`, not centroid fallback where possible
