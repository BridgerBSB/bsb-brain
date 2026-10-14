---
title: "MLB Stats API context (Cael, Oct 2026)"
date: 2026-10-12
tags: [mlb-stats-api, reference, cael, parked]
---

# MLB Stats API context (Cael, Oct 2026)

**What it is:** Cael's end-to-end read of his `mlb-statsapi/context/` folder (endpoints, the 155-metric catalog, MLB's "Raw and Parsed Data Spec" PDF, and the 2018 C++ Metrics Engine source), written as a reference for the Mazzo OF + BR wishlist work.

**Status: parked - revisit after Mazzo item 6** (steal times + matchup cards are the current target). Zac's framing: another holistic, all-branch thing to take into account.

Two parts: Part A is project-agnostic (endpoints, auth, catalog, payload, engine). Part B is scoped to the outfield jump project ([[mazzo-of-br-wishlist-2026-10]] item 2a "Launch").

## Summary

### Endpoints (host `https://statsapi.mlb.com`)
- `GET /api/v1/game/{gamePk}/{playId}/analytics/raw` - full raw tracking payload for ONE play, driven by `GET /api/v1/game/{gamePk}/guids` (the play GUID index). One request per play, ~300 per game.
- `GET /api/v1.1/game/{gamePk}/feed/live`, `/api/v1/game/{gamePk}/boxscore`, `/api/v1/people/{mlbId}` - lineup, position and bio resolution.
- `POST /api/v1/authentication/okta/token/refresh` - access token from a refresh token.
- URLs come from a 2018 engine snapshot: "what the kernel called", not a current contract. The spec implies an `analytics/parsed` sibling, but that literal path appears nowhere in the context.
- Parsed metrics arrive as hydrations, not endpoints: `analytics(metrics)` (IDs 1000-1176, per play, per player) and `analytics(contextMetrics)` (17001-17012, modeled values). Each metric row carries type_id, name, unit, value, value_unrounded, target_id (position), target_mlb_id, play_id, game_primary_key, time (frame), support_level, mlb_kernel_version.

