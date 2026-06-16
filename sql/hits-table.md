---
type: reference
domain: data
tags:
  - sql
  - groundcontrol2
  - table
---
# Astros.Hits

One row **per batted ball** (Astros org only) — EV, launch angle, trajectory. Source for Damage, Barrel%, Avg EV. Part of [[MOC-groundcontrol-schema]].

## Join keys
- `sched_id` + `pitch_id` → [[pitches-view]], gated on `pitch_result_id IN (12,13,14)` (BIP only)
- **No `batter_id`** — attach player via Pitches_View

## Key columns
- `hit_exit_speed` (EV mph), `hit_vertical_angle` (LA °), `hit_bearing` (spray)
- `hit_trajectory_id` → `LK_Hit_Trajectories`; **2,3,4 = bunts**

## Gotchas (standard filters)
- Exclude bunts: `hit_trajectory_id NOT IN (2,3,4) OR ... IS NULL`
- Cap extremes: `hit_exit_speed < 125`
- Low-level LA misread: `NOT (hit_vertical_angle < -25 AND level_code IN ('hsb','sum','bbc'))`
- ⚠ `MLBAM.Hits` is the league-wide sibling but **can't join to `MLBAM.Pitch_fx`** (`sv_pitch_id` is NULL there). See [[db-joins]].

Feeds expected stats via `Astros.Hits_Probabilities` ([[xwoba]]).
