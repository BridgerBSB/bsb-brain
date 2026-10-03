---
name: poc-tracker-metric-canonical
description: "Canonical affiliate-tracker Point-of-Contact metrics (PoC / PoCRelY / PoCRelX) — source columns + exact formulas. Don't use SCV bally_con."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0bfc755b-45b2-477b-a36a-f9af9b4ec50a
---

The hitting affiliate tracker (Barrelsville) PoC family comes from
**`Astros.Hits.hit_initial_contact_point_x / _y`** (BIP-only), NOT from
`groundcontroltracking...swing_contact_values.bally_con`. SCV `bally_con`
is raw ball-Y distance from the plate apex (always positive) — wrong metric.

Reference impl: `barrelsville/src/tracker_data.py` `_POC_QUERY` (`poc_depth_in`)
+ `_POC_REL_QUERY` (`poc_rel_y`, `poc_rel_x`). Display labels: PoC / PoCRelY /
PoCRelX, format `f1` (1 decimal), no percentile color (hib=None).

**PoC (poc_depth_in)** — depth from the FRONT of the plate:
`h.hit_initial_contact_point_y * 12.0 - 17.0` (HawkEye origin = back tip,
front edge = 17"). **Positive = out front of the plate front edge; negative =
behind it / over the plate.** BIP-only (`pitch_result_id IN (12,13,14,18,19,20)`),
`hit_initial_contact_point_y IS NOT NULL`, sanity `BETWEEN -24 AND 48`. From
`Astros.Hits` only — no tracking-table join needed.

**PoCRelY (poc_rel_y)** — Y of contact relative to the batter's body center:
`(h.hit_initial_contact_point_y - pos.y_b) * 12.0` (inches). Positive = in
front of body, negative = jammed/late. **Requires** the body-position join to
`groundcontroltracking.tracking.player_tracking_bypos` (contact event +10
frames) → HawkEye-only, sparse at non-HE MiLB venues.

**PoCRelX (poc_rel_x)** — lateral contact vs body center:
`(h.hit_initial_contact_point_x - pos.x_b) * 12.0 * (L? -1 : 1)` →
**pull-side positive for BOTH L and R** (May 9 2026 fix).

Used Jun 29 2026 for [[brutcher-spray-poc-query]] (Zac wanted PoC by level,
not the SCV thing I first wrote). Lesson: PoC is a known tracker metric — read
`tracker_data.py` PoC queries, don't reach for SCV.
