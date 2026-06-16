---
name: session-2026-05-18-xwoba-handoff
description: "May 18 2026 — xwOBA migration sweep COMPLETE. All 10 outstanding files + helper upgrade shipped across all 4 worktrees. Salas verification deferred to work laptop (DB access)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 3ab21951-afd2-48a7-9e6b-354b31f57d5c
---

## ✅ STATUS — MIGRATION COMPLETE (May 18 2026 late evening)

Every xwoba surface across all 4 worktrees now uses **Pattern A** (SQL
per-pitch JOIN to `mlbam.Schedule + Guts.woba_lwts` on `(year, league)`)
or **Pattern B** (Python `compute_xwoba` helper with per-PA weight
columns on pa_df).

Audit verification command from `xwoba-canonical.md` returns ZERO
matches across all 4 worktrees — no remaining `:w_bb` / `:w_1b` /
`:w_2b` / `:w_3b` / `:w_hr` SQL params.

**Single source of truth:** `.claude/rules/xwoba-canonical.md`. Synced
byte-identical to all 4 worktrees (md5 `a079a161...`).

---

## What got shipped today (chronological)

| # | Commit | What |
|---|---|---|
| 1 | `a6c81ebe` (barrelsville) | Upgrade `xwoba_canonical.py::compute_xwoba` — per-PA weight columns mode (when `weights=None`, reads `w_bb`/`w_1b`/`w_2b`/`w_3b`/`w_hr` from pa_df row). Single-dict mode preserved for backward compat. |
| 2 | `be1bd919` (pd-goals) | Sibling sync of helper upgrade. md5 byte-identical. |
| 3 | `d3e8218d` (barrelsville) | Postgame fix — `_compute_xwoba` switches to per-PA mode. pa_query + `_get_season_heatmap_data` query both add LEFT JOIN to mlbam.Schedule + Guts.woba_lwts. `_enrich_season_heatmap` vectorizes over per-pitch weight arrays. **Salas fix.** |
| 4 | `c83d8aac` (barrelsville) | postgame_percentiles `_BATTER_XWOBA_QUERY` per-pitch JOIN, drops `:w_*` params. |
| 5 | `f74c42e4` (barrelsville) | sugar_land_la_ev_data per-BIP JOIN. Compute functions use per-row weights. Drops year-loop weight fetch. |
| 6 | `f85274b1` (barrelsville) | poc_research_data per-BIP JOIN. Same pattern as Sugar Land. |
| 7 | `7cf92f04` (barrelsville) | 3 batch scripts: dsl_to_a_analysis.py (2 SQL blocks), heart_zone_report.py (3 SQL blocks + xwoba_params trim), exploration/zsw_analysis.py (level→league JOIN). |
| 8 | `d851a86e` (pd-goals) | splitter_analysis.py per-pitch JOIN with per-row Python weight computation. |
| 9 | `84de1512` (pd-goals) + sync to 3 worktrees | xwoba-canonical.md migration-map rewrite + bug-history entry. |

---

## Salas case — the verification target

Hector Salas 2026: 37 PA Low A (CAR), 3 PA A+ (SAL), 12 PA AA (TEX).
PA-weighted = .3648 ≈ .364 (GC2 value).

Before fix: postgame showed **.367** (single-dict applied his
mode-league weights to every PA, including the AA + A+ PAs).

After fix: postgame's pa_query now JOINs Guts.woba_lwts per-pitch, so
each PA carries its game's actual league weights. compute_xwoba reads
per-row. **Expected output: .364 (matching GC2 within .001 rounding).**

**Verification deferred to work laptop** — DB access required to run
`barrelsville/scripts/diagnose_xwoba_vs_gc2.py` (or just regenerate
Salas's postgame PDF). Run when next on work laptop.

---

## Pin re-run — DONE (May 19, work laptop)

User completed `pin_tracker_seasons.py` on May 19 after the migration
landed. Affiliate Tracker pins now reflect post-migration xwoba values.
Apps that compute xwoba live (postgame, weekly_hitter, hitter_kpi
org_kpi, sugar_land, poc_research, batch scripts) didn't need pin
re-runs anyway.

---

## What NOT to do post-migration

- **Don't add a new inline xwoba formula** anywhere. Every surface
  routes through `compute_xwoba()` (Python) or the per-pitch JOIN SQL
  pattern. Tripwire on this in the rules file.
- **Don't pass a single weights dict** to `compute_xwoba` for any
  batter who could be multi-level. Use per-PA mode (weights=None +
  populate columns via SQL JOIN). If you don't know whether a batter
  is multi-level, default to per-PA mode — it works for single-level
  too.
- **Don't use `level_code = X AVG` as a weight source.** Ever.
  League-first only, per-pitch JOIN preferred.
- **Don't ship a wOBA migration without the same Pattern A / Pattern B
  discipline.** wOBA still has level-AVG paths in some Python
  computations (Barrelsville hitter_kpi `get_player_table_data` line
  ~1270, tracker line ~1080). Documented as separate future sweep —
  see `xwoba-canonical.md` §"Same discipline applies to wOBA + gcOBA".
  Don't piecemeal-fix wOBA without auditing all callers.

---

## Lesson encoded

The May 18 morning session shipped 5 SQL-aggregate surfaces and
claimed "everywhere done." The Salas multi-level case + the audit
command revealed 10 more files plus the helper signature itself.
Running the audit command from the rule file FIRST (before claiming
completeness) would have caught this in the original session.

Going forward: the audit command in `xwoba-canonical.md` §"Audit
command" is the source of truth for migration completeness. Run it
before any "everywhere" claim. Don't claim it without seeing zero
results.

---

## Cross-references

- `.claude/rules/xwoba-canonical.md` — the single source of truth.
  Updated and synced to all 4 worktrees.
- `.claude/rules/woba-rules.md` — wOBA / weight lookup / numerator
  patterns. Mostly aligned with xwoba canonical.
- `.claude/rules/three-surface-parity.md` — tracker ↔ KPI weekly ↔
  PD Goals invariants. xwoba now matches GC2 (instead of matching each
  other at a drifted level-AVG value).
- `.claude/rules/multi-level-rollup.md` — multi-level aggregation
  iron rule. xwoba aggregates by PA count which is naturally additive
  across levels.
- `barrelsville/scripts/diagnose_xwoba_vs_gc2.py` — 3-test diagnostic
  (Neyens single-league, Sacco single-league, Salas multi-level).
  Run after any future change to verify GC2 parity.
