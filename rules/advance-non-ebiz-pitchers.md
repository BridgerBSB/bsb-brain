---
paths:
  - "**/advance_*.py"
  - "**/generate_advance*.py"
  - "**/*pitcher_advance*.py"
  - "**/*fielding_advance*.py"
---

# Non-EBIZ Pitchers in Advance Reports — One-Off Procedure (BLOCKING)

Some opposing pitchers we'll face don't have a clean `MLB_eBis.PP_MASTER`
record. The standard advance flow assumes PP_MASTER is the source of
truth for org / level / position. When it isn't, the standard flow
silently breaks (NULL → NaN → `'float' has no attribute 'upper'`) or
returns zero search results.

This rule documents the diagnostic + one-off-report procedure for these
players. Use it whenever an opposing pitcher in an upcoming series
doesn't surface in the search-by-name dropdown, OR they surface but
render with garbage metadata (org `???`, level `???`, etc.).

## When this comes up

- **Mid-season acquisitions off independent ball** (Atlantic League,
  American Association, etc.). Player joins the affiliate roster days
  before we face them; PP_MASTER hasn't synced yet.
- **Recently released / between-orgs** players who are floating in the
  data but not on a current 40-man roster.
- **One-off bullpen rehab / NRI lookups** where they pitched against
  affiliates but PP_MASTER didn't pick them up.
- **Multiple `groundcontrol_id` rows for the same human.** GC2 ingest
  occasionally assigns a new `groundcontrol_id` when an external feed
  re-IDs a player. We end up with 2-3 rows in `Astros.Players` for one
  person — usually one "real" row (non-NULL `ebis_id` + `mlbam_id`) and
  1-2 stub rows. Pitches in `Pitches_View` get tagged with whichever
  GC id was active at the time, so a single human's career data is
  split across the IDs.

## Diagnostic (always run this first)

```bash
# Edit the @pitcher_first / @pitcher_last DECLARE lines, then run:
sql-queries/non-ebiz-pitcher-lookup.sql
```

The script returns three result sets:
1. **All `Astros.Players` rows** for the name. The "real" row is the
   one with non-NULL `ebis_id`, `mlbam_id`, `birthdate`. Others are stubs.
2. **Last-12-months pitch activity** aggregated across all rows by
   `(year, level_code, sched_type)`. Confirms data exists, shows where it lives.
3. **Per-game detail with cumulative IP** so you can eyeball where the
   30-IP boundary will land.

If step 2 returns zero rows: the pitcher truly has no recent data —
nothing to advance against. If step 1 shows multiple rows: collect ALL
of those `groundcontrol_id` values for the next step.

## In-app version (preferred for end users)

The Barrelsville Advance app has a **Pitcher Diagnostic** tab (3rd tab,
sibling to Series Scouting + Pitcher Lookup) that walks coaches through
the same diagnostic + stitched-report flow without requiring a CLI run.
Steps in the UI:

1. Enter first + last name
2. View every `Astros.Players` row for the name (no PP_MASTER inner-join,
   so stubs + amateur tracking ids surface) with auto-cluster badges:
   same name + same non-NULL DOB = same human
3. View last-12-month pitch activity per gc_id grouped by (year, level,
   sched_type) — confirms data exists, shows where it lives
4. Auto-run R4 draft bridge — green confirm if `R4.mlbam_id` overlaps
   `Astros.Players.mlbam_id` from any returned row
5. Multi-select gc_ids (pre-checked: DOB cluster around the real PP_MASTER
   row, filtered to ids with data) + override metadata fields (org/level/
   throws/mlbam_id auto-filled from the real gc_id) + max-IP recency knob
6. Generate → renders inline + Download PDF (visual parity with Pitcher
   Lookup tab)

Backend in `barrelsville/src/advance_diagnostic.py` shares its 4 core
helpers (`fetch_outings`, `walk_to_max_ip`, `fetch_pitches`,
`build_synthetic_pitcher`) with the CLI below — single source of truth.

## One-off CLI (use after diagnostic confirms data)

```bash
python scripts/generate_advance_oneoff.py \
    --pitcher-ids <gc_id_1> <gc_id_2> <gc_id_3> \
    --first-name <First> --last-name <Last> \
    --throws <R|L> \
    --level <aaa|aax|afa|afx|rok|dsl> \
    --mlbam-id <id_if_known>
```

