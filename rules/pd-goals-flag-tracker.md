# PD Goals — PD Flag Tracker — CLI Sibling

> **Extracted from `pd-goals.md` 2026-05-19** to keep the parent rule under
> the article-recommended discoverability threshold. See parent for
> `## PD Flag Tracker — CLI Sibling` pointer. Auto-loaded with the parent on any
> Python edit in `pd-goals/`.

---

## PD Flag Tracker — CLI Sibling (LIVE Apr 26, 2026 — IN ITERATION)

Standalone CLI in the `pd-goals/` worktree that emits a weekly L2W
(last-2-weeks) drift PDF + Slack delivery for every HOU MiLB player.
Compares each player's L2W metric averages to their **own season-to-date**
baseline (player_season — same convention across every metric as of
Apr 27 2026 fix; the original Phase 1 league_level Damage% baseline
was reverted).

### Files (5-file touchpoint pattern — keep in sync)

| Role | File |
|---|---|
| Threshold + direction + gate config | `pd-goals/src/drift_thresholds.py` |
| Hitter SQL + dispatcher | `pd-goals/src/drift_hitting.py` |
| Pitcher SQL + dispatcher | `pd-goals/src/drift_pitching.py` |
| BR SQL + dispatcher (May 10 2026) | `pd-goals/src/drift_br.py` |
| Catcher SQL + dispatcher (May 10 2026, NetK only) | `pd-goals/src/drift_catcher.py` |
| CLI / PDF render / Slack delivery | `pd-goals/scripts/drift_alert.py` |
| Design doc | `docs/plans/2026-04-26-pd-drift-alert-design.md` |
| Live status + open thresholds | `memory/pd-flag-tracker-status.md` |

When changing ANY metric, ALL THREE of these need to stay in sync:
1. `drift_thresholds.py` — config dict (label, threshold, gate, direction, higher_better, unit, fmt)
2. The domain SQL module (`drift_hitting.py` / `drift_pitching.py` / `drift_br.py` / `drift_catcher.py`) — SQL computation + entry in `metric_map` dispatcher
3. `drift_alert.py` — glossary entry in `_build_glossary` (per-metric one-liner) + section render + CSV writer + stdout summary

### Layout invariants (BLOCKING)

- **Window:** L2W (`ROLLING_WINDOW_DAYS = 14`). Bumped from 7 on Apr 27 2026 — bigger sample for thin-PA hitters / 1-start pitchers.
- **Page:** Each section (Pitching, Hitting, **Baserunning, Catcher**) splits side-by-side **Good (left, green) ‖ Bad (right, red)** at ~48% width each.
- **Chunked:** ≤25 rows per side per chunk. Reportlab outer Tables can't split across pages within a cell, so emit multiple outer Tables (one per chunk) and let platypus break between them. See bug history in commit `b6c40c7`.
- **Headers on first chunk only:** column header + Good/Bad sub-header render once per side; continuation chunks just stream rows. `show_header=False` in `_build_flag_table`.
- **Column header:** `Player ‖ Level ‖ Metric ‖ <Baseline> ‖ <Current> (n) ‖ Δ` where baseline/current labels vary by mode (`Season ‖ L2W` for weekly, `<from_year> ‖ <to_year>` for YoY — May 10 2026 mode-aware header swap).

### Metric coloring rules (BLOCKING)

`_delta_color(higher_better, delta)` in `drift_alert.py` decides Δ color:
- `higher_better=True, delta > 0` → green; `delta < 0` → red
- `higher_better=False, delta > 0` → red; `delta < 0` → green
- `higher_better=None` → ALWAYS red (mechanical drift = always concerning)

Metrics flagged with `higher_better=None` (always red): Release ht/side, Extension, Attack angle, VBA*, Loft*, Tilt*, Swing%. The asterisks in the glossary are explained ONCE in the methodology footer: *"\* drift may be a deliberate mechanical adjustment (e.g. attack-plane vs specific pitch shapes)"* — keep that pattern; don't bloat per-metric one-liners with the same caveat.

