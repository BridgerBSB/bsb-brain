# Advance Opponent Selection — Date Window, NOT Series Count (BLOCKING)

All advance reports (hitting / pitching / fielding) decide WHICH opponents
to scout for the upcoming week. The window MUST be **date-based (next N days,
default 7)** and return **every opponent in that window** — NOT "next N series."

Created Jun 23 2026 after the bug below shipped to production.

---

## The bug (don't reintroduce)

`get_upcoming_series(level, season, num_series=N)` slices by **opponent count**
(`all_series[:num_series]`, where a "series" = consecutive games vs one opponent).

- Full-season affiliates (AAA/AA/A+/A): one 6-game series = the whole week →
  `num_series=1` is correct.
- **FCL / DSL / MLB**: play multiple **single games vs DIFFERENT opponents** in a
  week. `num_series=1` grabs only the FIRST opponent and silently drops the rest —
  so those affiliates got ONE advance when they faced 3-4 teams.

Someone "shrank the lookahead to one week" by setting `--series 1`, which is the
WRONG unit (opponents, not time). In barrelsville it was worse: `--series` defaulted
to `1` (truthy), so `if not args.series and args.days` was dead code and the existing
`--days` window never ran.

## The fix / pattern

- Batch scripts default `--series 0` (manual override only) + `--days 7`.
- Fetch extra series (e.g. 10), then filter by the date window:
  ```python
  fetch_count = args.series if args.series else 10
  series_list = get_upcoming_series(level, season, num_series=fetch_count)
  if not args.series and args.days and series_list:
      cutoff = date.today() + timedelta(days=args.days)
      series_list = [s for s in series_list if s["series_start"] <= cutoff]
  ```
- **`run_monday.ps1` passes `--days 7`, NEVER `--series 1`** on the 3 advance steps.
- Result: full-season → 1 opponent/week (unchanged); FCL/DSL/MLB → ALL opponents that week.

## Per-worktree sites

| Worktree | Batch script | Data fn |
|---|---|---|
| Barrelsville (hitting) | `scripts/generate_advance_batch.py` | `src/advance_data.py::get_upcoming_series` |
| Arm Farm (pitching) | `scripts/generate_advance_pitching_batch.py` | `src/advance_pitching_data.py::get_upcoming_series` |
| Intangibles (fielding) | `scripts/generate_hitter_advance.py` + `generate_of_positioning.py` | `src/hitter_advance_data.py::get_upcoming_series` |
| Orchestrator | `pd-goals/scripts/run_monday.ps1` (advance-hitting / -pitching / -fielding steps) | — |

## What NOT to do

- **Don't pass `--series 1` anywhere** (cascade or manual) — it's an opponent count, not a week.
- **Don't default `--series` to a truthy value** — it disables the date window (dead-code trap).
- **Don't add a date window to ONE worktree only** — all 3 advance systems must match.
- To run multiple levels in one shot: `--level dsl rok` (DSL + FCL). FCL = `rok`, DSL = `dsl`.
