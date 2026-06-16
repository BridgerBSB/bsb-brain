---
name: velo-ceiling-status
description: FB Velo Ceiling by Zone Height per-hitter heatmap — shipped + PAUSED June 8 2026 awaiting director/coordinator feedback
metadata: 
  node_type: memory
  type: project
  originSessionId: e4e531cd-29b9-438f-a172-c39cd262c67c
---

# FB Velo Ceiling by Zone Height — PAUSED (June 8 2026), awaiting feedback

Per-hitter PDF heatmap: how well a hitter handles fastballs (FF+FT) as they get
harder, by zone height. Built for the Daudet dev-list dig (Sam Niedorf ask), now
a general org tool. On `feature/barrelsville`. **PAUSED — waiting on Farm Director
+ hitting coordinator feedback before more work.**

## Files + run
- Data: `barrelsville/src/velo_ceiling_data.py`
- Script: `barrelsville/scripts/generate_velo_ceiling_heatmap.py`
- Design doc (full current state): `barrelsville/docs/plans/2026-05-28-ff-velo-ceiling-by-zone-design.md`
- Whole-org batch: `python barrelsville/scripts/generate_velo_ceiling_heatmap.py`
- One hitter: `... --batter <gc_id>` (Daudet 252859, Schiavone 218498)
- Defaults: current season, all 6 MiLB levels pooled; `--min-total-swings 100` publish gate.

## What it shows
3 height bands (top/mid/bottom third of the height-derived ABS **Tango Shadow**
zone, NOT measured sz_top/bot) × 6 velo buckets (2 mph: 90-91 … 100-101). Each
cell = his Contact% on FF/FT there. Color graded vs his **own in-zone fastball
contact average for that same velo range** (apples-to-apples as of June 2026).
Green=more contact than usual, red=less, white=at, grey=<10 swings.
Orange marker = per-band velo ceiling = fastest bucket where he still holds his
average with ≥10 swings (permissive; capped by sample, not just skill).

## Shipped this session (June 2026, all pushed)
- 5→3 bands; 1mph→2mph buckets (larger sample)
- baseline global → in-grid (apples-to-apples)
- `--batter` flag (single vs whole-org batch)
- PDF bottom-text overlap fixed + plain-language labels
- ceiling marker row bug fixed (was drawn one band too low)
- also added `--batter` flag to `hitter_analysis.py` (single-hitter org-sweep)

## OPEN on resume — pick the per-band gate
Per-cell 10-swing min still in place → thin bands/high-velo edges grey out,
ceilings capped by sample. Options:
- (A) band-level gate, no per-cell grey [RECOMMENDED, band min ~20]
- (B) lower per-cell min 10→6
- (C) cumulative-from-bottom ceiling
User hasn't chosen. (A) is the fix for the "only one orange marker" thinness.

## Deferred (revisit after feedback)
- horizontal `plate_x` gate (currently height-only, any side counts)
- bands off measured sz_top/sz_bot vs height-derived ABS zone
- Streamlit app integration
- FF vs FT split + platoon (vs LHP/RHP) splits
- on-PDF legend/key box (explainer currently lives in Slack)

Related: [[promotion-models-status]] (other Daudet-era dev work). Coordinator-facing
explainer text (colors + "what it is") was finalized in this session's Slack.
