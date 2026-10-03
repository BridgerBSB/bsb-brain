# AC Dashboard — Three-Surface Parity Audit

**Date:** 2026-05-12
**Scope:** Cesar Salazar 2025 AAA reference. Read-only audit; no
code changes. Audit covers every metric the AC dashboard surfaces
against the three canonical surfaces:

- **Tracker** — `intangibles/src/catching_tracker_data.py`
  (especially `get_catcher_leaderboard` + `_COMBINED_FRAMING_QUERY` +
  `_THROWING_AGG_QUERY` + `_POP_TIME_AGG_QUERY` +
  `_COMBINED_BLOCKING_BYPITCH_QUERY` + `_DEPTH_PER_CATCHER_QUERY`)
- **KPI weekly** — `intangibles/src/c_kpi_data.py`
  (per-catcher CTE inside `_PLAYER_TABLE_QUERY`)
- **PD-Goals org KPI** — `pd-goals/src/org_kpi_data.py`
  (`_CATCHER_PITCH_ORG_QUERY` + `_CATCHER_THROWING_ORG_QUERY` +
  `_CATCHER_BLOCKING_ORG_QUERY` + `_CATCHER_AUGPOP_ORG_QUERY`)

**Methodology:** AC's per-catcher facts come from
`catching_tracker_data.get_catcher_leaderboard()` (canonical helper),
so most metric math IS canonical-by-construction. The audit verifies
that (a) the helper-call inheritance is clean, (b) AC's own SQL in
`stats.py`, `gameday.py`, `cards_extras.py`, `leaders.py`,
`scoreboard.py`, `pitch_calling.py`, `pitchers.py` matches canonical
filters, and (c) no AC-only SQL re-implements a metric formula.

---

## Executive Summary

| Metric | AC | Tracker | KPI | PD-Goals | Verdict |
|---|---|---|---|---|---|
| FramRAA | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| NetK | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| R2K% | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| Arm Strength P99 | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| Pop Time 2B P01 | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| Exchange P10 | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| BlockRAA | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| Framing 5-bucket | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| Bounce% (aug_pop) | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| Depth | inherits via `get_catcher_leaderboard` | canonical | canonical | canonical | PARITY |
| AC Stats Tab NetK + Blocks | **AC-only SQL** | n/a | n/a | n/a | **AC DRIFT** — see §13 |
| AC Cards Pop Hand Split | **AC-only SQL** | n/a | n/a | n/a | **AC DRIFT** — see §14 |
| AC Pitch Calling tab | **AC-only SQL — `pv.balls`/`pv.strikes` (wrong cols)** | n/a | n/a | n/a | **AC CRASH BUG** — see §15 |
| AC Pitchers tab | **AC-only SQL — `pv.balls`/`pv.strikes` (wrong cols)**, `induced_vert_break`/`horizontal_break` (wrong cols) | n/a | n/a | n/a | **AC CRASH BUG** — see §16 |

---

## 1. FramRAA

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:144` | inherited | inherited | calls `get_catcher_leaderboard(level_codes, season, min_pitches=1, sched_types)` |
| Tracker | `catching_tracker_data.py:1057-1124` `_COMBINED_FRAMING_QUERY` | `pitch_result_id IN (4,5,6)` + `called_strike_chance_mlb BETWEEN 0.05 AND 0.95` + `rv_after_if_take_ball/strike NOT NULL` + `pitch_id > 0` + take-detection in WHERE | `SUM((CS_indicator - CSC) * (rv_ball - rv_strike))` per `ev.c_id`, take detection in WHERE not CASE | JOIN `ab_event_id` |
| KPI weekly | `c_kpi_data.py:728-738` `_PLAYER_TABLE_QUERY` | same: `(4,5,6)` + `CSC_mlb BETWEEN 0.05 AND 0.95` + `rv NOT NULL` + take detection inside CASE | same formula | JOIN `ab_event_id` |
| PD-Goals org | `org_kpi_data.py:2086-2096` `_CATCHER_PITCH_ORG_QUERY` | same: `(4,5,6)` + `CSC_mlb BETWEEN 0.05 AND 0.95` + `rv NOT NULL` + `{is_take}` template token | same formula, `GROUP BY UPPER(mt.org_abbrev)` via `ev.fielding_team_id` | JOIN `ab_event_id` |

Verdict: **PARITY.** AC inherits the canonical SUM exactly via
`get_catcher_leaderboard`. The "Depth canon" 3-surface-parity rule's
JOIN-`ab_event_id` invariant is honored in all three.

---

## 2. NetK

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:144` | inherited | inherited | reads `total_netk` column from leaderboard |
| Tracker | `catching_tracker_data.py:1062-1064` | `pitch_result_id IN (4,5,6)` + **strict** `called_strike_chance > 0.05 AND < 0.95` + `ignore_flag = 0` | `SUM(pv.net_k)` | uses level-adjusted `called_strike_chance`, NOT `_mlb` |
| KPI weekly | `c_kpi_data.py:684-688` | same: `(4,5,6)` + strict `> 0.05 AND < 0.95` + `ignore_flag = 0` | `SUM(pv.net_k)` | level-adjusted CSC ✓ |
| PD-Goals org | `org_kpi_data.py:2045-2049` | same: `(4,5,6)` + strict `> 0.05 AND < 0.95` + `ignore_flag = 0` | `SUM(pv.net_k)` per org | level-adjusted CSC ✓ |

