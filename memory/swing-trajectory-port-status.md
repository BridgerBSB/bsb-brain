---
name: swing-trajectory-port-status
description: "Pause-point memory for porting the Statcast swing-path visualizer into Barrelsville Postgame Tab2 Visuals. Discovery phase (v2 SQL just ran, sections 1-4 results in CSVs with user, section 5 didn't output). Resume here."
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e6e8d5b-3ddf-49a1-89f1-93c41cf10ac9
---

# Swing-Trajectory Visualizer Port — Pause Point (2026-05-21)

## Goal

Port the user's existing public Statcast swing-path visualizer
(`swing-path/catcher-interference-app/swing_path_app.py` +
`notebooks/create_realistic_swing_arc.py`) into Barrelsville Postgame
Tab2 Visuals — augmenting the existing 3D PoC panel with swing arcs
leading into the contact-point dots. Ohtani-style multi-swing overlay
becomes "select multiple BIPs in the video index → arcs overlay in 3D
PoC panel."

## State on pause

**Discovery phase, 2 SQL passes deep, NOT yet plotting.** Decision
between Path 1 (per-frame plot from real GC2 frames) vs Path 2 (Hermite
reconstruction from scalars) is gated on what the Swing_Shapes K-prefix
columns actually represent.

## What v1 discovery told us (Apr-May 2026)

**Tables present in `groundcontroltracking.Tracking`:**
- `Hitter_Kinematics` — body biomech at swing start (lead_wrist_rot,
  torso_flexion, etc.). NOT per-frame bat trajectory.
- `Swing_Contact_Values` — bat velocity + position at CONTACT FRAME
  only (batvx_con, baty_con, batz_con, e1x_con, etc.). Confirmed.
- `Swing_Shapes` — **HAS K-prefix scalar columns** (Km30, Km15, K0,
  K15, K30, K45) + plane_p0/p1/p2 + loft + tilt + x0/y0/z0. Each
  K-column is a single scalar per swing (NOT an x/y/z triple). Meaning
  unclear without column docs.
- `Swing_Damage_Windows` — sparse, mostly NULL t_in/t_out in sample.
- `LK_Ball_Trajectory_Types`, `LK_Kinematic_Segments`,
  `LK_Kinematic_Timestamps` — lookup tables, not yet queried.

**Sparse-coverage warning:** the specific test pitch in v1 returned
0 rows in ALL 4 tables (Swing_Shapes, SCV, Hitter_Kinematics,
Swing_Damage_Windows). HawkEye venue dependency confirmed via
`tracking-schema.md` §HawkEye-coverage-caveat (~50% sparsity at
non-HawkEye MiLB venues).

## What v2 discovery is asking (the CSVs user has, not yet pasted)

`sql-queries/bat-trajectory-discovery-v2.sql` — committed `30a82df8`,
fixed `9cc29cee` (was referencing pv.batting_team_id; switched to
ev.batting_team_id via ab_event_id JOIN per db-joins.md).

5 sections:
1. **LK_Kinematic_Timestamps** rows — naming for K-prefix labels
2. **LK_Kinematic_Segments + LK_Ball_Trajectory_Types** — context
3. **Full Swing_Shapes column list + extended_properties** — column comments
4. **Coverage check** — % HOU MLB 2026 BIPs with Swing_Shapes rows vs SCV baseline
5. **20-swing sample sorted by bat speed** — correlation diagnostic:
   - K0 stays constant ~0.4 regardless of speed → position/coordinate
   - K0 correlates with speed → velocity/curvature

User has CSVs from **sections 1-4 only**. **Section 5 did not output.**
Likely cause: SQL error in the section 5 query (probably the same
fielding_team_id-on-PV bug pattern, OR a column name issue, OR the
ORDER BY referencing an alias from inside the SELECT). Diagnose at
resume.

## Resume checklist (next session)

1. **Read this file FIRST**, then `.claude/rules/tracking-schema.md`
   for HawkEye coverage + 64-table catalog context.
2. **Get CSVs from user** for sections 1-4. Paste back into convo.
3. **Diagnose section 5 failure.** Likely candidates:
   - `bat_speed_mph` referenced in `ORDER BY` — T-SQL allows aliases
     in ORDER BY but only for the outermost SELECT. Should be fine
     but worth verifying.
   - `pv.pitch_result_id IN (12,13,14)` should be valid (BIP codes).
   - The 4 JOINs (sv, plays, scv, ss) might be over-restricting —
     INNER JOIN on Swing_Shapes drops every swing without a SS row,
     which is exactly what we DON'T want to filter on for the
     sample. **Probable fix: LEFT JOIN Swing_Shapes** so swings
     without SS show up with NULL K-values (and we sample on bat
     speed even when SS is missing).
   - Or: error was about `tp` not existing — should be
     `groundcontroltracking.Tracking.Plays`, confirm casing matches
     server config.
