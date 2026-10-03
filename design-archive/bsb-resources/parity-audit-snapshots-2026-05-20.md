# Snapshot Parity Audit — 2026-05-20

Follow-up audit covering the **per-player snapshot scripts** that the weekly KPI
audit missed. These are the literal `*snapshot*.py` files:

- `barrelsville/scripts/kpi_snapshot_3.py` — hitter snapshot (also has a pitcher section)
- `bullpen-report/scripts/pitcher_kpi_snapshot.py` — pitcher snapshot (HOU MiLB org-wide landscape PDF)
- `intangibles/src/snapshot_data.py` + `snapshot_report.py` + `scripts/generate_kpi_snapshot.py` — covers BR + OF + IF + Catcher in one family

These are a **4th surface** distinct from tracker / KPI weekly / PD-Goals org KPI.
For every metric a snapshot displays, the value MUST match whatever canonical
surface coaches see elsewhere.

Companion to `docs/parity-audit-2026-05-20.md` (which audited the weekly KPI
reports). Where this file refers to "the weekly audit," that's the doc.

---

## Executive Summary

| Family | Metrics audited | BLOCKING drift | Minor / Cosmetic | Match cleanly |
|---|---:|---:|---:|---:|
| Hitter snapshot | 19 | **3** | 1 | 13 |
| Pitcher snapshot | ~9 | **1** | 2 (semantic / intentional) | 6 |
| Intangibles snapshot (4 domains) | 49 | **2** | 3 | 44 |
| **TOTAL** | **~77** | **6** | **6** | **~63** |

### Cross-cutting observations

1. **Snapshots are mostly self-contained** — pitcher snapshot and intangibles snapshot duplicate SQL rather than importing helpers. Hitter snapshot is the exception: 13 of 19 metrics inherit from `postgame_data.py::compute_game_stats` and get the May 18-19 xwOBA migration for free.

2. **Carryover from the weekly audit:**
   - **Pitcher snapshot AVOIDED 2 of the 3 pitcher weekly BLOCKING items** by being self-contained. Whiff% IS gated by `did_swing`; gcERA IS derived (matches GC2). The 3rd item (EW%) doesn't apply because the snapshot doesn't show EW%.
   - **BR snapshot CARRIES the same `_LEADS_QUERY` PBL-gate bug** as KPI weekly — and it's worse (no `Pitches_View` JOIN at all).
   - **BR snapshot AVOIDED the truncated CS canon** (uses full 7-code list).

3. **New bug class found in snapshots: per-PA league-AVG wOBA weights** instead of canonical per-PA-league JOIN. Hitter snapshot uses `get_woba_weights(level_code=lv)` which is the legacy level-AVG fallback. Per `xwoba-canonical.md`: "League-first only. Ever."

4. **Combined tally with the weekly audit: 11 BLOCKING items total** across 9 surfaces. KPI weekly weighted heavier (5 of 11), but snapshots add 6 more.

---

## BLOCKING Drift — Top of Queue

### #6 — Intangibles BR snapshot `leads` CTE missing PBL canonical filters (WORST)

**File**: `intangibles/src/snapshot_data.py:1123-1148`

