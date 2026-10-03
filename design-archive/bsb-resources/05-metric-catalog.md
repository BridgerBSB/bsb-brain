# Metric Catalog

This chapter is a complete catalog of every metric the codebase
computes. It pairs the **codebase metric guide** (where each metric
is computed, what filters apply, and what's intentionally different
from GC2) with the **official Houston Astros GroundControl glossary**
(plain-English + Spanish definitions per metric).

Read it like a reference, not start-to-finish. When you encounter a
metric you don't recognize on a report, jump to the glossary section.
When you need the source code, use the codebase guide.

::: tip
**What's in this chapter:**

1. Codebase guide --- per-metric source-file pointers, gates, and
   blocking rules.
2. The complete GroundControl metric glossary --- every metric
   defined in plain English (and Spanish), official from GC.

The official PDFs (Astros Glossary + R&D papers on gcERA + gcPerf)
ship alongside the handbook source at
`docs/handbook/assets/astros-glossary.pdf`,
`docs/handbook/assets/ar-gcera.pdf`, and
`docs/handbook/assets/ar-gcperf.pdf`. Open them when you need the
formal derivations or pages 5-7 of the glossary that don't fit
cleanly into a markdown table.
:::

## Codebase metric guide

For each metric: where it's computed, what filters apply, what's the
canonical reference implementation.

### Hitting metrics

| Metric | Canonical reference | Notes |
|---|---|---|
| **wOBA** (per-batter, SQL inline) | `pd-goals/src/org_kpi_data.py::_HITTING_ORG_QUERY` (~line 720) | Denom = `AB + BB - IBB + HBP + SF`. Event-anchored driver |
| **wOBA** (per-batter, Python) | `barrelsville/src/tracker_data.py` (~line 1080) | Fetch component counts via SQL, weights via dict, math in Python |
| **wOBA weights** | `barrelsville/src/hitter_kpi_data.py::_get_woba_weights` line 145 | `AVG(woba_*)` across league splits. Falls back to season-1 before May |
| **wRC+ league env** | `barrelsville/src/hitter_kpi_data.py::_get_league_woba_env` line 191 | `AVG(wOBA) / AVG(wOBA_scale) / AVG(runs_per_pa)` per level |
| **wRC+ formula** | `((wOBA - lg_wOBA) / scale + runs_per_pa) / runs_per_pa * 100` | Same across pd-goals + barrelsville |
| **xwOBA** (per-batter) | `barrelsville/src/hitter_kpi_data.py` xwoba block | `Hits_Probabilities` + exponents from `Guts.hit_specs_ratios`. Exponents do NOT fall back to prior year |
| **gcOBA** (per-batter) | `barrelsville/src/tracker_data.py` gcOBA block | 6-component composite. See Ch 4 for the formula |
| **K% / BB%** | `barrelsville/src/tracker_data.py` | Denom = `SUM(pa) + SUM(ibb)` (total PA inc. IBB + SH). **Distinct from wOBA denom** |
| **Ctct% / Whiff%** | `barrelsville/src/tracker_data.py` | Denom = swings. Whiff requires `did_swing = 1` gate |
| **ZCtct% / ZSw% / OSw%** | `barrelsville/src/tracker_data.py` | CSC-weighted (NOT binary). Uses `called_strike_chance_mlb` |
| **Chase%** | `barrelsville/src/tracker_data.py` | The ONE binary swing metric --- threshold is `csc < 0.01` |
| **Barrel% / Hard% / PullAir% / Dmg%** | `barrelsville/src/tracker_data.py` | Denom = `n_bip_tracked` (bunt + EV cap applied) |
| **Avg EV / Max EV** | `barrelsville/src/postgame_data.py::EV_MISREAD_CTE` | Misread filter applied; Max EV = true `MAX()` after cleaning |
| **InZ%** | `barrelsville/src/tracker_data.py` (pitcher view) | `AVG(called_strike_chance_mlb)` continuous --- never binary `csc > 0.5` |
| **zxwOBA** | `barrelsville/src/postgame_data.py` | Per-pitch wOBA-scale delta. Norm constant `_ZXWOBA_NORM_RANGE = 0.015` |
| **Bat speed at contact** | `barrelsville/src/bat_speed_clean.py::clean_bat_speed_per_player` | Canonical helper. 8 surfaces route through it. See Ch 6 |
| **Damage** (per BIP) | `pd-goals/src/metrics.py::calculate_damage_vectorized` | Logistic in EV + LA centered at (98, 27), -0.34 rad. See Ch 6 for cross-app rounding rule |