### `_is_good_flag` for the Good/Bad split

A flag goes to the **Good** column iff `_is_good_flag(flag) == True`, which mirrors `_delta_color`'s logic:
- mechanical drift (`higher_better=None`) is NEVER good (always Bad column, always red Δ)
- otherwise good iff Δ moves in the favorable direction for that metric

### YoY mode (May 10 2026) — `--yoy` flag for intervention candidates

`get_pitching_drift()` and `get_hitting_drift()` both accept `mode="yoy"`
+ `from_year` + `to_year` kwargs. Compares full from-year baseline vs
to-year YTD current. Same metrics, thresholds, Good/Bad split, sort key
as weekly mode — just swaps the window.

**CLI usage:**
```bash
python pd-goals/scripts/drift_alert.py --yoy --csv out.csv --deliver
# defaults: from_year=current-1, to_year=current. Override with
# --from-year YYYY --to-year YYYY.
```

**Volume gates:** Use `drift_thresholds.get_volume_gate(metric_key, mode)`
not `cfg["volume_gate"]` directly. In YoY mode, gates from
`YOY_VOLUME_OVERRIDES` apply — 50 PA / 300 P (matches PD Goals pool
gates per user May 10 2026 spec). L2W gates would way overflag.

**Implementation differs by domain (one-time, ok to keep):**
- Pitching: 4 parallel YoY query strings (`_PITCHER_*_QUERY_YOY`). Single-pass
  two-year scan with year-bucketed CASE WHEN. Same column names as weekly
  (`season_*`, `week_*`) so the aggregation loop is shared.
- Hitting: run-twice approach in `_get_hitting_drift_yoy()` — calls
  existing weekly queries twice with full-year week ranges (Jan-Dec from_year
  + Jan-today to_year), merges `week_X` cols across runs. Avoided duplicating
  the 1000+ lines of hitting SQL.

**v1 coverage gaps + closures (status as of May 10 2026):**
- **CLOSED:** Slack column header / subtitle / glossary all now mode-aware.
  YoY runs render `2025 ‖ 2026 (n)` headers + `YoY: 2026 YTD vs 2025
  full season ...` subtitle.
- **CLOSED:** Catcher domain — new `drift_catcher.py` ships NetK (Sam's
  Arturo Flores intervention example). Only NetK for v1; Pop2B / AugPop /
  FramRAA / BlockRAA stay in the catcher weekly KPI report by design.
- **CLOSED:** BR domain — new `drift_br.py` ships 1B PL + 2B PL. Mirrors
  the canonical `intangibles/src/br_tracker_data.py` SQL pattern (LEFT
  JOIN nbo_2b / nbo_3b for next-base-occupied gate, NOT NOT-EXISTS —
  see `pitfalls.md` error 130).
- **CLOSED:** Roster filter — `MLB_eBis.PP_MASTER` JOIN (Alvaro pattern)
  added to every active-CTE so released/traded players (Willingham,
  Sanchez) no longer leak.
- **Open:** Hitting gcOBA in YoY mode — still deferred. Multi-component
  Python aggregation needs more refactor for year-mask. Weekly mode
  computes it normally.

**CSV export** (`--csv PATH`): one row per `(player, metric)` flagged.
Columns: `domain, player, level, id, metric, baseline_label,
baseline_value, current_label, current_value, current_n, delta,
direction, is_good, fmt, unit`. Sortable in Excel; Sam pastes top
rows into coordinator-meeting notes.

**Weekly path completely untouched.** `mode="weekly"` is the default
for both entry points; existing CLI invocations + the Connect schedule
(if/when wired) work unchanged.

### Future direction (the "may become an app" piece)

Today this is CLI-only — no Streamlit page, no pin, no in-app interaction. The data layer (`drift_hitting.py` / `drift_pitching.py`) is already written as importable functions returning `FlaggedMetric` / `HitterFlaggedMetric` dataclasses, so when we wire it to a Streamlit page later:

