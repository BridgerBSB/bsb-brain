---
name: HOU Affiliates vs FF+FT — boss-ask query SHIPPED
description: One-off SQL — per-HOU-affiliate xSLG/xBA/wOBAcon vs pooled FF+FT, with rank-out-of-30-orgs columns. Boss-ask May 6 2026, shipped same day.
type: project
originSessionId: 47b25890-8571-4b11-bb6b-15744e1d420a
---
## What shipped

`sql-queries/hou-affiliates-vs-ff-ft.sql` on `feature/pd-goals` (commits
`a726a75` → `c1e76d4` over 4 fixes).

One row per HOU affiliate level (MLB → DSL). For each:

| Column | Meaning |
|---|---|
| `n_bips`, `avg_ev`, `avg_la` | Sample-size + sanity context |
| `xslg` / `xba` / `wobacon` | Pool-aggregated per-affiliate metric vs FF+FT only |
| `r_xslg` / `r_xba` / `r_wobacon` | Affiliate's rank across all 30 orgs at its level (1 = best, DENSE_RANK) |

@season DECLARE at the top defaults to 2026; user can flip it.

## Boss framing — used in Slack response

Two-sentence explanation for the boss on KPI L2W coloring:

1. The L2W table shows each pitcher's actual stats from the last two weeks.
2. The percentile coloring on those L2W stats is calibrated to the full-season distribution — so green means "this guy's recent form would be elite over a full season."

(Same idea applies to the affiliate query: pool aggregation = team
stat, NOT per-player simple mean. Clarified during build.)

## Bug fixes during the build (4 in sequence)

1. **Cross-worktree import** (`b2ea4ed` on Sugar Land matrix) — pd-goals/src/metrics.py was unreachable from bsb-wt-hitting. Inlined Damage formula. Lesson: `feedback_no_cross_worktree_imports.md`.
2. **Custom EV misread CTE diverged from canonical** (`660ec10`) — was missing `n_bip >= 20` gate + R+S+E baseline scope. Replaced with `EV_MISREAD_CTE` helper from `barrelsville/src/database.py`.
3. **DSL leaking into ROK** (`85215dc`) — used `level_code` for filter+groupby. DSL is `level_code='rok' + gc2_level_code='dsl'` per `level-codes.md`. Switched to `gc2_level_code` for the rok/dsl split. ROK row went from 182 BIPs (DSL leakage) → empty (FCL hasn't started). DSL row went from empty → 182 BIPs.
4. **Rank columns added** (`c1e76d4`) — boss follow-up. `DENSE_RANK() OVER (PARTITION BY level_code ORDER BY metric DESC)`. Pulls all 30 orgs to compute rank, filters to HOU at the end.

## Things to remember for future similar boss-asks

- **Pool aggregation = "team stat"** — when asked "how is the affiliate doing," pool-aggregate (volume-weighted across the level). Per-player simple mean answers a different question ("typical individual's stat"). User had a clarifying moment on this — should NOT have to explain twice. Default to pool for org-level questions, ask if uncertain.
- **`level_code` vs `gc2_level_code`** — always use `gc2_level_code` for rok/dsl split, period. Or check `level-codes.md` BEFORE writing a level filter that includes 'rok' or 'dsl'.
- **EV misread = canonical CTE always** — never roll your own. `EV_MISREAD_CTE` from `barrelsville/src/database.py` (Python use) or paste the same structure into standalone .sql files. `n_bip >= 20` gate is the load-bearing piece I missed initially.
- **Rank-across-orgs pattern is reusable** — pull all orgs, GROUP BY (level, org), `DENSE_RANK() OVER (PARTITION BY level ORDER BY metric DESC)`, filter to HOU at end. Useful for any "how do we stack up" question.

## Pairs with

- `feedback_no_cross_worktree_imports.md` — inlining lesson from build #1
- `feedback_org_rollup_aggregation.md` — pool vs per-player choice
- `.claude/rules/level-codes.md` — DSL/FCL split rule (the bug source)
- `.claude/rules/woba-rules.md` — wOBAcon weight conventions
- `barrelsville/src/database.py::EV_MISREAD_CTE` — canonical EV cleaning