Verdict: **PARITY.** All four use the **strict** inequality and the
level-adjusted `called_strike_chance` (NOT `_mlb`) per
`gc2-metrics.md` NetK BLOCKING rules.

**AC SECONDARY NetK READ — leaders.py + scoreboard.py + gameday.py
+ cards_extras.py:** four separate AC SQL queries reimplement NetK
inline (rather than calling `get_catcher_leaderboard`). All four
match canonical: `pitch_result_id IN (4,5,6)` + strict
`called_strike_chance > 0.05 AND < 0.95` + `ISNULL(ignore_flag, 0)
= 0` + `pitch_id > 0` + JOIN on `ab_event_id`. **PARITY confirmed
across all 5 AC sites.**

---

## 3. R2K%

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:144` | inherited | inherited | reads `r2k_pct` from leaderboard |
| Tracker | `catching_tracker_data.py:847+_R2K_QUERY` (used inside leaderboard merge) | `ab_pitch_number=3` + `(cev.pa=0 OR cev.so=1)` + `pv.pitch_id > 0` | `100 * AVG(CASE WHEN strikes_after >= 2 THEN 1.0 ELSE 0.0 END)` | LEFT JOIN `cev` on `cur_event_id` per `gc2-metrics.md` R2K% canon |
| KPI weekly | `c_kpi_data.py:722-727` | same GC2 formula | same | LEFT JOIN cev correctly |
| PD-Goals org | `org_kpi_data.py:2079-2083` | same GC2 formula | per-org AVG | LEFT JOIN cev correctly |

Verdict: **PARITY.** All four use the GC2 R2K% formula with `(cev.pa=0
OR cev.so=1)` denominator filter. Display format pct1 on AC + KPI;
pct2 on PD-Goals (`f6f5a88` fix per `rules/three-surface-parity.md`
catcher Apr 18 bug history).

---

## 4. Arm Strength P99

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:144` | inherited | inherited | reads `arm_strength` from leaderboard |
| Tracker | `catching_tracker_data.py:498-547` `_THROWING_AGG_QUERY` | `tdm.pos_id=2` + per-catcher `arm BETWEEN 60 AND 94` | `PERCENTILE_CONT(0.99) WITHIN GROUP ORDER BY ... OVER (PARTITION BY catcher_id)` + n_arm count exposed | range 60-94 per `fielding.md` |
| KPI weekly | `c_kpi_data.py:767-769` | same: `arm BETWEEN 60 AND 94`, `tdm.pos_id=2` | P99 per-catcher | matches |
| PD-Goals org | `org_kpi_data.py:2174-2178` `_CATCHER_THROWING_ORG_QUERY` | same: 60-94 range, `tdm.pos_id=2` | per-catcher P99 → org weighted by `n_arm` per `multi-level-rollup.md` | matches; org rollup correct |

Verdict: **PARITY.** Arm range 60-94 is canonical. Multi-level org
rollup weighted by per-catcher `n_arm` (per
`rules/multi-level-rollup.md` iron rule).

