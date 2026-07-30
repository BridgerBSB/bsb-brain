---
paths:
  - "**/*kpi*.py"
---
# KPI Weekly — Active-Roster Season Table Filter (BLOCKING)

## What this rule covers

The Season table on every KPI weekly report displays only HOU players who
are CURRENTLY rostered at that affiliate level per `MLB_eBis.PP_MASTER`.
Players who played at the level but moved away (e.g. AAA→MLB callup) keep
contributing to **stats**, **percentile pools**, **chart lines**, **rank
boxes**, and **cards** — they just don't appear as a row in the Season
table.

Six surfaces affected. One pattern. Apr 27 2026 boss request.

**Pairs with `kpi-weekly-charts.md`** (chart-line mechanics) and
`three-surface-parity.md` (parity invariants). This rule is about display-
layer filtering, not metric math.

---

## What gets filtered, what doesn't (BLOCKING)

This is the most important thing to get right. If you filter the wrong
layer, you silently break percentile pools and three-surface parity.

| View | Filtered by current roster? | Why |
|---|---|---|
| **Season table rows** | YES — only currently rostered HOU players show | What the user/coach sees at the affiliate level |
| **L2W (2-week span) table rows** | NO — unfiltered | Recent activity reflects whoever played, even if just promoted/demoted |
| **Chart line** | NO — unfiltered | Org rollup needs every fielder/hitter/pitcher who played at the level |
| **Rank box at month-end** | NO — unfiltered | Same reason |
| **Card / season-to-date** | NO — unfiltered | Pulls from unfiltered org pool |
| **Percentile coloring on L2W table** | NO — pool built from full season_df | Coloring would go wrong if calibrated against shrunk pool |
| **Tracker app** | NO — unfiltered | Tracker has its own scope semantics |
| **PD Goals org KPI report** | NO — unfiltered | PD Goals uses tracker pool, not KPI weekly Season filter |
| **Postgame reports** | NO — unfiltered | Postgame is per-game, not per-affiliate |

**The filter touches ONE layer: `season_df` rows in
`get_player_tables_for_level`. Everything else stays untouched.**

---

## Where to put the filter (BLOCKING — common bug location)

In each `*_kpi_data.py` module's `get_player_tables_for_level` function.
Apply the filter **AFTER** `apply_season_percentiles()` runs, NOT before.

```python
def get_player_tables_for_level(level_code, season, ...):
    with ThreadPoolExecutor(max_workers=2) as pool:
        season_future = pool.submit(get_player_table_data, level_code, season, None, None, ...)
        span_future   = pool.submit(get_player_table_data, level_code, season, start_date, end_date, ...)
        season_df = season_future.result()
        span_df   = span_future.result()

    # 1) Use FULL season_df to compute percentile distribution for L2W coloring
    if not span_df.empty and not season_df.empty:
        span_df = apply_season_percentiles(span_df, season_df, TABLE_METRIC_KEYS)

    # 2) THEN filter season_df display rows by current roster (Apr 27 2026)
    if not season_df.empty and "<id_col>" in season_df.columns:
        roster_ids = get_active_roster_ids(level_code, season)
        if roster_ids:
            season_df = season_df[
                season_df["<id_col>"].isin(roster_ids)
            ].reset_index(drop=True)

    return season_df, span_df
```

**Order matters.** If you filter season_df BEFORE
`apply_season_percentiles`, the L2W table's percentile coloring is built
from a shrunk pool — every player without a current roster spot drops
out of the distribution, percentile ranks shift up, recently-promoted
players get over-bright colors. Don't do that.

---

## ID column per report

| Report | Module | ID column for filter |
|---|---|---|
| Barrelsville hitter | `barrelsville/src/hitter_kpi_data.py` | `batter_id` |
| Arm Farm pitcher | `bullpen-report/src/pitcher_kpi_data.py` | `pitcher_id` |
| Intangibles OF | `intangibles/src/of_kpi_data.py` | `fielder_id` |
| Intangibles IF | `intangibles/src/if_kpi_data.py` | `fielder_id` |
| Intangibles BR | `intangibles/src/br_kpi_data.py` | `runner_id` |
| Intangibles Catcher | `intangibles/src/c_kpi_data.py` | `catcher_id` |

