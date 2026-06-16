---
name: GroundControl2 tables use Astros. schema prefix — never .dbo., never bare
description: Pitches_View, Events_View, Schedule_View, Hits, etc. live in the Astros schema. Always write Astros.Pitches_View. Never GroundControl2.dbo.Pitches_View. Never bare Pitches_View.
type: feedback
originSessionId: 576ada4c-1a2e-4e9a-89a0-e9fd305a6281
---
**Rule:** GroundControl2 baseball tables are in the `Astros` schema. Always prefix with `Astros.`.

**Why:** User corrected this Apr 23 2026. Confirmed by grep across `pd-goals/src/` — every reference is `Astros.Pitches_View`, `Astros.Events_View`, `Astros.Schedule_View`, etc. No `.dbo.` anywhere. No bare forms. The earlier "bare is fine" rule I wrote was wrong — I got the pattern backwards.

**How to apply:** When writing SQL against GC2 baseball tables:
- `FROM Astros.Pitches_View pv` ✅
- `FROM Astros.Events_View ev` ✅
- `FROM Astros.Schedule_View sv` ✅
- `FROM Astros.Hits h` ✅
- `FROM Astros.Video_Network vn` ✅
- `FROM Astros.Bat_Tracking_Metrics bt` ✅

❌ NEVER `GroundControl2.dbo.Pitches_View` or `dbo.Pitches_View` or bare `Pitches_View`.

**Other schemas keep their own prefixes (NEVER `.dbo.`):**
- `Guts.woba_lwts`
- **`MLB_eBis.PP_MASTER`** — NO `.dbo.` Confirmed Apr 24 2026 across 4 production files (roster.py, advance_pitching_data.py, pd-goals/src/report.py, pd-goals/src/roster.py). JOIN pattern: `JOIN Astros.Players r ON r.ebis_id = pm.player_id`. Real columns: `pm.ORG_LK`, `pm.LEVELOFPLAY_LK`, `pm.MNROSTERSTATUS_LK`, `pm.MJROSTERSTATUS_LK`, `pm.EMPLOYEE_FLG`, `pm.POSITION_LK`, `pm.player_id`. My earlier rule incorrectly said `.dbo.PP_MASTER` was "the one exception" — wrong. No exceptions. The only `MLB_eBis.dbo.PP_MASTER` in the codebase is in a one-off discovery script (pd-goals/db_discovery_extract.py), not production.
- `mlbam.YTD_Team_Batting_Stats` + `mlbam.players` + `mlbam.Gamelog_Pitching` + `MLBAM.Teams`
- `GroundControl2.BlastMotion.Series_Metrics_View` (three-part for non-Astros schema inside GC2)
- `groundcontroltracking.tracking.pitch_hit_trajectories` + `groundcontroltracking.tracking.play_starting_positions`

If unsure about a table, grep `pd-goals/src/` for `FROM .*<TableName>` and copy the existing form verbatim.

**Column traps that pair with this:**
- Pitches_View has NO `ab_number`. Use `pv.ab_event_id` (PA key) or `pv.cur_event_id` (final pitch of PA). See `rules/db-columns.md` + `rules/db-joins.md`.
- Pitch-in-PA counter = `pv.ab_pitch_number` (not `pitch_number`).