- `pages/5_PD_Flag_Tracker.py` (or similar) imports `get_pitching_drift()` + `get_hitting_drift()`
- App page renders the same Good/Bad split as Plotly tables (no PDF render needed in-app)
- Optional: pin the flagged-metrics DataFrame daily so the app is fast vs. running the SQL on every page load
- CLI stays as the Slack-delivery path; the app is the interactive review path

When that happens, follow the `in-app-submission.md` pattern for the pin layer (parquet pin + `goals_loader`-style cached read) and the `tracker-parquet-pins.md` pattern if a per-day or per-week pin makes sense.

### Domain modules + canonical patterns (BLOCKING)

Each domain module (`drift_br.py`, `drift_catcher.py`, `drift_fielding.py`)
**MUST mirror the affiliate-tracker / postgame SQL pattern verbatim.** Years of
T-SQL pitfall corrections are baked in there. See `feedback_mirror_canonical_br_fielding_patterns.md`
in memory and `rules/reference-impl-index.md` for the canonical pointers per
domain.

- BR canonical: `intangibles/src/br_tracker_data.py` (LEFT JOIN nbo_2b/nbo_3b
  for next-base-occupied gate, 5.0 ft floor + 20.0 ft ceiling on 1B PL,
  25.0 ft ceiling on 2B PL per data-cleaning.md §2)
- Catcher canonical: `intangibles/src/catching_tracker_data.py` (NetK SUM
  pattern with strict CSC > 0.05 AND < 0.95, pitch_result_id IN (4,5,6),
  ignore_flag = 0, pv.net_k column directly per gc2-metrics.md NetK rules)
- Fielding canonical: `intangibles/src/fielding_tracker_data.py` + the
  per-play helper `pd-goals/src/rolling_stats.py::_fielding_per_play`
  (6-term Tier 1 gate per fielding.md, arm range filter, TopSpd ≤ 34 cap)

### Roster filter (BLOCKING — May 10 2026)

Every `active_*` CTE across all drift modules JOINs `MLB_eBis.PP_MASTER`
via the Alvaro pattern:
```sql
JOIN Astros.Players rpl ON rpl.groundcontrol_id = pv.<pitcher_id|batter_id>
JOIN MLB_eBis.PP_MASTER rpm ON rpm.player_id = rpl.ebis_id
WHERE ...
  AND rpm.ORG_LK = 'hou'
  AND rpm.EMPLOYEE_FLG = 0
  AND COALESCE(rpm.MNROSTERSTATUS_LK, rpm.MJROSTERSTATUS_LK)
      NOT IN ('rel','fa','vol','dis','ti','RES','REL','FA','VOL','DIS','TI','res')
```

Source pattern: `pd-goals/src/roster.py`. Same filter as KPI weekly Season
tables (`kpi-roster-filter.md`). Released/traded players no longer leak
into flags. 17 active-CTE blocks share this gate (3 added May 21 2026
for `drift_fielding.py`: weekly query, YoY query, name-level lookup).

### Current flag inventory (May 10 2026 — full)

**Pitching** (`drift_pitching.py`): FB velo, FF velo, SL velo, CH velo, K%,
BB%, Release height, Release side, Extension, InZ% overall, 0-0 InZ%
(FPinZ%), R2K%, GB%, HH% allowed, per-PT SRV (FF/FT/SI/SL/FC/CH/CU/FS),
per-PT Whf% (same 8), per-PT InZ% (same 8).

**Hitting** (`drift_hitting.py`): Bat speed, Attack angle, VBA, Loft,
Tilt, SwDec, Damage%, gcOBA, Hitter Whiff%, Swing%, OSw%, PoC.

**BR** (`drift_br.py`): 1B PL, 2B PL.
- ±1.0 ft (raised from 0.7 May 10 2026 after first real run).
- ≥10 base-pitches in window.
- 1B PL: 5.0 ft floor + 20.0 ft ceiling. 2B PL: 25.0 ft ceiling.
  Per data-cleaning.md §2 (HawkEye glitch guards, May 12 2026).
