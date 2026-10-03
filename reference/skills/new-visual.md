---
name: new-visual
description: Visual standards verification. Use when creating ANY new chart, plot, zone grid, spray chart, heatmap, table, or visual element in any report or app page. Also use when modifying existing visuals.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# New Visual Verification Checklist

Before creating or modifying ANY visual element, you MUST answer these questions and verify against `.claude/rules/visual-standards.md`.

## Step 1: What Convention?
- [ ] Is this a hitting context (catcher's view) or pitching context (pitcher's view)?
- [ ] Check the file's plate_x handling — is it RAW (catcher) or FLIPPED (pitcher)?
- [ ] Home plate pentagon MUST match: raw plate_x → point DOWN, flipped plate_x → point UP
- [ ] Verify against the convention table in `rules/visual-standards.md`

## Step 2: Which Framework?
- [ ] matplotlib (PDF/report) or Plotly (Streamlit app)?
- [ ] If both exist (e.g., Barrelsville postgame has PDF + app), they must produce visually identical output
- [ ] Check `rules/visual-standards.md` for which framework each chart type uses

## Step 3: Are Zones Personalized?
- [ ] Postgame zone grids: per-batter from `get_batter_zone_bounds()` (YES)
- [ ] Advance pitching zones: per-HITTER from `get_hitter_zone_bounds()` (YES)
- [ ] Simple location scatter: fixed generic SZ (±0.83, 1.5-3.5) (NO)
- [ ] Catcher zones: fixed ±0.939 with CSC framing buckets (NO)

## Step 4: What Are the Exact Dimensions?
- [ ] Check `rules/visual-standards.md` for the canonical dimensions of this chart type
- [ ] DO NOT invent new axis ranges, color scales, or normalization ranges
- [ ] Copy exact constants from the canonical spec

## Step 5: Does This Chart Exist Elsewhere?
- [ ] Grep for similar chart functions across the codebase
- [ ] If an identical chart exists in another app (e.g., spray chart in OF + IF), it MUST use the same dimensions
- [ ] **NEVER customize spray chart dimensions per position** — always use full field (330-400-330, z=200)
- [ ] **NEVER customize strike zone width per position** unless the data convention requires it (catcher ±0.939 is intentional)

## Step 6: Color Standards
- [ ] Pitch type colors: use `PITCH_TYPE_COLORS` from `bullpen_data.py` (canonical source)
- [ ] Percentile gradient: Red (#E53935) → White → Green (#66BB6A)
- [ ] Astros branding: Navy `#002D62`, Orange `#EB6E1F`
- [ ] Heatmap colormaps: check `rules/visual-standards.md` for the specific chart's colormap

## Step 7: Construction Pattern
- [ ] Check `rules/visual-standards.md` for "How It's Built" section for this chart type
- [ ] Follow the documented construction pattern — don't reinvent
- [ ] If building a new chart type not documented, ADD it to visual-standards.md after building

## Step 8: Render and Look (BLOCKING — do not skip)
See `rules/render-and-look.md`. `py_compile` and unit tests are BLIND to layout.
- [ ] Render the visual to a PNG with **synthetic data** (no DB needed for layout), calling the SAME draw function the report/app uses
- [ ] Match production `dpi` (usually 150) and `bbox_inches` — fixed-pixel `figimage` logos/headshots move with dpi
- [ ] **Open the PNG with the Read tool and actually look at it**
- [ ] Check overlap (text under logo/headshot/other text), clipping at edges, empty/zero-data panels, off-canvas legends, color contrast
- [ ] Stress the **worst case** — longest name, most pitch types, the empty side of a split — not just the happy path
- [ ] Only claim it works / commit AFTER you have viewed the image