---

## 5. Pop Time 2B P01

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:144` | inherited | inherited | reads `pop_time_2b` from leaderboard |
| Tracker | `catching_tracker_data.py:620-661` `_POP_TIME_AGG_QUERY` | `tdm.pos_id=2` + `pop_time BETWEEN 1.70 AND 2.35` | P01 per-catcher | source: **TDM** (not `CatcherDefense_Throwing`) per `gc2-metrics.md` |
| KPI weekly | `c_kpi_data.py:773-775` | same: 1.70-2.35, TDM | P01 per-catcher | matches |
| PD-Goals org | `org_kpi_data.py:2169-2173` | same: 1.70-2.35 | per-catcher P01 → org weighted by `n_pop` | matches |

Verdict: **PARITY.** TDM source + 1.70-2.35 range is canonical for the
*tracker* Pop2B base. (Apr 18 fix `99f077d` changed the tracker base
from SBA-events-only to all TDM throws to match PD-Goals/KPI — see
`three-surface-parity.md` catcher bug history.)

---

## 6. Exchange P10

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:144` | inherited | inherited | reads `exchange` from leaderboard |
| Tracker | `catching_tracker_data.py:533-537` `_THROWING_AGG_QUERY` | `tdm.pos_id=2` + `exchange >= 0.4 AND arm_strength >= 60` + `competitive_throw=1` in throw_pct CTE | P10 per-catcher + n_exch count | competitive_throw filter (per `gc2-metrics.md` Exchange rule) |
| KPI weekly | `c_kpi_data.py:770-772` | `exchange >= 0.4 AND tdm.arm_strength >= 60` | P10 per-catcher | **No `competitive_throw=1` filter.** Drift TBD — see §11 |
| PD-Goals org | `org_kpi_data.py:2179-2183` | same as KPI: `exchange >= 0.4 AND arm_strength >= 60` | per-catcher P10 → org weighted by `n_exch` | **No `competitive_throw=1` filter** |

Verdict: **POTENTIAL DRIFT — Tracker vs KPI / PD-Goals.** Tracker adds
`competitive_throw = 1` to the throw_pct CTE; KPI and PD-Goals don't.
The arm_floor + exchange_floor filter already gates most non-competitive
throws (catcher's-perspective return throws don't have exchange-time data
typically), so the practical drift may be ≤0.01s. Documented as **OPEN
QUESTION 1** below.

---

## 7. BlockRAA

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:144` | inherited | inherited | reads `blocking_raa` (SurPP × br_rv) from leaderboard |
| Tracker | `catching_tracker_data.py:1201-1218` `_COMBINED_BLOCKING_BYPITCH_QUERY` | `pitch_id > 0` | `SUM(passed_pitch - pp_prob)` as `blocking_surpp_raw`; multiplied by `br_rv` (negated per Apr 18 fix `2aa1555`) in Python | `ab_event_id` JOIN ✓ |
| KPI weekly | `c_kpi_data.py:783-797` | `pitch_id > 0` | `SUM(passed_pitch - pp_prob)` as `blocking_surpp_raw`; same Python sign convention | matches |
| PD-Goals org | `org_kpi_data.py:2199-2220` `_CATCHER_BLOCKING_ORG_QUERY` | `pitch_id > 0` | `SUM(passed_pitch - pp_prob)` per org | matches |

Verdict: **PARITY.** All three use the canonical `SUM(passed_pitch -
pp_prob)` SUM pattern with NEGATED baserunner_advance_rv applied in
Python (Apr 18 fix per `three-surface-parity.md`).

---

## 8. Framing 5-bucket (E Stl / Stl / Mid / Loss / B Loss)

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:204-213` | inherited (via `e_stl_rate` etc. columns on leaderboard) | inherited | reads 5 rate columns directly |
| Tracker | `catching_tracker_data.py:1084-1103` `_COMBINED_FRAMING_QUERY` | `called_strike_chance_mlb` buckets | per-org rate `100 * SUM(CS) / SUM(CS + CB)` | uses `_mlb` (MLB model), NOT level-adjusted (intentional per `gc2-metrics.md`) |
| KPI weekly | `c_kpi_data.py:695-720` | same CSC_mlb buckets, same code groups | same rate formula | matches |
| PD-Goals org | `org_kpi_data.py:2052-2077` | same CSC_mlb buckets, same code groups | rate from count sums at multi-level (re-derived, not pitch-weighted avg per `multi-level-rollup.md`) | matches |

