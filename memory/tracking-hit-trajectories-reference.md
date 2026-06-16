---
name: tracking-hit-trajectories-reference
description: groundcontroltracking.tracking.pitch_hit_trajectories and tracking.plays schema — 3D spray chart data, polynomial trajectories, landing positions
type: reference
---

## groundcontroltracking.tracking.pitch_hit_trajectories

**Join key:** `sched_id` + `tracking_play_id` → join to `tracking.plays` to get `astros_pitch_id`
**Database:** GroundControlTracking (separate from GroundControl2)

### Key Columns for 3D Spray Chart

| Column | What It Is |
|--------|-----------|
| `hit_trajectory_max_height_z` | **REAL peak height (ft)** — replaces our ½g(t/2)² calc |
| `hit_trajectory_max_height_x` | X position at peak |
| `hit_trajectory_max_height_t` | Time at peak |
| `hit_landing_pos_x` | Landing X (cartesian, no trig needed) |
| `hit_landing_pos_y` | Landing Y (cartesian) |
| `hit_landing_pos_z` | Landing Z |
| `hit_landing_dist` | Landing distance (same as Astros.Hits.hit_distance) |
| `hit_landing_bearing` | Landing bearing (same as Astros.Hits.hit_bearing) |
| `hit_landing_time` | Time of landing |
| `hit_contact_pos_x/y/z` | Where bat hit ball in 3D |
| `hit_launch_speed` | EV at launch |
| `hit_launch_angle` | Launch angle |
| `hit_launch_direction` | Spray direction at launch |

### 9th-Order Polynomial Trajectory (FULL flight path)
- `hit_trajectory_poly_x_1` through `hit_trajectory_poly_x_9` — X coefficients
- `hit_trajectory_poly_y_1` through `hit_trajectory_poly_y_9` — Y coefficients
- **Z coefficients MISSPELLED** (per Adam Brodie, director of R&D):
  - `hit_trajectory_polz_z_1` (first one: "polz" not "poly")
  - `hit_trajectorz_polz_z_2` through `hit_trajectorz_polz_z_9` (rest: "trajectorz" AND "polz")
- These define the exact ball flight curve. Evaluate at time t for position.
- `hit_trajectory_valid_time_from` / `hit_trajectory_valid_time_to` — valid time range
- `hit_trajectory_measured_time_from` / `hit_trajectory_measured_time_to` — measured time range

### Other Hit Columns
| Column | What It Is |
|--------|-----------|
| `hit_last_measured_pos_x/y/z` | Last tracked position |
| `hit_last_measured_vel_x/y/z` | Last tracked velocity |
| `hit_last_measured_dist/bearing` | Last tracked polar |
| `hit_last_measured_time` | Last measurement time |
| `hit_landing_vel_x/y/z` | Velocity at landing |
| `hit_trajectory_110_pos_x/y/z` | Position at 110ft (?) |
| `hit_launch_spinrate/spinaxis` | Batted ball spin |
| `hit_contact_point_pos_x/y/z` | Contact point on bat |
| `hit_impact_point_angle` | Impact angle |
| `hit_sweet_spot_deviation_axial/long` | Sweet spot deviation |
| `hit_before_impact_point_speed_mph` | Bat speed before impact |
| `hit_after_impact_point_speed_mph` | Bat speed after impact |
| `hit_impact_time` | Time of impact |

### Pitch Columns (also in this table)
- Full pitch trajectory: release pos/vel/spin, polynomial coefficients (3rd order), break, zone speed
- `pitch_release_extension`, `pitch_release_spinrate`, `pitch_release_angle`
- `pitch_trajectory_pfxx/pfxz` — pitch movement

---

## groundcontroltracking.tracking.plays

**Join key:** `sched_id` + `tracking_play_id` (PK) → links to `pitch_hit_trajectories`
**Bridge to Astros schema:** `astros_pitch_id` = `Astros.Pitches_View.pitch_id` (with same `sched_id`)

| Column | Type | What It Is |
|--------|------|-----------|
| `sched_id` | int | Game ID (same as Astros.Schedule_View) |
| `tracking_play_id` | smallint | Tracking-specific play ID |
| `at_bat_number` | tinyint | PA number in game |
| `pitch_number` | tinyint | Pitch number in PA |
| `pickoff_number` | tinyint | Pickoff attempt number |
| `game_mode` | tinyint | Game mode flag |
| `inning` | tinyint | Inning |
| `is_top_inning` | bit | Top/bottom |
| `is_pitch` | bit | Is this a pitch (vs pickoff) |
| `is_pickoff` | bit | Is this a pickoff attempt |
| `is_hit` | bit | Did this result in a BIP |
| `is_scrubbed` | bit | Data quality flag |
| `number_of_metric_errors` | smallint | Error count |
| `astros_pitch_id` | smallint | **JOIN KEY to Astros.Pitches_View.pitch_id** |
| `source_play_id` | varchar | Source system ID |
| `pitch_release_tracking_timestamp_id` | smallint | Tracking timestamp |
| `event_number` | smallint | Event number |
| `pitcher_mlbam_id` | int | Pitcher MLBAM ID |
| `batter_mlbam_id` | int | Batter MLBAM ID |
| `pitcher_throws` | varchar | L/R |
| `bat_side` | varchar | L/R |

---

## Join Path: Astros → Tracking

```
Astros.Pitches_View pv
  → groundcontroltracking.tracking.plays tp
    ON pv.sched_id = tp.sched_id AND pv.pitch_id = tp.astros_pitch_id
  → groundcontroltracking.tracking.pitch_hit_trajectories pht
    ON tp.sched_id = pht.sched_id AND tp.tracking_play_id = pht.tracking_play_id
```

**NOT every play has tracking data.** Use LEFT JOIN — fall back to Bezier approximation from Astros.Hits when tracking is NULL.

## Coverage Notes (Mar 22, 2026)
- HawkEye venues have full tracking; TrackMan venues may have partial/no hit trajectory data
- The 3D spray chart should: try tracking data first → fall back to hang_time physics → fall back to LA*distance estimate
