---
name: fielding-advance-of-grid
description: "Intangibles fielding advance OF spray chart changed to 3x5 grid (Mazzo) — shipped, pending app redeploy"
metadata: 
  node_type: memory
  type: project
  originSessionId: 370b94e8-4946-4bb8-9df9-a1b3abfadcc4
---

**Fielding advance OF spray-tendency = 3×5 grid (Dylan Mazzo request) — SHIPPED Jun 23 2026 on `feature/astros-intangibles` (commit `d66377c2`), pending app redeploy.**

OF section of the green bird's-eye sector chart is now **5 lateral columns × 3 depth rows = 15 cells** (4 dividing lines across the −45..45 fan, 18° each; depth rows 150–210 / 210–270 / 270+, deepest open-ended, drawn to 330). Replaces the old 3 OF wedges; adds depth dimension. **IF unchanged** (4 wedges); IF/OF LA-dist boundary untouched.

- **Single source of truth:** `intangibles/src/hitter_advance_report.py::_draw_wedge_chart` — powers BOTH the app (`fielding_advance_page.py`→`_draw_hitter_page`) AND the PDF report/batch. App↔Report parity automatic.
- **Applies at EVERY level** (no level gate); currently only RUN at DSL in practice. **No low-`n` fallback** added (Mazzo accepted dilution; `if total_bips < N` revert-to-coarse is the easy future option). Rejected alt: per-position 3×3 (27 cells) — too sparse.
- Verified render-and-look (normal + empty-OF). Mocks in `C:\Users\Owner\Downloads\mock_fielding_*.png`.

**Open follow-ups:** (1) **IF slivers** — Mazzo's original ask also wanted INF spots split into 2–3 slivers; NOT done, pending his 2-vs-3 / lateral-vs-depth call (3-sliver apex cramming is real); same `_draw_wedge_chart`. (2) **OF `_is_dead` parity patch** (separate DSL-video fix, IF-only so far) still queued for next app redeploy. (3) **Go-live:** app needs Connect redeploy; PDF report just needs work-laptop `git pull`.

Vault detail: `projects/fielding-advance-spray-grid.md`. Related: [[switch-hitter-advance-2page-2026-06-17]].