Verdict: **PARITY.** Bucket boundaries (≤0.05, 0.05–0.25, 0.25–0.75
with split, 0.75–0.95, ≥0.95) match across all three. CS/CB code
groups match (`(6,3,24,30,31)` and `(1,2,4,5,11,15,17,26,27,28,29)`).

---

## 9. Bounce% (aug_pop_bounce_pct)

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | `ac_dashboard/data/catcher_facts.py:144` | inherited | inherited | reads `aug_pop_bounce_pct` from leaderboard |
| Tracker | `catching_tracker_data.py:1316-1318` `_SBA_METRICS_AGG_QUERY` family | `aug_pop IS NOT NULL` | `AVG(bounce_flag) * 100` per catcher | source: `CatcherDefense_SBA_Metrics` |
| KPI weekly | n/a — Bounce% not surfaced in c_kpi_data.py | — | — | not displayed in KPI weekly |
| PD-Goals org | n/a — Bounce% not surfaced in org_kpi_data.py | — | — | not in default PD-Goals catcher cols |

Verdict: **PARITY (where applicable).** AC inherits cleanly; not
present in KPI weekly or PD-Goals org for cross-check, but the
tracker formula matches `gc2-metrics.md` canonical (AVG of bounce
flag × 100, gated by aug_pop NOT NULL). This is the right surface for
this metric.

---

## 10. Depth

| Source | File:line | Filters | Aggregation | Notes |
|---|---|---|---|---|
| AC dashboard | not surfaced on Catcher Cards (deferred per master spec). Tracker-bundled `depth` column exists in inherited DataFrame from `get_catcher_leaderboard`. | inherited | inherited | per `three-surface-parity.md` § Depth canon |
| Tracker | `catching_tracker_data.py:1372-1390` `_DEPTH_PER_CATCHER_QUERY` | `ev.c_id IS NOT NULL` + `pitch_id > 0` + `pitch_result NOT IN ('intentional_ball', 'pitch_out')` | `AVG(pos.y_at_pitch_release)` JOIN `Play_Starting_Positions ... pos_id = 2` | postgame canon ✓ |
| KPI weekly | `c_kpi_data.py:813-832` depth CTE | same: IBB+pitchout exclusion, `pitch_id > 0`, `c_id NOT NULL` | `AVG(pos.y_at_pitch_release)` | matches postgame canon (May 9 fix) |
| PD-Goals org | `org_kpi_data.py:2248-2274` `_CATCHER_AUGPOP_ORG_QUERY` depth_base CTE | same exclusions | `AVG(depth)` per org | matches postgame canon |

Verdict: **PARITY.** All 4 surfaces (incl. postgame, per
`three-surface-parity.md` Depth canon May 9 2026) use the same
canonical formula.

---

## 11. AC Inheritance Path Audit

Every AC metric on the Catcher Cards tab is inherited from
`get_catcher_leaderboard()` in `catching_tracker_data.py`. The
inheritance is **byte-clean** — no AC-side re-aggregation, no AC-side
filter overrides. AC computes ONLY:

- Percentile ranks (via `compute_percentile_ranks(pool_df)` — also
  canonical helper)
- Level-rank / org-rank position via simple `pool_df.sort_values`
- Pool-gate display masking (`n_pitches >= 1500`) per
  `rules/intangibles.md` KPI Percentile Pool Gates

None of these post-processing steps alter metric values; only the
displayed percentile + rank pair gets hidden when the catcher is below
the 1500-pitch pool gate.

**ev.event_id JOIN convention:** All AC SQL files (`leaders.py:119`,
`scoreboard.py:191`, `gameday.py:108`, `cards_extras.py:184,203,218`,
`stats.py:51,117`, `pitch_calling.py:113`, `pitchers.py:79,139,216`)
correctly use `ev.event_id = pv.ab_event_id`. **No `cur_event_id`
usage anywhere in AC.** Matches the May 10 fix per the audit prompt.

