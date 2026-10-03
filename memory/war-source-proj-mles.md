---
name: war-source-proj-mles
description: Where career MLB WAR lives in GC2 — Proj.Batting_MLEs.war / Proj.Pitching_MLEs.war (Astros internal MLE WAR)
metadata: 
  node_type: memory
  type: reference
  originSessionId: da5385a4-89e3-45b6-bbd3-2129418ecffa
---

Career MLB WAR is **already in GC2** — do NOT stage a "discovery query" or reach for FanGraphs/bbref (the DB has no external WAR).

- **Hitters:** `Proj.Batting_MLEs.war`
- **Pitchers:** `Proj.Pitching_MLEs.war`
- Aggregate `SUM(war)` per player, **MLB-level only**: `team_id IN (SELECT team_id FROM MLBAM.Teams WHERE sport_code='mlb')`.
- Keyed by `groundcontrol_id` (join `Astros.Players` on `mlbam_id` when starting from an MLBAM id).

The promotion-models parquet column `career_mlb_war` is **all zeros** because it was scaffolded but never wired to these tables — the value exists; the ETL just never populated it. Pull from `Proj.*_MLEs.war`, don't re-derive.

Reference impls (grep before rewriting): `sql-queries/mlb-sp-2plus-war-aball-ff-2seam-usage.sql`, `sql-queries/Promo Pressure v2.sql`, `sql-queries/orp-top25-diagnostic.sql`, `sql-queries/Historical RAR - Amat Population.sql`. Related: [[promotion-models-status]].
