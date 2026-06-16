---
name: Catcher Framing Hexbin one-off (SHIPPED v1, May 12 2026)
description: Per-catcher framing heatmap PDF on `feature/astros-intangibles`. 3 pages per catcher (Total / vs RHP / vs LHP), 6 hexbin panels per page (2 years × 3 pitch buckets), Tango SZ overlay, pool-gated colorbar. Header NetK byte-matches canonical KPI weekly / tracker. User flagged for possible leaderboard/dashboard integration in v2.
type: project
originSessionId: ab66b0ed-b07c-45a1-9036-65c1fb626353
---
## What it is

CLI-generated multi-page PDF showing where each HOU MiLB-rostered
catcher is gaining/losing strikes via framing, split by pitch group
and pitcher handedness. Lives in the intangibles realm but doesn't
touch the Streamlit app — pure ad-hoc PDF for coordinator review.

User said v1 "looks pretty darn good" on the work laptop May 12 2026.
May iterate tomorrow.

## Files (worktree: `bsb-wt-intangibles/astros-intangibles/`)

| Role | Path |
|---|---|
| Data layer | `intangibles/src/catcher_framing_hexbin_data.py` |
| CLI + PDF renderer | `intangibles/scripts/generate_catcher_framing_hexbin.py` |
| Design doc | `intangibles/docs/plans/2026-05-12-catcher-framing-hexbin-design.md` |
| Manifest registry | `intangibles/manifest.json` (line 57) |

Branch: `feature/astros-intangibles`. Latest commit: `c19f684`.

## Output

`output/Catcher_Framing_Hexbin_2025-2026.pdf` — one combined PDF.
~20 catchers × 3 pages each ≈ 60 pages (catchers with 0 pitches in
both years get skipped entirely; catchers with data in one year
only still get 3 pages with empty-year placeholders).

Run command (work laptop):
```powershell
cd C:\Users\zbridger\bsb-wt-intangibles\intangibles
python scripts/generate_catcher_framing_hexbin.py
# or with explicit seasons / delivery channel:
python scripts/generate_catcher_framing_hexbin.py --seasons 2025 2026 --deliver --channel C0ABHSF6SCA
```

## Per-page layout

Each page is landscape letter, 2 rows × 3 cols of hexbin maps.

```
+---------------------------------------------------------------+
| {Catcher Name}                            NetK ({page_label}) |
| {page_label: Total / vs RHP / vs LHP}     2025  +12.40       |
| Current level: AAA | Seasons: 2025-2026   2026   -8.10       |
| Pitches in scope: N,NNN                                       |
+---------------------------------------------------------------+
|  2025 |  [FB hex]   [OS hex]   [BB hex]                       |
|       |                                                       |
|  2026 |  [FB hex]   [OS hex]   [BB hex]      [Colorbar]       |
+---------------------------------------------------------------+
| Generated YYYY-MM-DD ... · Red = strikes lost ... catcher's view |
+---------------------------------------------------------------+
```

3 pages per catcher: **Total** (all pitcher_throws), **vs RHP**
(pitcher_throws='R'), **vs LHP** (pitcher_throws='L').

## Locked design decisions (all questioned and answered by user during
the session — don't reinvent without re-asking)

1. **Pitch buckets** — `FB: FF/FT/SI/FC`, `OS: CH/FS`, `BB: SL/SW/CB/CU/KC/ST`.
2. **Hex value** — `reduce_C_function=np.mean` on `pv.net_k` (the
   pre-computed canonical per-pitch column, NOT computed in SQL).
   Each hex shows mean per-pitch NetK contribution in that location.
3. **Colormap** — `RdBu` (red = lost strikes, blue = stolen
   strikes). User explicitly flipped from "red=good" to "red=bad"
   early in the session.
4. **Colorbar scale** — symmetric `±max(|p1|, |p99|)` derived from
   per-pitch `pv.net_k` across the league pool at that catcher's
   current PP_MASTER level. White at 0 = level avg.
5. **Pool gate** — `POOL_MIN_PITCHES = 1500` framing-window pitches
   per catcher at the level (matches canonical NetK pool gate in
   `c_kpi_data.py` and `catching_tracker_data.py`). Display is
   UNGATED — every rostered catcher shows up as 3 pages regardless.
6. **Handedness split** — by PITCHER hand (`pv.pitcher_throws`), NOT
   batter hand. User explicitly corrected mid-session: catcher cares
   what arm slot is delivering. Values 'R' / 'L'.
