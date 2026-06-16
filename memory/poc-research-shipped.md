---
name: PoC Research One-Off
description: MLB-only damage/EV/SLG/xSLG/wOBAcon/xwOBAcon by 1-inch PoC depth + PoCRelY buckets. Shipped May 10 2026.
type: project
originSessionId: c13f2012-f4bf-45b6-a6b0-3bffe2344b5e
---
# PoC Research — Damage by Point-of-Contact Depth

**Status:** SHIPPED May 10 2026 on `feature/barrelsville` (commits `7ad50a9`, `8d580af`, `d57d551`).

**Ask (voice, May 10):** how do damage/EV/SLG/xSLG/wOBAcon/xwOBAcon vary
with point-of-contact depth, both vs the front of the plate (PoC) and
vs the batter's body center (PoCRelY)?

## What it does

- Pulls every MLB regular-season BIP for 2024-2026, all 30 orgs.
- Per-BIP cleaning matches the canonical
  `damage-pct-cross-app-divergences.md` standard: BIP-only, EV in (0,
  125), LA not null, bunt exclusion, EV-misread filter (per-batter P95
  cap via `EV_MISREAD_CTE`).
- Computes 6 per-BIP metrics, each formula identical to the affiliate
  tracker / sugar_land canon:
  - Damage% (canonical EV+LA formula, `pd-goals/src/metrics.py` math)
  - SLG (actual total bases; `cev.[1b]/[2b]/[3b]/hr` × {1,2,3,4})
  - xSLG (Hits_Probabilities × year exponents × {1,2,3,4})
  - wOBAcon (actual outcome × year wOBA weights)
  - xwOBAcon (Hits_Probabilities × year exponents × year wOBA weights)
  - Avg EV (raw)
- Year-specific weights/exponents pulled via the SAME helpers tracker
  uses: `tracker_data._get_woba_weights(year, "mlb")` +
  `_get_hit_specs_exponents(year)`.
- Buckets each axis by 1 inch (configurable) and writes 2-page PDF
  (page 1 = PoC depth, page 2 = PoCRelY) + long-form CSV.

## Files

- `barrelsville/src/poc_research_data.py` — SQL + per-BIP metric
  computation + bucketing helpers
- `barrelsville/scripts/generate_poc_research.py` — CLI + 2x3 chart
  rendering + CSV writer

## Run

```powershell
python barrelsville/scripts/generate_poc_research.py
# defaults: 2024-2026 MLB, 1-inch buckets, min 25 BIPs/bucket for the line
# overrides: --start-year / --end-year / --bucket-width / --min-bucket-n
```

Output: `barrelsville/output/poc_research_<YYYY-MM-DD>.{pdf,csv}` (CSV
is long-form: axis × bucket × n_bips × all 6 metrics).

## NOT in manifest.json or connect_pins/deploy.ps1

CLI-only research one-off. Not Streamlit-deployed, not pinned, not
Connect-scheduled. No reason to bundle into either deploy.

## Future iterations may want

- HOU overlay on league curves
- L/R hitter handedness split
- Per-level (e.g. AAA vs AA vs MLB) split if asked
- Tighter or wider x-axis windows depending on what the data shows
- Wider bucket width (--bucket-width 2 or 3) if 1-inch is too noisy at
  the tails