### Auth and rate limits
- Current auth (from Cael's repo code, not the context docs): Okta refresh token -> Bearer header (`MLB_REFRESH_TOKEN` env var). The 2018 engine used HTTP Basic (`STATSAPI_USER` / `STATSAPI_PASS` env vars). The doc names env vars only; it contains no credential values.
- **Entitlement is separate from auth:** an authorized account without metrics entitlement gets NO metric array and no error. A client has to tell "no metrics on this play" apart from "not entitled".
- **No rate limit is documented anywhere** (no 429 / Retry-After / throttle hit across 522 files). The engine had no backoff or retry. Pacing is ours to design.

### What data it exposes
- **Metric catalog: 155 IDs** = 128 Production, 13 Deprecated, 8 Legacy, 6 Development. Pitching 38, Batting 50, Baserunning 28, Fielding 39.
- **Context metrics (17xxx, modeled, none computed by the engine):** 17001 Catch Probability, 17002 Hit Probability, 17003 Intended Pitch Location (Legacy, catcher mitt at release), 17004 HR in X Ballparks, **17005 Jump (OF, feet vs league average for the given play)**, 17006 xSLG, 17007 xwOBA, 17008 OAA (Dev), 17009 Fielding Runs Prevented (Dev), **17010 Stolen Base Probability (Dev, from lead distance + pitcher average release time)**, 17011 WPA (Dev), 17012 Sac Fly Probability (Dev).
- **Raw payload:** `mergedPositionalData` (per-frame XY of every tracked object), `gameEvent` (count / outs / runners, pre and post pitch), `ballPositionalData` (pitch release, spin, trajectory; hit launch and landing; 8th-order hit polynomials; measured vs estimated ball positions), `playEvents` (event type + timeCode). `ReducedConfidence` arrays flag fields that are estimates.
- **Lookups:** data source codes (2 Hawk-Eye, 3 TrackMan, 4 ChyronHego, ...), position IDs (7 LF / 8 CF / 9 RF, 11-13 runners on 1st/2nd/3rd), shift classifications, 31 fielding zones, IF/OF out-of-position bitmasks.
- **Engine:** 111 statistic classes, 32 ordered quality filters, hard-coded 29.97 fps, fence geometry for the 30 MLB parks only (2018-era names, no MiLB parks).

### Gotchas
- **Two event-code schemes:** API `playEventType` vs the engine's internal codes. Do not cross-map.
- **`typ` disagrees:** the spec says 1 players / 2 umpires / 3 coaches; the parser treats 1 home / 2 away. Verify on a live payload before filtering.
- **Two clocks:** fielder frames are absolute UTC; ball and event data are seconds from pitch release. Any fielder-vs-ball metric has to bridge them first.
- **Sample rate is undocumented**; the engine's 29.97 fps assumption is admittedly stale (Hawk-Eye). Measure the real cadence on a live payload.
- **Y sign:** documented "In = Negative", but the spec's own examples are positive going out. Trust the examples. Origin = back tip of home plate; units are feet.
- **No fielder z:** z is ball-only. No vertical leap or hop height is measurable; "jump" here can only mean ground covered.
- **1142 Fielder Jump Distance is straight-line displacement 0-3 s from release** with no direction term, so it is NOT Savant's Jump. 1128 Reaction = path 0-1.5 s, 1127 Burst = path 1.5-3 s, 1129 Routing = path minus straight line (higher is worse). These are release-anchored; 1023 / 1077 and the deprecated 1007 / 1011 / 1021 / 1022 are contact-anchored, so the two families are not comparable.
- Fielder speeds are always finite differences of smoothed positions (measured speed is never used); the `qi` quality indicator is never read; a last-interval double-count adds ~0.7 ft per window.
- Burst-family population: the fielder who made the play, plus others within 30 ft of the projected landing point. Infield balls drop every non-catching fielder; catchers and pitchers are near-absent.
- **Level coverage (MLB vs MiLB) is NOT answerable from the docs.** It is the gate for running any of this on affiliates.
- Doc defects: `API_Depreciated_Metric_Replacements.csv` is a copy of the source-values CSV (the deprecation replacement map is missing); 61 of 216 rows in `API_Metrics.csv` are conversion debris (filter on numeric ID); 1019 Positioning cannot compute (empty heat-map file); six engine reference CSVs are absent.
- Deprecations are announced 6+ months ahead and removed around Feb 1.

## Where it could plug in (only where the doc supports it)
- **Intangibles / OF, Mazzo item 2a "Launch":** Part B is written for this. A Savant-style directional Jump has to be REBUILT from `mergedPositionalData` + the ball's projected landing point (1097 / hit polynomials); 1142 is not it, and 17005 is opaque and league-relative. 17001 Catch Probability is the natural benchmark.
- **Intangibles / OF, item 2b pre-pitch hop:** the feed carries no fielder z, so hop height is not in this data; only XY movement timing is.
- **Intangibles / OF, item 3 directional tracker:** the doc states no "correct direction" primitive is published per play; it has to be built from the fielder path joined to the ball trajectory (same clock bridge as above).
- **Intangibles / BR, item 6 steal times + matchup cards:** catalog has 1009 Lead Distance, 1010 Secondary Lead Distance, 1020 First Step (stealing), 1040-1042 Base Steal Time (1->2, 2->3, 3->H), 1035-1037 Time to Next Base, 1006 Pitcher Release (s), 1026 Pop Time and 1024 Exchange (C), plus 17010 Stolen Base Probability (Development). MiLB coverage unknown.
- **Intangibles / catcher:** 1026 Pop Time, 1024 Exchange, 1025 Pick-Off Steal Exchange, 1038 Throw Distance.
- **Arm Farm:** 38 pitching IDs (incl. 1172 Pitcher Arm Angle, 1006 Pitcher Release, inferred backspin / sidespin / gyrospin). The doc proposes no Arm Farm use.
- **Barrelsville:** batting IDs incl. 1162 Attack Angle, 1163 Bat Speed, 1166 Distance from Sweet Spot, 1169 Sword, 1173-1176 batter depth / distance off plate / stance, 17006 / 17007 xSLG / xwOBA. The doc proposes no Barrelsville use.
- **PD Engine:** nothing in the doc maps to it.
- Also: 17003 Intended Pitch Location (catcher mitt at release, Legacy) is relevant to [[command-cv-status]].

## Overlap with what we already had
- [[mlb-stats-api-exploration]] (May 14 memory snapshot) and its design doc [[2026-05-14-mlb-stats-api-exploration]]: public endpoints keyless with CORS `*`, live feed works for MLB and MiLB, sportId map (1 mlb, 11 aaa, 12 aax, 13 afa, 14 afx, 16 rok; DSL has no sportId), OpenAPI spec at `docs.statsapi.mlb.com/openapi.json` (178 paths), Umpire tab served from `MLBAM.PBP_PreGame` with no API. That work covered the PUBLIC feed; Cael's doc covers the AUTHED tracking / analytics layer the May notes never touched.
- The May OpenAPI pull listed `/contextMetrics`, `/winProbability`, `/batTracking/...`, `/analytics/biomechanics/...`, `/analytics/skeletalData/chunked`. That spec is where to check Cael's open question about an `analytics/parsed` path.
- [[2026-07-03]] daily: Zac's Okta login unlocked the authed API (Bearer for the analytics endpoint, token expires hourly), consistent with Cael's Okta refresh-token picture. Same day, the authed analytics payload supplied plate_x/z for A+ (Asheville) games: a hint about pitch data at A+, NOT evidence that fielder `mergedPositionalData` exists at MiLB.
- [[savant-fielding-visuals-research]] and the Savant Jump capture inside [[mazzo-of-br-wishlist-2026-10]] give the public Jump / Reaction / Burst / Route definitions to compare against 1127 / 1128 / 1129 / 1142.
- [[owner-pd-deck-mlb-value-research]] also references statsapi.mlb.com.

## Source
- Local file: `C:\Users\zbrid\Downloads\CONTEXT_SUMMARY.md` (52 KB, 578 lines), written by Cael, captured 2026-10-12.
- Underlying material (Cael's repo, not in our worktrees): `mlb-statsapi/context/` (API_Metric_Context CSVs + metric-IDs md, `API_Tracking_Data/raw-and-parsed-tracking-spec.pdf` rev 04/02/2024, `Metrics Engine Code/` 522-file C++ tree at MLB kernel 1.37), plus `R/auth.R` and `R/api.R`.

## Original (verbatim)

_Full original below. Only change: em and en dashes normalized to plain hyphens (vault no-dash rule). The untouched file remains at the source path above._

# MLB Stats API - Context Reference

Everything in `mlb-statsapi/context/`, read end to end on 2026-10-12.

- **Part A** is a project-agnostic reference to the whole context folder - endpoints, feeds, the full metric catalog, auth, rate limits, the payload spec, and the Metrics Engine architecture.
- **Part B** is scoped to the outfield jump project - fielder/ball tracking fields, sample rate, coordinates, level coverage, how the engine computes fielder movement and reaction, and gaps.

**Sources**
| Path (under `context/`) | What it is |
|---|---|
| `API_Metric_Context/MLB Stats API Metric IDs.md` | Curated metric-ID reference, with an app-usage and "worth adding later" list |
| `API_Metric_Context/API_CSV_Context/` | 10 CSVs: metric catalog, context metrics, support levels, source values, shift classifications, fielding zones, IF/OF out-of-position codes, event-based gameplay |
| `API_Tracking_Data/raw-and-parsed-tracking-spec.pdf` | 27-page MLB "Raw and Parsed Data Spec", rev. 04/02/2024 |
| `API_Tracking_Data/Metrics Engine Code/` | 522-file C++ source tree - the "mlb-kernel" that computes the parsed metrics. MLB © 2018, `MLB_KERNEL_VERSION "1.37"` |
| `Stats_API_Metrics.zip` | Archive of the same tree (gitignored, kept on disk) |

**Citation shorthand** - `ENGINE/` = `context/API_Tracking_Data/Metrics Engine Code/bdt-blackbox/`, `SHARED/` = `.../Metrics Engine Code/shared/`

---
---

# Part A - Project-agnostic reference

## A1. Endpoints

The spec PDF describes *payload shapes* and never gives a URL. Every URL below comes from the engine source, a 2018-era snapshot - treat these as "what the kernel called", not as a current contract.

| Endpoint | Returns | Cited at |
|---|---|---|
| `GET /api/v1/game/{gamePk}/{playId}/analytics/raw` | Full raw tracking payload for **one play** - see A6 for the structure | `ENGINE/io/StatCastServer.cpp:296-300` |
| `GET /api/v1/game/{gamePk}/guids` | Play GUIDs for a game - the index you iterate to drive per-play `analytics/raw` calls | `ENGINE/io/StatCastServer.cpp:305-309` |
| `GET /api/v1.1/game/{gamePk}/feed/live` | Full live game feed; kernel uses it for lineup/player resolution | `ENGINE/io/StatCastServer.cpp:347`, `ENGINE/io/PlayerIo.cpp:93` |
| `GET /api/v1/game/{gamePk}/boxscore` | Boxscore, for player/position resolution | `ENGINE/io/PlayerIo.cpp:83` |
| `GET /api/v1/people/{mlbId}` | Player biographical lookup | `ENGINE/io/PlayerIo.cpp:103` |
| `POST /api/v1/authentication/okta/token/refresh` | Access token from a refresh token (see A3) | `R/auth.R:1` (repo, not context) |
| `https://research.mlb.com/games/{gamePk}/plays/{playId}` | Human-facing play page the kernel stamps into DB rows for QA - not a data feed | `ENGINE/database/StatisticDatabaseFacade.cpp:647` |
| `http://gd2.mlb.com/components/game/{league}/year_YYYY/month_MM/day_DD/gid_.../inning/inning_all.xml` | Legacy Gameday XML, superseded; fallback path only | `ENGINE/io/GamedayServer.cpp` |

Host is `https://statsapi.mlb.com` throughout. A `parsed` sibling to `analytics/raw` is implied by the spec's own table of contents (§2 "Parsed Tracking Data → Measurements"), but **the literal `analytics/parsed` path appears nowhere in the context** - the kernel's commented-out builder at `ENGINE/database/StatisticDatabaseFacade.cpp:1149` only ever shows `/analytics/raw`. Confirm against live docs.

## A2. Hydrations and the metric envelope

Parsed metrics arrive as *hydrations* on game/play responses, not as their own endpoints:

| Hydration | ID range | Contents |
|---|---|---|
| `analytics(metrics)` | `1000`-`1176` | Per-play, per-player measured metrics - 155 defined (A4) |
| `analytics(contextMetrics)` | `17001`-`17012` | Modeled/probabilistic values (A5) |

Each metric row (`Measurements: statistics`, spec p. 23) carries: `type_id`, `name`, `description`, `category`, `unit`, `value`, `value_unrounded`, `target_id` (position 1-9 etc.), `target_mlb_id`, `play_id`, `game_primary_key`, `time` (frame count), `support_level`, `mlb_kernel_version`.

Sibling measurement nodes: `Measurements: diagram` returns an SVG of the play (`ENGINE/io/PlayDiagramIo.cpp:134`, a 250×250 viewBox). `Measurements: event_based_gameplay` returned per-event player position arrays but was **removed after 2019** (spec p. 22) - do not design against it.

## A3. Auth

Two inconsistent pictures, neither a current spec:

- **Engine (2018):** HTTP Basic via libcurl `CURLOPT_USERPWD` from `user:password`, sourced from `STATSAPI_USER` / `STATSAPI_PASS` env vars - `ENGINE/io/StatCastServer.cpp:105,125,178,237,349`, plumbed through `SHARED/source/FileHelper.cpp:231`.
- **This repo today:** Okta refresh-token → Bearer. `R/auth.R:1` posts to `/api/v1/authentication/okta/token/refresh` with `MLB_REFRESH_TOKEN`; `R/api.R:6` sends `Authorization: Bearer <token>`. (Outside `context/`; noted because the context's answer is stale.)

**Entitlement is separate from authentication.** `MLB Stats API Metric IDs.md` warns that metrics data "is not available to all users" and that an account without it "returns no metric array at all" - an authorized request can come back with no metrics and no error. Clients must distinguish "no metrics on this play" from "not entitled".

## A4. Rate limits

**Nothing in `context/` states one.** A scan for rate-limit, throttle, `429`, and `Retry-After` across all 522 files returns no hits. The engine has no backoff, no retry, and no pacing; the only knob is a timeout argument on `GetUrlAsString` (used once, 8 s, `ENGINE/io/StatCastServer.cpp:349`). Since per-play `analytics/raw` means one request per play (~300/game), assume you must design pacing yourself.

## A5. Metric catalog - all 155 IDs

From `API_Metrics.csv`. Counts by support level: **128 Production, 13 Deprecated, 8 Legacy, 6 Development.** Filter the CSV on numeric `ID` - 61 of its 216 rows are conversion debris (A9).

### Pitching (38)

| ID | Metric | Unit | Support |
|---|---|---|---|
| 1000 | Spin Rate | RPM | Production |
| 1001 | Extension | Feet | Production |
| 1002 | Regular Speed | MPH | Production |
| 1006 | Pitcher Release | Seconds | Production |
| 1028 | Perceived Pitch Velocity | MPH | Production |
| 1043 | Pitching Position | String | Production |
| 1047 | Release Backspin Rate | RPM | Deprecated |
| 1048 | Release Sidespin Rate | RPM | Deprecated |
| 1064 | Gyrospin Rate | RPM | Deprecated |
| 1065 | Spin Angle | Degrees | Production |
| 1094 | Plate Time (_y0) | Seconds | Production |
| 1095 | Plate Time (_y17) | Seconds | Production |
| 1096 | Plate Time (_yi) | Seconds | Production |
| 1098 | Distance to Catcher's Mitt | Feet | Legacy |
| 1100 | Vertical Break | Feet | Production |
| 1101 | Vertical Break Induced | Feet | Production |
| 1102 | Horizontal Break | Feet | Production |
| 1109 | Plate Speed | MPH | Production |
| 1110 | Pitch Launch Direction | Degrees | Production |
| 1111 | Pitch Launch Angle | Degrees | Production |
| 1120 | Revolutions Hand To Plate | Revolutions | Production |
| 1121 | Inferred Backspin Rate | RPM | Production |
| 1122 | Inferred Sidespin Rate | RPM | Production |
| 1123 | Inferred Gyrospin Rate | RPM | Production |
| 1126 | Relative Strike Zone Location | Inches | Production |
| 1132 | Relative Strike Zone Location X | Pct (%) | Production |
| 1133 | Relative Strike Zone Location Z | Pct (%) | Production |
| 1134 | Attack Zones | Category | Production |
| 1145 | Spin Rate Per MPH | RPM/MPH | Development |
| 1146 | Gameday Zone | Number | Development |
| 1147 | Plate Location X | Feet | Production |
| 1148 | Plate Location Z | Feet | Production |
| 1150 | Active Spin Angle | Degrees | Production |
| 1151 | Backspin | RPM | Production |
| 1152 | Sidespin | RPM | Production |
| 1153 | Gyrospin | RPM | Production |
| 1165 | Pitcher Biomechanics | Boolean | Production |
| 1172 | Pitcher Arm Angle | Degrees | Production |

### Batting (50)

| ID | Metric | Unit | Support |
|---|---|---|---|
| 1003 | Exit Velocity | MPH | Production |
| 1004 | Launch Vector | String | Production |
| 1005 | Launch Angle | Degrees | Production |
| 1027 | Hang Time | Seconds | Production |
| 1029 | Home Run Trot | Seconds | Production |
| 1030 | Hit Distance | Feet | Production |
| 1031 | Projected Hit Distance | Feet | Production |
| 1033 | Hit Type | String | Production |
| 1039 | Max Height | Feet | Production |
| 1044 | Estimated Generated Velocity | MPH | Legacy |
| 1045 | Estimated Swing Speed | MPH | Legacy |
| 1049 | Hit Travel Time | Seconds | Production |
| 1050 | Hit Travel Distance | Feet | Production |
| 1063 | Hit Spin Rate | RPM | Production |
| 1066 | Hit Spin Angle | Degrees | Production |
| 1074 | Hit Distance At 8 Feet | Feet | Deprecated |
| 1075 | Hang Time At 8 Feet | Seconds | Deprecated |
| 1076 | Barreled Ball | String | Production |
| 1079 | Hit Trajectory | JSON | Production |
| 1084 | Spin Axis Octants | String | Production |
| 1087-1090 | Batted Ball Travel Time (_z0/_z8/_zi/_zf) | Seconds | Production |
| 1091-1093 | Opportunity Time (_z0/_z8/_zi) | Seconds | Production |
| 1097 | Projected Landing Position | JSON | Production |
| 1103-1106 | Batted Ball Travel Distance (_z0/_z8/_zi/_zf) | Feet | Production |
| 1112 | Hit Launch Direction | Degrees | Production |
| 1113 | Ball Height at the Fence | Feet | Production |
| 1114 | Projected Distance of Ball From Fence | Feet | Production |
| 1117 | Wall Ball Classification | Category | Legacy |
| 1139 | Hit Tracking Percentage | Pct (%) | Production |
| 1144 | Ball Location At 300 Feet | JSON | Development |
| 1149 | Hit Landing Bearing | Degrees | Production |
| 1162 | Attack Angle | Degrees | Production |
| 1163 | Bat Speed | MPH | Production |
| 1164 | Batter Biomechanics | Boolean | Production |
| 1166 | Distance from Sweet Spot | Inches | Production |
| 1169 | Sword | Boolean | Production |
| 1170 | Swing Length | Feet | Development |
| 1171 | Squared-Up Percentage | Pct (%) | Development |
| 1173 | Batter Depth in Box | Inches | Production |
| 1174 | Batter Distance Off Plate | Inches | Production |
| 1175 | Batter Distance Between Feet | Inches | Production |
| 1176 | Batter Stance Angle | Degrees | Production |

The `_z0`/`_z8`/`_zi`/`_zf` suffixes are trajectory reference heights (ground, 8 ft, initial, final); `_y0`/`_y17`/`_yi` on Plate Time are the analogous pitch-side reference planes.

### Baserunning (28 - 25 categorised plus the 3 tag-up rows the CSV leaves blank)

| ID | Metric | Unit | Support |
|---|---|---|---|
| 1007 | First step | Seconds | Deprecated |
| 1008 | Top Speed | MPH | Deprecated |
| 1009 | Lead Distance | Feet | Production |
| 1010 | Secondary Lead Distance | Feet | Production |
| 1011 | Acceleration | Seconds | Deprecated |
| 1012 | Home to First | Seconds | Production |
| 1013-1017 | Extra Bases (H→2nd, H→3rd, 1st→3rd, 1st→H, 2nd→H) | Seconds | Production |
| 1020 | First step (stealing) | Seconds | Production |
| 1035-1037 | Time to Next Base (1→2, 2→3, 3→H) | Seconds | Production |
| 1040-1042 | Base Steal Time (1→2, 2→3, 3→H) | Seconds | Production |
| 1055-1057 | Time to Next Base on Tag Ups (1→2, 2→3, 3→H) | Seconds | Production |
| 1058 | First Step on Tag Ups | Seconds | Legacy |
| 1071 | Distance from Base on Throw | Feet | Production |
| 1083 | Baserunner Markers | JSON | Production |
| 1085 | Speed in the Last Seconds | JSON | Production |
| 1115 | Time out of Batters Box | Seconds | Production |
| 1118 | Key Step | Seconds | Production |
| 1119 | Burst | Feet | Production |

`1118` Key Step = time to cover the first 3 ft toward first. `1119` Burst = distance covered in the 1.5 s after those first 3 ft. Note these are the *batter-runner* analogues of the fielder family below, and they are time/distance-defined differently.

### Fielding (39)

| ID | Metric | Scope | Unit | Support |
|---|---|---|---|---|
| 1018 | Arm Strength | Fielding | MPH | Production |
| 1019 | Positioning | Fielding | - | Development |
| 1021 | First Step Efficiency | IF/OF | Degrees | Deprecated |
| 1022 | Route Efficiency | Fielding | Percentage | Deprecated |
| 1023 | Distance Covered | Fielding | Feet | Production |
| 1024 | Exchange | Fielding | Seconds | Production |
| 1025 | Pick-Off Steal Exchange | C | Seconds | Production |
| 1026 | Pop Time | C | Seconds | Production |
| 1032 | Top Acceleration | Fielding | m/s² | Deprecated |
| 1034 | Throwing Accuracy | IF/OF | Feet | Legacy |
| 1038 | Throw Distance | C/P/IF/OF | Feet | Production |
| 1046 | Throw-fielder Angle | Fielding | Degrees | Deprecated |
| 1051 | Distance from Ball Landing | OF | Feet | Production |
| 1052 | Projected Distance from Ball Landing | IF/OF | Feet | Production |
| 1053 | Angle to where the Ball Landed | OF | Degrees | Production |
| 1054 | Angle to where the Ball was Caught | OF | Degrees | Production |
| 1059 | Start Player Position | Fielding | Feet | Production |
| 1060 | End Player Position | Fielding | Feet | Legacy |
| 1061 | Start Player Angle | Fielding | Degrees | Production |
| 1062 | End Player Angle | Fielding | Degrees | Legacy |
| 1067 | Shift Classification | IF/OF | String | Production |
| 1068 | Fielding Zone | IF/OF | String | Production |
| 1069 | Infielder Out-of-position Code | IF | String | Production |
| 1070 | Outfielder Out-of-position Code | OF | String | Production |
| 1077 | Distance Covered Breakdown | OF | JSON | Production |
| 1078 | Outfielder Distance to Fence | OF | Feet | Production |
| 1080 | Projected Distance From Ball Crossing Fence | OF | Feet | Production |
| 1081 | Sprint Speed | Fielding | ft/s | Production |
| 1082 | Startup Time | IF/OF | Seconds | Production |
| 1086 | Total Distance Covered | Fielding | Feet | Production |
| 1099 | Route to Sprint Speed | Fielding | Degrees | Production |
| 1108 | Exchange Distance | Fielding | Feet | Production |
| 1116 | Fielder Engagement | IF/OF | Seconds | Deprecated |
| 1127 | Fielder Burst Distance | Fielding | Feet | Production |
| 1128 | Fielder Reaction Distance | Fielding | Feet | Production |
| 1129 | Fielder Routing Distance | Fielding | Feet | Production |
| 1137 | Throw Distance with Bounces | Fielding | Feet | Production |
| 1138 | Intercept Batted Ball | Fielding | Category | Production |
| 1142 | Fielder Jump Distance | Fielding | Feet | Production |

### Retired

Deprecated: `1007` `1008` `1011` `1021` `1022` `1032` `1046` `1047` `1048` `1064` `1074` `1075` `1116`.
Legacy: `1034` `1044` `1045` `1058` `1060` `1062` `1098` `1117`.
Development: `1019` `1144` `1145` `1146` `1170` `1171`.

## A6. Context metrics (17xxx)

From `API_Context_Metrics.csv` - modeled values, a separate hydration, none of them computed by the engine in this tree.

| ID | Metric | Category | Unit | Support | Definition |
|---|---|---|---|---|---|
| 17001 | Catch Probability | Fielding (OF) | Pct | Production | Likelihood a batted ball to the outfield is caught |
| 17002 | Hit Probability | Batting | Pct | Production | Likelihood a batted ball is a hit |
| 17003 | Intended Pitch Location | Pitching | Feet | Legacy | Catcher's mitt position at release ≈ catcher centre-of-mass + 2 ft in +y and +z |
| 17004 | Home Run in X Ballparks | Batting | Number | Production | Count of parks where this ball would be a HR |
| 17005 | **Jump** | Fielding (OF) | Feet | Production | Fielder's jump distance **relative to the league average for the given play** |
| 17006 | Expected Slugging | Batting | Pct | Production | Total bases from EV, LA, and on some balls Sprint Speed |
| 17007 | Expected wOBA | Batting | Pct | Production | wOBA from the same inputs |
| 17008 | Outs Above Average | Fielding | Number | Development | Outs credited/debited vs. expected out probability (60% play: +0.4 for the out, −0.6 for the miss) |
| 17009 | Fielding Runs Prevented | Fielding | Number | Development | OAA converted to runs, position-adjusted |
| 17010 | Stolen Base Probability | Baserunning | Pct | Development | From runner lead distance and pitcher average release time |
| 17011 | Win Probability Added | Batting | Pct | Development | Win-probability change event to event |
| 17012 | Sac Fly Probability | Fielding | JSON | Development | Inner/outer distance ranges where a fielder can throw out a runner scoring from third |

## A7. Support levels

From `API_Support_Levels.csv`, verbatim intent:

| Level | Meaning |
|---|---|
| **Development** | Not vetted for completeness or accuracy; not recommended for consumer use |
| **Beta** | Initial vetting done, intended for eventual production; may not be validated or backfilled, may be removed at any time |
| **Production** | Validated, backfilled, announced via the Research Blog with documentation; full support |
| **Legacy** | Fully supported but may not meet current scientific/statistical rigor; use with caution, may be deprecated later |
| **Deprecated** | No longer valid, slated for removal. Announced via Research Blog with **≥6 months lead time**; removals happen in the offseason, **on or around February 1**; fully supported during the window |

## A8. Lookup tables and enums

**Data source** (`API_Source_Values.csv`, mirrored in `ENGINE/DataSourceType.h:50-57`) - `2` Hawk-Eye, `3` TrackMan, `4` ChyronHego, `5` TrackMan+ChyronHego, `6` TrackMan+ChyronHego filtered, `7` computational model, `8` stringer, `9` unknown.

**Position identifiers** (spec p. 25) - `0` unknown, `1` P, `2` C, `3` 1B, `4` 2B, `5` 3B, `6` SS, `7` LF, `8` CF, `9` RF, `10` batter, `11`/`12`/`13` runner on 1st/2nd/3rd at start of play, `14`-`17` HP/1B/2B/3B umpires, `18`/`19` 1B/3B coach, `20`/`21` LF/RF foul-line umpires, `1001` ball, `1002`-`1009` manager/batting-pitching-bench-bullpen coach/bullpen catcher/coach/special assistant, `1010`/`1011` home/away team.

**`playEventType`** (spec p. 24) - `0` BEGIN_OF_PLAY, `1` PITCHER_GOING_TO_WINDUP, `2` BALL_WAS_PITCHED, `3` BALL_WAS_HIT, `4` BALL_WAS_CAUGHT, `5` BALL_WAS_CAUGHT_OUT, `6` BALL_WAS_RELEASED, `7` BALL_WAS_DEFLECTED, `8` TAG_WAS_APPLIED, `9` PICK_OFF_BALL_RELEASED, `10` END_OF_PLAY, `11` REMOVED, `12` BALL_WAS_RELEASED, `13` BALL_WAS_DEFLECTED, `14` BALL_WAS_CATCHER_RELEASED, `15` PICK_OFF_BALL_RELEASED, `16` BALL_BOUNCE, `17` BALL_WAS_FIELDED. (Codes 6/12 and 7/13 and 9/15 are duplicated labels in the published list.)

**Engine's internal event codes are different** (`ENGINE/MlbGameplayEventType.h`) - `1` BALL_WAS_PITCHED, `2` BALL_WAS_CAUGHT, `3` BALL_WAS_RELEASED, `4` BALL_WAS_HIT, `5` END_OF_PLAY, `9` BALL_WAS_DEFLECTED, `10`-`13` RUNNER_REACHED_1ST/2ND/3RD/HOME, `14` PITCHER_FIRST_MOVEMENT, `15` TAG_WAS_APPLIED, `16` PLAYER_TOP_SPEED, `17` BEGIN_OF_PLAY, `18` PLAYER_SECONDARY_LEAD_DISTANCE, `19` BALL_BOUNCE, `23` OFF_THE_WALL. **Do not cross-map the two numbering schemes.** `PITCHER_FIRST_MOVEMENT`, `PLAYER_TOP_SPEED`, `PLAYER_SECONDARY_LEAD_DISTANCE` and `OFF_THE_WALL` are engine-derived and have no API `playEventType` equivalent.

**Segment types** (spec p. 25) - `BaseballPitch`, `BaseballPickoff`, `BaseballHit`, `BaseballCatcherThrow`, `BaseballBounce`, `BaseballDeflection`, `BaseballThrow`, `Unknown`.

**`mergedPositionalData.typ`** (spec p. 26) - `0` unassigned, `1` players, `2` umpires, `3` coaches, `4` ball. (The engine parser disagrees - see A10.)

**Shift classifications** (`API_Shift_Classifications.csv`) - all distances from home plate:

| Value | Rule |
|---|---|
| 5th infielder | More than 4 fielders within 160 ft |
| infield shift | 3 infielders on one side of the 2B bag within 260 ft |
| extreme infield shift | 4 fielders right of the 2B bag within 260 ft |
| 4th outfielder | More than 3 fielders at least 260 ft out |
| extreme outfield shift | 3 fielders one side of the 2B bag and 0 the other, all ≥260 ft |

Engine enum uses a bit-style encoding: `EXTREME_INFIELD_SHIFT = 1`, `INFIELD_SHIFT = 2`, `EXTREME_OUTFIELD_SHIFT = 4` (`ENGINE/ShiftClassificationType.h`).

**Fielding zones** (`API_Fielding_Zone_Values.csv`, 31 values; enum at `ENGINE/FieldingZoneType.h`) - `Standard`, `Standard In/Back/Left/Right`, `Standard Holding Runner`, `In`, `Back`, `Deep`, `Line`, `Guarding Line`, `Gap`, `Hole`, `Left side`, `Right side`, `Middle to Left`, `Middle to Right`, `Rover`, `CF rover`, `RF rover`, `1B-2B hole`, `2B spot`, `2B-P hole`, `SS spot`, `SS-P hole`, `CF spot`, `LF spot`, `LF Gap`, `RF spot`, `RF Gap`, `Infield`, `Outfield`.

**Out-of-position codes** - bitmask sums. Infield (`API_Infield_Out_of_Pos.csv`): 1B=1, 2B=2, 3B=4, SS=8, so 0-15. Outfield (`API_Outfield_Out_of_Pos.csv`, identical content to `API_Event_Based_Gameplay.csv`): LF=1, CF=2, RF=4, so 0-7.

**Other engine enums** - `PitchType.h` (`FA FT FF FC FS GY CH FO SI SL CU KC KN SC IN PO EP UN NO SN AB AS`, 0-indexed), `HitType.h` (grounder, line drive, fly ball, pop up, plus bunt grounder/line drive/pop up), `HitHardnessType.h` (unknown/soft/routine/hard), `PlayModeType.h` (batting practice, warm up, live, undefined), plus `AtBatEventType.h`, `MlbOutcomeType.h`, `MlbOutcomeDetailType.h`, `OutcomeCode.h`, `UmpireCallType.h`, `PitchDescriptionType.h`, `PitchingPositionType.h`, `BaseType.h`, `BallTrajectoryType.h`, `IccType.h`.

## A9. Raw tracking payload structure

Full outline from the spec, with the sections every consumer should know:

```
Play                        gamePk, playId (GUID), gameDate,
                            MeasurementTime (time ball was pitched),
                            MeasurementTimeCode (frame count at pitch),
                            MeasurementTimeCodeOffset  ← "Avoid, use MeasurementTime"
mergedPositionalData[]      per-frame positions of ALL tracked objects (Part B §B1)
gameEvent                   gpk, pitch_hand, pitch_call, pitch_type, guid,
                            lineup{pos,id}, umpires{pos,id}, event{pos,details{pos,typ,id},typ},
                            runners[], sit{balls,strikes,outs,inning,top_inning,runner_on_1b/2b/3b},
                            post_sit{same, post-pitch}
ballPositionalData
  calibrationData           radar-only plays: RadarTilt/Roll/Pan, CalibrationTime,
                            MeasurementID, CalibrationID
  PitchSegment
    LastMeasuredData        Position XYZ, Time (from release), Velocity XYZ, Distance, Bearing
    ReleaseData             Extension, SpinVector XYZ (RPM), Angle, SpinAxis, ReleasePosition XYZ,
                            seamOrientation (3×3 rotation matrix Xx..Zz), FrameRate (spin camera),
                            Time, spinFitError, ReleaseSpeed, Direction (+ toward 3B), SpinRate,
                            ReducedConfidence[]
    TrajectoryData          HorizontalBreak, VerticalBreak, VerticalBreakInduced, ZoneSpeed,
                            ZoneTime, VerticalApproachAngle, HorizontalApproachAngle,
                            EffectiveVelocity, TrajectoryPolynomial X/Y/Z (2nd order),
                            ValidTimeInterval, MeasuredTimeInterval, Location XYZ (front of plate),
                            PFxData{PfxVert, PfxHorz, x0, v0, a0}  ← pre-2017 PITCHf/x format
  Segments[].SegmentData    SegmentType, StartData, FirstMeasuredData, LastMeasuredData,
                            EndData{Speed,Position,Time,Velocity}, LandingData,
                            TrajectoryPolynomial X/Y/Z, ReducedConfidence[]
  BallPositions[]           TimeCode (frames), TimeCodeOffset, Time, Type ("Measured"/"Estimated"),
                            Position XYZ, Velocity XYZ
  HitSegment
    LaunchData              Speed, Angle, SpinAxis, SpinRate, ContactPosition XYZ,
                            Direction (+ toward 1B)
    LastMeasuredData        Position XYZ, Time, Velocity XYZ, Distance, Bearing
    LandingData             Position XYZ (z=0), Time, Velocity XYZ, Distance, Bearing
    TrajectoryData          HitPositionAt110Feet XYZ, MaxHeightPosition XYZ,
                            TrajectoryPolynomial X/Y/Z (8th order), ValidTimeInterval,
                            MeasuredTimeInterval
    ReducedConfidence[]
playEvents[]                Timestamp, playID, playEventID, playEventType, playEvent (string),
                            positionID (optional), timeCode, scrubbedFlag
                            (0 = not scrubbed, 1 = added by secondary scrubber, 2 = scrubber updated)
gameMetaData                "Do Not USE" (spec p. 22)
Measurements                diagram (SVG) | event_based_gameplay (removed after 2019) | statistics
```

**`ReducedConfidence`** recurs throughout: a string array naming fields that may be estimates rather than measurements. `"StartData"` present means start data was estimated. First-measured data is never flagged.

Pitch trajectories are 2nd-order polynomials; hit trajectories are 8th-order. `ValidTimeInterval` is the projected applicability window, `MeasuredTimeInterval` the actually-tracked window - the gap between them tells you where the curve is extrapolated.

## A10. Metrics Engine Code - architecture

522 files, 442 of them `.cpp`/`.h`, in two trees.

**`ENGINE/` (bdt-blackbox)** - the kernel. Top level holds ~30 enum/lookup headers (A8) plus `FieldLayout`, `ParkInfo`, `MlbSceneryLayout`, `Baseball`, `EngineConfig`, `StringResource.h` (every metric name, description, unit and support level as `STRING_RESOURCE_nnnn` macros), and `MlbConfig.h` (`MLB_KERNEL_VERSION "1.37"` - the value that lands in the `mlb_kernel_version` field of each metric row).

| Subdir | Files | Role |
|---|---|---|
| `analytics/` | 254 | **111 `*Statistic` classes** + the shared kinematics layer (`analytics.cpp`), `StatisticFactory`, `Statistic`, `StatisticalDescription`, `TargetMovement`, `Moment`, `MatrixChart`, `constants.h`, `MlbThreshold.h`, `DataConstants`, `savgol.cpp`, `gpr.h`, `data/` (7 `.dat`), `regression-test/` |
| `io/` | 50 | `StatCastServer` (Stats API client), `StatCastPlayIo` (the raw-JSON parser, rapidjson), `GamedayServer` (legacy XML), `PlayerIo`, `Gameplay`, `Snapshot`, `TargetPosition`, `GameplayEvent`, `Pitch`, `Hit`, `BallThrow`, `Player`, `Team`, `Venue`, `PlayDiagramIo` (SVG), `TrackmanIo`, `PitchFxIo`, `HegoTargetPosition` |
| `filtering/` | 86 | 32 ordered quality filters (below) + `GameplayOperations` (shared geometry/event helpers), `HitModel`, `StatCastFilterFactory` |
| `enrichment/` | 8 | `AddOffTheWallEventStep`, `MissingHitAttributesStep`, `RemoveUnnecessaryMeasurementsStep` |
| `consolidation/` | 2 | `GameplayConsolidation` |
| `database/` | 3 | `StatisticDatabaseFacade`, `CenterOfBattedBallHeatMap.data` |
| `app/` | 3 | `StatCompApp` - the pipeline driver |

**`SHARED/`** - a general-purpose C++ utility library, 36 headers / 22 sources: `MyMath`, `MyAnalytics`, `MomentsOfDistribution`, `Vector2/3`, `Matrix4`, `BoundingBox`, `Distance`, `CurveResampling`, `VertexPool`, `UnitConversion`, `Timestamp`, `UnixEpoch`, `Timer`, `TimeLogger`, `Logger`, `Message`, `FileHelper`, `FilePreloader`, `CsvInputFile/OutputFile`, `JsonHelper`, `ImageHelper`, `Color`, `SceneryLayout`, `StateModelChecker`, `TargetMeasurement`, `ObjectPool`, `PropertyObject`.

**Pipeline** (`ENGINE/app/StatCompApp.cpp:118-158`) - three toggleable steps (`STATCOMP_STEP_TYPE`: Filtering, Enrichment, Analytics), run as:

1. `filtering::CheckConsistency` - "essential that the filtering step is the first in the pipeline which may remove events"
2. `enrichment::AddBallThrowArray` (unconditional)
3. `filtering::CBallMeasurementFiltering().Run`
4. `enrichment::Run` - the 3 steps above. A comment notes the ordering constraint: events depend on player classification, which filtering updates.
5. `analytics::ComputeStatistics`

**Filter order** (`ENGINE/filtering/GameplayFiltering.cpp`, 32 filters) - GameEventOwnership, TransitionBetweenEvents, CheckPlayerClassification, MissingTargetMeasurements, RemoveUnassignedEvents, BallPositionAtThrow, RemoveDuplicateEvents, MeasurementsOutsideTimeInterval, CheckMergedTrajectories, CheckFrozenPlayers, HitExtrapolation, InvalidBounceEvent, BallWasHitEvent, Pickoff, InvalidPitchRelease, BeginOfPlayEventTime, InitialInfielderPosition, InitialOutfielderPosition, InitialRunnerPosition, RelativeInfielderPosition, OutcomeEvent, PlayDuration, MisplacedTargets, PitcherTracking, ProjectedLandingPosition, SwappedPlayers, InitialOutfielderSprayAngle, InitialOutfielderDistanceToHome, InfieldFieldingAlignment, HitTrajectory, PitchTrajectory, MissingGameEvents.

**Analytics dispatch** - `ENGINE/analytics/GameplayAnalytics.cpp` has 108 `EVALUATE_STATISTIC(id, class)` entries. Three classes emit several metrics each: `CSprintSpeedStatistic` → 1081 + 1082 + 1099; `CRelativeStrikeZoneLocationStatistic` → 1126 + 1132 + 1133 + 1134; `CFielderBurstDistanceStatistic` → 1127 + 1128 + 1129 + 1142. Every statistic implements `CheckPreConditions` / `Evaluate` / `CheckPostConditions`, and failed post-conditions emit a structured `CMessage` into the gameplay object rather than aborting the pipeline.

**Statistical baselines** - `ENGINE/analytics/DataConstants.cpp` `#include`s 7 `.dat` files as inline C arrays giving 12 distribution moments each (MEAN, MEAN_DEVIATION, STANDARD_DEVIATION, VARIANCE, SKEWNESS, KURTOSIS, quartiles 0-4, MEDIAN - enum at `SHARED/include/MyAnalytics.h:48`). Covered: Exchange, Exit_Velocity, Extension, Hang_Time, Lead_Distance, Pitcher_Release, Secondary_Lead_Distance. E.g. Exit Velocity MEAN 87.3664, STANDARD_DEVIATION 11.2617. The code calls this "hard-coded as a local text-based database. It will be replaced by a proper database call in the future."

**Physical constants** (`ENGINE/analytics/constants.h`) - max ball speed 106 mph; tracking assumed at **29.97 fps (30/1.001)** with a 2-frame dropout tolerance; average running speed 6 mph and max 44.72 km/h (both used as movement thresholds); max acceleration 9.5 m/s²; average pitcher extension 5.83 ft; max play time 60 s; base width 15″ before 2023, 18″ after. `MlbThreshold.h` adds average home-to-first = 4250 ms.

**Venue geometry** - `ENGINE/EngineConfig.cpp` embeds a JSON blob of `VenueData{venueID, venueName, fenceDimensions[{angle, x, y, z}]}` for **30 MLB parks**, fence height and position sampled per degree of spray angle. Names date the snapshot: Safeco Field, AT&T Park, SunTrust Park, Globe Life Park, Miller Park, Guaranteed Rate Fld. **No MiLB parks.** `EngineConfig.h` can also load this from an external file.

**Persistence** - `ENGINE/database/StatisticDatabaseFacade.cpp` reads/writes six reference CSVs: `positioning.csv`, `zone_position_error.csv`, `fielding_zone.csv`, `pitcher_movement.csv`, `pitch_information.csv`, `throw_information.csv`. **None of these files are in the tree** (A11).

## A11. Known defects, stale pieces, and missing files

**In the documentation:**
- **`API_Depreciated_Metric_Replacements.csv` is wrong** - a byte-for-byte copy of `API_Source_Values.csv` (the data-source list). The replacement mapping for the 13 deprecated and 8 legacy metrics is **not in the context at all**.
- **`API_Metrics.csv` carries 61 non-metric rows** out of 216 - 54 fully/partly empty plus markdown table separators (`:-:`, `:-`), debris from a PDF→CSV conversion. Filter on numeric `ID`.
- **`API_Outfield_Out_of_Pos.csv` and `API_Event_Based_Gameplay.csv` are identical**, both the LF/CF/RF bitmask.
- **`1032` Top Acceleration has an empty description**, and is the only metric in the catalog not in feet/seconds/MPH ("Meters per Square Second").
- Spec sign/origin contradictions: Y is documented "In = Negative, Out = Positive" but its own examples are positive going out; pitch `Direction` is "+ toward 3B" while hit `Direction` is "+ toward 1B"; pitch and hit `SpinAxis` descriptions disagree about which side 90° pulls to; origin is called both "tip" and "back tip" of home plate.
- `playEventType` publishes duplicate labels for codes 6/12, 7/13, 9/15.

**Engine vs. documentation:**
- **`typ` disagrees.** Spec says `1` players / `2` umpires / `3` coaches; the parser at `ENGINE/io/StatCastPlayIo.cpp:1915-1935` treats `1` home team / `2` away team, handles both identically, and ignores `3`. Verify against a live payload before filtering.
- **Support levels disagree.** `StringResource.h:365-366` sets `1127`/`1128`/`1129` to "Beta" and `1142` to "Development"; the CSV says all four are Production. The engine snapshot predates the CSV.
- Internal event codes differ from API `playEventType` (A8).

**Missing or dead in the engine tree:**
- **`CenterOfBattedBallHeatMap.data` is 0 bytes** - so `1019` Positioning, which measures distance to that heat-map centre (`ENGINE/analytics/PositioningStatistic.cpp:93`), cannot compute from this snapshot.
- The six `database/*.csv` reference files are read but absent.
- `savgol.cpp` and `gpr.h` are vestigial: both `SetSpeedMeanSavitzkyGolayFilterFeetSec` and `SetSpeedMeanGaussianProcessFeetSec` are fed the same median+Gaussian value, commented "Keep old reports running" (`ENGINE/analytics/analytics.cpp:265-270`).
- `ENGINE/NhlType.h` is present - leftover from a shared multi-sport codebase.
- `GetAveragePitchPaceByYearInSeconds` only knows 2010-2014 and `LOG_ERROR()`s otherwise (`constants.h:91-117`).

---
---

# Part B - Outfield jump project

## B1. The one fielder-tracking feed

**`mergedPositionalData`, inside `GET /api/v1/game/{gamePk}/{playId}/analytics/raw`, is the only feed in the context that gives fielder position as a time series.** Spec p. 2: "an array of x,y,z coordinates, and time stamps, for the duration of the entire play as measured by the cameras."

Everything else is ball-only or a single summary point. `ballPositionalData.BallPositions` is the ball's measured track; `PitchSegment`/`HitSegment`/`Segments` are ball trajectory polynomials and event-point snapshots; metrics `1059`-`1062` give fielder start/end position and angle as scalars, not a path.

### Fields

Each array element is one timestamped frame holding an array of all tracked objects:

| Field | Type | Meaning |
|---|---|---|
| `timeStamp` | UTC timestamp | When the positions were located. Two different string formats occur in the wild - `ENGINE/io/StatCastPlayIo.cpp:1874` dispatches on both. |
| `positions[]` | array | One entry per tracked object in that frame |
| `positions[].x` | number (ft) | Lateral |
| `positions[].y` | number (ft) | Toward/away from the pitcher |
| `positions[].z` | number (ft) | Vertical - **"Only valid for ball (typ 4)"** (spec p. 2) |
| `positions[].typ` | number | Object class - but see A11, spec and parser disagree |
| `positions[].id` | number | Which object - position identifier list in A8 (`7` LF, `8` CF, `9` RF) |
| `positions[].qi` | number | Quality Indicator - "value that indicates the certainty of the tracked target" |
| `positions[].oo` | number | Object origin: `0` ChyronHego, `1` Trackman. **"Invalid beginning in 2020."** |

### Ball-side data worth pairing with it

For an OF jump metric you need the ball as well as the fielder. Available per play:

| Source | Gives you |
|---|---|
| `HitSegment.LaunchData` | Contact position XYZ, EV, launch angle, `Direction`, spin |
| `HitSegment.LandingData` | Landing position XYZ (z=0), time from release, velocity, distance, bearing |
| `HitSegment.TrajectoryData` | 8th-order X/Y/Z polynomials - evaluate ball position at any t; plus `HitPositionAt110Feet`, `MaxHeightPosition`, measured vs. valid time intervals |
| `BallPositions[]` | Measured ball track with `Type` = Measured/Estimated per sample |
| Metric `1097` | Projected Landing Position (JSON) - what the engine's own fielder metrics key on |
| Metric `1079` | Hit Trajectory as JSON, ball position in **0.5-second intervals** from contact to first contact with ground/wall/fielder |
| Metric `1144` | Ball Location At 300 Feet (JSON, Development) |
| Metrics `1078`, `1113`, `1114`, `1080` | OF distance to fence, ball height at the fence, projected ball distance from fence, projected fielder distance from ball crossing fence |
| Metric `17001` | Catch Probability - the natural benchmark to regress against |
| `ENGINE/EngineConfig.cpp` | Per-park fence `{angle, x, y, z}` for 30 MLB venues, for wall-proximity work |

## B2. Timestamps and sample rate

- Frame times on `mergedPositionalData` are **absolute UTC**. Ball and event data instead use **seconds relative to pitch release** (`MeasurementTime`), plus a `TimeCode` frame counter and a sub-frame `TimeCodeOffset`. **Any fielder-vs-ball computation has to bridge those two clocks** - this is the first real piece of plumbing the project needs.
- **The spec never states a sample rate for `mergedPositionalData`.** The nearest statements are `BallPosition.Time` = "Time measured in .1 intervals" (spec p. 15) and a `FrameRate` field that is explicitly the Hawk-Eye *spin camera*, not the positional system (spec p. 7).
- The engine hard-codes **29.97 fps (30/1.001), ≈33.37 ms/frame**, and treats a gap over **2 frames (≈66.7 ms)** as a dropout - `ENGINE/analytics/constants.h:62-87`. Its own comments concede this outlived the data: `GetMaximumRunningSpeedInFeetSec` carries "increasing the maximum by an order of magnitude due to change in Hawkeye tracking" (`constants.h:165-170`). **Verify the real cadence empirically on a live payload** before trusting any derivative.

## B3. Coordinate system

- **Origin:** the back tip of home plate. Corroborated by metric `1059` ("distance between the fielder and the back tip of home plate") and the PFx `x0` convention at "50 ft from the back tip of home plate" (spec p. 9). The spec is internally inconsistent, saying "tip of home plate" in the ball `Distance`/`Bearing` fields - resolve empirically if sub-foot accuracy matters.
- **Units:** feet throughout; velocities ft/s.
- **Axes:** X lateral, left negative / right positive **from the catcher's perspective**; Y toward/away from the pitcher; Z up positive.
- **Watch the Y sign.** Field tables say "In = Negative; Out = Positive", but the spec's own examples give release `Y: 54.59` and a batted ball at `Y: 357.25`. Y is positive going out toward centre field. Trust the examples.
- **Bearing** is measured from the back tip of home plate; metric `1149` Hit Landing Bearing and `1061`/`1099` fielder angles use related conventions - `1099` defines 0° as straight in toward home and +90° to the fielder's right.
- Field geometry comes from `ENGINE/MlbSceneryLayout.cpp` and `ENGINE/ParkInfo.cpp`, keyed by park and season; base width changes 15″→18″ in 2023 (`constants.h:193-203`).

## B4. Level coverage (MLB vs MiLB)

**The context never states which levels carry tracking data.** No mention of MiLB, sportId, or any level/affiliate concept appears in the spec or any CSV. Two weak signals, both pointing MLB-only:

- The engine's fence geometry covers exactly the **30 MLB parks** (`ENGINE/EngineConfig.cpp`) - no MiLB venue appears anywhere in the tree.
- The only `"milb/"` string in 522 files is one entry in a league list for the *legacy* gd2 XML scraper (`ENGINE/io/GamedayServer.cpp:2576`), alongside college, independent and high-school paths. That is the old Gameday URL space, not evidence about Hawk-Eye.

What the context *does* pin down is the vendor timeline: data source values `2`-`9` (A8) combined with "`oo` … Invalid beginning in 2020" means pre-2020 plays are TrackMan radar + ChyronHego optical, post-2020 plays Hawk-Eye. **MLB/MiLB coverage is the first question to answer against the live API - it is not answerable from these documents, and it gates whether this project can run on Astros affiliates at all.**

## B5. How the engine computes fielder movement and reaction

### The shared kinematics pipeline

Nearly every movement metric runs raw positions through one function: **`GetStatisticalDescription(std::vector<CTargetPosition>)` at `ENGINE/analytics/analytics.cpp:106`**, returning per-sample `CTargetPositionStatisticalDescription` (`ENGINE/analytics/TargetPositionStatisticalDescription.h`).

1. **Bail if fewer than 3 samples** (`analytics.cpp:111`).
2. **Forward differences** per sample: `dtMsec`, `dpFeet = |p(n+1) − p(n)|` (3D), `speedFeetSec = dpFeet / dt` (`:185`). If a sample is flagged measured and carries its own speed, that is used instead (`:182`) - which never happens for fielders, see B6.
3. **Reject duplicate timestamps** carrying different positions, returning empty (`:141-166`).
4. **Smooth the speed series:** 5-point median filter when >5 samples (`:231`), then recursive Gaussian σ=2.0 (`:234`). The median width of 5 is documented as empirically chosen against ChyronHego data.
5. **Acceleration** = numerical derivative of smoothed speed w.r.t. cumulative time (`:242`).
6. **Direction** from per-axis deltas, median+Gaussian smoothed, normalized, rescaled by smoothed speed (`:280-330`).
7. **`dpMeanFeet` = dt × smoothed speed** (`:352`) - "expected displacement" per interval. **This, not raw `dpFeet`, is what every path-length metric sums.**

### Jump, reaction, burst and route - `CFielderBurstDistanceStatistic`

All four of `1127`/`1128`/`1129`/`1142` come from **one class**, `ENGINE/analytics/FielderBurstDistanceStatistic.cpp`, dispatched by a single entry - `EVALUATE_STATISTIC(1127, mlb::analytics::CFielderBurstDistanceStatistic); // Includes 1128 & 1129` at `ENGINE/analytics/GameplayAnalytics.cpp:261`. IDs declared at `GameplayAnalytics.h:148-157`.

**Windows - all anchored to `BALL_WAS_PITCHED`, i.e. pitch release, in microseconds** (`FielderBurstDistanceStatistic.cpp:177-186`):

| ID | Metric | Window from release |
|---|---|---|
| `1128` | Fielder Reaction Distance | 0 → 1.5 s |
| `1127` | Fielder Burst Distance | 1.5 s → 3.0 s |
| `1129` | Fielder Routing Distance | 0 → 3.0 s |
| `1142` | Fielder Jump Distance | 0 → 3.0 s |

**Formulas** (`EvaluateForPlayer`, `:291-418`). With `pathLength = Σ GetDpMeanFeet()` over the window (`:328-334`) and `straight = EuclideanDistance3(first, last)` (`:388`):

- **Reaction (1128)** = `pathLength(0 → 1.5 s)` - `:356-374`
- **Burst (1127)** = `pathLength(1.5 → 3.0 s)` - `:337-355`
- **Routing (1129)** = `pathLength(0 → 3.0 s) − straight(0 → 3.0 s)` - `:399`. Excess path over the direct line; **higher is worse.**
- **Jump (1142)** = `distanceCovered - (distanceCovered - straightDistanceCovered)` - `:410`. Written as reaction+burst−routing to match its stated definition (`StringResource.h:355`), but it reduces algebraically to **`straightDistanceCovered`: straight-line displacement from where the fielder stood at release to where he stood 3 s later.**

**Eligibility and population** (`:165-290`):
- Requires `mlb::filtering::HitIntoPlay`, plus valid `PITCHER_FIRST_MOVEMENT` and `BALL_WAS_PITCHED` events.
- Requires at least one `BALL_WAS_CAUGHT` (which includes `BALL_WAS_FIELDED`) or `BALL_WAS_DEFLECTED`; the earliest by time wins.
- The **fielder who made the play always qualifies** (`:213-217`), gated only by `mlb::filtering::IsFielder` - which includes P and C (`ENGINE/filtering/GameplayOperations.cpp`, `IsInfielder`).
- **Other fielders qualify only within 30.0 ft** of the projected landing position at projected landing time (`:274`). That set is 1B/2B/3B/SS/LF/CF/RF - catcher is explicitly commented out ("likely don't care about burst for catchers", `:260`) and the pitcher is never added (`:253-260`).
- **Infield balls drop every non-catching fielder:** if the projected landing point falls inside the 90 ft × 90 ft square spanned by the home→1B and home→3B unit vectors, the landing position is nulled and the radius loop is skipped (`:221-243`).
- Post-conditions reject null, non-finite and negative values (`:63-110`).

### Other fielder movement metrics

| ID | Metric | Computation | File |
|---|---|---|---|
| `1007` | First step (deprecated) | Walk the smoothed speed series forward to the first sample above **6 mph** (`GetAverageRunningSpeedInFeetSec`, `constants.h:159-162`), then **backward** while speed > **1 mph** and still monotonically decreasing, catching the *last* onset of acceleration; value = `hitTime − firstStepTime`. Window is hit−1 s → hit+5 s. | `FirstStepStatistic.cpp:135-158, 244-252` |
| `1011` | Acceleration (deprecated) | Time from `BALL_WAS_HIT` to maximum speed over the whole play. | `AccelerationStatistic.cpp:110-119` |
| `1021` | First Step Efficiency (deprecated) | Truncate trajectory to the first **3.0 ft** of travel, then `trajectoryVector.Angle(firstStepVector)` - deviation between the line to the ball and the actual first stride. | `FirstStepEfficiencyStatistic.cpp:111-113, 142` |
| `1022` | Route Efficiency (deprecated) | On a catch: `displacement / distanceCovered` from hit to catch. On no catch, for fielders within 30 ft of a landing point under 3.0 ft: `displacement / (bias + distanceCovered)`, `bias` = end-of-path distance to the landing spot. Full 8-step algorithm commented inline. | `RouteEfficiencyStatistic.cpp:206-224` |
| `1023` | Distance Covered | Path length from `BALL_WAS_HIT` to the catch, or to landing time for fielders within 30 ft. Aborts if `BALL_WAS_RELEASED` precedes the catch. **Values under 3.0 ft rejected.** | `DistanceCoveredStatistic.cpp:158-172, 108` |
| `1077` | Distance Covered Breakdown | Same accumulation, emitted as a JSON array of (time, distance) pairs. | `DistanceCoveredBreakdownStatistic.cpp:162, 219` |
| `1081` | Sprint Speed | Slide a **1-second** window and keep the maximum **straight-line displacement / dt** - not path length. Includes per-player anomaly detection. | `SprintSpeedStatistic.cpp:168-199` |
| `1082` | Startup Time | `actualDeltaTime − (displacement / sprintSpeed)` - time lost versus covering the same ground at top 1-second speed. | `SprintSpeedStatistic.cpp:317-338` |
| `1099` | Route to Sprint Speed | Angle of the route between position at pitch release and position at the start of the fastest 1-second window. 0° = straight in toward home, +90° = to the fielder's right. | `SprintSpeedStatistic.cpp:476` |
| `1086` | Total Distance Covered | Path length over the whole play. | `TotalDistanceCoveredStatistic.cpp:152` |
| `1019` | Positioning | Euclidean distance from the fielder to the centre of a batted-ball heat map - **whose data file is empty**, see A11. | `PositioningStatistic.cpp:93` |
| `1051`/`1052` | Distance from / Projected Distance from Ball Landing | Fielder-to-landing-point distance at landing time / at contact. | `DistanceFromBallLandingStatistic.cpp`, `ProjectedDistanceFromBallLandingStatistic.cpp` |
| `1053`/`1054` | Angle to where Ball Landed / was Caught | Angular versions of the above. | `AngleToWhereTheBallLanded.cpp`, `AngleToWhereTheBallWasCaught.cpp` |
| `1138` | Intercept Batted Ball | Intersection (or projected intersection) of player path and ball path. | `InterceptBattedBallStatistic.cpp` |
| `1116` | Fielder Engagement (deprecated) | Array of a fielder's fielding potential along the ball trajectory. | `FielderEngagementStatistic.cpp` |

Also present and potentially useful: `BurstStatistic.cpp` and `KeyStepStatistic.cpp` (the batter-runner `1119`/`1118` analogues), `InstantaneousTopSpeedStatistic.cpp`, `TopAccelerationStatistic.cpp`, `CorneringStatistic.cpp`, `RangeStatistic.cpp`, `OutfielderDistanceToFenceStatistic.cpp`, `WallBallStatistic.cpp`, `ProjectedDistanceFromBallCrossingFenceStatistic.cpp`, `SacrificeFlyStatistic.cpp`, `TargetMovement.cpp` (path/range/top-speed helpers over a trajectory).

**Two different time anchors are in play.** `1127`/`1128`/`1129`/`1142` and `1099` start at **pitch release**; `1007`/`1011`/`1021`/`1022`/`1023`/`1077` start at **bat-on-ball contact**. They are not directly comparable, and a release-anchored 3-second window includes the whole pitch flight (~0.4-0.5 s) plus the swing before the ball is even struck.

## B6. Gaps

### Blocking

**No vertical position for fielders - no physical jump is measurable at all.** The spec restricts `z` to the ball ("Only valid for ball (typ 4)", p. 2) and the parser enforces it: `ENGINE/io/StatCastPlayIo.cpp:1937-1943` reads `z` **only** under `case 4:`; for players it sets X and Y and leaves Z unset. "Jump" in this data can only ever mean *ground covered*, never leaving the ground, vertical leap height, or at-the-wall timing. `EuclideanDistance3` in the Jump/Routing math (`FielderBurstDistanceStatistic.cpp:388`) is therefore effectively 2D for fielders. **If the goal is a literal leap metric, the context contains no source for it.**

**Sample rate is undocumented and the engine's assumption is stale** (B2). A 1.5 s boundary and a 3.0 s boundary land wherever frames happen to fall, which sets the floor on reaction-phase precision.

**Level coverage is unknown** (B4) - the prerequisite for any org-wide fielding work.

### Semantic gaps in what's exposed

**`1142` is displacement, not Statcast's public Jump.** Straight-line displacement over 0-3 s from pitch release, with no directional term. A fielder breaking 3 ft on a perfect line and one breaking 3 ft the wrong way score identically. Any direction-aware jump has to be rebuilt from `mergedPositionalData` plus the ball's projected landing point.

**No "correct direction" primitive is published per play.** Deriving it means joining the fielder path to the ball trajectory, which means bridging the UTC and release-relative clocks (B2). The pieces are all in B1; the join is yours to build.

**`17005 Jump` is league-relative and opaque.** Defined only as "the fielder's jump distance relative to the league average for the given play" - a Fielding (OF) delta in feet, Production. Not decomposed into reaction/burst/route, and no formula, baseline, or play-matching logic appears anywhere in `context/`. Nothing in the engine computes it; it lives in a modeling layer outside this tree, consistent with all `17xxx` being contextMetrics.

**Measured instantaneous speed never reaches the pipeline for fielders.** `analytics.cpp:182` prefers a sample's own speed when `IsMeasured()` is true, but the merged-positional parser calls `SetIsMeasured(false)` unconditionally (`ENGINE/io/StatCastPlayIo.cpp:1908`, commented that TrackMan would be "measured" and Hego optical "not measured"). Every fielder speed is thus a finite difference of smoothed positions, carrying the smoothing's lag and attenuation - worst exactly where a reaction metric is most sensitive, in the first few frames.

**`qi` (quality indicator) is unused.** The spec publishes a per-sample certainty value; the parser never reads it and no metric weights or filters on it. Serious jump work should use it, and will have to characterize its scale from live data since the spec defines no range.

**A window-sum edge artifact.** In `GetStatisticalDescription` the final sample of an array copies `dt`/`dp` from the previous sample (`analytics.cpp:189-206`), so summing `GetDpMeanFeet()` over a window counts the last interval twice - roughly one frame's travel (~0.7 ft for a fielder at 20 ft/s). It also means the frame at the 1.5 s boundary contributes to both the reaction and burst windows. Small, but systematic and same-signed across `1127`/`1128`/`1129`.

**Catchers and pitchers are near-absent, and infield plays are excluded.** The 30 ft radius population excludes both (`FielderBurstDistanceStatistic.cpp:253-260`); they appear only when they personally made the play. Infield balls additionally drop every non-catching fielder (`:221-243`). Coverage is sparse and selection-biased toward outfield plays - convenient for this project, but it means the published distributions are not a general fielding sample.

**`1019` Positioning cannot compute** from this snapshot - its heat-map data file is empty (A11). If starting position relative to a batted-ball expectation matters, that baseline has to be rebuilt.

### Not in the context at all

No `analytics/parsed` URL (A1). No rate limits (A4). No current auth contract (A3). No deprecation-replacement mapping, so the four deprecated predecessors most relevant here - `1007` First step, `1011` Acceleration, `1021` First Step Efficiency, `1022` Route Efficiency - have no documented successor; the `1127`-`1129`/`1142` family is the presumable replacement but nothing states it. And no `mlb_kernel_version` history, so there is no way to tell from these docs which kernel version produced a stored value or when a formula changed underneath it.