7. **Strike zone overlay** — TWO rectangles per `sz-framework-savant-zones.md`:
   - Heart (solid) = ABS rectangle, 17" wide × 1.626-3.221 ft
   - Shadow OUTER (dashed) = 26.6" wide × 1.197-3.651 ft
   Initial v1 had Shadow wrongly at 20" (the Tango ENVELOPE, not the
   Shadow OUTER ring). Fixed in `945bb4a`.
8. **Orientation** — catcher's view. Raw `pv.plate_x` (no flip)
   because intangibles + raw DB convention is catcher's perspective.
   Home plate pentagon drawn point-DOWN. See `coordinates.md`.
9. **Roster filter** — HOU MiLB only (`LEVELOFPLAY_LK NOT IN ('ml')`,
   `POSITION_LK = 'C'`, active per usual Alvaro filter). Mirrors
   `kpi-roster-filter.md` inverted.
10. **Data scope** — ALL their called pitches across ALL levels
    (MLB callup pitches still count), `sched_type = 'R'`,
    `pitch_id > 0`, canonical NetK filter from
    `catching_tracker_data.py::_COMBINED_FRAMING_QUERY:1057-1124`.
11. **Skip empty catchers** — if 0 pitches across both years, skip
    entirely (continue past page loop). Auguste Cunio + similar
    shell-roster guys won't waste 3 blank pages.
12. **Per-year NetK in header** — 2025 and 2026 totals stacked
    separately so the header mirrors the 2-row hex grid. Each year
    colored independently (orange positive, red negative).
13. **Header NetK byte-matches KPI weekly** — verified Perez 2026
    -16.70 = -16.70 after parity fix `2f8071c`. Pool filters that
    drift from canonical (`plate_x IS NOT NULL` etc.) were removed
    from SQL and moved to the Python render path so SUM stays clean.

## Bug history during session

| Commit | Bug |
|---|---|
| `70e876f` | `IN :tuple` → pyodbc TVP error. Inlined as SQL literal. Documented in `feedback_pyodbc_in_tuple_tvp.md`. |
| `5b66625` | `pv.sz_top` / `pv.sz_bot` columns don't exist in this DB. Catcher report uses league-avg constants. Dropped from SELECT. |
| `945bb4a` | Shadow zone drawn at 20" (Tango ENVELOPE) instead of 26.6" (Shadow OUTER). Pivoted to 6-panel layout + pitcher-hand handedness same commit. |
| `40e9893` | Initial handedness was batter-side. User wanted PITCHER side. Swapped `pv.bat_side` → `pv.pitcher_throws`. Also added 1500-pitch pool gate same commit. |
| `2f8071c` | `plate_x/plate_z IS NOT NULL` SQL filter caused 0.28 NetK gap vs KPI weekly canonical. Moved coord drop to Python render path. |
| `c19f684` | Skip catchers with 0 pitches in both years (Auguste Cunio case). |

## Future ideas (user-flagged)

- **Leaderboard / dashboard integration.** User said: "maybe this
  might be something we incorporate into the leaderboard and whatnot
  later, but I... or a dashboard, I mean." Possible angles:
  - Per-catcher "best/worst zone" rollup as a tracker-page column
  - AC dashboard (`ac_dashboard/tab_catcher_cards.py`?) tab showing
    these hex maps for a single selected catcher
  - Movement plot-style page for catcher framing
- **Handedness expansion** — if framing skill diverges strongly by
  pitch type × pitcher hand, may want to split by pitcher hand AND
  batter hand (6 pages instead of 3). Defer until user asks.
- **More years** — currently `--seasons 2025 2026`. Could extend back
  to 2024 / 2023 if archive data is useful for development trajectory.
- **Multiple catchers per page** — currently 1 catcher per 3 pages.
  Could compress to side-by-side comparison if coordinator wants to
  see e.g. Perez vs Lee directly.

## Cross-references

- Design doc (intangibles worktree): `intangibles/docs/plans/2026-05-12-catcher-framing-hexbin-design.md`
- Canonical NetK SQL: `intangibles/src/catching_tracker_data.py::_COMBINED_FRAMING_QUERY` lines 1057-1124
- KPI weekly NetK (where Perez -16.70 came from): `intangibles/src/c_kpi_data.py::pitch_counts` CTE lines 679-748
- Tango framework: `memory/sz-framework-savant-zones.md` (Heart vs Shadow OUTER distinction)
- Roster filter pattern: `.claude/rules/kpi-roster-filter.md` (mirrored, inverted to exclude MLB)
- Catcher tracker handedness column (`pv.pitcher_throws`): `intangibles/src/catching_tracker_data.py:426-428`
- Pyodbc IN-tuple feedback: `memory/feedback_pyodbc_in_tuple_tvp.md`
