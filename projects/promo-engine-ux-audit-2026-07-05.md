---
created: 2026-07-05
type: research
status: captured
tags:
  - promotion-release-models
  - ux
  - streamlit
  - dashboard-design
---
# Promo-Engine UX Audit + Research (Jul 5 2026)

Goal: make the Promotion + Release board (`pd-goals/promo-engine/app.py`) clear/intuitive for a new
user (coach/exec) and nicer. Core problems: grades are WITHIN-LEVEL percentile ranks (a 90 at FCL ≠
90 at AAA); 3 player states (fully-graded / release-only / new-level) all share one drawer; percentile
framing wanted. Links: [[promotion-release-models]] · [[release-multilevel-yoy-carryover-2026-07-04]]

## Sources

### Nielsen Norman Group — "Dashboards: Making Charts Easier to Understand" (preattentive)
https://www.nngroup.com/articles/dashboards-preattentive/
- **Length & 2D position** are the attributes humans judge *quantities* by accurately → use bars/bullets/
  lines, NOT pie/donut (area is misjudged), NOT radial gauges (waste space, harder than linear).
- **Color & shape = categorical grouping, NOT quantity.** Use color as *reinforcement only* — up to
  4.5% are colorblind; pair color with shape/position for a stronger, accessible signal.
- **Takeaway for us:** our Promote/Release are shown as bare colored 0-100 numbers. Numbers alone don't
  exploit length/position. Render each grade as a **horizontal bullet/bar** with the level's distribution
  as backdrop so "40" reads visually as "40th pct in FCL". Don't lean on green/red alone — add
  position/icon (colorblind-safe).

### Bullet charts for percentile-vs-benchmark (Power BI percentile chart / Datylon chart guide)
https://www.certlibrary.com/blog/mastering-power-bi-custom-visuals-the-percentile-chart/ ·
https://www.datylon.com/blog/types-of-charts-graphs-examples-data-visualization
- **Bullet chart** = compact bar + target marker + reference bands in one row; linear beats circular for
  a value-against-a-range. A **percentile chart** shows the value below which a % of observations fall.
- **Takeaway for us:** the bullet is the ideal mark for a within-level percentile rank — his value, the
  level median as the target tick, quartile bands behind it. One row per grade, reads at a glance,
  and the band context makes "within-level, not cross-level" visually obvious.

### UXPin / NN-adjacent dashboard principles (search synthesis)
https://www.uxpin.com/studio/blog/dashboard-design-principles/
- Effective dashboards show **5–9 core elements**; use **progressive disclosure / drill-down** to keep
  the main view clean; establish **hierarchy** (size/position/color) so the critical KPI is seen first;
  keep **consistency** in fonts/labels/color for low cognitive load.
- **Takeaway for us:** board is already lean (good). The DRAWER is where progressive disclosure should
  adapt to the player — one generic drawer is the bug (Apker/release-only looked broken).

## Audit of the current app

| Issue | Now | Fix direction |
|---|---|---|
| Grades = bare colored numbers | "40" in a colored pill | **Bullet/bar** with level median tick + quartile bands (percentile made visual) |
| Cross-level comparability not conveyed | 90 at FCL looks like 90 at AAA | Label "rank within {level}"; consider **faceting/grouping by level**; bullet bands are per-level |
| One drawer for 3 states | fully-graded drawer used for all | **3 drawer variants**: fully-graded (promote+release+drivers), release-only (no promote section — DONE Jul 5), new-level (pooled read + "read from body of work") |
| Release drivers missing for pooled players | empty section | compute drivers on the primary row, or show a "pooled read" note (Bug B) |
| Color-only semantics | green/red | pair with icon/position (4.5% colorblind) |
| Dual-metric meaning | two hero cards | one-line "Promote = ready for next level · Release = whole-body-of-work risk" |

## Prioritized recommendations
1. **Bullet/bar grades** with per-level median + quartile bands (biggest clarity win; makes percentile +
   within-level both visual). 2. **3 drawer variants** (release-only done; add new-level + pooled-driver
   note). 3. **"within {level}" framing** everywhere a grade shows. 4. **Colorblind-safe** (icon+position,
   not just green/red). 5. Level facet/group option on the board.

## Council-relevant?
UX/dashboard methodology — not stats/ML rigor, so NOT added to council-knowledge-base §7. Lives here +
linked from the project hub.