- Up = good.

**Catcher** (`drift_catcher.py`): NetK only.
- ±5.0 net strikes (cumulative SUM).
- Gate: **≥1500 TOTAL pitches caught** (not edge pitches — matches the
  canonical NetK percentile pool gate). `season_netk_n` and `week_netk_n`
  in the SQL count `COUNT(*)` of pitches caught, NOT the edge-CSC subset.
  Verified May 10 2026 via `sql-queries/netk-diagnostic-2025-vs-2026.sql`.
  Earlier "500 edge pitches" gate was wrong (edge ≈ 20% of total) and
  filtered out every real candidate.
- Up = good. YoY-mainly by design.

**Fielding** (`drift_fielding.py`): OAA, React P25, TopSpd P95, Arm P99,
PAA/EO — each split IF + OF (10 metric configs total in
`drift_thresholds.py`).
- IF positions: 3 (1B), 4 (2B), 5 (3B), 6 (SS). Arm floor 70 mph.
- OF positions: 7 (LF), 8 (CF), 9 (RF). Arm floor 75 mph.
- Tier 1 6-term gate applied in Python (`dcbp_om + dcbp_cp + dcbp_ct +
  tdm_cp + tdm_ct + arm_pass > 0`) on percentile metrics (React P25,
  TopSpd P95, Arm P99). Mirrors `rules/fielding.md`.
- OAA + PAA/EO use ALL DCBP rows (no gate per the "Cumulative value
  metrics" exception in `fielding.md`). PAA/EO offset subtraction
  approximates GC2 calibration per `rolling_stats.py::_fielding_per_game`.
- Volume gates: ≥10 Tier 1 plays for OAA / React / TopSpd, ≥10 qualifying
  throws for Arm P99 (range-filtered, not the same as comp_plays), ≥10
  DCBP rows for PAA/EO. YoY mode bumps all five to 50.
- Roster filter (Alvaro pattern) applied on `active_fielders` CTE.
- Multi-position players emit one flag per pos_group they appear in
  (e.g. Suarez plays 2B and LF in L14 → may flag both `react_inf_p25`
  AND `react_of_p25`).
- Section renders as ONE "Fielding" block in the PDF + CSV; metric
  labels (`OAA (IF)` / `OAA (OF)` / etc.) disambiguate inside.
- Mirrors `intangibles/src/fielding_tracker_data.py` canonical SQL
  patterns. Reference helper for column shape: `rolling_stats.py::_fielding_per_play`.

### Don't do

- Don't add metrics that are inverses of existing flags (Contact% / Whiff% lesson — every Contact flag was the inverse of the same player's Whiff flag, doubled noise without doubled signal). Pick one.
- Don't repeat headers across chunks. The user explicitly hates it. `show_header=False` on continuation chunks.
- Don't change ANY metric in one of the touchpoint files without updating the others (config, SQL module, drift_alert glossary).
- Don't reintroduce `baseline_kind="league_level"` for any metric. ALL metrics use `player_season` as of Apr 27 2026.
- Don't use `logger.warning` in dispatcher try/except — Connect hides them by default. Use `print()` (same gotcha as `tracker-parquet-pins.md` rule 5.3).
- Don't use `NOT EXISTS` inside `SUM/AVG/COUNT(CASE WHEN ...)` — SQL Server error 130. Use LEFT JOIN + IS NULL pattern (May 10 2026 drift_br bug).
- Don't bypass the roster filter — release/trade leakage is a design bug not a data bug. Apply Alvaro pattern to every new `active_*` CTE.
- Don't drop the 5.0 ft floor or 20.0 ft ceiling on 1B PL, or the 25.0 ft ceiling on 2B PL — all HawkEye glitch guards per data-cleaning.md §2.
- Don't add `runner_going` filter to PL — that's for SL/TL only (steal inflates secondary). PL captures the runner's position at pitch release, before they've left.
