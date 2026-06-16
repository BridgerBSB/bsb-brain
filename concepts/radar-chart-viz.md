---
type: concept
domain: viz
source: personal-bsbres/examples
created: '2026-06-15'
---
# Radar / Web Chart — force-plate comps

matplotlib **polar radar ("web") charts** comparing the *athletic-testing profile* of 90+ mph throwers vs 95+ mph throwers vs the population minimum, across 6–7 force-plate axes. Four scripts in [[dsproj-data-science-examples]]: `radar_90mph.py`, `radar_final.py`, `rct.py`, `test_MIN.py`. Outputs include `web chart strength.png`. The visual ancestor of the BSB report "web chart strength" comps.

## Data

Pulled live from `hp_data.hp_tests` (SQLAlchemy/pymysql) with `WHERE pitch_speed_mph >= 90`. The 95+ web is `df[df['pitch_speed_mph'] >= 95]`.

## Axes (the 6–7 force-plate categories)

```
Body Weight, CMJ Peak Power, SJ Peak Power, Reactive Strength (RSI),
Peak Takeoff Force (plyo pushup), Net Peak Vertical Force (IMTP)[, Pitching Max HSS]
```
`rct.py` = 6-axis hexagon (drops HSS); `radar_90mph.py` / `radar_final.py` = 7-axis (adds `pitching_max_hss`).

## The three webs plotted

1. **AVG ≥90 mph** (orange) — `df.mean(skipna=True)` over all 90+ throwers
2. **AVG ≥95 mph** (blue) — mean of the 95+ subset (the "elite" profile)
3. **MIN nonzero** (red) — `df.replace(0, np.nan).min()` floor

## Normalization (the key technique)

Each axis is on a different scale (lbs vs watts vs newtons), so every metric is rescaled to **0–100 per-axis** before plotting. Two normalization conventions appear:

- **min-anchored** (`radar_90mph.py`, `rct.py`):
  ```python
  range_values = averages_90 - mins
  range_values[range_values == 0] = 1          # guard /0
  normalized = ((value - mins) / range_values) * 100
  ```
- **global min→max** (`radar_final.py`):
  ```python
  global_min = df[col].replace(0, np.nan).min()    # exclude 0 from the floor
  global_max = df[col].max()
  norm = (value - global_min) / (global_max - global_min) * 100
  ```
- `test_MIN.py` divides by `df_maxs` only (max-anchored) — a third variant, with debug prints of the raw mins.

**Excluding zeros from the min** (`replace(0, np.nan)`) is the recurring lesson — a 0 force-plate read is a missing test, not a real floor, and would crush the normalization.

## Matplotlib polar mechanics (reusable recipe)

```python
angles = np.linspace(0, 2*np.pi, len(categories), endpoint=False).tolist()
angles += angles[:1]                              # close the loop
values = np.append(norm.values, norm.values[0])   # close the data
fig, ax = plt.subplots(subplot_kw=dict(polar=True))
ax.plot(angles, values, ...); ax.fill(angles, values, alpha=0.3)
ax.set_xticks(angles[:-1]); ax.set_xticklabels(categories)
ax.set_yticklabels([])                            # hide radial ticks
# annotate raw (un-normalized) values via ax.text(angle, radius, f"{v:.1f}")
```
The chart shows **normalized geometry** but annotates the **raw values** as text at each vertex, so a coach reads the actual lbs/watts/newtons while the shape stays comparable.

## Links

- [[dsproj-data-science-examples]] (parent index)
- [[biomech-scores]] · [[hitting-biomechanics]] (the force-plate metrics being plotted)
- [[percentile-rank-scoring]] (sibling "compare across players" technique)
- [[MOC-baseball-analytics]]