Defaults are wired to **Kyle Funkhouser** (Apr 2026 case study) so a no-arg
run regenerates his report.

| Flag | Default | Notes |
|---|---|---|
| `--pitcher-ids` | Funkhouser's 3 GC ids | Pass ALL the gc_ids from diagnostic step 1, including stubs |
| `--first-name` / `--last-name` | Kyle / Funkhouser | Header display + filename |
| `--throws` | R | R/L — affects pitch-view orientation |
| `--level` | aaa | Used as the **percentile pool** — pick the level whose distributions best represent where this pitcher is competing now |
| `--org` | IND | Display label only |
| `--mlbam-id` | 608335 | Enables MLBAM headshot if the ID exists in their cache; pass `0` or omit if unknown |
| `--max-ip` | 30.0 | The recency window walks back from today until cum IP ≥ this |
| `--season` | current year | Which season's percentile distributions to load |
| `--bat-side` | both | `R` / `L` / `both` |
| `--deliver` | off | Posts to `weekly-player-updates` (`C0AVBKPEG8H`) via the standard Logic App |
| `--logic-app-url` | `LOGIC_APP_URL` env | Same env var as boxscore / postgame delivery |

## How the script differs from `generate_advance.py`

| | Standard `generate_advance.py` | One-off `generate_advance_oneoff.py` |
|---|---|---|
| Pitcher lookup | PP_MASTER + `Astros.Players` join | None — metadata supplied via CLI flags |
| `pitcher_id` SQL | `pv.pitcher_id = :pitcher_id` (single) | `pv.pitcher_id IN (...)` (union of N GC ids) |
| Org / level / position | Resolved from PP_MASTER | Manually passed via flags |
| Recency window | Full season + auto NARROW/WIDE scope mode | Always WIDE-equivalent, walked to `--max-ip` |
| Headshot | From PP_MASTER → mlbam_id chain | Direct `--mlbam-id` flag |
| Use when | Active 40-man / clean affiliate pitcher | Indy / multi-GC-id / non-PP_MASTER edge cases |

## Caveats

- **Arm angle** is computed from the *primary* (first) GC id in
  `--pitcher-ids`. If most pitches are tagged under a non-primary id,
  arm angle may be empty. Re-run with the heaviest-data GC id listed
  first to fix.
- **No NARROW vs WIDE detection.** The script always uses the permissive
  WIDE-equivalent filter (`R+S+E+I`, allow bbc/ind/int/sum/win/min)
  because non-EBIZ pitchers almost always need the wider net. See
  `.claude/rules/advance-levels.md`.
- **Boundary game inclusion.** The IP walk includes the game that
  *crosses* the `--max-ip` threshold, so you may end up with ~32 IP
  shown for a `--max-ip 30` run. Better than truncating mid-game.
- **Synthetic pitcher Series.** Some advance-report features that
  query PP_MASTER directly (e.g. roster status banner) will show
  generic placeholders. The pitch data + percentile coloring + zone
  visualizations + spray chart all work normally.

## Forward-looking — same pattern for future advance domains

When pitcher advance (what hitters do vs pitchers) and fielding advance
get built, they MUST also have a `generate_*_advance_oneoff.py`
companion using the same architecture:

- Custom IN-clause SQL across N GC ids (one human → many `Astros.Players`)
- Synthetic player Series with manual metadata from CLI flags
- Same `--max-ip` / `--max-pa` / `--max-plays` recency walk
- Same permissive level filter (see `advance-levels.md`)
- Same delivery path to `weekly-player-updates`

Don't re-derive this from scratch. Copy `generate_advance_oneoff.py`,
swap the SQL targets, and adjust the synthetic Series schema.

## Cross-reference

- Level filter policy: `.claude/rules/advance-levels.md`
- DB IDs / column meanings: `.claude/rules/db-columns.md` (pitcher_id =
  groundcontrol_id, mlbam_id mapping)
- Diagnostic SQL template: `sql-queries/non-ebiz-pitcher-lookup.sql`
- Reference impl: `barrelsville/scripts/generate_advance_oneoff.py`
- Worked example (history): `sql-queries/funkhouser-int-check.sql`
