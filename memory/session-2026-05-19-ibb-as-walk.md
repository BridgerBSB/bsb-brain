---
name: session-2026-05-19-ibb-as-walk
description: May 19 2026 session — xwOBA IBB-as-walk fix + WOBA_WEIGHTS_JOIN canonical constant + f-string trap lessons
metadata: 
  node_type: memory
  type: project
  originSessionId: 6802ad97-9ff3-47cf-b627-fb6528fa49d1
---

# May 19 2026 — xwOBA IBB-as-walk + WOBA_WEIGHTS_JOIN canonical constant

## What shipped

**ROOT CAUSE FIX**: Sacco AA xwoba was .330 (ours) vs .335 (GC2). Root: GC2 treats IBB as walk in xwoba (`when bb=1 or hbp=1 then 1.0 * Woba.woba_bb` — no IBB filter). Our helper + every SQL CASE excluded IBB. Salas (A/A+/AA) matched because zero IBBs at low levels. After fix: **Sacco AND Salas both align on gcOBA AND xwOBA in postgame** (user verified).

**Changes across all 4 worktrees**:
1. `compute_xwoba` helper: dropped `if is_ibb: return None` branch. IBB rows have BB=1 in our schema → fall into BB/HBP branch → contribute w_bb to numer + 1 to denom. Sibling-synced barrelsville + pd-goals (md5 verified).
2. SQL CASE in 8 xwoba sites: dropped `WHEN ibb=1 THEN NULL` clause across barrelsville tracker / hitter_kpi / weekly_hitter / postgame_percentiles / + 2 scripts. Also PD Goals org_kpi_data xwoba_pa filter widened to include IBB rows.
3. PA filter `pa=1` → `pa=1 OR ibb=1` on 3 sites (hitter_kpi_data xwoba block, weekly_hitter_data xwoba block).
4. `_get_league_wrcplus_distribution` (tracker wRC+ pool): rewrote wOBA formula — was hard-coding literal `1.0` for BB/HBP instead of `woba_bb`/`woba_hb`, also counted SH in denom via `COUNT(non-IBB rows)` instead of GC2's `AB+BB-IBB+HBP+SF`. Both bugs fixed.

**NEW `WOBA_WEIGHTS_JOIN` canonical SQL constant** in `xwoba_canonical.py` (sibling-synced). Replaces the duplicated `LEFT JOIN MLBAM.Schedule + Guts.woba_lwts` JOIN block across 10 sites in 8 files. Pre-aggregated AVG() on (year, league) subquery for safety against multi-row Guts entries. Caller contract: must have `Astros.Schedule_View sv` aliased; constant produces aliases `ms` + `woba`.

## The f-string trap lesson (BLOCKING — documented in xwoba-canonical.md)

The `""" + WOBA_WEIGHTS_JOIN + """` concat pattern is FRAGILE. The second triple-quote must MATCH the f-string status of the ORIGINAL query opening:

- Module-level `_NAME = """` queries (use `.format()` at runtime) → second half STAYS `"""` (matches the original)
- Function-body `xwoba_sql = f"""` queries (Python locals in scope) → second half MUST be `f"""`

Mismatched → either `{level_filter}` stays literal (SQL syntax error) OR NameError at module import.

**Per-file checklist now in `xwoba-canonical.md`** — see "WOBA_WEIGHTS_JOIN injection — BLOCKING f-string trap" section. Lists every site + its required suffix.

**TODO refactor (deferred)**: switch to `/*__WOBA_WEIGHTS_JOIN__*/` sentinel + `.replace()` pattern. Uniform across all queries, immune to f-string vs .format() confusion. Half-day work; eliminates this bug class permanently.

**EVEN BETTER**: a `build_xwoba_query(driver, scope_filter, ...)` Python function that returns the complete SQL with CASE + WOBA_WEIGHTS_JOIN + filters all injected. Like `clean_bat_speed_per_player` — one function, every caller imports. That's the right next architectural step when metric churn slows.

## Rule files updated + synced byte-identical to all 4 worktrees

- `xwoba-canonical.md` (4 worktrees, md5 verified) — flipped IBB rule + WOBA_WEIGHTS_JOIN contract + f-string trap section + TODO
- `woba-rules.md` — two stale "xwoba excludes IBB" statements updated
- `db-columns.md` — xwoba denom rule updated
- `gc2-metrics.md` — IBB-in-rates rule updated
- `multi-level-rollup.md` — xwoba aggregation row updated

## Surface map — final state

Every surface that touches xwoba/wOBA routes through one of:
1. `compute_xwoba()` helper (Python) — fixed
2. SQL query with `WOBA_WEIGHTS_JOIN` constant + corrected IBB CASE — fixed
3. xSLG-only paths (no xwoba) — not affected

Audited scripts: hitter_analysis (uses helper via import ✓), hitter_kpi (chart + table both fixed ✓), weekly_hitter (fixed ✓), postgame (per-batter + heatmap pool ✓), tracker (4 sites + wRC+ pool ✓), sugar_land + poc_research + dsl_to_a + zsw + heart_zone + splitter (scripts migrated ✓), PD Goals org_kpi (hitting + wrc_by_level ✓), postgame_percentiles ✓.

## Work-laptop verification — DONE (May 19)

Pin re-run completed by user same-day. Tracker now reflects IBB-as-walk
xwoba values. No outstanding pin work for this migration.

## Commits this session (~14 commits)

- IBB-as-walk fix + WOBA_WEIGHTS_JOIN ship: `73149085` (barrelsville), `056f1ccc` (pd-goals)
- Bullpen + Intangibles rule sync: `369b795a`, `3234df8a`
- Chart-line IBB fix: `cf2e42f8`
- f-string production fix (3 rounds — caught + fixed each surface mismatch): `fdc5d906`, `b409bff5`, `3824a68f`, `3ceafd34`
- f-string trap docs + sync to 4 worktrees: `7dea861a`, `8a7e8e0a`, `faae736c`, `9a7bcd9c`
- IBB-canon flip in db-columns/gc2-metrics/multi-level-rollup/woba-rules: `74d00367`, `8e1753b5`, `c2d22cf1`, `930bbc92`

## Frustrated user note

Multiple production-breaking iterations on the f-string concat pattern. Each fix exposed a new mismatch (postgame f-string broken first, then module-level NameError after f""" universal, then weekly_hitter broken again after revert). Per-file checklist now in `xwoba-canonical.md` so future me doesn't repeat. User explicitly asked for "documentation in the future to fix... so you don't mess it up" — that's the f-string trap section.

The deeper lesson: **the WOBA_WEIGHTS_JOIN concat IS fragile architecture**. The sentinel-based `/*__WOBA_WEIGHTS_JOIN__*/` `.replace()` pattern OR the full `build_xwoba_query()` Python function are the architecturally correct fixes. Documented as TODO.
