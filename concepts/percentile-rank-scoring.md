---
type: concept
domain: modeling
source: personal-bsbres/examples
created: '2026-06-15'
---
# Percentile-Rank Scoring — Blue Jays player valuation

Direction-aware percentile-rank scoring that collapses many hitting metrics into one composite **`simple_score`** per player. From the `bluejays_q/` take-home exercise in [[dsproj-data-science-examples]] (`bluejays.py` + `jays_image.py`). This is the conceptual ancestor of the BSB report-app "P-metric" coloring and org-KPI rank tables — same idea: rank within the pool, color by direction, average to a composite.

## The scoring logic

A `metrics` dict pairs each column with a **higher-is-better** boolean:
```python
metrics = {
    'BBPct': True,   'SOPct': False,  'ZSwingPct': True,  'OSwingPct': False,
    'AvgExitVelo': True, 'AirAvgExitVelo': True, 'ContactPct': True,
    '98th Percentile EV': True, 'HardHitPct': True, 'AirPullPct': True,
}
```
- `True` → reward high values · `False` → reward low values (SOPct, OSwingPct).

```python
def score_metric(series, higher_is_better):
    if higher_is_better:
        return series.rank(ascending=True,  method='min')   # high value → high rank
    else:
        return series.rank(ascending=False, method='min')   # low value  → high rank

for metric, hib in metrics.items():
    df[f'{metric}_score'] = score_metric(df[metric], hib)

df['simple_score'] = df[[f'{m}_score' for m in metrics]].sum(axis=1) / len(metrics)
```

So each metric becomes a **rank (1..N)**, the direction flips the sort for "lower is better" stats, and `simple_score` is the **mean rank** across all 10 metrics — a single composite valuation number per prospect. `method='min'` gives ties the same (lowest) rank.

## Data

`Player Valuation Exercise 2 Player List.csv` — ~33 college draft prospects, full hitting + pitching + per-pitch-type scouting line (PA, AVG/OBP/SLUG, `BBPct`, `SOPct`, `ZSwingPct`, `OSwingPct`, `AvgExitVelo`, `AirAvgExitVelo`, `98th Percentile EV`, `HardHitPct`, `AirPullPct`, `xwOBAcon`; pitchers carry ERA/WHIP/`FB Velocity`/`SL Induced Vertical Break`/etc.). The scoring uses 10 hitting columns. (A commented step notes the percentage columns must be cast `str.rstrip('%').astype(float)/100` first so ranks compute on numbers.)

## The styled-table render (`jays_image.py`)

Reads the with-scores CSV, filters `simple_score > 0`, and applies a **diverging red/white/blue heat** to each `*_score` column via pandas `Styler.applymap`, on a fixed 1..33 scale:
```python
def apply_metric_color(val):
    if val < 15:   return f'background-color: rgb(0, 0, {255 - int((val/15)*255)})'   # blue (low rank)
    elif val > 16: return f'background-color: rgb({int(((val-16)/(33-16))*255)}, 0, 0)' # red (high rank)
    return 'background-color: white'                                                     # mid → white
```
Plus a categorical `Subjective Defense at Position` color (Above Average = red, Below Average = blue, Average = white). Output: `Player_Valuation_Chart.png`. `bluejays.py` carries an equivalent commented matplotlib `ax.table` version with the same blue-low / red-high cell coloring.

## Why it matters

This is the **same pattern the production report apps use** — rank a player within a pool, color cells by metric direction (`higher_is_better`), and roll up to a composite. The BSB `percentile_to_color(pct, higher_is_better=...)` helper, the org-KPI ΣRk rank tables, and the draft `pctile_to_color` coloring are all this exercise grown up. White-at-midpoint diverging colormap also recurs (see the BSB visual-standards diverging-colormap rule).

## Links

- [[dsproj-data-science-examples]] (parent index)
- [[radar-chart-viz]] (sibling cross-player comparison viz)
- [[wrc-plus]] · [[xwoba]] · [[barrel-pct]] (metrics that feed scoring like this in production)
- [[MOC-baseball-analytics]]
