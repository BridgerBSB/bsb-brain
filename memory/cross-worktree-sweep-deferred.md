---
name: cross-worktree-sweep-deferred
description: Cross-worktree stale doc sweep (Barrelsville + Arm Farm + PD-Goals) deferred — another agent is handling heavier lifts on those branches. Candidates listed in .claude/rules/.graduation-log.md. Resume when the other agent's work settles.
type: project
originSessionId: 29235c4c-f246-4018-b859-2eb928b0df6c
---
## Cross-Worktree Stale Doc Sweep — Deferred Apr 21 2026

**Why deferred:** A different agent is conquering a heftier lift on the other three worktree branches (Barrelsville, Arm Farm, PD-Goals). Don't want the memory-cleanup skill touching those worktrees while active refactor is in flight — creates merge conflicts and makes attribution of doc changes harder.

**What's already done (intangibles only):**
- 10 app-dir docs deleted — commits `41537fb` + `f5a0d4d` on `feature/astros-intangibles`
- 6 memory files deleted + MEMORY.md updated
- Skill refinement + graduation log bootstrapped — commit `44ac12d` on `feature/pd-goals`

**What's pending (other worktrees):**

| Worktree | Candidate files | Notes |
|---|---|---|
| Barrelsville (`bsb-wt-hitting`) | `barrelsville/BARRELSVILLE_DATA_REFERENCE.md`, `barrelsville/PRD.md`, `barrelsville/docs/ADVANCE_BATCH_DESIGN.md`, `barrelsville/docs/GC2_METRIC_COMPARISON.md`, `barrelsville/docs/PROMOTION_DETERIORATION_RESEARCH.md`, `barrelsville/docs/plans/2026-03-19-gc2-level-code-refactor.md`, `barrelsville/docs/advance-reference/` | Full list in .graduation-log.md |
| Arm Farm (`bsb-wt-bullpen`) | `bullpen-report/PRD.md` (and likely more — parallel scan got cancelled during intangibles sweep) | Need fresh scan |
| PD-Goals (main repo, `feature/pd-goals` branch) | `pd-goals/docs/plans/2026-04-11-org-kpi-implementation.md`, `pd-goals/docs/plans/2026-04-11-org-kpi-report.md` | Both plans executed |

**How to apply when resuming:**
1. Check with user first — confirm the other agent's work has settled
2. Invoke `memory-cleanup` skill with scope arg = worktree path
3. Pre-flight scan will regenerate the candidate list (timestamps may have moved)
4. Append results to `.graduation-log.md` under a new dated entry
