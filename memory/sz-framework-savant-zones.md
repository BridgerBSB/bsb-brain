---
name: Strike Zone Framework — Two Systems (ABS display + Tango/Savant classification)
description: Source-of-truth image + split between ABS 17" display SZ (rulebook, no pad) and Tango classification zones (Heart/Shadow/Chase/Waste computed on 20"-wide × ±1.5"-padded extended zone). Used for Hrt Sw%, Chase%, 13/17-zone hitter_analysis grids.
type: reference
originSessionId: 967e8752-cb38-4540-b3a2-cb69fee5e15c
---
## Source of Truth
Image: `C:\Users\Owner\Downloads\image (530).png`

## TWO FRAMEWORKS — DO NOT CONFLATE

| Purpose | Which framework | Widths | Heights |
|---|---|---|---|
| **Drawing the SZ rectangle** on any plot (postgame, advance, catcher, LVA, etc.) | Framework 1 — ABS | 17" (plate) | 0.27×h to 0.535×h **(no pad)** |
| **Classifying pitch location** (Hrt Sw%, Shadow Tk%, Chase%, Waste%) AND drawing hitter_analysis 13/17-zone grids | Framework 2 — Tango | 20" envelope (Heart ±6.7", Shadow outer ±13.3", Chase outer ±20") | EXTENDED SZ with **+1.5"/−1.5" pad**, then % of that half-height from center |

## Framework 1 — ABS Strike Zone (drawn, 2026 MLB ABS Challenge rules)

- X half-width: **0.708 ft (±8.5", 17" wide)** — our existing `HP_HALF_W` is correct
- Z bounds: `SZ_bot = 0.27 × height`, `SZ_top = 0.535 × height` (feet)
- NO pad — ABS captured at middle of plate, precise
- When no hitter specified: use **avg MLB hitter height 6.0212 ft** → 1.626 – 3.221 ft (NOT 1.5 – 3.5)

## Framework 2 — Tango/Savant Classification Zones

Used for: Heart Sw%/Tk%, Shadow Sw%/Tk%, Chase%, Waste%, hitter_analysis 13-zone + 17-zone grids.

### X boundaries (fixed, not hitter-dependent)
| Ring | Half-width (in) | Half-width (ft) |
|---|---|---|
| Heart outer | 6.7 | 0.558 |
| Shadow outer | 13.3 | 1.108 |
| Chase outer | 20.0 | 1.667 |
| Waste | > 20 | > 1.667 |

### Z boundaries (hitter-dependent, USE EXTENDED SZ)
- **Extended SZ top** = `0.535 × h + 1.5"` (ball-radius pad above ABS top)
- **Extended SZ bot** = `0.27 × h - 1.5"` (ball-radius pad below ABS bot)
- `z_c = (Extended_top + Extended_bot) / 2` = `0.4025 × h` (center — same as ABS center, pad is symmetric)
- `h_ext = (Extended_top - Extended_bot) / 2` = `0.1325 × h + 0.125 ft`
- Heart z: `z_c ± 0.67 × h_ext`
- Shadow z band: `z_c ± [0.67, 1.33] × h_ext`
- Chase z band: `z_c ± [1.33, 2.00] × h_ext`
- Waste z: beyond 200% half-height from center

### Classification (exclusive, order matters)
1. `|x| ≤ 6.7" AND |z - z_c| / h_ext ≤ 0.67` → Heart
2. `|x| ≤ 13.3" AND |z - z_c| / h_ext ≤ 1.33` → Shadow
3. `|x| ≤ 20.0" AND |z - z_c| / h_ext ≤ 2.00` → Chase
4. else → Waste

## Computed defaults — avg MLB hitter (h = 6.0212 ft / 72.255")

Query: `SELECT AVG(height_feet*12 + height_inches)/12 FROM MLBAM.Players WHERE LEVELOFPLAY_LK='ml' AND POSITION_LK NOT IN ('RHS','RHR','LHS','LHR')` → 72.2549 in = 6.0212 ft.

**Framework 1 — ABS display SZ:**
- SZ_bot = 0.27 × 6.0212 = **1.626 ft**
- SZ_top = 0.535 × 6.0212 = **3.221 ft**
- x: ±0.708 ft (fixed)

**Framework 2 — Tango classification:**
- Extended bot = 0.27 × 6.0212 - 0.125 = **1.501 ft**
- Extended top = 0.535 × 6.0212 + 0.125 = **3.346 ft**
- z_c = 2.424 ft, h_ext = 0.923 ft
- Heart z: 1.806 – 3.042 ft
- Shadow z (lower band): 1.196 – 1.806
- Shadow z (upper band): 3.042 – 3.652
- Chase z (lower band): 0.578 – 1.196
- Chase z (upper band): 3.652 – 4.270

## What 1.5 – 3.5 ft was
Legacy hardcoded default from before avg-MLB-height was computed. SUPERSEDED — use avg MLB 6.0212 ft when no hitter specified.

## One more clarification (2026-04-21 end-of-session)
**The "Tango zone" IS the +1.5"-on-all-sides extended zone. There is no separate "Updated Tango Zone."** Heart/Shadow/Chase/Waste are ALWAYS measured as % bands off the Tango zone — regardless of whether the visible plot also shows the 17" ABS rectangle. Earlier confusion about "future Updated Tango Zone" was a misspeak; it's one framework.

Tango zone dimensions (to make this unambiguous):
- X: ±10" = ±0.833 ft (1.5" wider than plate on each side)
- Z: `0.27×h - 1.5"` to `0.535×h + 1.5"` (1.5" taller than ABS on each side)
- Heart/Shadow/Chase outer = 67% / 133% / 200% of Tango half-width (x) AND half-height (z), measured from zone center

## In-scope visual + data refactor (confirmed scope)
Apply the Tango framework to Heart/Shadow in these files:
- `barrelsville/src/postgame_report.py` — zone grid cells
- `barrelsville/pages/1_Postgame.py` — Plotly zone grid
- `barrelsville/src/weekly_hitter_report.py` — heart zone draw
- `barrelsville/scripts/heart_zone_report.py` — heart zone draw
- `barrelsville/src/postgame_data.py::compute_game_stats()` — Hrt Sw%/Tk% classification (data side)
- `barrelsville/src/weekly_hitter_data.py` — heart sw/tk% SQL if present
- `barrelsville/src/plots.py::abs_zone_bounds()` — return Tango-compatible bounds

Out-of-scope this round (future, no rename):
- `hitter_analysis.py` 13/17-zone grid (adds Chase + Waste as grid cells — same framework)
- `generate_team_hitter_analysis.py`

Not affected:
- Arm Farm (no Heart/Shadow drawn)
- Intangibles catcher (CSC buckets, not Heart/Shadow)

## Status (2026-04-21 final)
Framework locked. Edit list below in next conversation turn. Plan to be formalized via `superpowers:writing-plans`. Old ball-radius-inset (±0.587 heart, ±0.829 shadow, ±0.121 inset) to be REMOVED from code + `visual-standards.md`.
