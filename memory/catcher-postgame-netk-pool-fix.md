---
name: catcher-postgame-netk-pool-fix
description: SHIPPED May 24 2026 — Catcher postgame Season NetK now colored vs per-catcher season pool (not per-game pool). Plus App↔Report parity fix on Streamlit page receiving-table NetK.
metadata: 
  node_type: memory
  type: project
  originSessionId: d9e21775-982f-40de-bfa5-0b683a6df8f2
---

# Catcher Postgame Season NetK — Pool Grain Fix (May 24 2026)

User caught: Will Bush's NetK red in postgame, green in KPI snapshot
and affiliate tracker. Same underlying value, different colors → bug.

## Root cause

`intangibles/src/catcher_report.py:325-327` scored the catcher's
**SEASON-aggregate NetK** value (`netk_season`, e.g. -8 net strikes
over 6 weeks) against the **per-GAME percentile pool**
(`percentiles["netk_game"]`).

Scale mismatch:
- Per-game NetK pool: mean ~0, range -10 to +15 (one game's edge calls)
- Per-catcher season NetK: range -50 to +50 (full season)

Season value of -8 lands deep in the LOW tail of the game-pool (where
any single game of -8 is a disaster) → RED. Same -8 vs other catchers'
season totals (much wider dist) lands at ~50th percentile → green-ish.

KPI snapshot, affiliate tracker, KPI weekly all correctly use
`netk_season_total` pool (per-catcher season aggregates). Only
postgame's "Full Season" column was wrong.

NetK is the **unique offender** among catcher metrics in that table.
Arm/Exch/Pop2B are per-throw rates — P99 arm of a season vs P99 arm
of a game land on the same physical scale (80 mph is 80 mph). Only
cumulative-SUM metrics have this season-vs-game scale mismatch.

## Commits

**`feature/astros-intangibles`:**

1. `48736400` — PDF fix. `catcher_report.py:325-330` swapped
   `percentiles["netk_game"]` → `percentiles["netk_season_total"]`.
   The `netk_season_total` pool was already shipped in
   `c4c27aba` (May 22 KPI snapshot batch) — postgame just needed to
   point at it.

2. `e048f1ee` — App parity. `pages/4_Catching.py` had **two** inline
   duplicated coloring sites that didn't auto-propagate from the
   PDF fix:
   - Line 1124-1133: main NetK table Season cell, same bug. Swapped
     to `netk_season_total`.
   - Line 724-806: `_style_receiving` (by-PT receiving table) applied
     `netk_game` pool uniformly to every cell. PDF correctly splits:
     per-PT rows use rate vs `netk_by_pt[pt]` pool; Total row uses
     raw NetK vs `netk_game`. App now mirrors via row-wise styler
     with `_n_called` threaded through from the original df (before
     `_hide` drops underscore columns).

## App↔Report parity lesson

Inline duplicated coloring logic in the app means PDF fixes don't
auto-propagate. **Audit checklist before claiming any catcher render
fix done:** grep BOTH `intangibles/src/` AND
`intangibles/pages/` for `netk_game`, `netk_season_total`,
`percentile_from_distribution`. Every match's pool key must match
its value grain (season vs game vs per-PT rate).

## What NOT to do

- Don't revert to `netk_game` pool on the Season cell. It compares
  season aggregates against game-level dists — different scales.
- Don't apply `netk_game` uniformly to per-PT receiving table rows.
  Per-PT rows are per-PT-rate values, need per-PT-rate pool
  (`netk_by_pt[pt]`).
- Don't strip `_n_called` from the receiving df before
  `_style_receiving` — the row-wise styler needs it to compute the
  rate per PT. The current pattern threads it through via
  `n_called_by_pt` dict built BEFORE `_hide` drops underscore cols.

## Cross-references

- `three-surface-parity.md` Catcher bug-history table — FramRAA /
  BlockRAA / framing-buckets bug history (related but different bug
  class).
- `kpi-snapshot-fixes-shipped.md` — `netk_season_total` pool source
  (where it was first added May 22).
- `multi-level-rollup.md` — different concern; the catcher pooling
  fix for multi-level Arm/Exch/Pop is still deferred per
  `three-surface-parity.md`.