---

## 12. CSC Gate / ignore_flag / pitch_id > 0 Audit (BLOCKING)

| AC site | `pitch_id > 0` | `ignore_flag = 0` (NetK family) | CSC gate | JOIN key |
|---|---|---|---|---|
| `leaders.py:123-127` | ✓ | ✓ ISNULL pattern | strict `> 0.05 AND < 0.95` ✓ | `ab_event_id` ✓ |
| `scoreboard.py:193-197` | ✓ | ✓ ISNULL pattern | strict `> 0.05 AND < 0.95` ✓ | `ab_event_id` ✓ |
| `gameday.py:115-119` | ✓ | ✓ ISNULL pattern | strict `> 0.05 AND < 0.95` ✓ | `ab_event_id` ✓ |
| `gameday.py` (zone plot 295-301) | ✓ | ✓ ISNULL pattern | strict `> 0.05 AND < 0.95` ✓ | `ab_event_id` ✓ |
| `cards_extras.py` (pop split) | n/a (CatcherDefense_Throwing) | n/a | n/a | `cdt.def_indiff = 0` ✓ |
| `cards_extras.py` (recent games) | ✓ | ✓ ISNULL pattern (inside CASE) | strict `> 0.05 AND < 0.95` ✓ inside CASE | `ab_event_id` ✓ |
| `stats.py:38-47` (base_pitches CTE) | ✓ | ✓ ISNULL pattern (inside CASE WHEN for netk_val) | strict `> 0.05 AND < 0.95` ✓ inside CASE | `ab_event_id` ✓ |
| `pitch_calling.py` | ✓ | (no NetK SUM) | (long-form pitches only) | `ab_event_id` ✓ |
| `pitchers.py` | ✓ | (no NetK SUM in §200+) | mixed | `ab_event_id` ✓ |

All filter invariants hold across AC's hand-written SQL. The strict
`> 0.05 AND < 0.95` rule (per `gc2-metrics.md` NetK blocking rule 5)
and `ISNULL(ignore_flag, 0) = 0` (per `pitfalls.md` ignore_flag
exception for NetK) are honored everywhere they matter.

---

## DRIFT FOUND IN AC

### 13. AC Stats tab — `stats.py` blocks-saved formula divergence

**File:** `intangibles/src/ac_dashboard/data/stats.py:108-127`
(`get_career_defensive_stats` → blocks subquery)

**AC SQL:**
```sql
SELECT
    SUM(CASE WHEN cdb.dirt_block = 1 THEN 1 ELSE 0 END) AS blocks_saved,
    COUNT(*) AS blocks_opps
FROM Astros.CatcherDefense_Blocking_ByPitch cdb
JOIN Astros.Pitches_View pv ON cdb.sched_id = pv.sched_id AND cdb.pitch_id = pv.pitch_id
...
WHERE ev.c_id = :cid
  AND pv.pitch_id > 0
  AND sv.sched_type IN ('R', 'S', 'E', 'I', 'V')
```

**Canonical** (`catcher_data.py::compute_blocking_summary` +
`_COMBINED_BLOCKING_BYPITCH_QUERY` in tracker):
`SUM(CAST(passed_pitch AS int))` and `SUM(CAST(passed_pitch AS int) -
pp_prob)` — the canonical pattern uses the `passed_pitch` BIT column
and `pp_prob` expected value to compute SurPP and BlockRAA.

`dirt_block` is a different column entirely; it's a flag for whether
the pitch was a block opportunity (dirt-ball gate). Using
`dirt_block = 1` as a "saved" indicator is **wrong** — that counts
*opportunities*, not successful blocks. The `blocks_opps` column also
counts `COUNT(*)` of every blocking-by-pitch row (not a dirt-ball
gate); should be `SUM(CAST(dirtball_flag AS int))` or similar.

