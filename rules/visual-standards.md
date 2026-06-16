---
paths:
  - "**/src/*report*.py"
  - "**/src/plots.py"
  - "**/pages/*.py"
  - "**/scripts/*.py"
  - "**/src/*page*.py"
---

# Visual Standards — All Apps

## RULE: Questions to Ask Before Creating Any New Visual

Before drawing ANY new chart, zone plot, spray chart, or table in any app:
1. **What convention?** Catcher's view (raw plate_x, HP down) or pitcher's view (flipped, HP up)?
2. **Which framework?** matplotlib (PDF) or Plotly (app)? Both?
3. **Per-batter/hitter personalized bounds?** Or fixed generic SZ?
4. **What are the exact dimensions?** Copy from the canonical spec below — do NOT invent new ones.
5. **Does an identical chart exist in another app?** If so, match it exactly (e.g., spray chart dimensions NEVER differ by position).

---

## Home Plate & plate_x Convention — DEFINITIVE

**Rule:** Raw plate_x from DB = catcher's view. If plate_x is negated (`-plate_x`), it's pitcher's view. Home plate pentagon MUST match the convention.

| Context | plate_x | HP Point | Convention | How Flipped |
|---------|---------|----------|------------|-------------|
| **Barrelsville `postgame_report.py`** (PDF zone grid) | RAW | **DOWN** | Catcher's view | Not flipped |
| **Barrelsville `advance_report.py`** (density plots) | FLIPPED | **UP** | Pitcher's view | Inline: `px = -cs_df["plate_x"]` |
| **Barrelsville `hitter_analysis.py`** | RAW | **DOWN** | Catcher's view | Not flipped |
| **Barrelsville `plots.py`** (location scatter) | Expects pre-flipped | **UP** | Pitcher's view | **DEAD CODE — never called in Barrelsville** |
| **Arm Farm `plots.py`** | FLIPPED | **UP** | Pitcher's view | Via `enrich_pitches()` in bullpen_data.py |
| **Arm Farm `postgame_report.py`** | FLIPPED | **UP** | Pitcher's view | Via `enrich_pitches()` |
| **Arm Farm `advance_pitching_report.py`** | FLIPPED | **UP** | Pitcher's view | Inline: `plate_x = -plate_x` |
| **Intangibles `catcher_report.py`** | RAW | **DOWN** | Catcher's view | Not flipped |

### Home Plate Pentagon Vertices

### BLOCKING: Plate width is ABSOLUTE — always `HP_HW = 0.708 ft` (17" real)

