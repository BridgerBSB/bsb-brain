# Portable TrackMan Reference (V Sched Type)

## Discovery (Mar 4, 2026)

`sched_type = 'V'` = **Portable TrackMan** — physically different hardware from the fixed stadium TrackMan/HawkEye system. Used for:
- Bullpen side sessions (standard use)
- Some **live games** (when portable unit is the only tracking available)

## The Problem

When V games appear in postgame reports (Barrelsville, Arm Farm, Intangibles):
- Game shows up in sidebar (Schedule_View has the sched_id)
- Queries hit `Astros.Pitches_View` → **data is empty/NULL** for many columns
- Reports render with missing data or crash

**Root cause:** V game pitch data lives in `Trackman.pitches_portable`, NOT in `Astros.Pitches_View`. The Astros ingestion pipeline doesn't fully populate Pitches_View for portable-tracked games.

## Trackman Schema Tables

Found in `Trackman.*` schema on GCSQL02:

| Table | Purpose |
|-------|---------|
| `Trackman.pitches_portable` | **Pitch-level data from portable units** |
| `Trackman.portable_extracts` | **Extract metadata** (ExtractID, FileName, DateUploaded, sched_id) |
| `Trackman.Pitches` | Fixed-system pitch data |
| `Trackman.Pitches_Corrected` | Corrected pitch data |
| `Trackman.Pitches_Corrections` | Correction log |
| `Trackman.Game_Data` | Game-level metadata |
| `Trackman.Portable_Devices` | Device inventory |
| `Trackman.Link_Game_To_MLBAM` | TrackMan game → MLBAM game mapping |
| `Trackman.Link_Pitches_To_Synergy` | Pitch → Synergy video mapping |
| `Trackman.Player_ID_Merges` | Player ID reconciliation |
| `Trackman.Id_Game_List_View` | Game list view |
| `Trackman.Id_List_View` | ID list view |
| `Trackman.MILB_Data_Uploads` | MiLB upload tracking |
| `Trackman.Staging_*` | Staging tables (Data, CSVLoad, VideoApp, PortableCSVL, Starting_Positi) |
| `Trackman.Amat_Guid_To_Id_Map` | Amateur GUID mapping |
| `Trackman.Game_Load_Times` | Load time tracking |

### portable_extracts Columns
| Column | Type | Nullable |
|--------|------|----------|
| ExtractID | int | NO (PK) |
| FileName | nvarchar(255) | YES |
| DateUploaded | datetime | YES |
| sched_id | int | YES |

### pitches_portable Columns
| Column | Type | Notes |
|--------|------|-------|
| ExtractId | int | FK to portable_extracts |
| PitchNo | int | Matches `pv.pitch_id` in bullpen JOIN |
| Date | date | |
| Time | time | |
| Pitcher | nvarchar(255) | Name string |
| PitcherId | nvarchar(255) | TrackMan pitcher ID |
| PitcherThrows | nvarchar(15) | L/R |
| PitcherTeam | nvarchar(25) | |
| Batter | nvarchar(255) | Name string |
| BatterId | nvarchar(255) | TrackMan batter ID |
| BatterSide | nvarchar(15) | L/R |
| PitcherSet | nvarchar(15) | Stretch/Windup |
| TaggedPitchType | nvarchar(45) | Raw tag (FF, SL, etc.) |
| HitType | nvarchar(45) | Ground ball, fly ball, etc. |
| **RelSpeed** | decimal | = `start_speed` / velo |
| VertRelAngle | decimal | Vertical release angle |
| HorzRelAngle | decimal | Horizontal release angle |
| **SpinRate** | decimal | = `spinrate` |
| SpinAxis | decimal | |
| Tilt | nvarchar(15) | Clock-face tilt string |
| **RelHeight** | decimal | = `release_z` |
| **RelSide** | decimal | = `release_x` |
| **Extension** | decimal | = `extension` |
| **VertBreak** | decimal | Vertical break |
| **InducedVertBreak** | decimal | = `inducedvertbreak` / IVB |
| **HorzBreak** | decimal | = `horzbreak` |
| **PlateLocHeight** | decimal | = `plate_z` (location) |
| **PlateLocSide** | decimal | = `plate_x` (location) |
| ZoneSpeed | decimal | Speed at plate |
| VertApprAngle | decimal | Vertical approach angle |
| HorzApprAngle | decimal | Horizontal approach angle |
| ZoneTime | decimal | |
| **ExitSpeed** | decimal | = `hit_exit_speed` (EV) |
| **Angle** | decimal | = `hit_vertical_angle` (LA) |
| **Direction** | decimal | Spray direction |
| HitSpinRate | decimal | |
| PositionAt110X | decimal | |
| PositionAt110Y | decimal | |
| PositionAt110Z | decimal | |
| **Distance** | decimal | Hit distance |
| **Bearing** | decimal | Hit bearing |
| HangTime | decimal | |
| pfxx | decimal | Horizontal movement (pfx) |
| pfxz | decimal | Vertical movement (pfx) |
| x0, y0, z0 | decimal | Release point coords |
| vx0, vy0, vz0 | decimal | Initial velocity components |
| ax0, ay0, az0 | decimal | Acceleration components |
| LastTrackedDistance | decimal | |
| ContactPositionX/Y/Z | decimal | Contact point coords |
| Device | int | Device ID |