### Pitching metrics

| Metric | Canonical reference | Notes |
|---|---|---|
| **FPinZ%** | `bullpen-report/src/tracker_data.py` | First-pitch-in-zone (`balls_before=0 AND strikes_before=0`) |
| **R2K%** | `bullpen-report/src/tracker_data.py` + `pd-goals/src/org_kpi_data.py` | GC2 formula: `ab_pitch_number=3 AND strikes_after>=2`, gated by `(pa=0 OR so=1)`. Display 2 decimals |
| **K-BB%** (pitcher) | `bullpen-report/src/tracker_data.py` | `K% - BB%` subtraction |
| **gcERA** | `bullpen-report/src/tracker_data.py` | PA-weighted, global MLB HR rate, before-May fallback |
| **gcPerf** | `bullpen-report/src/postgame_data.py` | 6-result run-value sum, scaled to 20-80 |
| **Stuff+ / StuffRelVel / All / Component / Grade** | `Astros.Pitches_Grades` columns | All on 20-80 scale |
| **Loc Grade** | `bullpen-report/src/tracker_data.py` | `AVG(stuffrelvelloc - stuffrelvel)` |
| **FB Velo** | `bullpen-report/src/tracker_data.py` | `('FF','FT','SI')` --- SI included intentionally |
| **EW%** (Early Win) | `bullpen-report/src/pitcher_kpi_data.py` | `balls_before <= 1 AND strikes_before <= 1` (all 4 early counts), `rv_gain_given_hit_specs < 0` |
| **2K Proj** | `bullpen-report/src/pitcher_kpi_data.py` | Projection model, 2-strike count |
| **pBarrel** | Inline in many files | Always with bunt + EV cap |
| **Whiff%** | All apps | Whiffs / swings. WHIFF_CODES = `(10, 16, 21, 22, 23, 25)` |
| **Arm angle** | Brodie formula in `bullpen-report/src/postgame_data.py::get_arm_angle` | NOT a stored column --- computed from release point geometry |

### Fielding metrics (OF / IF / Catcher)