The plate is a physical object. Its width **never** changes with the SZ framework we're drawing:
- Under **ABS SZ (17" = ±0.708)** → plate matches zone width exactly
- Under **Tango SZ (20" = ±0.833)** → plate is narrower than zone (zone extends 1.5" past plate each side — correct by design)

**Never hand-roll `hp_w = 0.72` or other stylized values for the width.** Always use `HP_HW` (or import/derive it). Depth **can** be stylized (0.40 ft below zone is the standard for the side-on pentagon), but width is absolute.

Historical bug: `hitter_analysis.py::_draw_home_plate` and `generate_slg_vs_xslg_heatmap.py` both had `hp_w = 0.72` (8.64" — ~half real width) until commits `1a79cce` + `1c29d1b` (2026-04-22) fixed them.

**Catcher's view (point DOWN):** Used by Barrelsville PDF, hitter_analysis, Intangibles catcher
```python
hp_verts = [
    (-HP_HW, 0.45),   # top left (flat edge facing pitcher)
    (HP_HW, 0.45),    # top right
    (HP_HW, 0.25),    # right side
    (0, 0.05),        # point (facing catcher, BOTTOM)
    (-HP_HW, 0.25),   # left side
]
```

**Pitcher's view (point UP):** Used by Arm Farm all, Barrelsville advance density
```python
hp_verts = [
    (-HP_HW, 0.05),   # bottom left (flat edge, catcher side)
    (HP_HW, 0.05),    # bottom right
    (HP_HW, 0.25),    # right side
    (0, 0.45),        # point (facing pitcher, TOP)
    (-HP_HW, 0.25),   # left side
]
```

---

## Strike Zone — Two Frameworks (Updated Apr 21, 2026)

Two coexisting frameworks govern Barrelsville zone work. They are NOT the same thing. Every SZ visual or classification path must be explicit about which framework it uses.

### Framework 1 — ABS Display SZ (the solid rectangle that gets drawn)

Matches the 2026 MLB ABS Challenge zone (captured at middle of plate).

**X (fixed for all batters):**
- Width = 17" = **±0.708 ft** (`HP_HALF_W`, same as plate)

**Z (per-batter from height, NO ball-radius pad):**
```python
SZ_bot = 0.27  * height_ft
SZ_top = 0.535 * height_ft
```

**Default when no hitter specified:** avg MLB hitter height `MLB_AVG_HITTER_HEIGHT_FT = 6.0212` ft → SZ = **[1.626, 3.221]** ft. The legacy 1.5–3.5 default is retired.

### Framework 2 — Tango Classification (Heart / Shadow / Chase / Waste)

Defines the 4-zone taxonomy for `Hrt Sw%`, `Hrt Tk%`, `Shd%`, `Chase%`, `Waste%`. X boundaries are FIXED (not hitter-dependent). Z boundaries derive from the Tango-extended zone = ABS SZ + 1.5" pad on all 4 sides.

**X boundaries (fixed):**
| Boundary | Inches | Feet |
|---|---:|---:|
| Heart outer | ±6.7" | **±0.558 ft** |
| Shadow outer | ±13.3" | **±1.108 ft** |
| Chase outer | ±20.0" | **±1.667 ft** |

**Tango extended zone (ABS SZ + 1.5" pad):**
```python
extended_bot = 0.27  * height_ft - 0.125      # 1.5" pad in feet
extended_top = 0.535 * height_ft + 0.125
z_c   = 0.4025  * height_ft                    # Tango center
h_ext = 0.1325  * height_ft + 0.125            # Tango half-height
```

**Z bands from Tango center (67%/133%/200%):**
| Ring | Distance from z_c | Formula (feet) |
|---|---:|---|
| Heart Z min | 0.67 × h_ext below z_c | `0.313725 × h - 0.08375` |
| Heart Z max | 0.67 × h_ext above z_c | `0.491275 × h + 0.08375` |
| Shadow Z min | 1.33 × h_ext below z_c | `0.226075 × h - 0.16625` |
| Shadow Z max | 1.33 × h_ext above z_c | `0.578925 × h + 0.16625` |
| Chase Z min | 2.00 × h_ext below z_c | `0.1375  × h - 0.25`    |
| Chase Z max | 2.00 × h_ext above z_c | `0.6675  × h + 0.25`    |

### Classification (exclusive, ORDER MATTERS)
```
1. |x| ≤ 6.7"  AND  |z − z_c| / h_ext ≤ 0.67  → Heart
2. |x| ≤ 13.3" AND  |z − z_c| / h_ext ≤ 1.33  → Shadow
3. |x| ≤ 20.0" AND  |z − z_c| / h_ext ≤ 2.00  → Chase
4. else                                       → Waste
```

### Rendering Policy (locked Apr 21, 2026)

Three-surface parity — postgame PDF, postgame app, weekly hitter report render identically:

| Layer | Line | Edge Color | LW | Fill (mpl) | Fill (Plotly) |
|---|---|---|---:|---|---|
| SZ rect | solid | black | 2.0 | none | none |
| Heart rect | dotted (`linestyle=":"` / `dash="dot"`) | `#555555` | 0.9 | `#90EE90` | `rgba(76,175,80,0.1)` |
| Shadow rect | dotted | `#888888` | 0.7 | `#f5f5f5` | `rgba(200,200,200,0.1)` |

Chase is not drawn as a rectangle in any current visual (only used for classification). Heart fill is optional — present on Barrelsville postgame zone cells and weekly hitter heart chart, omitted on density heatmaps.

### Single Source of Truth

`barrelsville/src/plots.py::abs_zone_bounds(height_ft)` — returns a dict exposing BOTH frameworks' values. **ALL code (visuals + data classification) MUST call it.** Never inline ball-radius math or hardcode legacy values.

Callers:
- `postgame_data.py::_lookup_batter_height()` — batter height from `mlbam.players`, fallback `MLB_AVG_HITTER_HEIGHT_FT`
- `postgame_data.py::get_batter_zone_bounds(batter_id)` — height → `abs_zone_bounds()` wrapper
- `postgame_report.py` PDF + `1_Postgame.py` app + `weekly_hitter_report.py` — all render via the same dict
- `compute_game_stats(height_ft=...)` + SQL classification CTEs — same Tango X bounds + Z formulas

### BLOCKING: Visual and Data Must Match (Apr 18, 2026 — Tango reaffirmed Apr 21)

When a zone is DRAWN at given bounds, pitches classified AGAINST that zone must use the SAME bounds. Both sides must call `abs_zone_bounds()` from the same source of truth.

- **Visual:** `abs_zone_bounds(batter_height)` → rectangle dimensions
- **Data (Python):** `compute_game_stats(height_ft=batter_height)` → Hrt/Shd/Chase/Waste classification via Tango X + Z formulas
- **Data (SQL):** per-batter JOIN on `mlbam.players` exposes `height_ft`; CTE computes Heart/Shadow/Chase X+Z using the SAME Tango formulas; NEVER hardcoded.

**NEVER hardcode:**
- Legacy X bounds: `±0.587`, `±0.829`, `±0.121` (retired ball-radius-inset system)
- Legacy Z defaults: `1.5/3.5`, `1.83/3.17`, `1.665/3.335` (retired fixed ranges)
- Legacy Z math: `sz_bot + 0.121` / `sz_top - 0.121` (retired ball-radius inset)
- Old ±0.75/±0.939/±1.128 system (retired earlier)

**Zone layers drawn (postgame PDF + app, weekly hitter heart chart):** SZ (solid) + Heart (dotted) + Shadow (dotted)
**Zone layers drawn (advance density + LVA + location scatters):** SZ outline only

### Per-Hitter Zones (Arm Farm advance pitching)

**NOTE:** Arm Farm uses a similar-but-not-identical per-hitter zone approach and is OUT OF SCOPE for the Tango refactor. Do not propagate Tango changes into Arm Farm without an explicit plan.

- **X-axis:** Fixed ±0.83 (legacy, NOT the ABS 17" value — separate latent bug, not fixing here)
- **Z-axis:** Per-HITTER via `get_hitter_zone_bounds(hitter_id)`, default fallback `sz_z_min=1.665, sz_z_max=3.335`

### Catcher Zone (Intangibles)
- SZ: ±0.708 ft (Framework 1, ABS 17"). Z should be MLB-avg fallback via `abs_zone_bounds(None)` → [1.626, 3.221] ft.
- **Current reality:** `intangibles/src/catcher_report.py` + `pages/4_Catching.py` still hardcode `1.5–3.5`. **Out of scope for the Tango refactor — flagged for future alignment.**
- 7-color CSC framing buckets (not Heart/Shadow) — see Catcher Framing Colors section below

---

## 2×3 Zone Grid — How It's Built (Barrelsville Postgame)

**Layout:** Pre-2K / 2K × Takes / Swings / BIPs (6 cells)
**Heatmap grid:** 50×50 cells, x=[-2.0, 2.0], z=[0.0, 4.5] (PDF) or [-0.1, 4.5] (app)
**Gaussian smoothing:** sigma=3.0
**Colormap (RV Gain):** 5-stop Red→LightRed→White→LightBlue→Blue
- `_RV_NORM_RANGE = 0.05` (symmetric: [-0.05, +0.05]) — Barrelsville postgame + plots.py
- zxwOBA uses `_ZXWOBA_NORM_RANGE = 0.015`

**Cell mapping:** `xi = int((plate_x + 2.0) / 4.0 * 49)`, similar for z
**Zone layers in each cell:** Shadow → SZ → Heart (3 nested rectangles), all per-batter
**Implementation:** `postgame_report.py::_draw_zone_base()` (PDF), `1_Postgame.py::_add_zone_shapes()` (app)

---

## Spray Charts — NEVER CUSTOMIZE PER POSITION

### 3D Spray Chart (Intangibles OF + IF individual pages)
**CRITICAL:** Same dimensions for ALL positions. Never zoom, shorten, or customize.

```python
# Foul lines: 330 ft
# Fence arc: 330-400-330 (parametric cosine)
fence_dist = 330 + 70 * cos(radians(angle * 2))

# Camera & layout
z_range = [0, 200]
aspectratio = dict(x=1, y=1.2, z=0.4)
camera_eye = dict(x=-1.5, y=-1.5, z=0.8)
height = 500
margin = dict(l=0, r=0, t=30, b=0)

# Diamond
diamond_x = [0, -63.6, 0, 63.6, 0]
diamond_y = [0, 63.6, 127.3, 63.6, 0]

# Ball flight arcs
# Ground balls (LA < 10): flat dashed lines
# Fly balls (LA >= 10): parabolic z = peak_height * 4 * t * (1-t)
```

**Coordinate transform (hit_bearing → x,y):**
```python
end_x = distance * sin(radians(hit_bearing))
end_y = distance * cos(radians(hit_bearing))
```

### 2D Spray Chart (Barrelsville Advance, Intangibles Hitter Advance)
- Stadium-specific fence: `_minute_maid_fence()` polynomial segments (MLB only)
- Coordinate system: home plate at origin, y up the middle
- Barrelsville: XBH only (2B, 3B, HR) with KDE density contours
- Hitter Advance: All BIPs with KDE density contours + wedge tendency chart

---

## Outfield Fence Standards — BLOCKING

**RULE:** ALWAYS use `_minute_maid_fence()` (Daikin Park dimensions) for ALL levels, ALL spray charts. No exceptions until affiliate-specific fence data is provided.

**NEVER use `_milb_fence`, `_generic_milb_fence`, or any cosine/flat fence.** These should be DELETED from the codebase, not left as fallbacks. If `_draw_baseball_field(fence_fn=None)` defaults to anything other than `_minute_maid_fence`, change the default.

### Minute Maid / Daikin Fence — THE ONLY FENCE
```python
def _minute_maid_fence(theta_deg):
    theta = np.radians(theta_deg)
    if 0.0 <= theta_deg < 23:
        return -2738.7177 / (np.sin(theta) - (8.400974 * np.cos(theta)))
    elif 23 <= theta_deg < 24.1:
        return 315.172 / (np.sin(theta) + (0.493462 * np.cos(theta)))
    # ... (7 piecewise segments total)
```
**Theta system:** 0° = LF foul line, 45° = dead center, 90° = RF foul line.

### Fence X-Coordinate — MUST NEGATE (Fixed Apr 15, 2026)
The fence function's theta 0° = LF foul line, which maps to negative x via `sin(theta-45)`. But catcher's view has LF on the catcher's RIGHT (positive x). **Negate the x-coordinate:**
```python
# CORRECT (catcher's view — Crawford Boxes on right)
fence_x.append(-r * np.sin(bearing_rad))
fence_y.append(r * np.cos(bearing_rad))

# WRONG (was mirrored — Crawford Boxes on left)
fence_x.append(r * np.sin(bearing_rad))
```
**Fixed in:** weekly_hitter_report.py, advance_report.py, generate_level_spray.py, of_weekly_report.py, if_weekly_report.py, hitter_advance_report.py.

### Future: Affiliate-Specific Fences
When affiliate venue data is provided from the database, replace `_minute_maid_fence` with per-venue functions. Until then, Minute Maid for everything.

### Fence Colors
- **Fence line:** `#C62828` (red) in Barrelsville + hitter advance
- **Fence line:** `#888888` (grey) in OF/IF individual page spray charts
- **Foul lines:** `#999999` (light grey) everywhere
- **Grass fill:** `#E8F5E9` (very light green) at alpha 0.3-0.4

---

## Pitch Type Colors (Canonical — shared across all apps)

```python
PITCH_TYPE_COLORS = {
    "FF": "#000000",   # black (4-seam)
    "SI": "#5DADE2",   # baby blue (sinker)
    "FT": "#5DADE2",   # baby blue (2-seam)
    "FC": "#39FF14",   # neon green (cutter)
    "SL": "#FF0000",   # bright red (slider)
    "CU": "#800000",   # maroon (curveball)
    "CH": "#BB86FC",   # light purple (changeup)
    "FS": "#4CAF50",   # light green (splitter)
    "ST": "#FF6B6B",   # light red (sweeper)
    "SV": "#7B68EE",   # medium slate blue (slurve)
    "KC": "#A52A2A",   # dark red-brown (knuckle curve)
    "KN": "#FF8C00",   # orange (knuckleball)
    "EP": "#FFD700",   # gold (eephus)
    "SC": "#008080",   # teal (screwball)
}
```
**Source of truth:** `bullpen-report/src/bullpen_data.py`. Barrelsville `plots.py` has inlined copy.

---

## Percentile Color Gradient

**Standard (Intangibles, Arm Farm, Barrelsville):**
```python
RED = (229, 57, 53)    # #E53935
WHITE = (255, 255, 255) # #FFFFFF
GREEN = (102, 187, 106) # #66BB6A

# pct < 0.5: lerp RED → WHITE
# pct >= 0.5: lerp WHITE → GREEN
# higher_is_better=False flips direction
```

**PD Goals (slight variant):**
```python
PERCENTILE_CMAP = ["#C8102E", "#E8A0A0", "#D9D9D9", "#90D090", "#28a745"]
# Deep Red (0%) → Grey (50%) → Deep Green (100%)
```

---

## Astros Branding
```python
ASTROS_NAVY = "#002D62"
ASTROS_ORANGE = "#EB6E1F"
```

---

## Chart-Specific Axis Ranges

| Chart | X Range | Z/Y Range | Notes |
|-------|---------|-----------|-------|
| Pitch Location | [-3, 3] ft | [-0.2, 5] ft | Strike zone + chase area |
| Movement Scatter | [-30, 30] in (HorzBrk) | [-30, 30] in (IVB) | Dynamic limits from data |
| Release Point | [0, 4] ft | [4, 7] ft | Dynamic, 0.5 ft grid |
| Zone Heatmap | [-2, 2] ft | [0, 4.5] ft | 50×50 gaussian smoothed |
| Density (Advance) | [-2, 2] ft | [0.5, 4.5] ft | 15 contour levels |
| Spray 3D | ±330 ft | [0, 400] ft | z=[0, 200] for ball flight |

---

## 13-Zone Savant Grid — How It's Built (hitter_analysis.py)

**Convention:** Catcher's view, home plate point DOWN. Uses default SZ (±0.83, 1.665-3.335) or per-batter bounds.

**Zone layout (catcher's view):**
```
  L-11  [1]  [2]  [3]  L-12     ← L-shaped corners wrap around 3x3
        [4]  [5]  [6]
  L-13  [7]  [8]  [9]  L-14
         [home plate]
```

**Interior 3x3 (Zones 1-9):** SZ divided into equal thirds:
```python
x_divs = [sz_left, sz_left + sz_w/3, sz_left + 2*sz_w/3, sz_right]
z_divs = [sz_bot, sz_bot + sz_h/3, sz_bot + 2*sz_h/3, sz_top]
cell_w = sz_w / 3   # ~0.553 ft
cell_h = sz_h / 3   # ~0.557 ft
# Zone 1 = top-left, Zone 5 = center, Zone 9 = bottom-right
```

**L-Shaped Outer Zones (11-14):** 6-vertex polygons wrapping around 3x3:
```python
margin_x = 0.55   # horizontal beyond SZ
margin_z = 0.45   # vertical beyond SZ
# 11 = upper-left L, 12 = upper-right L, 13 = lower-left L, 14 = lower-right L
# Split at mid_x=0.0 (vertical) and mid_z=(sz_bot+sz_top)/2 (horizontal)
```

**Color per cell:** xwOBA value → normalize to [0,1] via `_ZONE_CENTER` and `_ZONE_RANGE` → colormap
**Text:** Bold centered value (e.g., ".568"), white text on dark backgrounds, black on light

**Implementation:** `hitter_analysis.py::_draw_zone_heatmap()` (~lines 1698-1846)

---

## Density Plots — How They're Built (Barrelsville Advance)

**Two side-by-side panels per count-state:** LOC density (left) + DMG density (right)
**plate_x flipped inline:** `px = -cs_df["plate_x"]` (pitcher's view for advance)
**KDE construction:**
```python
from scipy.stats import gaussian_kde
kde = gaussian_kde(np.vstack([px, pz]), weights=weights)
# LOC: weights = uniform (pitch count)
# DMG: weights = hit_exit_speed (EV-weighted)
grid = 60×60, x=[-2, 2], z=[0.5, 4.5]
contour_levels = 15
```
**LOC colormap:** Blue→White→Orange→Red (5-stop `_DENSITY_CMAP`)
**DMG colormap:** White→LightRed→DarkRed→Maroon (4-stop `_DAMAGE_CMAP`)

### Diverging Plotly colormaps MUST have explicit white midpoints (BLOCKING)

Plotly interpolates colors in RGB space between adjacent stops. A naive red↔blue diverging scale (e.g., `[(0, "blue"), (0.5, "red"), (1, "blue")]`) passes through **purple** in the middle — RGB midpoint of (255,0,0) and (0,0,255) is (127,0,127). Wrong visual.

Add explicit `#FFFFFF` stops between each extreme and the central plateau:

```python
# Diverging-plateau colormap (e.g., AA/VBA/LA with optimal-range plateau)
def _diverging_plateau(cmin, cmax, plateau_low, plateau_high):
    plateau_low_n  = (plateau_low  - cmin) / (cmax - cmin)
    plateau_high_n = (plateau_high - cmin) / (cmax - cmin)
    mid_low  = plateau_low_n / 2
    mid_high = (plateau_high_n + 1) / 2
    return [
        [0.0,             "#1565C0"],  # blue (cold extreme)
        [mid_low,         "#FFFFFF"],  # white midpoint (low side)
        [plateau_low_n,   "#D32F2F"],  # red plateau start
        [plateau_high_n,  "#D32F2F"],  # red plateau end
        [mid_high,        "#FFFFFF"],  # white midpoint (high side)
        [1.0,             "#1565C0"],  # blue (warm extreme)
    ]
```

Same applies to any cool→warm or warm→cool diverging scale that uses non-grayscale endpoints. Always include `#FFFFFF` stops adjacent to where the gradient changes sign. Reference impl: `barrelsville/pages/1_Postgame.py::_diverging_plateau` (commit `228060c5`).
**SZ overlay:** Currently fixed ±0.83, 1.5-3.5 — diverges from ABS SZ (should be ±0.708 × MLB-avg via `abs_zone_bounds(None)`). Flagged for future fix.
**HP overlay:** Pitcher's view (point UP)

**Implementation:** `advance_report.py` (~lines 1004-1020, `_draw_density_heatmap()`)

---

## Pitching Advance Matchup Heatmap — How It's Built (Arm Farm)

**Two-column grid:** Pre-2K (left) and 2K (right) per pitch type.

**Pre-2K cells — Combined matchup heatmap (pitcher proj - hitter RV):**
- **Pitcher layer:** `fb_grade` (projection grade, 20-80 scouting scale) smoothed via Nadaraya-Watson KDE
- **Hitter layer:** `rv_gain_given_hit_specs` on swings only, FLIPPED (positive RV in DB = good for pitcher, so negate for hitter damage)
- **Combined:** `pitcher_surface - hitter_surface` (both normalized 0-1)
- **Blue = pitcher winning** (high projection, low hitter damage at that zone location)
- **Red = hitter winning** (low projection, high hitter damage)
- **White = neutral**

**Normalization ranges (tuned Mar 2026 from per-player-pitch-type distribution analysis, 50+ sample min):**
```python
_PROJ_MIN, _PROJ_MAX = 10.0, 70.0    # fb_grade: P5=10.4, P95=62 of player avgs
_RV_MIN, _RV_MAX = -0.10, 0.10       # rv_gain: covers 99.7% of player avgs
```
**Previous values:** 30-70 fb_grade (clipped 27% of player-pitch combos below floor), ±0.05 rv_gain (clipped 25% to saturated colors). Wider ranges provide more gradient/nuance.

**2K cells — Separate KDE density layers (no weighting):**
- Pitcher whiff density (blue contourf)
- Hitter whiff density (red contourf)

**Colormap:** 5-stop Blue→LightBlue→White→LightRed→Red (`_MATCHUP_CMAP`)
**Norm:** `Normalize(vmin=-1.0, vmax=1.0)` for combined score

**Implementation:** `advance_pitching_report.py::_draw_matchup_kde()` (~line 434)

---

## Arm Farm Postgame fb_grade Heatmap

**Per-pitch-type zone background** using season-long R-game data:
- Raw `fb_grade` values placed on 50×50 grid, gaussian smoothed (sigma=3.0)
- **NO clipping on raw values** — averaging tames noise
- Final normalization: `(smoothed_avg - 20) / 60` → [0, 1] on full 20-80 scale
- **Red = low grade (bad for pitcher), White = 50 avg, Blue = high grade (good for pitcher)**
- Per-pixel alpha proportional to density (empty areas transparent, max 0.7)
- Colormap: `_PROJ_HEATMAP` Red→White→Blue diverging

**Implementation:** `postgame_report.py::_draw_proj_heatmap()` (~line 1840)

---

## LVA Heatmap Cell — How It's Built (Arm Farm)

**Season heatmap background + game-day pitch scatter overlay:**
1. Season data → gaussian KDE → contourf background (light gradient)
2. Game-day pitches → scatter with 5 marker shapes (see LVA markers table below)
3. SZ rectangle overlay (currently fixed ±0.83, 1.5-3.5 — also diverges from ABS SZ, flagged for future fix)
4. Home plate pentagon (pitcher's view, point UP)

**Grid layout:** One cell per pitch_type × count-state bucket
**Implementation:** `plots.py::create_lva_cell_plotly()` (app), `postgame_report.py::_draw_lva_cell()` (PDF)

---

## KPI Line Charts — How They're Built (All KPI Reports)

**Pattern:** 30 org trend lines (grey) with HOU navy bold overlay
```python
# Grey org lines (background)
for org in all_orgs:
    ax.plot(dates, values, color="#999999", linewidth=0.5, alpha=0.3)

# HOU navy line (foreground)
ax.plot(hou_dates, hou_values, color=ASTROS_NAVY, linewidth=2.5)
```
**Layout:** GridSpec(4, 6) — rows 0-1: 6 charts (2×3), rows 2-3: 2 tables
**Rank annotations:** Monthly boxes showing HOU rank among 30 orgs
**Used by:** All 6 KPI reports (pitcher, hitter, OF, IF, BR, catcher)

**Implementation:** `*_kpi_report.py` files in each project

---

## Plottable Tables — How They're Built (All Reports)

**Standard pattern:**
```python
from plottable import Table, ColumnDefinition

col_defs = [ColumnDefinition(name=col, textprops={...}, width=...)]
table = Table(df, column_definitions=col_defs, ...)
_fix_null_bbox(table)  # transparent bbox for None cells (see pdf-patterns.md)
# Per-row percentile coloring (if needed):
for row_idx in range(len(df)):
    cell = table.cells[row_idx, col_idx]
    bp = cell.text.get_bbox_patch()
    if bp: bp.set_facecolor(percentile_color)
```
**Key:** Must add `bbox` to `textprops` if doing per-row coloring (see `rules/pdf-patterns.md`)

---

## Catcher Zone Plots — How They're Built (4-Panel Layout)

**4 panels:** RHP Fastballs, RHP OS/Breaking, LHP Fastballs, LHP OS/Breaking
**Each panel:** SZ rectangle (±0.708 × legacy 1.5-3.5 hardcode — should migrate to MLB-avg via `abs_zone_bounds(None)` → [1.626, 3.221] ft) + scattered pitches colored by CSC 7-bucket
**Home plate:** Catcher's view (point DOWN, raw plate_x)
**SZ width ±0.708** (ABS standard — matches all apps)

**Implementation:** `catcher_report.py::_draw_strike_zone_plots()` (~line 519)

---

## Break Chart Mirroring (Barrelsville Advance)

**LHH PDF:** Break chart positioned LEFT (x=0.05, y=0.54)
**RHH PDF:** Break chart positioned RIGHT (x=0.61, y=0.54)
**Axis:** HorzBrk ±25" × IVB ±25", crosshairs at (0,0)
**Colors:** PITCH_TYPE_COLORS per pitch type

---

## PDF Rendering Constants

```python
# Standard page
FIGSIZE = (11, 8.5)  # landscape
DPI = 150
BACKEND = 'Agg'

# Multi-page via PdfPages
# Font sizes: 6-9px for tables, 10-14px for headers

# Plottable tables
HEADER_DIVIDER_LW = 1.5
ROW_DIVIDER_LW = 0.3-0.5
COL_BORDER_LW = 0.3

# Bar chart values: INSIDE bars (white text, centered)
```

---

## YTD Boxes — How They're Built (OF/IF Weekly Report KPI Page)

**Location:** Bottom of page 2, left 60% (x=0.03–0.68), below ARM section separator.
**Layout:** 8 boxes evenly spaced, `FancyBboxPatch` with rounded corners.
**Divider:** Grey lines left/right of "Year to Date" label (same pattern as Barrelsville achievements).

**Per box (top to bottom):**
1. Metric label with aggregate: `TopSpd (P95)` — fontsize 5.5, bold
2. Large value: fontsize 11, bold, `_fmt_val()` formatted
3. Percentile ordinal: `_ordinal(pctile)` — fontsize 5 (e.g., "62nd", NOT "62th")
4. Lvl Rank: `Lvl: #3/45` — fontsize 4, grey
5. Org Rank: `Org: #1/8` — fontsize 4, grey

**Background color:** `percentile_to_color(pctile/100, higher_is_better=True)` — same red→white→green gradient as battery bars.

**Implementation:** `of_weekly_report._draw_ytd_boxes()` (OF + IF delegates to this).

---

## Direction Rose (Intangibles fielding weekly)
```python
# 8 sectors: N/NE/E/SE/S/SW/W/NW
# Theta zero = North, direction = clockwise
# Bar height = play count per sector
# Color = PAA-weighted gradient
#   positive PAA → green (0 white → +0.10 green)
#   negative PAA → red (0 white → -0.10 red)
# Elevation: 25°, Azimuth: -135°
```

---

## LVA Grid Marker Shapes (Arm Farm)

| Result | matplotlib | Plotly | Definition |
|--------|-----------|--------|------------|
| Whiff | `'o'` filled | `circle` | pitch_result_id IN (10,16,21,22,23) |
| Foul | `'s'` square | `square` | pitch_result_id IN (7,8,9) |
| Hard Hit | `'X'` cross | `x` | BIP with EV >= 89 |
| Weak | `'^'` triangle | `triangle-up` | BIP with EV < 89 or NULL |
| Take | `'o'` hollow | `circle-open` | did_swing=0 |

---

## Click-to-Video Pattern (Streamlit Apps)

All interactive Plotly charts with pitch-level data support click-to-video.

**SQL:** Add `vid.video_url AS pitch_video_url` via `LEFT JOIN Astros.Video vid ON vid.sched_id = pv.sched_id AND vid.pitch_id = pv.pitch_id AND vid.angle_id = 1`

**Plotly customdata:** `customdata = pts[['sched_id', 'pitch_id', 'pitch_video_url']].values`

**Streamlit rendering:**
```python
@st.fragment
def _render_charts():
    fig = build_chart(...)
    event = st.plotly_chart(fig, use_container_width=True,
                            on_select="rerun", selection_mode=("points",),
                            key="chart_key")
    _handle_chart_click(event, video_url_index=2, chart_key="chart_key")
```

**`video_url_index`** = position of the URL in customdata array (0-indexed). With `[sched_id, pitch_id, url]` it's index 2.

### Canonical Helper — pitch-identity tracking (BLOCKING)

The reference implementation lives at
`intangibles/pages/4_Catching.py::_handle_chart_click`. **Use this
verbatim — do not reinvent.** It tracks the *identity* of the last
opened pitch (built from the customdata fields BEFORE the URL) so a
second click on a different dot still fires after the first one was
already selected.

```python
def _open_video_js(url: str) -> str:
    safe_url = url.replace("'", "\\'").replace('"', '\\"')
    return f'<script>window.open("{safe_url}", "_blank");</script>'

def _handle_chart_click(event, chart_key: str,
                        video_url_index: int = 2) -> None:
    state_key = f"_video_last_pitch_{chart_key}"
    if not event or not event.selection or not event.selection.points:
        return
    last_opened = st.session_state.get(state_key)
    # Scan in reverse to find the newest different pitch
    for pt in reversed(event.selection.points):
        cd = pt.get("customdata", [])
        if len(cd) > video_url_index:
            url = cd[video_url_index]
            if url and str(url).startswith("http"):
                pitch_id = str(cd[:video_url_index])
                if pitch_id != last_opened:
                    st.session_state[state_key] = pitch_id
                    st.components.v1.html(_open_video_js(url), height=0)
                    return
    # Re-click on same pitch — only re-fire on a new selection count
    newest = event.selection.points[-1]
    cd = newest.get("customdata", [])
    if len(cd) > video_url_index:
        url = cd[video_url_index]
        if url and str(url).startswith("http"):
            pitch_id = str(cd[:video_url_index])
            count_key = f"_video_count_{chart_key}"
            n_pts = len(event.selection.points)
            if st.session_state.get(count_key) != n_pts:
                st.session_state[count_key] = n_pts
                st.session_state[state_key] = pitch_id
                st.components.v1.html(_open_video_js(url), height=0)
```

**What NOT to do — selection-count tracking is BROKEN.** A naive
`if len(event.selection.points) > prev_count` pattern fires once on
the first click, then dies. Plotly's `selection_mode=("points",)`
KEEPS prior points in the event payload, so the count doesn't grow
on a second different click. Use the pitch-identity helper above.

This was the bug shipped on `pd-goals/pages/4_WPA_Plays.py` Apr 25
2026 (commit `e3765c6` = fix). Same trap exists in
`barrelsville/pages/1_Postgame.py:1337` if it's ever touched —
that file's count-based version works because the scatter cells
are tiny and users rarely click two dots in the same cell. But
for any large interactive chart (WP timeline, big scatter), the
identity-tracking helper is required.

**Apps using this pattern:**
| App | Charts with click-to-video | Helper variant |
|-----|---------------------------|----------------|
| Intangibles Catcher (4_Catching.py) | 4 SZ panels, throws scatter, blocks scatter, setup charts | identity (canonical) |
| PD Engine WPA Plays (4_WPA_Plays.py) | WP timeline | identity (canonical) |
| Arm Farm Postgame (2_Postgame.py) | LVA cells, movement scatter, location scatter, **release point scatter, rolling chart dots** (May 14 2026) | count-based (legacy, OK in small cells) |
| Barrelsville Postgame (1_Postgame.py) | Zone grid cells | count-based (legacy, OK in small cells) |

**When adding click-to-video to a new chart:** 1) Add video URL to the data query, 2) Build customdata as `[id_field_1, id_field_2, ..., url]`, 3) Wrap in `@st.fragment` if performance matters, 4) Use `on_select="rerun"` + the canonical pitch-identity `_handle_chart_click()` from this rule. Do not copy the count-based variant.

### Plotly Scatter3d click does NOT work in Streamlit (BLOCKING — confirmed dead May 16 2026)

`plotly.Scatter3d` only emits `plotly_click` events. Streamlit's `on_select="rerun"` only listens for `plotly_selected`. The two events do not bridge for 3D traces. Symptom: event payload arrives but `selection.points` is always `[]`:

```
{"has_event":true,"selection":{"points":[],"point_indices":[],"box":[],"lasso":[]},"points_len":0}
```

Burned 5 attempts on the Barrelsville Visuals tab 3D PoC chart before confirming. **Don't try to make native Streamlit-Plotly 3D click-to-video work.** Two real workarounds (neither shipped yet):

| Workaround | Notes |
|---|---|
| `streamlit-plotly-events` (third-party, andfanilo) | Exposes `plotly_click` directly. Adds requirements.txt dep. ~5 lines per chart. |
| **JS injection via `st.components.v1.html`** (preferred) | Render figure via `pio.to_html` + browser-side JS listener `gd.on('plotly_click', ...)` that calls `window.open(customdata[N])`. Zero Streamlit roundtrip, no rerun cascade. ~30 lines per chart. Best fit when click only needs to open a URL. |

Fallback for 2D-only context (what shipped on Barrelsville Visuals tab): a `BIP video index` dataframe expander below the 3D chart, with one row per BIP and a `▶ Play` LinkColumn that opens `cf_angle_url`. Lets users navigate to any pitch's video without the 3D click being interactive.

**2D Plotly traces (Scatter, Heatmap) still work fine** with the canonical `_handle_chart_click()` helper above — this quirk is 3D-only.

---

## Catcher Framing Colors (7-bucket CSC)

| Bucket | CSC Range | Color | Meaning |
|--------|-----------|-------|---------|
| E Stl | 0.00-0.05 | `#1B5E20` (dark green) | Excellent strike gain |
| Stl | 0.05-0.25 | `#66BB6A` (light green) | Strike gain |
| Mid+ | 0.25-0.50 | `#42A5F5` (blue) | Mid-gain |
| Expected | ~0.50 | `#BBBBBB` (grey) | Matched expectation |
| Mid- | 0.50-0.75 | `#FDD835` (yellow) | Mid-loss |
| Loss | 0.75-0.95 | `#FF9800` (orange) | Strike loss |
| B Loss | 0.95-1.00 | `#F44336` (red) | Bad loss |