## Column Mapping: pitches_portable → Astros.Pitches_View

| pitches_portable | Astros.Pitches_View | Used in reports |
|-----------------|---------------------|----------------|
| RelSpeed | start_speed | Velo ✓ |
| PlateLocSide | plate_x | Location ✓ |
| PlateLocHeight | plate_z | Location ✓ |
| HorzBreak | horzbreak | Movement ✓ |
| InducedVertBreak | inducedvertbreak | Movement ✓ |
| SpinRate | spinrate | Spin ✓ |
| RelHeight | release_z | Release point ✓ |
| RelSide | release_x | Release point ✓ |
| Extension | extension | Extension ✓ |
| TaggedPitchType | pitch_type | Pitch type ✓ |
| BatterSide | bat_side | Batter hand ✓ |
| ExitSpeed | (via Hits) hit_exit_speed | EV ✓ |
| Angle | (via Hits) hit_vertical_angle | LA ✓ |
| Direction/Bearing | (via Hits) hit_bearing | Spray ✓ |
| vx0, vy0, vz0 | vx0, vy0, vz0 | Trajectory ✓ |

## What's NOT in pitches_portable (critical gaps for postgame)

- **called_strike_chance_mlb (CSC)** — no zone probability → no ZSw%, OSw%, Chase%, ZCtct%, OCtct%, ZWhiff%
- **pitch_result_id** — no swing/take/foul/whiff/BIP classification
- **did_swing** — no swing detection
- **cur_event_id / ab_event_id** — no PA linkage
- **Event outcomes** (1b, 2b, 3b, hr, ab, bb, hbp, sf) — no wOBA, no xwOBA, no statline
- **Stuff grades** (stuffrelvel_grade_2080, etc.) — no stuff+
- **Pitches_Grades** data — no loc grade
- **pBarrel** — no barrel probability
- **rv_gain_given_hit_specs** — no run values
- **count context** (balls_before, strikes_before) — no count-state analysis

## What IS available for V game reports

Can show: velo, movement, spin, location plot, release point, extension, exit velo, launch angle, spray, hit distance.

Cannot show: zone metrics, swing/take outcomes, wOBA, xwOBA, percentile coloring on most metrics, PA results, statline, stuff grades, pBarrel, gcPerf, run values.

## Current State in Code

All postgame projects **include V** in game queries:
- Barrelsville: `GAME_SCHED_TYPES = ("R","S","E","V","I")` in `postgame_data.py:77`
- Arm Farm: `GAME_SCHED_TYPES = ("R","S","E","V","I")` in `postgame_data.py:44`
- Intangibles: V included in `DATA_SCHED_TYPES`
- PD Goals: **excludes V** — `('E','R','S')` in `database.py:27`

Barrelsville `postgame_data.py:1272` already has a comment acknowledging the issue:
> `# are NULL for sched_type='V' (Live BP). Derive PA outcomes from`

## Existing Portable JOIN Pattern (Bullpen Reports)

The bullpen side report already handles this correctly in `bullpen_data.py`:
```sql
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
LEFT JOIN (
    SELECT sched_id, MAX(ExtractID) AS ExtractID
    FROM Trackman.portable_extracts
    GROUP BY sched_id
) pe2 ON sv.sched_id = pe2.sched_id
LEFT JOIN Trackman.pitches_portable pp ON pe2.ExtractID = pp.ExtractId
    AND pv.pitch_id = pp.PitchNo
```

## TODO: Future Fix Options

1. **For V games, query pitches_portable instead of (or in addition to) Pitches_View**
   - Use the bullpen JOIN pattern above
   - COALESCE portable columns over Astros columns for V games
2. **Show what we can** for V games — velo, movement, batted ball — and blank/hide zone metrics, outcomes
3. **Exclude V from postgame** entirely with a note explaining data limitations
4. **Hybrid approach** — show V games in sidebar with a "(Portable)" tag, render a limited report
