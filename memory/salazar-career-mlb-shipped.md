---
name: salazar-career-mlb-shipped
description: "--career flag on catcher postgame CLI; one-off for Salazar green card May 24 2026. Useful for any catcher career retrospective at one level (mlb / aaa / etc.)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 471af353-7946-4638-8d73-46aa92c41cf3
---

# Catcher Postgame `--career` Flag — Shipped May 24 2026

One-off addition to the existing per-game catcher postgame CLI. Adds a
`--career` flag that bypasses the date/game loop and pools every regular-
season pitch / throw / block / setup position the catcher caught at a
chosen level. Same PDF render as the per-game path — strike-zone plots,
throws scatter, blocks scatter, setup positions, percentile coloring, all
of it — just sourced from a career pool instead of one game.

**Built for**: Cesar Salazar (gc_id 71625) green card paperwork (USCIS
needed evidence of MLB-caliber catching performance over his career).

**Will not be used much** — user direction May 24 2026. Keep it on the
shelf; it's a CLI flag that costs nothing to leave in. Useful any time a
catcher needs a "career at one level" retrospective.

---

## File + commit

- `intangibles/scripts/generate_catcher_report.py` — `--career` flag
  added in commit `bdf2eea9` on `feature/astros-intangibles`
- Self-contained: 4 SQL templates + helpers added inline in the CLI.
  Does NOT touch `src/catcher_data.py`. Per-game path untouched.

## Usage

```powershell
# Default = all-time at MLB level (Salazar use case)
python scripts/generate_catcher_report.py --career --catcher 71625 --level mlb

# Scope to specific seasons
python scripts/generate_catcher_report.py --career --catcher 71625 --level mlb --seasons 2022 2023 2024 2025

# Different level (e.g. all his AAA stint)
python scripts/generate_catcher_report.py --career --catcher 71625 --level aaa
```

When `--career` is set:
- `--date` is NOT required
- `--catcher GC_ID` IS required
- `--level` defaults to `mlb`
- `--seasons` optional (default: all-time)

## What populates the PDF

Same `generate_catcher_report(...)` renderer the per-game path uses.
Career-pooled value populates BOTH the "game" and "season" slots —
they intentionally show identical numbers because there's no per-game
vs season distinction when you're pooling a career.

| Slot | Career mode value |
|---|---|
| `pitch_df` | All regular-season MLB pitches at level, across seasons |
| `throws_df` | All throws |
| `blocks_df` | All dirtballs |
| `setup_df` | All catcher setup positions |
| `netk_game` = `netk_season` | Career NetK |
| `depth_game` = `depth_season` | Career avg depth (RHH / LHH split) |
| `throwing_game` = `throwing_season` | Career throwing summary |
| `blocking_game` = `blocking_season` | Career blocking summary |
| `augpop_game` = `augpop_season` | Career AugPop (from throws_df) |
| `pitcher_list` | Top 15 pitchers caught by pitch count |
| `opp_name`, `opp_netk` | None (no opponent in career mode) |
| `netk_record` | "-" |
| `game_date` (header) | `"Career MLB (All Seasons)"` or `"Career MLB (2022–2025)"` |
| Percentile pool | Most-recent season at level (= `max(--seasons)` or current year) |

## Known limitations (would-be follow-ups)

1. **AugPop accuracy + bounce% blank.** The throws SQL doesn't surface
   `accuracy_penalty` or `bounce_flag`. `_career_augpop` returns those
   as `None` — those tiles render "—" in the PDF. Fix would be a
   separate AugPop SBA-events career query mirroring `_AUGPOP_SEASON_QUERY`.

2. **Percentile pool defaults to current year.** If `--seasons` is
   omitted, percentile coloring pool uses `datetime.now().year`. If
   that year isn't populated yet (e.g. running in January), coloring
   may render flat. Workaround: pass `--seasons` explicitly to pin
   the pool year.

3. **Setup pages render per-pitcher.** With 15 pitchers, that's a
   thick PDF. To trim, lower `top_n` in `_career_pitchers_caught`.

4. **One level at a time.** `--level mlb` only pools MLB. Doesn't
   accept multi-level (no `level_codes` list). For Salazar's MLB-only
   green card use case this was fine; if a future ask needs e.g.
   "all his AAA + MLB combined", extend the SQL templates to take
   `IN (...)` instead of `=`.

## When to revisit

- Spring training inclusion → would be a `--include-spring` flag (drop
  the `sched_type = 'R'` filter or widen to `('R','S')`).
- Multi-level pooling → see limitation #4.
- App equivalent → if a coach wants to interactively pull career
  catcher reports for any HOU catcher, port the data fetchers into
  `intangibles/src/catcher_data.py` and add a Streamlit page.
  Architecture is straightforward; user has explicitly said this
  won't be used much, so don't preemptively build.

## Related

- `.claude/rules/intangibles.md` — catcher postgame ownership
- `intangibles/scripts/generate_catcher_report.py:_generate_career_report`
  — the orchestrator function
- `intangibles/src/catcher_data.py::compute_netk` /
  `compute_receiving_table` / `compute_throwing_summary` /
  `compute_blocking_summary` — canonical compute helpers reused
- Salazar gc_id `71625` per `pd-goals/data/slack_channels.csv`