**Worse than the weekly version (BR #4):** snapshot's `_BR_SNAPSHOT_QUERY` leads CTE doesn't even JOIN `Astros.Pitches_View`. So both required filters are absent:
- No `JOIN Astros.Pitches_View pv ON pbl.sched_id = pv.sched_id AND pbl.pitch_id = pv.pitch_id`
- No `AND pv.pitch_id > 0`
- No `AND pbl.ignore_flag = 0`

**Canonical pattern** (in `br_tracker_data.py:510-524` and `pd-goals/src/org_kpi_data.py:1880-1906`):
```sql
FROM Astros.Pitches_Baserunner_Leads pbl
JOIN Astros.Pitches_View pv ON pbl.sched_id = pv.sched_id AND pbl.pitch_id = pv.pitch_id
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
LEFT JOIN ... nbo_2b ...
LEFT JOIN ... nbo_3b ...
WHERE ...
  AND pv.pitch_id > 0
  AND pbl.ignore_flag = 0
```

**Numeric impact**: Snapshot LL 1B / LL 2B values include ignore-flagged HawkEye reads + pitch_id=0 sentinel rows. Drift from tracker/KPI weekly. Affects every BR snapshot per-player row.

---

### #7 — Hitter snapshot wOBA uses level-AVG weights (`xwoba-canonical.md` violation)

**File**: `barrelsville/scripts/kpi_snapshot_3.py:485`
**Code**: `lv_weights = get_woba_weights(used_season, level_code=lv)`

**Bug**: Falls into the legacy level-AVG branch of `get_woba_weights` (postgame_data.py:366-385) because `league=None`. Returns AVG across leagues at that level. Per `xwoba-canonical.md`: *"Don't use `level_code = X` AVG-across-leagues as a weight source. Ever. League-first only."*

**Salas-class drift**: Affects any batter who played multi-league levels (A = Carolina + SAL; AA = TEX + EL; AAA = IL + PCL; FCL contains complex leagues, etc.).

**Fix is elegant**: `pa_df` ALREADY has per-PA `w_bb/w_1b/w_2b/w_3b/w_hr` columns from postgame's `_query_timeframe` (which JOINs `WOBA_WEIGHTS_JOIN` per `postgame_data.py:1862`). Snapshot is throwing those away and re-fetching level-AVG weights. **Use what's already on the dataframe.** Mirror `_compute_xwoba`'s per-PA aggregation pattern.

---

### #8 — Hitter snapshot wRC+ inherits broken wOBA

**File**: `kpi_snapshot_3.py:507-511`

**Bug**: `_compute_wrc_plus(lv_woba, ...)` is fed the level-AVG-weight wOBA from H1 above. Even though `_get_league_woba_env` correctly pulls per-league `lg_woba/scale/runs_per_pa` when `mlbam_league` is present, the numerator wOBA was computed wrong upstream. Compounding drift via the `(wOBA - lg_woba) / scale` amplification.

**Fix**: Once H1 lands, wRC+ converges automatically.

---

### #9 — Pitcher snapshot K%/BB% denominator IBB inclusion

**File**: `bullpen-report/scripts/pitcher_kpi_snapshot.py:253-277`

**Code**:
```python
pa_rows = df[df["cur_event_id"].notna() & (df["pa"] == 1)]  # excludes IBB rows (pa=0)
pa_total = len(pa_rows)
bb_no_ibb = bb - ibb
k_pct = so / pa_total
bb_pct = bb_no_ibb / pa_total
```

**Canonical** (tracker `_PITCH_LEVEL_QUERY:690` + `pitcher_kpi_data.py:571`):
```sql
SUM(CAST(ev.pa AS int)) + SUM(CAST(ISNULL(ev.ibb, 0) AS int)) AS bf   -- includes IBB
-- K% = so / bf, BB% = bb (full count) / bf
```

**Numeric impact**: For any pitcher with non-zero IBB, snapshot K%/BB% will be different from tracker/KPI weekly for the same pitcher in the same window. Snapshot is internally consistent (its percentile pool uses the same definition), so the bug surfaces as **a coach pulling the snapshot next to the tracker and seeing different K%/BB% values for the same guy**.

**Fix**: Switch to the canonical `BF = SUM(pa) + SUM(ibb)` denominator and use raw `SUM(bb)` (including IBB) in the BB% numerator. Mirror tracker/KPI exactly.

---

### #10 — Hitter snapshot K%/BB% percentile pool BB% includes IBB

**File**: `kpi_snapshot_3.py:848-851`

**Bug**: Pool BB% computed as `SUM(bb=1) / SUM(pa=1)` (raw `ev.bb`, includes IBB). Per-player BB% at L459 is `(bb - ibb) / pa` (strips IBB). Pool BB% > per-player BB% by exactly the IBB share. Percentile rank drifts low for any batter with IBBs.

**Fix**: Add `AND CAST(ISNULL(ev.ibb,0) AS int)=0` to the BB-numerator CASE WHEN in the pool query. This mirrors the pattern the same file uses elsewhere for pitcher pools at `kpi_snapshot_3.py:947-948`.

---

### #11 — Intangibles IF snapshot arm-strength floor 75 instead of 70

**File**: `intangibles/src/snapshot_data.py:118`

**Code**: `SNAPSHOT_CONFIGS["IF"]["arm_range"]: (75, 108)`

**Canonical** (per `fielding.md`): IF floor = **70**, OF floor = 75. Tracker (`fielding_tracker_data.py`) uses 70-108 for IF. Snapshot config uses OF floor for IF — likely a copy-paste from the OF config.

**Numeric impact**:
- ArmIF P99 biased higher in snapshot (excludes legitimate 70-74 mph IF throws).
- ExchIF P10 also affected since the exchange gate is tied to the arm floor.
- ~10% relative drift on borderline IF arms.

**Fix**: One-line change in `snapshot_data.py:118` from `(75, 108)` to `(70, 108)`.

---

## Minor / Documented Divergences

### Hitter snapshot
- **Side observation (H4)**: The snapshot's PITCHER section (lines 654 et al — yes, the hitter snapshot script also draws pitcher pages) uses inline `level_code NOT IN (...)` blacklist instead of `_build_level_filter()`. Bypasses DSL/FCL `gc2_level_code` split. Different bug class, lives in the same file. Surface drift only matters if someone uses the hitter snapshot's pitcher pages.

### Pitcher snapshot
- **K/BB ratio vs K-BB% subtraction**: Snapshot column labeled "K/BB" computes `k_pct / bb_pct` (ratio). KPI weekly's equivalent column is `K-BB%` (subtraction). Different metric, similar header. Coach seeing both surfaces could confuse the two. Worth aligning labels even if math intentionally differs.
- **FIP global vs per-level FIPConstant**: Snapshot uses AL global constant (~3.10-3.25). Tracker uses per-level constant (FCL FIPConstant differs from AAA, etc.). Snapshot's choice is documented at the file header as intentional "for internal percentile consistency." But absolute FIP values for non-MLB pitchers will not match tracker.

### Intangibles snapshot
- **Catcher Pop2B**: Snapshot adds `play_code LIKE '%SB2%'/'%CS2%'` + `event_result_id IN (4,5,42,43,46,47)` filters on top of the canonical range filter (1.70-2.35). More restrictive than tracker. Values match closely (since the range already isolates 2B throws) but n_throws_2b could be slightly lower on edge cases. Cosmetic.
- **Catcher snapshot omits Depth and AugPop2B entirely.** Not in `SNAPSHOT_CONFIGS["C"]["metrics"]`. This is a **coverage gap, not a parity bug.** If the user wants Depth on the catcher snapshot, port the canonical `intangibles/src/catcher_data.py::_SEASON_DEPTH_QUERY` pattern.

---

## What Did NOT Drift (worth knowing)

### Hitter snapshot — May 18-19 xwOBA migration carried correctly
The snapshot inherits 13 metrics from `compute_game_stats` (postgame canon). All of these match: Dmg%, Avg EV, Ctct%, ZCtct%, Whiff%, OSw%, ZSw%, PullAir%, BS, gcOBA, xwOBA, EV cleaning, bat speed cleaning. The Salas-class xwOBA fix lands for free.

### Pitcher snapshot AVOIDED 2 of the 3 weekly pitcher BLOCKING items
- Whiff% numerator IS gated by `did_swing=1` (full ignore-flag swing-recovery clause). Does NOT carry the weekly bug.
- gcERA IS derived (`bip_rate = 1 - so - bb_hbp`, matches GC2). Does NOT carry the weekly bug.
- EW%: not applicable (snapshot doesn't show EW%).

### BR snapshot AVOIDED the truncated CS canon
Snapshot CS counting uses full `(4,5,6,7,29,30,31)` at line 1034. Does NOT carry the weekly chart's truncated `(4,5,6)`.

### Catcher snapshot NetK / framing buckets / R2K% / FramRAA / BlockRAA all clean
Canonical CSC ranges, pitch_result_id codes, `ignore_flag=0`, `pitch_id>0`, BlockRAA sign flip. Matches tracker + KPI weekly + PD-Goals.

### Fielding 6-term Tier 1 gate intact in OF + IF snapshot
`snapshot_data.py:464-469`. Matches `fielding.md` canon.

---

## Combined Tally with the Weekly Audit

**11 BLOCKING items total across 9 surfaces:**

| # | Surface | Item | Severity |
|---|---|---|---|
| W1 | BR KPI weekly | `_DATE_RANGE_PLAYER_QUERY` leads CTE missing PBL gates | HIGH (every lead average in KPI weekly Season table) |
| W2 | Pitcher KPI weekly + tracker | Whiff% numerator missing `did_swing=1` gate (4 sites) | MEDIUM |
| W3 | Pitcher KPI weekly | gcERA `bip_rate` direct vs derived + missing bunt filter | MEDIUM |
| W4 | Pitcher KPI weekly | EW% BIP codes truncated to (12,13,14) | LOW |
| W5 | BR KPI weekly | Chart `_ORG_DAILY_SB_CS_QUERY` CS canon truncated to (4,5,6) | LOW (chart line only) |
| S6 | Intangibles BR snapshot | Leads CTE missing pitch_id + ignore_flag + no PV JOIN | HIGH (every BR lead in snapshot) |
| S7 | Hitter snapshot | wOBA level-AVG weights instead of per-PA-league | HIGH (Salas-class) |
| S8 | Hitter snapshot | wRC+ inherits broken wOBA | HIGH (compounded) |
| S9 | Pitcher snapshot | K%/BB% BF denominator excludes IBB | MEDIUM (snapshot vs tracker mismatch) |
| S10 | Hitter snapshot | K%/BB% pool BB% includes IBB (pool vs player mismatch) | LOW |
| S11 | Intangibles IF snapshot | IF arm floor 75 vs canonical 70 | LOW |

**Pattern**: KPI weekly + snapshots split the drift evenly. Tracker + PD-Goals + postgame are in good shape (the canonical sources). The two surfaces that get less attention from parity sweeps (KPI weekly + snapshots) carry every documented BLOCKING item.

---

## Recommended Fix Priority

1. **W1 + S6** (BR PBL gates) — same bug class, both worth fixing in one BR sweep. Touches `br_kpi_data.py` and `snapshot_data.py`. ~10 LOC total.
2. **S7 + S8** (hitter snapshot wOBA + wRC+) — paired. Fixes via reading existing per-PA columns from pa_df. ~15 LOC.
3. **W2** (pitcher Whiff% gate) — 4 sites in `bullpen-report/`. ~8 LOC.
4. **S9** (pitcher snapshot K%/BB% IBB) — canonical denominator. ~5 LOC.
5. **S11** (IF arm floor 75 → 70) — one-line config fix.
6. **W3 + W4** (pitcher gcERA + EW% BIP codes) — KPI weekly cleanup. ~5 LOC.
7. **S10** (hitter K%/BB% pool IBB) — `kpi_snapshot_3.py:848` one-line.
8. **W5** (BR chart CS canon) — `br_kpi_data.py:156,168` two-line.

**Total: ~50 LOC across 4 files in 3 worktrees.** All surgical, no architecture changes. Each can ship independently.

**Side observations to consider** (not BLOCKING, but coach-visible):
- Pitcher snapshot K/BB ratio vs KPI K-BB% subtraction — align column labels.
- Pitcher snapshot global FIP vs tracker per-level FIP — current behavior is documented intentional, but if a coach pulls both, FIP values for HOU AA won't match.
- Catcher snapshot missing Depth + AugPop2B — coverage gap, ask if intentional.

---

## Files Audited

### Hitter snapshot
- `bsb-wt-hitting/barrelsville/scripts/kpi_snapshot_3.py` (full file)
- Plus references to `barrelsville/src/postgame_data.py` (compute_game_stats canon), `bat_speed_clean.py`, `xwoba_canonical.py`, `postgame_percentiles.py`

### Pitcher snapshot
- `bsb-wt-bullpen/bullpen-report/scripts/pitcher_kpi_snapshot.py` (full file)
- Plus references to `tracker_data.py`, `pitcher_kpi_data.py` for diff

### Intangibles snapshot
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/snapshot_data.py` (full file)
- `bsb-wt-intangibles/astros-intangibles/intangibles/src/snapshot_report.py`
- `bsb-wt-intangibles/astros-intangibles/intangibles/scripts/generate_kpi_snapshot.py`
- Plus references to all 4 domain modules (br_tracker_data, fielding_tracker_data, catching_tracker_data, of_kpi_data, if_kpi_data, c_kpi_data, br_kpi_data) and PD-Goals org_kpi_data.py

### Canonical rules cross-referenced
Same set as the weekly audit (see `docs/parity-audit-2026-05-20.md` § Canonical rules cross-referenced).

---

## Methodology

3 parallel background agents — one per snapshot family. Each read whole snapshot
files + cross-referenced canonical rules + diffed against the 4 reference surfaces
(tracker, KPI weekly, PD-Goals org KPI, postgame canon where applicable).

Static code audit only — no SQL execution, no numerical impact computation. All
findings include exact file:line refs.

Audit run timestamp: 2026-05-20 (companion to `docs/parity-audit-2026-05-20.md`).