---

## The roster helper — `get_active_roster_ids(level_code, season)`

Lives in each app's `database.py` (three copies — one per worktree). Takes
an MLBAM SPORT level code (`mlb`, `aaa`, `aax`, `afa`, `afx`, `rok`, `dsl`),
returns a `frozenset` of `groundcontrol_id` values for HOU players
currently rostered at that level.

### Level code mapping (MLBAM SPORT → PP_MASTER LEVELOFPLAY_LK)

| MLBAM SPORT (chart layer) | PP_MASTER LEVELOFPLAY_LK |
|---|---|
| `mlb` | `ml` |
| `aaa` | `3a` |
| `aax` | `2a` |
| `afa` | `1a` |
| `afx` | `1f` |
| `rok` | `r` |
| `dsl` | `ds` |

The KPI report code uses MLBAM SPORT codes everywhere; PP_MASTER stores
LEVELOFPLAY_LK as 2-character abbreviations. The helper does the mapping
internally — callers only pass the MLBAM code.

`LEVELOFPLAY_LK` returns UPPERCASE (per `db-columns.md`) — always
`.strip().lower()` before comparing. The helper handles this with
`LOWER(pm.LEVELOFPLAY_LK) = :pp_level`.

### Active roster status filter

```sql
WHERE LOWER(pm.LEVELOFPLAY_LK) = :pp_level
  AND pm.ORG_LK = 'hou'
  AND pm.EMPLOYEE_FLG = 0
  AND COALESCE(pm.MNROSTERSTATUS_LK, pm.MJROSTERSTATUS_LK)
      NOT IN ('rel', 'fa', 'vol', 'dis', 'ti',
              'RES', 'REL', 'FA', 'VOL', 'DIS', 'TI', 'res')
```