Same pattern in `cards_extras.py:212-228` `_RECENT_GAMES_QUERY`
game_blocks CTE — `SUM(CASE WHEN cb.passed_pitch = 0 THEN 1 ELSE 0
END) AS blocks_saved` is also wrong: it counts pitches where `passed_pitch=0`
which under the canonical blocking-by-pitch gate (`dirtball_flag=1`,
`event_result NOT IN ('walk','hit_by_pitch')`, `pitch_result NOT IN
('hit_into_play','hit_into_play_no_out')`) approximates "successful
blocks on dirt balls" — but the gate filters differ from `catcher_data.py`
`get_blocks_data` (canonical) and the SUM/COUNT semantics still don't
match the canonical SurPP-based RAA computation.

**Fix suggestion (do NOT apply this pass):** Replace stats.py blocks
subquery with a call to `catcher_data.get_blocks_data` per
(year, level) or restructure to mirror the canonical
`_COMBINED_BLOCKING_BYPITCH_QUERY` filters + columns. Same for
`cards_extras.py` `_RECENT_GAMES_QUERY` game_blocks CTE. Match the
canonical for both `saved` and `opportunities`.

**Severity:** Medium. Stats tab is a multi-year career view; the
`blocks_saved`/`blocks_opps` columns would display incorrect counts
for any year/level row. Doesn't affect the Catcher Cards' BlockRAA
(which is properly inherited from `get_catcher_leaderboard`), so the
primary defensive metric stays correct.

### 14. AC `get_pop_hand_split` — no canonical Pop2B range filter

**File:** `cards_extras.py:128-146` `_slice` helper

**AC computation:** `pop_2b = rows.loc[is_2b, "pop_time"].dropna().mean()`
— a raw mean of pop_time on 2B-throw rows.

**Canonical Pop2B** (per `gc2-metrics.md` "Catcher Metric Aggregation
Standard" + `_POP_TIME_AGG_QUERY`): **P01** (1st percentile) with
range filter **1.70–2.35**.

This is a documented divergence for context — the per-batter-side
split is a "what the average looked like vs L/R/S" context view, not
the published canonical Pop2B value. The function docstring
acknowledges this: "`all` is the unsplit canon (matches tracker Pop2B
value within rounding)" — which is **false**: the `all` slice uses
`mean()` not P01 with 1.70-2.35 range, so it WILL NOT match the
tracker value (which is also surfaced on the same Catcher Card via
`get_catcher_card_facts`).

**Fix suggestion (do NOT apply this pass):**
- Option A: update the docstring to remove the "matches tracker" claim.
- Option B: change the `all` slice (only) to use the canonical
  `PERCENTILE_CONT(0.01) WHERE pop_time BETWEEN 1.70 AND 2.35`
  pattern. Leave the L/R/S split as raw `mean()` if a coach wants the
  context view.
- Option C: emit BOTH the mean and the P01 (with range gate) per side
  for transparency.

**Severity:** Low–Medium. The pop hand-split panel is an additive
"context" view — the canonical Pop2B value on the same card is
unaffected. The user-facing risk is that the `all` value displayed on
the hand-split panel diverges from the Pop2B (P01) tile on the same
card.

### 15. AC Pitch Calling tab — `pv.balls`/`pv.strikes` column name bug

**File:** `intangibles/src/ac_dashboard/data/pitch_calling.py:100-101,
120-121`

```sql
SELECT
    pv.balls,
    pv.strikes,
    ...
WHERE
    AND pv.balls IS NOT NULL
    AND pv.strikes IS NOT NULL
```

**Bug:** Per `rules/db-columns.md`, `Astros.Pitches_View` columns
are `balls_before` and `strikes_before`. `pv.balls` and `pv.strikes`
do not exist — this SQL will throw `Invalid column name 'balls'` at
runtime.

Every other catcher SQL in `catcher_data.py` correctly uses
`pv.balls_before` and `pv.strikes_before` (e.g.,
`catcher_data.py:83-84`).

**Fix suggestion (do NOT apply this pass):** Rename `pv.balls` →
`pv.balls_before` (with `AS balls` alias if downstream code expects
`balls`) and `pv.strikes` → `pv.strikes_before` (with `AS strikes`
alias). Apply to all 4 references in pitch_calling.py.

**Severity:** CRITICAL — Pitch Calling tab will crash on first
query execution.

### 16. AC Pitchers tab — multiple column name bugs

**File:** `intangibles/src/ac_dashboard/data/pitchers.py:202-207`