| Metric | Canonical reference | Notes |
|---|---|---|
| **OF/IF Tier 1 gate** | `intangibles/src/fielding_tracker_data.py` + `pd-goals/src/org_kpi_data.py` | 6-term OR. See Ch 6 |
| **TopSpd** | P95 with `top_speed <= 34` | Higher = better |
| **AccelCU / AccelCD** | P75 | Higher = better |
| **React** | P25 | Lower = better (faster reaction) |
| **UseReact** | OF only, P25 | Lower = better |
| **ReactRad / ReactAccRad** | P25 | Lower = better |
| **Arm** | OF: 60-100 P99; IF: 60-94 P99; C: 60-94 P99 | Higher = better |
| **Exchange** | P10 with `exchange >= 0.4 AND arm >= 60` | Lower = better (faster) |
| **OAA** | `SUM(out_made - out_prob)` | Statcast definition. Cumulative |
| **PAA / EO / RAA** | `pd-goals/src/org_kpi_data.py` + `intangibles/src/fielding_tracker_data.py` | Calibrated via `guts.PAA_EO_Position_Calibration`, keyed on `(pos_id, positional, season)`. **NO Tier 1/2/3 gate** --- summed across ALL DCBP rows for the fielder, so PAA can go against someone on plays they weren't the first defender on (see Ch 6). `positional` is a **tracking-completeness flag** (1 = fully HawkEye-tracked, 0 = `out_prob`-only); GC2 publishes a `_Tracked` variant restricted to `positional = 1` which we don't expose yet. Canonical displayed value = `paa_cal` (matches GC2's "PAA" exactly); `raw_paa = SUM(dcbp.paa)` is internal math plumbing only --- never display. See `.claude/rules/pd-goals-defense.md` "Calibration mechanics" for the full breakdown. |
| **NetK** (catcher) | `intangibles/src/catching_tracker_data.py` + `c_kpi_data.py` | `SUM(pv.net_k)` --- pre-computed column. Strict `> 0.05 AND < 0.95`, result_id `(4,5,6)`, `ignore_flag = 0` |
| **NetK/P** (catcher per-pitch rate) | `intangibles/src/catching_tracker_data.py` | `SUM(net_k) / COUNT(edge)` --- ONLY in affiliate tracker |
| **FramRAA** (catcher) | `intangibles/src/catching_tracker_data.py::_ORG_PITCHES_COMBINED_QUERY` | `(CS_indicator - CSC) * (rv_ball - rv_strike)` --- uses `called_strike_chance_mlb`, inclusive `BETWEEN 0.05 AND 0.95` |
| **BlockRAA** (catcher) | Computed in Python, `surpp * baserunner_advance_rv` (NEGATED) | `br_rv` must be negated --- pitching-team perspective |
| **SurPP** (catcher) | `intangibles/src/catching_tracker_data.py` | `SUM(passed_pitch) - SUM(pp_prob)` |
| **AugPop2B** (catcher) | P01 with `aug_pop IS NOT NULL` (NEVER AVG) | Accuracy-adjusted pop time |
| **Pop2B / Pop3B** (catcher) | P01 within 1.70-2.35 / 1.40-1.85 | Fastest throws |
| **Catcher framing buckets** | `intangibles/src/catching_tracker_data.py` | E Stl / Stl / Mid / Loss / B Loss --- CS rate per CSC zone |

### Baserunning metrics

| Metric | Canonical reference | Notes |
|---|---|---|
| **TopSpd / React / T22 / Split1 / AccelCD / AccelCU** (BR tracking) | `intangibles/src/br_tracker_data.py` | AVG of per-play values (not percentile) |
| **PL / SL / TL** (lead distances) | `intangibles/src/br_tracker_data.py` | PL = all leads (no `runner_going` filter). SL/TL filter `runner_going = 0`. 1B leads gate on `closest_fielder_distance <= 10` |
| **SB / CS counts** | `intangibles/src/br_tracker_data.py` + PD-Goals org KPI | `Events_View.event_result_id` (official scoring). NEVER `Events_StolenBases.success` |
| **SB%** | `100 * SB / (SB + CS)` --- pooled at org level | Apr 2026 addition. CS includes pickoffs (event_result_id 4,5,6,7,29,30,31) |
| **1→3 / 2→H** | `intangibles/src/br_tracker_data.py::_FT3_S2H_QUERY` | SINGLE-only (gates on `ev.[1b] = 1`). Doubles + triples don't count even when runner physically went 1→3 |
| **Bases On** | Times reaching base safely (denom for SB% / 1→3% / 2→H%) | Pool-weighted at org level |

### Performance science (Force Deck)

| Metric | What | Direction |
|---|---|---|
| **ConcPwrBM** | Concentric Power / BM (Twitch) | Correlated with sprint speed |
| **ConcImp100ms** | Concentric Impulse 100ms (Explode) | Strength + twitch composite |
| **ConcImp** | Concentric Impulse (Strength) | Correlated with exit velocity |
| **EccPwrBM** | Eccentric Power / BM (Brakes) | Force absorption |
| **TakeOffVelo** | Body speed when feet leave plate | Predicts impulse w/ added mass |
| **RSImod** | Time-in-air / time-on-ground | Strength coach use |

Strength × Twitch matrix (R&D framework):

|  | Low Twitch | High Twitch |
|---|---|---|
| **Low Strength** | Light & Slow | Light & Fast (speed, accel, bat speed) |
| **High Strength** | Strong & Slow (power) | Strong & Fast (power + bat speed, high velo) |

### Blast Motion (swing sensor)

Different system from HawkEye --- wearable bat-sensor data captured
in BOTH practice and in-game swings. Source: `BlastMotion.Metrics_View`.

| Metric | Raw unit | Conversion | Display unit | Direction |
|---|---|---|---|---|
| Bat Speed | m/s | × 2.23694 | mph | HiB |
| Peak Hand Speed | m/s | × 2.23694 | mph | HiB |
| Attack Angle | radians | × 180/π | degrees | Range 4-16° |
| Vertical Bat Angle | radians | × 180/π | degrees | Range |
| Rotational Acceleration | m/s² | ÷ 9.81 | g | --- |
| Time to Contact | seconds | --- | seconds | LiB |

Reference impl: `barrelsville/scripts/blast_report.py` and
`pages/4_Blast_Motion.py`.

::: blocking
**Always convert before display.** Raw DB values are metric/radians.
The `BENCHMARKS` dict in `blast_report.py` is in display units (mph,
degrees, etc.). Never compare raw to benchmark.
:::

## The Houston Astros GroundControl glossary

The following sections are the official metric glossary, transcribed
from `astros-docs/Astros Glossary.pdf`. Treat this as authoritative
for metric definitions; treat the codebase guide above as authoritative
for filters and source code locations.

### Hitter metrics

| Metric | Definition |
|---|---|
| **wOBA** | Weighted On Base Average --- weights derived by year, level, league |
| **wRC+** | Weighted Runs Created adjusted for league and park |
| **ORP-Bat** | Offensive Runs Produced --- Batting (650 PAs) |
| **DRS** | Defensive Runs Saved (includes replacement adjustment) |
| **ORP-BR** | Offensive Runs Produced --- Baserunning |
| **RAR** | Runs Above Replacement |

### Pitcher metrics

| Metric | Definition |
|---|---|
| **ERA** | Earned Run Average |
| **ERA-** | Earned Run Average Adjusted |
| **FIP** | Fielding Independent Pitching |
| **FIP-** | Fielding Independent Pitching Adjusted |
| **PRS** | Pitching Runs Saved |
| **RAR** | Runs Above Replacement |

### Swing / pitch result metrics

| Metric | Definition | Details |
|---|---|---|
| **Pit** | Number of pitches | |
| **InZ%** | Weighted In Zone % by called K chance | |
| **1stPZ%** | % First pitch strike by pitch type weighted by called K chance | |
| **0-1%** | % First pitch strike by pitch type | |
| **Sw%** | Swings / pitches seen | % Swing on all pitches |
| **Ctct%** | Pitches contacted / swings | Foul tips = whiffs, not contact |
| **ZSw%** | % Swing on pitches weighted by called K chance | |
| **OSw%** | % Swing on pitches outside zone | Outside zone = 1 − called K chance |
| **ZCtct%** | Pitches Contacted in Zone / Swings in Zone | Weighted by called K chance |
| **OCtct%** | Pitches Contacted Out of Zone / Swings Out of Zone | Weighted by inverse called K chance |
| **Chase%** | % Swing on pitches with called K chance < 0.01 | |
| **SwStr%** | % Swinging Strike (plus foul tips) on all pitches | |
| **Whiff%** | % Swinging Strike (plus foul tip) on swings | |
| **ZWhiff%** | % Swinging Strike on swings weighted by called K chance | |
| **RVBIP** | Run Value on Balls in Play | |
| **RVBIP(HS)** | Hit Specs Run Value on Balls in Play | Hitter-specific |
| **RVGain** | Avg Run Value Gain | Run scoring attributable to pitch outcome |
| **RVGain(HS)** | Avg Run Value Gain Given Hit Specs | Hitter-specific |
| **SwDec** | Avg Swing Decision Grade | |

### Pitch attributes

| Metric | Definition | Details |
|---|---|---|
| **Use%** | Usage percentage | |
| **AvgVelo** | Avg velocity at pitch release | |
| **MaxVelo** | 99th percentile velocity at release | |
| **Spin** | Avg Spin Rate (RPM) | |
| **Tilt** | Spin Axis translated to clock direction | |
| **RelZ** | Avg height above home plate at release (ft) | |
| **RelX** | Avg distance from center of rubber at release (ft) | + = right side, − = left side |
| **Ext** | Avg extension from rubber to release (ft) | |
| **VertBrk** | Avg induced vertical break (in) | vs. gravity-only trajectory |
| **HorzBrk** | Avg horizontal break (in) | + = right, − = left (pitcher's view) |
| **VertRelAngle** | Avg angle between ball and ground at release (deg) | + = upward, − = downward |
| **HorzRelAngle** | Avg angle between ball and line to home at release (deg) | |
| **VertAppAngle** | Avg approach angle at home plate (deg) | Flatter FF = more swing & miss |
| **HorzAppAngle** | Avg horizontal approach angle at home plate (deg) | |

### Pitch grades (20-80 scale)

| Metric | Definition | Components |
|---|---|---|
| **StuffRelVel** | RV gain prediction from movement, velo, release, extension | Throws, Bat side, Velo, Max Velo, Breaks, Release x/z, Extension |
| **StuffVel** | RV gain prediction from movement and velocity | Throws, Bat side, Velo, Max Velo, Breaks |
| **All** | RV gain prediction including location | StuffRelVel + Plate x/z |
| **Component** | RV gain prediction including count | All + Count |
| **Grade** | Full model with time through order | Most predictive pitch grade |
| **Exp CS%** | Expected Take weighted by called K chance | |
| **Exp SwStr%** | Expected Whiff Given Expected Swing | |
| **Exp Whiff%** | Expected Miss Weighted by Expected Swing | |
| **Exp Chase%** | Expected Swings on pitches with called K chance < 0.01 | |
| **SwingDec** | Avg Projected Swing Decision | |

### Quality of contact

| Metric | Definition | Details |
|---|---|---|
| **Track%** | % BBE with Out Probability | |
| **Avg** | Avg Exit Velo on BBE (no bunts) | Predictive of future hitter performance |
| **Max** | 99th percentile Exit Velo (no bunts) | |
| **Useful** | Avg Useful Exit Velo | Deviation from optimal 20° LA |
| **Hard%** | % BBE with Exit Velo ≥ 95 | |
| **Barrel%** | % BBE with EV ≥ 98 + LA in range | Formula: EV ≥ 98.0 + 0.07 × (LA − 28)² |
| **LA** | Avg Launch Angle (no bunts) | |
| **SDLA** | Std Dev Launch Angle | |
| **LA10-30** | % BBE with LA 10-30° | |
| **Spray** | Avg Hit Bearing | |
| **GB%** | Ground ball % (LA < ~10°) | |
| **LD%** | Line drive % (LA ~10-30°) | |
| **FB%** | Fly ball % (LA ~30-50°) | |
| **PO%** | Pop-up % (LA > ~50°) | |
| **Pull%** | % GB with bearing ≤ 15° (LHH) or −15° (RHH) | |
| **Str%** | % GB within ± 15° | |
| **Oppo%** | % GB with bearing ≥ 15° (RHH) or −15° (LHH) | |
| **xBABIP** | Expected BABIP from hit specs | |
| **xAVG** | Expected AVG from out probability | |
| **xOBP** | Expected OBP from hit specs | |
| **xSLG** | Expected SLG from hit specs | |
| **xwOBA** | Expected wOBA from hit specs | |

### Defense metrics

| Metric | Definition | Details |
|---|---|---|
| **EO** | Expected Outs | Sum of out probabilities by year/level/position |
| **PAA** | Plays Above Average | |
| **RAA** | Runs Above Average | |
| **PAA/EO** | Plays Above Average / Expected Outs | |
| **Comp Plays** | Competitive Plays | Hit probability 5-95% |
| **TopSpd** | Top Speed (95th percentile on outs) | High connection with OPA for SS |
| **AccelCD** | Acceleration Chest Down (75th percentile) | High connection with OPA for 3B |
| **AccelCU** | Acceleration Chest Up (75th percentile) | |
| **Split1** | 0-10 yard time (5th percentile) | |
| **TimeTo22** | Time to 22 ft/s (5th percentile) | |
| **React** | Reaction time to 4 mph (25th percentile) | High connection with OPA for SS/3B |
| **UseReact** | Useful Reaction (OF only) | Time to 4 mph toward ball |
| **ReactRad** | Reaction Radius | Time to travel 1 ft from start |
| **ReactAccRad** | Reaction Accuracy Radius | Extra distance outside 3 ft radius |
| **ReactDist** | Reaction Distance | Distance covered 0.6s (IF) or 2s (OF) after contact |
| **TimetoField** | Time to Field | Time to catch/field from contact |
| **FieldDist** | Distance to Field | Distance traveled from starting position |
| **ArmINF** | Max throw velocity (INF) | 99th percentile, 60-94 mph range |
| **ExchINF** | Exchange time (INF) | 10th percentile on 60+ mph throws |
| **ArmOF** | Max throw velocity (OF) | 99th percentile, 60-100 mph range |
| **ExchOF** | Exchange time (OF) | 10th percentile on 60+ mph throws |

### Catcher defense

| Metric | Definition |
|---|---|
| **NetK** | Total Strike Probability Added |
| **xPP** | Expected Passed Pitches |
| **Arm** | Max throw velocity on SBA (99th percentile) |
| **Exch** | Exchange time on SBA (10th percentile) |
| **Pop2B** | Pop time to 2B |
| **Pop3B** | Pop time to 3B |
| **Acc** | Arm Accuracy (20-80 scale) |
| **AdjNetK** | Adjusted Strike Probability Added (controls for pitcher/umpire) |
| **RAA - Framing** | Runs Above Average (Framing) |
| **RAA650 - Framing** | RAA prorated to 650 PAs (Framing) |
| **RAA - Blocking** | Runs Above Average (Blocking) |
| **RAA650 - Blocking** | RAA prorated to 650 PAs (Blocking) |

### Baserunning metrics

*All metrics summarized on "max effort" plays --- home to 1st without
rounding/decelerating, or SBA.*

| Metric | Definition |
|---|---|
| **Comp H21** | Number of max effort runs to first |
| **TopSpd** | Top Speed (95th percentile) |
| **MaxSpd** | Max Speed (99th percentile, ft/s) |
| **AccelCD** | Acceleration Chest Down (75th percentile) |
| **AccelCU** | Acceleration Chest Up (75th percentile) |
| **Split1** | 0-10 yard time (5th percentile) |
| **Timeto22** | Time to 22 ft/s (5th percentile) |
| **React** | Reaction time to 4 mph (25th percentile) |
| **ReactShort** | Time to run 5 ft (baserunner) or 3 ft (batter-runner) |
| **PrimHeld** | Distance from 1B at pitch release (fielder within 10 ft) |
| **Prim** | Distance from base at pitch release |
| **Sec** | Distance from base at contact |

### Performance Science (Force Deck)

| Metric | Definition | Details |
|---|---|---|
| **ConcPwrBM** | Concentric Power / Body Mass (Twitch) | Correlated with sprint speed |
| **ConcImp100ms** | Concentric Impulse 100ms (Explode) | First 100ms of impulse phase |
| **ConcImp** | Concentric Impulse (Strength) | Correlated with exit velocity |
| **EccPwrBM** | Eccentric Power / Body Mass (Brakes) | Force absorption efficiency |
| **TakeOffVelo** | Takeoff Velocity | Body speed when feet leave plate |
| **RSImod** | RSI-modified | Time in air / time on ground |

### Miscellaneous

| Metric | Definition |
|---|---|
| **Framable** | Pitch with 5-95% chance of being called a strike |
| **Weak Contact** | BBE with expected RV < 0 |

## Key formulas (selected)

### gcERA

```
gcERA = ((3.9 + 31.1*hr_rate) * bip * pbarrel_rate
       + 3.5 * bip * (1 - pbarrel_rate)
       - 3.3 * SO
       + 9.9 * (BB + HBP))
       / TBF
```

### pBarrel

```
pBarrel = 1  if  hit_exit_speed >= 0.011 * la^2 - 0.91 * la + 95.0
       else 0
```

### MLB Barrel (linear)

```
Barrel = 1  if  hit_exit_speed * 1.5 - hit_vertical_angle >= 117
              AND (hit_exit_speed + hit_vertical_angle) >= 124
              AND hit_exit_speed >= 98
              AND hit_vertical_angle BETWEEN 4 AND 50
       else 0
```

### Damage (Astros internal)

```python
exp_term = (cos(-0.34) * (ev - 98.0)
          - sin(-0.34) * (la - 27.0)
          - 0.02 * (2 + sin(-0.34) * (ev - 98.0) + cos(-0.34) * (la - 27.0))**2)
damage = 1.6 * (1.3 ** exp_term) / (7.0 + 1.3 ** exp_term)
```

### gcOBA

```
gcOBA = MLB_OBP * (
    0.50 * K_rate
    + 1.49 * BB_HBP_rate
    + 0.11 * zero_whiff_pct
    + 0.08 * one_whiff_pct
    + (-0.10) * two_whiff_pct
    + (-0.10) * three_plus_whiff_pct
    + BIP_rate * (1.70 * barrel_rate + 1.09 * avg_useful_ev / 100)
)
```

### gcPerf (per-pitch run-value sum, scaled to 20-80)

```
gcPerf = 50.0 - 1500.0 * AVG(per-pitch RV)

per-pitch RV table:
  In-Heart whiff   = -0.10
  Out-Heart whiff  = -0.08
  Called Strike    = -0.02
  Ball + HBP       = +0.02
  pBarrel BBE      = +0.09
  non-pBarrel BBE  = -0.02
  Other            =  0.0
```

## Where to look next

- **Chapter 6** for the data cleaning canon --- what each metric
  filters out and why.
- **Chapter 11** for three-surface parity --- when a metric is computed
  in multiple places, how to keep them in sync.
- `astros-docs/Astros Glossary.pdf` --- the official PDF glossary
  (also at `docs/handbook/assets/astros-glossary.pdf`).
- `astros-docs/AR-gcERA-260923-213026.pdf`, `AR-gcPerf-100923-184838.pdf`
  --- R&D papers with the formal derivations.
- `.claude/rules/gc2-metrics.md` --- the canonical metric rule file.
- `.claude/rules/reference-impl-index.md` --- file-pointer index for
  every metric.