This matches `pd-goals/src/roster.py` (Alvaro's canonical roster query).
**Don't reinvent — copy this filter exactly.** The double-cased exclusions
catch upper- and lower-case variants since PP_MASTER status values are
inconsistent.

`COALESCE(MN, MJ)` — minor-league status takes precedence; falls back to
major-league status if minor is null.

### Failure mode

The helper wraps the query in `try/except` and returns `frozenset()` on
any error. Callers check `if roster_ids:` — if empty, NO filter is
applied (full season_df returned). This means:

- DB error during roster lookup → KPI report still generates, just shows
  every player who played (the pre-Apr-27 behavior). No crash.
- Unknown level code → empty set → no filter.
- Roster genuinely empty for that level → empty set → no filter
  (defensive: better to show everyone than show nothing).

---

## What about a player going up and coming back down?

Per the user spec (Apr 27 2026): "make sure that player were to have all
the ABs for that year — but the players who are actually listed are the
only ones to show up in the Season table."

Interpretation:

- **Stats column** = level-specific stats only (current behavior). Pena's
  AAA Season row shows his AAA-only ABs/throws/plays. MLB time doesn't
  bleed in.
- **Display row** = present if-and-only-if currently rostered at that
  level per PP_MASTER right now.

So Pena MLB→AAA: appears in AAA Season table with his AAA-only stats.
Dezenzo AAA→MLB: doesn't appear in AAA Season table; his AAA stats
still feed the AAA org rollup, percentile pool, chart line. Chart line
still has him; rank box for AAA includes him in the pool; he's just not
listed as a row.

This is the simpler interpretation. Don't try to merge cross-level stats
into one row — that would change the metric definition and break
three-surface parity.

---

## Three-surface parity (BLOCKING)

The roster filter is **strictly local to KPI weekly Season table display**.

Per `three-surface-parity.md`, every catcher/OF/IF/BR metric lives in 3
surfaces (tracker, KPI weekly, PD-Goals org KPI). All three should keep
producing the same numerical values. The filter is OUTSIDE that
invariant — it's just hiding rows from the KPI weekly Season table.

If a future change accidentally pushes the filter into:

- the chart-data fetch (`get_kpi_chart_data`)
- the percentile pool computation
- `get_org_cumulative_ranks` / `get_org_month_rank`
- the tracker module (`fielding_tracker_data.py`, etc.)
- PD-Goals org KPI (`pd-goals/src/org_kpi_data.py`)

→ that's a parity break. Three-surface parity will fail. Don't.

---

## Implementation playbook for a NEW report's roster filter

When adding a new KPI weekly-style report to any worktree:

1. **Add the helper to that app's `database.py`** if it's not already
   there. Copy from any of the three existing apps verbatim.
2. **Identify the ID column** in `get_player_tables_for_level`'s
   season_df output (`batter_id` / `pitcher_id` / `fielder_id` / etc.).
3. **Insert filter after `apply_season_percentiles()`** in
   `get_player_tables_for_level`, BEFORE the `return`. Use the canonical
   block from this rule.
4. **Don't touch `span_df`** — span table stays unfiltered.
5. **Don't touch chart-data, ranks, or pool computation** — three-surface
   parity protected.
6. **Verify** by generating a report for AAA when a known player has
   been promoted to MLB. They should disappear from the Season table.
   Their stats should still flow into the chart line / rank box.

---

## What NOT to do

- **Don't apply the filter inside `get_player_table_data`** — that
  shrinks the SQL pool, breaks the L2W percentile pool, and means you
  can't recover the unfiltered season for chart aggregation. Filter
  ALWAYS at the `get_player_tables_for_level` layer, AFTER pool
  computation.
- **Don't filter span_df** — recently promoted/demoted players SHOULD
  appear in the L2W table. The user explicitly said "ONLY SEASON."
- **Don't push the filter into the chart layer** — chart line, rank
  box, card all use the full unfiltered org pool.
- **Don't push the filter into tracker / PD-Goals / postgame** — the
  filter is local to KPI weekly Season tables.
- **Don't reuse `pd-goals/src/roster.py`'s `get_roster()` directly** —
  that returns full per-player metadata (photos, position categories,
  etc.) and joins on additional columns. The KPI helper is intentionally
  minimal: just `groundcontrol_id` set, fast, no metadata.
- **Don't crash on roster lookup failure** — return `frozenset()` and
  fall through to unfiltered display. KPI reports must keep generating.
- **Don't hardcode the inactive-status list separately in each app** —
  it lives in `database.py` as `_INACTIVE_ROSTER_STATUSES`. If you need
  to add a new status (e.g., a new IL code), update all 3 apps in lockstep.
- **Don't forget the `LOWER()` wrapping on `LEVELOFPLAY_LK`** —
  PP_MASTER stores it uppercase but the param is lowercase. See
  `db-columns.md` PP_MASTER section.
- **Don't add the filter to scripts/CLI tools that bypass
  `get_player_tables_for_level`** — only the report generators use that
  function. If a CLI computes its own per-player table, decide
  separately whether the roster filter applies.

---

## Bug history

- **Apr 27 2026** — Initial implementation. Boss request: "stats stay
  the same — only the players actually rostered show up in the Season
  table." Six reports patched in one pass:
  - `barrelsville/src/database.py` + `hitter_kpi_data.py` — commit `8caf403`
  - `bullpen-report/src/database.py` + `pitcher_kpi_data.py` — commit `fc957ae`
  - `intangibles/src/database.py` + `of_kpi_data.py` + `if_kpi_data.py`
    + `br_kpi_data.py` + `c_kpi_data.py` — commit `ac22ba1`
  - Verified Dezenzo (gc_id 1305158, AAA→MLB) drops from AAA Season
    table while keeping his AAA stats in the org rollup.

---

## Cross-references

- `kpi-weekly-charts.md` — chart-line implementation across the same 6 reports
- `three-surface-parity.md` — parity invariants (this filter is OUTSIDE the invariant)
- `db-columns.md` — PP_MASTER column reference, level code mappings, `LEVELOFPLAY_LK` uppercase quirk
- `pd-goals/src/roster.py` — canonical roster query (Alvaro's pattern)
- `kpi-parallelization.md` — `get_player_tables_for_level` P2 parallelization
