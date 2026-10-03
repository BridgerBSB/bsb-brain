---
tags:
  - intangibles
  - fielding-advance
  - shipped
created: '2026-06-23'
status: shipped-pending-deploy
---
# Fielding Advance — OF Spray Tendency Grid (3×5)

**What it is:** Redesign of the spray-tendency chart on the Intangibles **fielding advance** (the green bird's-eye sector chart fielders use for positioning). Requested by **Dylan Mazzo** (asst. field coordinator), Jun 2026.

## The change (SHIPPED Jun 23 2026)
- **OF is now a 3×5 grid = 15 cells**: 5 lateral columns (4 dividing lines across the −45°..+45° fan, 18° each) × 3 depth rows (shallow 150–210 / med 210–270 / deep 270+, deepest open-ended in counting, drawn to 330 ft). Each cell shaded white→dark-green by % of BIPs, labeled.
- **Replaces** the old 3-wedge outfield. Adds the **depth** dimension Mazzo wanted ("split each OF position into a grid") for positioning specificity.
- **IF unchanged** — still 4 wedges (22.5° each). The IF/OF classification boundary (LA<15 & dist<150 = IF; LA≥15 & dist≥150 = OF) is untouched.

## Locked-in decisions
- **Applies at EVERY level** (dsl, rok, afx, afa, aax, aaa, mlb) — no level gate. `_draw_wedge_chart` ignores `level_code` for the grid; only the KDE density-plot *fence shape* is level-dependent (Minute Maid for mlb).
- **Currently only RUN at DSL** in practice, but the code is uniform across levels.
- **No low-`n` fallback** — the 15 cells dilute at sparse samples (DSL especially → lighter greens). Mazzo accepted this tradeoff; Zac flagged the sample-size concern up front. A `if total_bips < N` revert-to-coarse branch is a known easy future option if DSL looks too washed out.
- Earlier rejected alternative: per-OF-position 3×3 (27 cells) — too sparse/busy; the mock proved it unreadable.

## Implementation (single source of truth)
- File: `intangibles/src/hitter_advance_report.py` → **`_draw_wedge_chart()`**.
- **App↔Report parity is automatic**: both the live app page (`fielding_advance_page.py` → `_draw_hitter_page` → `_draw_wedge_chart`) and the PDF report/batch (`generate_hitter_advance_report` / `_batch` → same chain) route through that one function. One edit changed both.
- Commit **`d66377c2`** on `feature/astros-intangibles`.
- Verified via render-and-look (BLOCKING rule #18): normal case (clean 15-cell grid) + empty-OF edge case (only IF draws, no errors).

## To go live
- **App** → next Intangibles **app redeploy** to Posit Connect.
- **PDF report** → next `git pull` on the work laptop (run_daily/batch uses new code; no Connect deploy needed for the report side).

## Open follow-ups
- **IF slivers** — Mazzo's original ask also mentioned splitting INF spots into 2–3 slivers; NOT done yet. Pending his call on 2 vs 3 lateral slivers (the 3-sliver apex cramming is real) or a shallow/deep ring. Same `_draw_wedge_chart` function.
- **OF `_is_dead` parity patch** (separate, unrelated DSL-video fix) still queued for the next app redeploy.

## Related
- [[MOC-astros-engineering]]
- [[switch-hitter-advance-2page-2026-06-17]] — prior fielding-advance change (2-page switch-hitter split), same file/parity trio.
