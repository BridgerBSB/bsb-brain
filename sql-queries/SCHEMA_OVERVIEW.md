# Astros Database Schema Reference

> **Last Updated:** January 26, 2026 (Strike%, FPS% formulas added)  
> **Purpose:** High-level overview of database architecture for PD Goals App

---

## 🗄️ Three Main Databases

| Database | Purpose | Key Content |
|----------|---------|-------------|
| **GroundControl2** | Pitch-level data, player info, scouting | All data outside biomechanics and bat tracking |
| **GroundControlSwing** | Blast bat tracking | Frame-by-frame time series + calculated metrics |
| **GroundControlTracking** | Hawkeye frame data | Bat tracking, ball tracking, player tracking, biomechanics |

---

## 📊 Main Tables in GroundControl2

### Core Tables

| Table | Purpose | Primary Key | Notes |
|-------|---------|-------------|-------|
| `Astros.Players` | All players, names, IDs | `groundcontrol_id` | Links to all player data in Astros schema |
| `Astros.Pitches_View` | Pitch-level metrics | `sched_id`, `pitch_id` | TM/HE data + grades, swing decision, called strike chance |
| `MLB_eBis.PP_MASTER` | Player info from eBIS | `PLAYER_ID` | Roster status, ORG, level, service time, draft info |
| `Astros.Schedule_View` | Game information | `sched_id` | Enhanced schedule with level, type |

### ID Mappings

```
Astros.Players.groundcontrol_id  ← Primary for Astros.* tables
Astros.Players.ebis_id           → MLB_eBis.PP_MASTER.PLAYER_ID
Astros.Players.mlbam_id          → MLBAM.*.player_id
```

---

## 🏟️ Level Codes (Professional Levels for PD)

| Code | Affiliate | Description |
|------|-----------|-------------|
| `ml` | HOU | MLB - Houston Astros |
| `3a` | AAA Sugar Land | Triple-A |
| `2a` | AA Corpus Christi | Double-A |
| `1a` | A+ Asheville | High-A |
| `1f` | A Fayetteville | Single-A |
| `r` | FCL | Florida Complex League (Rookie) |
| `ds` | DSL | Dominican Summer League |

**Note:** Other levels (bbc=College, hsb=High School, etc.) are amateur/scouting and not used for PD Goals.

---

## 📋 Roster Status Codes (mnrosterstatus_lk)

| Code | Description | Include in Goals? |
|------|-------------|-------------------|
| `ACT` | Active | ✅ Yes |
| `VOL` | Voluntary (leave) | ✅ Yes |
| `RES` | Restricted | ✅ Yes |
| `DIS` | Disqualified | ✅ Yes |
| `PAC` | Pending Active | ✅ Yes |
| `FA` | Free Agent | ❌ No |
| `REL` | Released | ❌ No |

---

## ⚾ Position Codes (POSITION_LK)

### Pitchers
| Code | Description | Normalized |
|------|-------------|------------|
| `RHS` | Right-Handed Starter | RHP |
| `RHR` | Right-Handed Reliever | RHP |
| `LHS` | Left-Handed Starter | LHP |
| `LHR` | Left-Handed Reliever | LHP |

### Position Players
| Code | Description | Category |
|------|-------------|----------|
| `C` | Catcher | C |
| `1B` | First Base | INF |
| `2B` | Second Base | INF |
| `3B` | Third Base | INF |
| `SS` | Shortstop | INF |
| `IF` | Infield (utility) | INF |
| `LF` | Left Field | OF |
| `CF` | Center Field | OF |
| `RF` | Right Field | OF |
| `OF` | Outfield (utility) | OF |

### Position Categories for Reports
- **Pitchers:** RHP, LHP (for goal norming)
- **Catchers:** C (unique defensive metrics)
- **Infielders:** INF (1B, 2B, 3B, SS, IF)
- **Outfielders:** OF (LF, CF, RF, OF)

---

## 🎯 Schedule Types (sched_type)

| Code | Description | Use for Goals? |
|------|-------------|----------------|
| `S` | Spring Training | ✅ Goals start here! |
| `R` | Regular Season | ✅ Primary |
| `D` | Division Series | ✅ Playoffs |
| `L` | League Championship | ✅ Playoffs |
| `W` | World Series | ✅ Playoffs |
| `F` | Wild Card | ✅ Playoffs |
| `E` | Exhibition | ⚠️ Maybe |
| `I` | Intersquad | ❌ Practice |
| `B` | Bullpen Session | ❌ Practice |
| `P` | Batting Practice | ❌ Practice |
| `V` | Live BP | ❌ Practice |
| `A` | All-Star Game | ❌ Special |

---

## 📈 Metrics Reference

### Pitching Metrics (MVP)

