# Catch Me If You Can (CMIYC) — R App Reference

## Source
R Shiny app by Houston Astros. File saved at `intangibles/CatchMeIfYouCan.R`.

## Key Visuals & Coordinates

### Throws Plot (3D scatter3d — Plotly)
- x = ThrowLocHorz (throw_xf), y = ThrowLocVert (throw_zf), z = ThrowLocDepth (throw_yf)
- 2B bag diamond: `x=c(0,1,0,-1,0), y=c(0,0,0,0,0), z=c(0,-1,-2,-1,0)`
- Color by pop_time: green→yellow→red (`c(0,'#006400'), c(.5,'#FFFF00'), c(1,'#ff0000')`)
- Markers: x=SB, circle=CS
- **Can't replicate 3D in PDF** — using 2D front view (x vs z/height)

### Blocks Plot (ggplot 2D)
- x = Loc_X (plate_x), y = Loc_Y (dirtball_y)
- **plate2** (scaled 0.95× from plate, centered around y=8.5/12):
  ```
  plate = (0,0), (8.5/12, 8.5/12), (8.5/12, 17/12), (-8.5/12, 17/12), (-8.5/12, 8.5/12), (0,0)
  plate2 = x*0.95, y = 0.95*(y - 8.5/12) + 8.5/12
  ```
- **Batter's boxes:** 4ft × 6ft, 0.5ft gap from plate edge (inner=±1.208, outer=±5.208, y=-2.292 to 3.708)
- **Color:** Blue gradient `low="#00035B", high="#90D5FF"`, limits (0, 0.4)
- **Shape by Result:** PB/WP vs Block
- **NO strike zone rectangle** in blocks

### Catcher Setup Plot (ggplot 2D, faceted)
- x = x_at_pitch_release, y = stacked_y (row_number by bin)
- `facet_grid(balls_before ~ strikes_before)` — rows=balls(0-3), cols=strikes(0-2)
- Binwidth: 0.2ft, x limits: (-2.25, 2.25), y limits: (0, 7.5)
- Fill by bat_side (R/L), shape=21 (filled circle, black stroke)
- Dashed vlines at ±8.5/12 (plate edges)
- Y axis hidden. Depth shown in hover tooltip only.
- Pitch type colors: FF=black, FT=blue, FC=#66FF00, FS=#013220, SL=red, CU=#800000, CH=#BE2ed6

### Depth Trends (separate ggplot)
- x = sched_date, y = depth (y_at_pitch_release) or horizontal (x_at_pitch_release)
- Color by pitch_type, filter y < 30 (outlier guard)
- Separate "Select Variable" toggle between depth and horizontal

## Data Queries
- Throws: `CatcherDefense_Throwing` + `Tracking_Defensive_Metrics` + `Video`
- Blocks: `Pitches_View` + `CatcherDefense_Blocking_ByPitch` + `Video` (dirtball_flag=1)
- Setup: `Pitches_Context_View` + `Play_Starting_Positions` (pos_id=2) + `Video_Network` (angle='a')

## Depth Direction
- y_at_pitch_release is NEGATIVE (behind home plate)
- Higher (less negative, e.g., -5.5 vs -6.5) = closer to plate = BETTER
- `higher_is_better=True` for percentile coloring