4. **From sections 1-3 results**: try to determine what Km30..K45
   represent. If LK_Kinematic_Timestamps has rows like
   `('K0', 0.0, 'contact frame', ...)`, that's the answer.
5. **From section 4 results**: gauge coverage rate. If < 30% of HOU
   MLB BIPs have Swing_Shapes, Path 1 isn't viable for the live app
   surface — too many empty arcs.
6. **Decision point** — Path 1 (real frames) vs Path 2 (Hermite from
   scalars):
   - Path 1: render per-frame arc from real GC2 keyframes. Heavier
     query, more accurate visual. Only viable if K-prefix columns
     are interpretable (position/velocity/curvature in known axis).
   - Path 2: port existing Hermite reconstruction from
     `swing-path/notebooks/create_realistic_swing_arc.py` using
     scalars (VBA/HBA at contact from SCV, loft + tilt from
     Swing_Shapes). Lossy if swing_length / path_tilt not available
     as scalars.

## Existing app inventory (offline-portable)

| Asset | Location | Use |
|---|---|---|
| Streamlit driver | `swing-path/catcher-interference-app/swing_path_app.py` | Reference UI |
| Hermite arc renderer | `swing-path/notebooks/create_realistic_swing_arc.py` (`draw_bat_ladder()`) | Path 2 prototype source |
| Metric definitions | `swing-path/MLB_STATCAST_DEFINITIONS.md` | attack_angle / attack_direction / swing_path_tilt / intercept point |
| Architecture doc | `swing-path/CLAUDE.md` | Coordinate system, 7 scalar inputs, data flow |

Plus already-known SCV column references from `db-columns.md`:
batvx/y/z_con (velocity), e1x/y/z_con (bat orientation unit vector),
batx/y/z_con (bat position at contact). The VBA + HBA formulas:
- VAA at contact = `90 - DEGREES(ACOS(e1z_con))`
- HAA at contact = `DEGREES(ATN2(e1y_con, ±e1x_con))`

## Tab2 integration plan (works for both paths)

Augment the existing `_vis_build_3d_poc` panel in
`barrelsville/pages/1_Postgame.py:2004`. Currently renders static
contact-point dots — add the swing arc leading INTO each dot. Same
panel, same `_vis_customdata_rows` click-to-video customdata, same
camera angle. Each swing becomes a colored line ending in the existing
PoC dot.

**Multi-swing comparison (Ohtani-style):** "select multiple BIPs in
the video index → overlay their arcs in the 3D PoC panel."

## Related work shipped same session

**Spray chart L/R inversion fix** — commit `8d84e0c8` on
`feature/barrelsville`. The 3D trajectory spray chart was using
`x_land = -distance*sin(bearing)` which inverted L/R from
`visual-standards.md` canonical. LHH pulled balls (positive bearing
= RF) were plotting on LEFT side (LF / RHH-pull side). Fixed by
dropping the `-` in both the arc landing point and the Minute Maid
fence loop. PoC charts were already correct because they use
`hit_initial_contact_point_x` directly with no transform.

NOT a swing-path bug, but caught in the same session because user
was eyeballing Tab2 Visuals charts that share the same parent file.

## Commits trail

| Commit | Branch | What |
|---|---|---|
| (early Apr) | `feature/pd-goals` | v1 discovery SQL written |
| `30a82df8` | `feature/pd-goals` | v2 discovery SQL |
| `9cc29cee` | `feature/pd-goals` | v2 fix: ev.batting_team_id via ab_event_id JOIN |
| `8d84e0c8` | `feature/barrelsville` | spray chart L/R inversion fix (unrelated but same session) |

## What NOT to do on resume

- Don't start writing rendering code without nailing down what K0
  means. Plotting blind is a coin flip per the user's own framing
  ("we'll know visually if the interpretation is right" was rejected
  as too risky).
- Don't INNER JOIN Swing_Shapes in the sample query. LEFT JOIN so
  swings without SS data still show up in the bat-speed-sorted sample.
- Don't reference `pv.batting_team_id` or `pv.fielding_team_id` —
  those columns live on `Events_View`, not `Pitches_View`. Use
  `ev.batting_team_id` after JOINing `ev ON ev.event_id = pv.ab_event_id`
  (per `db-joins.md` — `ab_event_id` is every-pitch, `cur_event_id`
  is NULL on ~75% of pitches).
- Don't assume coverage is high enough to ship until section 4
  numbers come back. If < 30% HOU MLB BIPs have Swing_Shapes, the
  feature is degraded enough that we'd want to design fallback
  behavior (skip arc, show only PoC dot) before building.