| Metric | Description | Source Table | Column(s) |
|--------|-------------|--------------|-----------|
| **Pitch** | Pitch type name | Pitches_View | `pitch_type` |
| **# of P** | Pitch count | Pitches_View | `COUNT(*)` |
| **Use%** | Usage rate | Pitches_View | Calculated |
| **AvgVelo** | Average velocity | Pitches_View | `AVG(release_speed)` |
| **MaxVelo** | Max velocity | Pitches_View | `MAX(release_speed)` |
| **Spin** | Spin rate | Pitches_View | `spin_rate` |
| **iVB** | Induced vertical break | Pitches_View | `AVG(inducedvertbreak)` - Higher = more rise for FF |
| **HB** | Horizontal break | Pitches_View | `AVG(horzbreak)` |
| **Strike%** | Strike rate | Pitches_View | `pitch_result_id NOT IN (balls)` / total. Includes BIP! |
| **FPS%** | First pitch strike % | Pitches_View | `ab_pitch_number = 1` AND strike |
| **inZ%** | In zone % | Pitches_View | `called_strike_chance_mlb` |
| **ZWhiff%** | Zone whiff % | Pitches_View | Whiffs in zone / swings in zone |
| **Whiff%** | Overall whiff % | Pitches_View | Whiffs / swings |
| **pBarrel%** | Parabolic barrel % | Hits | EV/LA formula |
| **Damage%** | Damage allowed | Hits | Complex EV/LA formula |
| **Avg EV** | Average exit velo allowed | Hits | `AVG(hit_exit_speed)` |
| **wOBACON** | wOBA on contact | Hits | Weighted calculation |
| **BABIP** | Batting avg on balls in play | Events_View | Calculated |
| **StuffRelVel** | Stuff grade (rel velo) | Pitches_Grades | `stuffrelvel_grade_2080` |
| **StuffVel** | Stuff grade (velo) | Pitches_Grades | `stuffvel_grade_2080` |

### Hitting Metrics (MVP)

| Metric | Description | Source Table | Column(s) |
|--------|-------------|--------------|-----------|
| **wOBA** | Weighted on-base average | Events_View + Guts | Weighted PA outcomes |
| **xwOBA** | Expected wOBA | Hits_Probabilities | `xwoba` |
| **wRC+** | Weighted runs created+ | Calculated | Park/league adjusted |
| **RAR** | Runs above replacement | Calculated | WAR component |
| **Track%** | Trackable batted balls % | Hits | Non-null EV/LA |
| **Avg EV** | Average exit velocity | Hits | `AVG(hit_exit_speed)` |
| **Max EV** | Max exit velocity | Hits | `MAX(hit_exit_speed)` |
| **Useful EV** | Useful exit velocity | Hits | `hit_useful_exit_speed` |
| **Barrel%** | Barrel rate | Hits | EV/LA formula |

### Defense Metrics - Infield

| Metric | Description | Source Table |
|--------|-------------|--------------|
| **Outs** | Total outs | Defense tables |
| **RAA** | Runs above average | Defense tables |
| **PAA/EO** | Plays above avg per event | Defense tables |
| **TopSpd** | Top speed | INF_Ability_Metrics |
| **Split1** | First step split | INF_Ability_Metrics |
| **AccelCD** | Acceleration (charge/dive) | INF_Ability_Metrics |
| **AccelCU** | Acceleration (cut) | INF_Ability_Metrics |
| **React** | Reaction time | INF_Ability_Metrics |
| **ReactRad** | Reaction radius | INF_Ability_Metrics |
| **ReactAccRad** | Reaction accel radius | INF_Ability_Metrics |
| **ArmINF** | Arm strength | INF_Ability_Metrics |
| **ExchINF** | Exchange time | INF_Ability_Metrics |
| **ThrowsINF** | Throw count | INF_Ability_Metrics |

### Defense Metrics - Outfield

| Metric | Description | Source Table |
|--------|-------------|--------------|
| **UseReact** | Useful reaction | OF_Ability_Metrics |
| **ReactRad** | Reaction radius | OF_Ability_Metrics |
| **ReactAccRad** | Reaction accel radius | OF_Ability_Metrics |
| **TopSpd** | Top speed | OF_Ability_Metrics |
| **ArmOF** | Arm strength | OF_Ability_Metrics |
| **ExchOF** | Exchange time | OF_Ability_Metrics |
| **ThrowsOF** | Throw count | OF_Ability_Metrics |

### Catcher Defense Metrics

| Metric | Description | Source Table |
|--------|-------------|--------------|
| **NetK** | Net strikeouts | CatcherDefense_Framing |
| **xPP** | Expected passed pitches | CatcherDefense_Blocking |
| **Arm** | Arm strength | CatcherDefense tables |
| **Acc** | Throw accuracy | CatcherDefense tables |
| **Exch** | Exchange time | CatcherDefense tables |
| **Pop2B** | Pop time to 2B | CatcherDefense tables |
| **Pop3B** | Pop time to 3B | CatcherDefense tables |
| **AdjNetK** | Adjusted net K | CatcherDefense_Framing |
| **RAA-Framing** | Runs above avg (framing) | CatcherDefense_Framing |
| **RAA-Blocking** | Runs above avg (blocking) | CatcherDefense_Blocking |

---

## 📊 Report Categories (Future)

### Hitting Report Tables
1. **Rocks** - Core stats (wOBA, xwOBA, wRC+, RAR)
2. **Swing Decisions** - Chase%, ZSwing%, SwDec
3. **Contact + Quality** - Barrel%, Damage%, EV
4. **Bat Speed + Path** - Bat speed, attack angle
5. **Ball Flight** - LA, spray, trajectory

### Pitching Report Tables
1. **Pitch Mix** - Usage, velocity, movement
2. **Results** - K%, BB%, BABIP
3. **Quality** - Stuff grades, Damage allowed
4. **Advanced** - gcERA, gcPerf, FIP

---

*Generated for PD Goals App - Houston Astros Player Development*
