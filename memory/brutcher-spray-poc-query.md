---
name: brutcher-spray-poc-query
description: "Drew Brutcher (130666, LHH) one-off query shape — spray Pull/Mid/Oppo % by month + delta, and PoC_Rel_Y (bally_con) by level"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0bfc755b-45b2-477b-a36a-f9af9b4ec50a
---

Drew Brutcher = `groundcontrol_id 130666`, **bats L**.

Two ad-hoc queries built Jun 29 2026 (Zac ask):
1. **Spray %** — Pull/Middle/Oppo as % of BIP, **per month (May, June) + a Delta
   (Jun-May) row**. LHH bearing zones: pull = RF `hit_bearing >= 15`,
   oppo = LF `hit_bearing <= -15`, middle = between. Bearing convention verified
   vs `org_kpi_data.py` PullAir% (neg = LF/3B, pos = RF/1B). Drive FROM
   Pitches_View, JOIN Hits on `sched_id+pitch_id` (Hits has no batter_id). The
   "two periods + delta" shape uses `UNION ALL` → see [[tsql-union-orderby-alias]]
   for the ORDER BY gotcha (wrap union in a CTE).
2. **PoC** by level A+ (`afa`) vs AA (`aax`) — the CANONICAL tracker metric,
   NOT SCV. `AVG(h.hit_initial_contact_point_y * 12.0 - 17.0)` from `Astros.Hits`,
   BIP-only, `CAST(... AS decimal(5,1))`. Positive = out front of plate edge,
   negative = behind. See [[poc-tracker-metric-canonical]] for the full formula
   family (PoC / PoCRelY / PoCRelX). My first pass used SCV `bally_con` (raw
   plate-apex distance, always positive) — WRONG; Zac caught it.

Output Zac wanted, lean: spray = month/n_bip/pull_pct/middle_pct/oppo_pct;
PoC = level/n_contact/PoC. Round at display only (1 decimal).
