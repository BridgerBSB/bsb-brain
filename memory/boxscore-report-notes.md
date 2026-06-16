# Box Score Report Notes (Updated Mar 11, 2026)

## Location
- `barrelsville/scripts/boxscore_report.py` on `feature/barrelsville`
- Worktree: `C:/Users/Owner/bsb-wt-hitting/`

## Status: SOLID — delivery method TBD
- PDF generates, pushed to `feature/barrelsville`
- Filename format: `boxscore-{level}-{date}-{sched_id}.pdf`

## Architecture
- Standalone script (~1500 lines), imports `src.roster.get_roster` for HOU org filtering
- Uses plottable Tables (proven kwargs only: `row_dividers`, `row_divider_kw`, `col_label_divider_kw`, `footer_divider`)
- Landscape PDF via matplotlib PdfPages

## Game Discovery: Roster-Based Filtering
- `get_affiliate_games(game_date, season)` — 3-step approach:
  1. Get HOU org roster IDs via `get_roster()` (PP_MASTER WHERE ORG_LK='hou')
  2. Find sched_ids where HOU players appeared in Pitches_View
  3. Get game metadata from Schedule_View + MLBAM.Teams
- Filters: `sched_type IN ('R','S','E','V','I')`, `level_code NOT IN ('int','win','bbc','mlb')`

## Page Layout
- **Page 1:** Linescore + Batting tables (away + home) + first 2 pitchers per team + top-5 footer
- **Page 2+:** Overflow pitchers (max 5 per page), with totals + top-5 footer on last page only
- Batting top starts at 0.818, pitching starts 0.03 below batting bottom
- Pitching header bars on page 1 only (not overflow pages)
- Top-5 footer: per-team boxes (Velo + EV) positioned 0.05 below last pitching table

## Batting Table
- Columns: #, Name, PA, 1B, 2B, 3B, HR, HBP, BB, SO, R, RBI, SB, FB Whf%, OS Whf%, HH, Av EV
- Totals row shows team name (e.g., "Space Cowboys") instead of "TOTALS"
- Subs determined by lineup_spot: if a player appears in a lineup_spot already used, they're a sub (indented)

## Pitching Tables
- Summary: IP, BF, R, ER, H, HR, BB, SO, HBP, PIT, STR, Str%, P/PA, P/IP, FPS, 1BO
- Pitch type: Pitch, Total, Use%, Whf%, Str%, Velo, Spin, Hop, HorzBrk
- FPS% = NOT IN BALL_CODES (binary outcome, different from FPinZ%)
- TOTALS row: team-wide aggregated stats, only shown on last page for each team
- `all_pitchers_for_totals` param ensures totals aggregate ALL pitchers even on overflow pages

## I Game (Intrasquad) Handling — IMPLEMENTED (Mar 11, 2026)
- **Team names:** MLBAM.Teams returns NULL for V/I → falls back to `AFFILIATE_NAMES` dict
- **V/I sched_type label** appended: e.g., "Sugar Land (Intrasquad)"
- **Data limitations (CONFIRMED Mar 10-11):**
  - PA outcome columns WORK: 1b, 2b, 3b, hr, bb, hbp, so — all properly tagged
  - Scoring columns ALL NULL: away/home_team_score_before/after, earned_runs, batter_rbi
  - StolenBases table: 0 rows for I games (confirmed Mar 8 BR investigation)
  - Astros.Hits: NO R/RBI columns (only EV, LA, bearing, trajectory)
  - Runner columns ALL NULL: runner_1b/2b/3b (before and after)
  - fielding_team_id, batting_team_id = NULL
  - Reason: no official scorer for intrasquad games, only TrackMan/HawkEye tracking
  - Raw TrackMan CSVs DO have RunsScored but GC doesn't ingest it for I games
- **Column exclusions when sched_type == 'I':**
  - Linescore: inning values show dashes, R column excluded entirely (H/E remain)
  - Batting: R, RBI, SB columns dropped from col defs + DataFrames
  - Pitching summary: R, ER columns dropped from col defs + DataFrames
  - Implementation: `_batting_col_defs(sched_type)` and `_pitching_summary_col_defs(sched_type)`
    filter via `I_GAME_EXCLUDE` sets. DataFrames also `.drop()` matching columns.
  - `_render_pitching_column` uses `valid_cols` set from `summary_col_defs` to filter
    both per-pitcher and TOTALS display dicts.

## Doubleheader Handling
- sched_id included in filename for disambiguation
- `game_number` column exists in MLBAM.Schedule (per Adam Brodie) for doubleheader distinction

## Constants
- `AFFILIATE_NAMES`: level_code → full name (aaa→Sugar Land, aax→Corpus Christi, etc.)
- `AFFILIATE_NICKNAMES`: level_code → short name (aaa→Space Cowboys, etc.)
- `SCHED_TYPE_LABELS`: V→Live BP, I→Intrasquad, S→Spring Training, etc.
- `MAX_PITCHERS_PAGE1 = 2`, `MAX_PITCHERS_OVERFLOW = 5`
- `PITCH_TYPE_NAMES`: FT→"2-Seam" (not "Fastball")

## Key Commits
- `78cc16b` — Simplify filename to `boxscore-{level}-{date}-{sched_id}.pdf`
- `e04d9e5` — Move pitching down 0.03, remove redundant headers on page 1
- `77fbf5b` — Pitching headers on page 1 only
- `ceb1a39` — FT → 2-Seam
- `058448c` — Team name in pitching totals
- `e7bfdf0` — Per-team top-5 footer boxes positioned dynamically
- `b81cd5d` — Reduce to 2 pitchers on page 1, remove overflow navy header
- `3bb5d33` — Fix FPS% to include BIP (NOT IN BALL_CODES)
- `601fc44` — Add pitch_result_id 25 to WHIFF_CODES, 18/19/20 to BIP_CODES
- `98f2618` — Hide R/RBI/SB (batting) and R/ER (pitching) for I games

## Next Steps
- Determine delivery method (Slack channels, batch, etc.)
