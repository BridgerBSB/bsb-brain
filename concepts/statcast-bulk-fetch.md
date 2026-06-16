---
type: concept
domain: data
source: personal-bsbres/examples
created: '2026-06-15'
---
# Statcast Bulk Fetch + Retry Pattern

The `pybaseball` historical-pull pipeline in `personal-bsbres/examples/` — three
scripts that demonstrate fetching full-season Statcast (Baseball Savant) data,
saving per-season CSVs, and recovering from the API's notorious large-range
flakiness via progressive chunking. This is the **public/Savant-side analog** of
the internal GroundControl2 spine; same shape, different source.

Source files:
- `run_pybsb.py` — single-season example (2024 → today), the "hello world"
- `fetch_historical_statcast.py` — the bulk multi-season driver (2020–2024)
- `retry_failed_seasons.py` — the resilience layer (chunked + monthly fallbacks)

---

## `run_pybsb.py` — the canonical single-season fetch

The teaching example. Pattern:

1. **Enable caching** — `from pybaseball import statcast, cache; cache.enable()`.
   This is the single most important line — it lets repeated runs skip
   already-downloaded date ranges (Savant pulls are slow and rate-limited).
2. **Define range** — `season_start = '2024-03-28'` (Opening Day) to `yesterday`
   (`datetime.today() - timedelta(days=1)`).
3. **Fetch** — `df = statcast(start_dt=season_start, end_dt=yesterday)`. One call
   returns every pitch in the range across all 30 teams.
4. **Guard empties** — `if df.empty: return` with a warning.
5. **Save** — `df.to_csv('../data/samples/statcast_2024_sample.csv', index=False)`.
6. **Explore** — prints row/col counts, date range, memory usage, then computes
   sample metrics inline: avg exit velo (`df['launch_speed'].mean()`), hard-hit
   rate (`(df['launch_speed'] >= 95).mean()`), barrel rate (`df['barrel'].mean()`),
   unique teams, and a `.head(3)` preview of key columns
   (`game_date, player_name, pitch_type, release_speed, launch_speed,
   launch_angle, hit_distance_sc, events, estimated_woba_using_speedangle, barrel`).
7. **Error handling** — try/except prints troubleshooting tips (check connection,
   smaller date range, `cache.purge()`).

This is the reference for how every downstream personal project starts its data
layer: `statcast()` → clean → metric. See [[statcast-pipeline]] for the broader
spine.

---

## `fetch_historical_statcast.py` — bulk multi-season driver

Pulls **2020–2024 regular seasons** as separate CSVs. Key design choices:

- **Hardcoded season date ranges** as a dict, regular-season only — explicitly
  accounting for the COVID-shortened 2020 (Jul 23 – Sep 27, 60 games):
  ```python
  seasons = {
      2020: ('2020-07-23', '2020-09-27'),  # shortened COVID season
      2021: ('2021-04-01', '2021-10-03'),
      2022: ('2022-04-07', '2022-10-05'),
      2023: ('2023-03-30', '2023-10-01'),
      2024: ('2024-03-28', '2024-09-29'),
  }
  ```
- **Per-season loop** with timing (`time.time()` deltas reported in minutes),
  empty-guard, save to `../data/samples/mlb_{year}.csv`, file-size report.
- **Per-season stats printout** — record count, team count, hit rate
  (`df['events'].isin(['single','double','triple','home_run']).sum()`).
- **Rate-limit politeness** — `time.sleep(30)` between seasons.
- **Keep-going semantics** — any season's exception is caught and the loop
  continues; a final summary reports `successful_downloads/total_seasons`.
- **Interactive confirmation gate** — `input("Do you want to continue? (y/N)")`
  at module bottom, warning each season is 200–500 MB / 10–30 min, total 1–3 hrs.

The cache (`cache.enable()`) means a re-run skips already-downloaded seasons,
so the script is safely re-runnable after a partial failure.

---

## `retry_failed_seasons.py` — the resilience layer (the interesting part)

Savant chokes on large date ranges (timeouts, malformed `game_date` parsing — the
2022 and 2024 seasons were the documented failures). This script is a **graduated
fallback ladder** for recovering exactly those failed seasons. The strategy
escalates only as needed:

1. **Skip-if-exists** — if `mlb_{year}.csv` already exists, count it as success
   and skip (idempotent re-runs).
2. **Straight retry** — try `statcast(start, end)` for the whole season first.
3. **Quarterly chunks** (`download_in_chunks`) — on empty result, split the season
   into 3 ranges (start→Jun 30, Jul 1→Aug 31, Sep 1→end), pull each, `pd.concat`
   the non-empty ones, with `time.sleep(10)` between chunks.
4. **Retry-with-cache-purge** (`download_with_retry`) — up to 3 attempts; on each
   retry after the first, `cache.purge()` + `time.sleep(5)`, then `time.sleep(60)`
   between attempts. Targets transient parsing issues.
5. **Monthly chunks** (`download_monthly_chunks`) — the finest granularity, used
   specifically when the exception message contains `"game_date"` for 2022. Walks
   month-by-month using `calendar.monthrange` to get each month's last day, pulls
   each month separately with `time.sleep(15)`, `pd.concat`s the results. This is
   the nuclear option for a season that won't come down any other way.
6. **Data cleaning before save** — `df['game_date'] = pd.to_datetime(df['game_date']).dt.strftime('%Y-%m-%d')`
   to normalize the very column that caused the parsing failures.

The error-type branching is the clever bit: it inspects `str(e)` and the year to
pick the right fallback (`"game_date" in str(e) and year == 2022 → monthly chunks`),
rather than blindly retrying. Final summary lists all five years' file status.

---

## Key columns / metrics surfaced

Statcast columns the scripts reference (Savant schema): `game_date`,
`player_name`, `pitch_type`, `release_speed`, `launch_speed`, `launch_angle`,
`hit_distance_sc`, `events`, `estimated_woba_using_speedangle`, `barrel`,
`home_team`. Derived inline: **avg exit velo**, **hard-hit rate** (`launch_speed
>= 95`), **barrel rate**, **hit rate** (single/double/triple/HR over PAs).

---

## Reusable lessons

- **`cache.enable()` first, always.** It's what makes multi-hour bulk pulls and
  retries survivable.
- **Chunk down progressively** (season → quarter → month) rather than one giant
  range — the Savant API's failure rate scales with range size.
- **Branch on the exception text + year** to pick the right fallback instead of a
  blind retry loop.
- **Idempotent skip-if-exists** + per-season CSVs = safe re-runnable backfill.
- **Politeness sleeps** (10–30 s between pulls) keep you off the rate limiter.
- Normalize `game_date` on the way out — it's the recurring parse-failure column.

## Links
- [[MOC-baseball-analytics]]
- [[statcast-pipeline]] — the broader data spine these feed
- [[advanced-modeling-setup]] — the model repos that consume this Statcast data
- [[stuff-plus-4s-pitching]] — public pitch models trained on Statcast 2020–2023
- [[personal-bsbres]] — the repo this lives under
