---
name: IF PAA Description Exclusions — SHELVED
description: 10-file refactor to zero/flip IF PAA on 4 description patterns. Shelved 2026-04-23 pending Farm Director decision on whether org stays on GC2 PAA methodology. Ready to resume once gate unlocks.
type: project
originSessionId: 1cd8256b-ca55-4ea7-8e49-06c860d42260
---
## Status: SHELVED 2026-04-23

Farm Director debating whether to stay on GC2's current PAA methodology or
switch frameworks. This entire plan assumes we patch GC2's
`Astros.Defense_Combined_By_Pos.paa` + `.out_prob` + `.drv` via description-
based CASE WHEN. If we switch off GC2, the plan is moot.

**Why:** Avoid sinking 10-file patch time until the methodology call lands.

**How to apply:** Do NOT execute this plan unless the Farm Director
explicitly commits to staying on GC2 PAA. Once confirmed, resume at Phase 0
— nothing upstream changes.

## The 4 description patterns (locked in, do not change on resume)

Group A — pitcher-primary plays, zero paa + out_prob + drv for IF pos_id IN (3,4,5,6):
- `%singles on a ground ball to pitcher%`
- `%singles on a soft bunt ground ball to pitcher%`
- `%deflected by pitcher%`

Group B — 1B missed catch, FLIP PAA sign for pos_id IN (4,5,6) only. 1B (pos_id 3) untouched. out_prob/drv unchanged:
- `%reaches on a missed catch error by first baseman%`

Gate: `dcbp.paa < 0` only. Positive PAA on matching play = keep credit, don't touch.

## Artifacts on branch feature/pd-goals (commit 47cf35d)

- `docs/plans/2026-04-23-if-paa-description-exclusions.md` — full plan with SHELVED banner
- `sql-queries/if-paa-exclusions-impact.sql` — impact test query, ready to run
- TaskCreate list (18 tasks, pending)

## 10 files in scope (do NOT edit until gate unlocks)

Intangibles worktree `feature/astros-intangibles`:
1. `intangibles/src/fielding_base.py` — Tier 1 leverage
2. `intangibles/src/fielding_tracker_data.py` — 4 direct DCBP queries (lines 543-565, 758-774, 972-991, 1180-1198)
3. `intangibles/src/if_kpi_data.py` — 2 queries (~129, ~390)
4. `intangibles/src/if_postgame_data.py` — per-play table (~199-247)
5. `intangibles/src/if_postgame_percentiles.py` — 3 queries (~58, 153, 233)
6. `intangibles/src/if_weekly_data.py` — verify routing first (may inherit base)
7. `intangibles/src/snapshot_data.py` — IF scope only (~540)

PD-Goals `feature/pd-goals`:
8. `pd-goals/src/org_kpi_data.py` — `_IF_VALUE_ORG_QUERY` line ~1562
9. `pd-goals/src/stats.py` — IF DEFENSE STATS block ~2595-2764
10. `pd-goals/src/percentiles.py` — DCBP queries ~2226-2252

## Gate to resume

Farm Director confirms GC2 PAA methodology stays. Possible outcomes:
- **Stay on GC2:** execute the plan as written. Fresh impact SQL run first (2026 data moves).
- **Switch to new methodology:** archive this plan, start a new plan for the new framework.

## Resume checklist (when gate unlocks)

1. Re-read `docs/plans/2026-04-23-if-paa-description-exclusions.md` top-to-bottom
2. Verify the 4 LIKE patterns still match GC2 description conventions (patterns may have evolved)
3. Run `sql-queries/if-paa-exclusions-impact.sql` fresh to get current-year impact numbers
4. User eyeballs output, confirms scope
5. Dispatch subagents per TaskCreate list in order (Task 1.1 → Task 1.8 intangibles, Task 2.1 → 2.4 pd-goals, Task 3 user verification, Task 4 pin rebuild, Tasks 5.x docs)

## Sacco context (original use case)

Tommy Sacco (gcid 82035) flagged as being unfairly docked PAA/EO due to
phantom attribution on plays where the pitcher fielded the ball. The 4
patterns above were derived from his 2026 rows in
`sql-queries/sacco-paa-exclusions-audit.sql` (committed 76eef18 et al).
Sacco's 2026 PAA/EO is expected to be the biggest mover post-patch.
