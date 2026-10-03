# Batch Advance Scouting Report — Design Document

**Created:** 2026-03-13
**Branch:** `feature/barrelsville`
**Status:** CODE COMPLETE — awaiting work laptop testing

## Purpose

Auto-generate advance scouting PDFs for all opposing pitchers in upcoming series across all MiLB levels (ROK through AAA). Coaches run this on Mondays (off day) to prep for the week's matchups.

## CLI Usage

```bash
# Default: all 5 levels, next 2 series
python scripts/generate_advance_batch.py

# Single level, one series
python scripts/generate_advance_batch.py --level aaa --series 1

# Diagnostic: verify table schemas + org mappings (run FIRST on work laptop)
python scripts/generate_advance_batch.py --diagnostic

# With Slack delivery to a specific channel
python scripts/generate_advance_batch.py --deliver --channel C0ABC123 \
    --logic-app-url "https://..."
```

### CLI Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--level` | all 5 (aaa aax afa afx rok) | MLBAM level codes to process |
| `--series` | 2 | Number of upcoming series per level |
| `--season` | current year | Season year |
| `--sched-type` | R | R (regular) or all |
| `--notes` | "" | Scouting notes for summary pages |
| `--output` | reports/advance/ | Output directory |
| `--deliver` | false | Send to Slack |
| `--channel` | required with --deliver | Slack channel ID |
| `--logic-app-url` | env LOGIC_APP_URL | Logic App URL |
| `--diagnostic` | false | Dump schemas + mappings, exit |

## PDF Structure

One combined PDF per pitcher (previously was two separate files):

| Page | Content |
|------|---------|
| 1 | Summary vs RHH (break chart, arsenal table, count-state usage, physical metrics) |
| 2 | Summary vs LHH (same layout, mirrored) |
| 3+ | Per-pitch-type density pages vs RHH (LOC + DMG heatmaps, spray chart, IZ% badges) |
| N+ | Per-pitch-type density pages vs LHH |

For a pitcher with 4 pitch types: 2 + 4 + 4 = **10 pages**.

### File Naming

```
{level}_{org}_{Last}_{First}_{series_start_YYYYMMDD}.pdf
```

Examples:
- `aaa_mil_Smith_John_20260327.pdf`
- `afa_car_Jones_Mike_20260401.pdf`

## Architecture

### New Tables (first time in codebase)

#### `MLBAM.Schedule`
Game schedule for all levels. Key columns:
- `GAME_DATE`, `HOME`, `AWAY`, `HOME_TEAM_ID`, `AWAY_TEAM_ID`, `SPORT`
- `SPORT` = MLBAM level code (aaa, aax, etc.)
- Verified via `--diagnostic` mode

#### `mlb_ebis.gbl_club_lkup`
eBis club lookup table. Maps team identifiers to ORG_LK codes.
- `CLUB_LK`, `ORG_LK`, `LEVELOFPLAY_LK`, `ACTIVE_FLG`
- **Known org_lk remapping quirks:** `la→lad`, `chi→chc`, `ny→nym`
- Uses eBis level codes (`3a`, `2a`, `1a`, `1f`, `r`) not MLBAM codes
- Filter: `ACTIVE_FLG = 1` and `ORG_LK <> 'boc'`

### Data Flow

```
1. get_upcoming_series(level, season, num_series)
   -> MLBAM.Schedule + MLBAM.Teams + gbl_club_lkup
   -> Returns: [{opp_org, opp_team_name, series_start, num_games}, ...]

2. For each series:
   get_opposing_pitchers(opp_org, level)
   -> MLB_eBis.PP_MASTER + Astros.Players
   -> Returns: DataFrame of active pitchers

3. For each pitcher:
   get_scouting_pitches(pitcher_id, level, season)
   -> Astros.Pitches_View + Schedule_View + Hits
   -> Returns: DataFrame (last 5 GS / 30 IP scope)

4. generate_combined_advance_report(pitcher, pitch_df, ...)
   -> PdfPages with both RHH + LHH pages
   -> Returns: PDF file path
```

### Key Functions

| Function | File | Purpose |
|----------|------|---------|
| `get_upcoming_series()` | advance_data.py | Query upcoming series from schedule |
| `get_org_lk_diagnostic()` | advance_data.py | Verify table schemas on work laptop |
| `generate_combined_advance_report()` | advance_report.py | Single PDF with both bat sides |
| `send_to_channel()` | deliver.py | Explicit Slack channel routing |

### Constants

| Constant | File | Value |
|----------|------|-------|
| `BATCH_LEVELS` | advance_data.py | `["aaa", "aax", "afa", "afx", "rok"]` |
| `MLBAM_TO_EBIS_LEVEL` | advance_data.py | Maps MLBAM sport codes to eBis level codes |
| `_MLBAM_ORG_TO_PP_ORG` | advance_data.py | Org remapping: la→lad, chi→chc, ny→nym |

## Series Detection Logic

1. Query all future games at level where HOU affiliate is home or away
2. Sort by game date
3. Group consecutive games vs same opponent into series
4. An off-day between games vs same opponent = still same series
5. Return first N series

## Delivery

Advance reports use **explicit channel routing** (`send_to_channel`) rather than the standard GC-ID-based routing (`send_reports_via_logic_app`). This is because opposing pitchers don't have entries in our `slack_channels.csv`.

Future: Add level-based channel mappings (e.g., `zzz_advance_aaa`) for automated routing.

## Testing Checklist

1. `--diagnostic` first: verify all table schemas and org mappings
2. `--level aaa --series 1`: single level, one series
3. Open PDF: verify pg1 (RHH summary), pg2 (LHH summary), pg3+ (pitch type pages)
4. Full default run: all 5 levels, 2 series
5. Check filenames match naming convention
6. `--deliver --channel C... --logic-app-url ...`: test Slack delivery