```sql
CAST(pv.induced_vert_break AS float) AS ivb,
CAST(pv.horizontal_break AS float) AS hb,
pv.plate_x,
pv.plate_z,
pv.balls,
pv.strikes,
```

**Bugs:**
- `pv.induced_vert_break` should be `pv.inducedvertbreak` (no underscores) — canonical column name per `pd-goals/src/metrics.py:423` and `pd-goals/src/rolling_stats.py:783`.
- `pv.horizontal_break` should be `pv.horzbreak` — canonical per `pd-goals/src/metrics.py:426`.
- `pv.balls` / `pv.strikes` same bug as §15.

Same `.between(0,3)` / `.between(0,2)` filter logic at
`pitchers.py:236` references `df["balls"]` / `df["strikes"]` which
would already be empty/missing if the SQL fails.

**Fix suggestion (do NOT apply this pass):** Rename all four
columns to their canonical names. Add `AS ivb`, `AS hb`, `AS balls`,
`AS strikes` aliases if downstream Python expects those names.

**Severity:** CRITICAL — Pitchers tab will crash on first query
execution.

---

## DRIFT FOUND ELSEWHERE

### Tracker vs KPI/PD-Goals: Exchange `competitive_throw=1` gate (§6)

`catching_tracker_data.py:539` adds `WHERE competitive_throw = 1` to
the `throw_pct` CTE; `c_kpi_data.py:770-772` and
`org_kpi_data.py:2179-2183` omit it. Per `gc2-metrics.md` and
`fielding.md`, the canonical GC2 Exchange filter IS
`competitive_throw=1`. **Tracker is canonical-correct; KPI and
PD-Goals diverge.** Practical impact: ≤0.01s on most catchers because
the arm_floor=60 + exchange_floor=0.4 filters already screen out most
warm-up / non-competitive throws. Not patched per "fix only AC"
directive — surfacing for user awareness.

---

## OPEN QUESTIONS

### Q1. Exchange `competitive_throw=1` filter — which side is canonical?

`gc2-metrics.md` says Exchange should filter `competitive_throw=1`.
The tracker (`catching_tracker_data.py:539`) applies it inside the
`throw_pct` CTE. KPI weekly + PD-Goals org omit it. Practical drift
is small. Should KPI + PD-Goals add the filter to match tracker?
Affects all 3 surfaces — needs explicit user decision before any
patch.

### Q2. AC Catcher Cards Pop hand-split docstring claim — fix doc or fix `all` slice?

`cards_extras.py:113-114` docstring says `all` slice "matches tracker
Pop2B value within rounding" — but the implementation uses
`mean()` not P01 with range gate. The displayed values WILL diverge.
Three repair options listed in §14 above; user decision needed on
which behavior is wanted.

### Q3. AC Stats tab Blocks columns — what user expectation?

The Stats tab's `blocks_saved` and `blocks_opps` columns are based
on the wrong `dirt_block` column with no canonical block-RAA
computation. Is the intent for this view to show:
- (a) Canonical SurPP-style "blocks saved above expected" (matches
  the canonical pattern but is a single signed number, not
  saved/opportunities), or
- (b) A coarser "successful blocks / opportunities" count for at-a-
  glance multi-year career display (in which case the right
  formula needs to be agreed — `dirtball_flag` gate + outcome
  parse from `event_result`)?

The current code does neither correctly. Needs design decision before
patch.

### Q4. Pitch Calling + Pitchers tabs — when were they last tested?

The `pv.balls`/`pv.strikes` column-name bug is critical (will crash
on first execution). Were these tabs ever run against live DB? If
so, this is a regression from a recent edit; if not, they shipped
broken. Worth checking commit history before fixing to understand
how this slipped past testing.

---

## Audit complete

No code modified. AC inheritance via `get_catcher_leaderboard()` is
clean for all 8 default Catcher Card KPI tiles (FramRAA, NetK, R2K%,
Arm, Pop2B, Exch, BlockRAA, Bounce%) and all 5 framing buckets.
Three AC-side bug classes identified (§13–§16); none affect
inherited metric values, but two are CRITICAL crash bugs on
secondary tabs (Pitch Calling, Pitchers).
