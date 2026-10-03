---
name: db-strain-ev-precompute-status
description: EV-misread P95 compute-once precompute — Phase 1 (Barrelsville hitting) + Phase 3 (Arm Farm pitcher) SHIPPED + verified + repinned Jun 24-25 2026. Pattern graduated to rules/compute-once-cte-precompute.md. Phase 2 (hitter siblings + PD Engine) still open. READ when resuming EV-cleaning efficiency work.
metadata:
  node_type: memory
  type: project
  originSessionId: 39b1cc13-1bb8-449e-a6cb-426006b0b6e5
---

# DB Strain + EV-Misread Compute-Once Precompute — SHIPPED (Phase 1 + 3)

Jun 24-25 2026. R&D (JJ Ruby) + Perla + Navisite flagged GroundControl2 strain:
5 parallel `cxconsumer` sessions (SPID 78/99/161/196/173, work laptop, Python)
running the affiliate-tracker pin's `batter_ev_p95` `PERCENTILE_CONT(0.95) OVER
(PARTITION BY batter_id)` full-season window sort — re-run inside ~a dozen query
strings per refresh, 5-wide. **FIX SHIPPED on both daily-saturating trackers.**

## The pattern (now the canonical rule)
Compute the per-batter P95 ONCE per season, inline it as a constant `VALUES`
lookup in place of the window sort. Output-neutral because the CTE depends ONLY
on season (not the caller's level/hand/H-A/date). Full prescriptive pattern +
the BLOCKING diff-harness gate graduated to **`.claude/rules/compute-once-cte-precompute.md`**
(synced to all 4 worktrees + the main repo, Jun 25). That rule is the durable
source of truth — read it, not this status, for HOW.

## Phase 1 — Barrelsville hitting tracker — SHIPPED + VERIFIED
- `feature/barrelsville` (bsb-wt-hitting). Commits `c9b74b2a` (impl) + `ccd72418`
  (harness). Mechanism: `database.py` `EV_CTE_SENTINEL` + `USE_EV_VALUES_CTE`
  toggle + `build_ev_values_cte` (chunked ≤1000 VALUES UNION ALL, `CAST AS float`
  + `repr()`, lock single-flight) + `_resolve_ev_cte` resolved in `run_query`;
  `tracker_data.py` one line `_EV_CTE = EV_CTE_SENTINEL`.
- Verified: `--check-p95` = 3005/3005 byte-identical (max_abs 0.000); full aax run
  all CLOSE at max_rel ~1e-15 ("Safe to ship"). Load: 889s→507s one combo.
- **Repinned 2026 + redeployed.**

## Phase 3 — Arm Farm pitcher tracker — SHIPPED + VERIFIED
- `feature/bullpen-reports` (bsb-wt-bullpen). Commit `a016e991`. Even tighter:
  all 7 EV queries funnel through `_inject_ev_misread_cleaning()`, so the swap is
  `_EV_P95_CTE.strip()` → `EV_CTE_SENTINEL` at the 2 inject lines (machinery
  ported into Arm Farm `database.py`; `_get_batter_ev_p95` helper already existed,
  WHERE byte-identical to `_EV_P95_CTE`).
- Verified: `--check-p95` = 3007/3007 byte-identical; aax run mostly PASS, org
  frames CLOSE (worst = `fb_spin`, a spin AVG UNRELATED to EV = proof it's
  plan-FP noise, max_rel ~1e-15).
- **Repinned 2026.** (Confirm daily pitcher re-pin runs from this worktree.)

## Key lessons (in the rule, restate here)
- SAFETY CRITERION: only precompute a CTE whose result is scope-independent
  (season-only). Fielding/catcher percentiles are scope-DEPENDENT pools →
  precomputing would ALTER data → do NOT apply there.
- Gate is DISPLAY-exact, not bit-exact. SQL float SUM/AVG isn't bit-reproducible
  across plans; `CLOSE` at ~1e-15 (incl. on non-EV columns) is FP aggregation
  noise = PASS. `check_exact=True` alone is the wrong gate (cost two rounds).
- Raw `Astros.Hits.hit_exit_speed` is NEVER mutated; cleaning is an in-query
  filter, opt-in per query, not gcOBA-specific.
- gcOBA UNCHANGED, still matches GC2 (avg_useful_ev identical to ~13 decimals).

## Phase 2 — OPEN (lower priority, weekly/on-demand, same one-line swap)
Barrelsville `hitter_kpi_data` / `weekly_hitter_data` / `postgame_percentiles` /
`poc_research_data` / `sugar_land_la_ev_data`; PD Engine `org_kpi_data.py` +
`gcoba_canonical.py` (VERIFIED they carry their own `batter_ev_p95`; needs the
resolver ported into PD Engine `database.py` first). Each: sentinel swap + a
`diff_ev_precompute.py` run. Do when convenient — they don't run in the daily pin.

## OUT OF SCOPE (touching MOVES outputs — never bundle)
- `hit_vertical_angle < -25` junk-level filter (pd-goals stats/rolling/drift).
- `hit_exit_speed >= 95 / >= 98` (Hard%, HH%, gcOBA components).
- Intangibles fielding/catcher/BR percentile pools (scope-dependent).

## Inventory delivered to R&D
Page 1 (A-D) `pd-goals/output/db_process_inventory.png/.pdf` +
page 2 (E-F) `..._page2.*`. Gens: `pd-goals/scripts/_db_process_inventory*_png.py`.
NO EM DASHES. Timings given: weekly ~8h Mondays, daily ~3h w/ FCL+DSL, trackers
heaviest. Reply to JJ: confirmed (then lifted) freeze, honest state-of-code,
every change paired with before/after diff. Durable fix = DB offload
([[connect-offload-migration]]).
