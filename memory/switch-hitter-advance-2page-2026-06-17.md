---
name: switch-hitter-advance-2page-2026-06-17
description: "Intangibles fielder advance: switch hitters get 2 stacked pages (vs RHP / vs LHP) split on pitcher hand, with hand-aware scope. SHIPPED on feature/astros-intangibles, untested on live DB."
metadata: 
  node_type: memory
  type: project
  originSessionId: 84f84ed7-99c0-458a-b6c8-38784ebafe34
---

# Switch-hitter 2-page fielder advance — Jun 17 2026

Worktree `C:\Users\Owner\bsb-wt-intangibles\astros-intangibles`, branch
`feature/astros-intangibles`. Files: `intangibles/src/hitter_advance_report.py`,
`hitter_advance_data.py`, `fielding_advance_page.py`,
`scripts/generate_hitter_advance.py`. **SHIPPED + pushed + synthetic-tested,
UNTESTED on live DB.**

## What it does
Switch hitters (`bats == 'S'`) in the fielder/hitter advance batch now produce
**TWO stacked pages** — one **vs. RHP**, one **vs. LHP** (RHP first) — instead of
one combined page. Everyone else keeps a single page.

- Split is on the ACTUAL pitcher hand each BIP was put in play against
  (`pv.pitcher_throws`, added to `_HITTER_BIPS_QUERY`), not inferred from bat side.
- **`get_hitter_page_specs(hitter, bip_df)` is the SINGLE source of truth** for the
  page plan — returns `[(sub_df, "vs. RHP"), (sub_df, "vs. LHP")]` for switch
  hitters, `[(bip_df, "")]` for everyone. Used by all 3 surfaces so they stay in
  lockstep (App↔Report parity): batch PDF (`generate_hitter_advance_batch`),
  per-hitter PDF (`generate_hitter_advance_report`), and the in-app inline
  `st.pyplot` render (`fielding_advance_page._render_hitter_inline`).
- Matchup folded INLINE into the title ("Ruben Reyes vs. RHP | Advance Positioning
  Report"). Earlier attempt put it as a right-aligned tag that slid UNDER the
  Astros logo (figimage spans fig-x ≈0.915–0.982) leaving a stray "P" — fixed by
  going inline. (This incident spawned BLOCKING rule `render-and-look.md` #18.)

## Hand-aware scope (so both pages are populated, not split-in-half)
`_get_batter_scope_sched_ids(..., switch=True)` gates the BIP-bucket walk-back on
the FOUR per-hand buckets (rhp_if, rhp_of, lhp_if, lhp_of) — each must clear the
`DEFAULT_MIN_BIPS_PER_BUCKET = 80` floor — instead of the 2 combined IF/OF buckets.
`_BATTER_GAME_BIP_QUERY` gained 4 per-hand `SUM(CASE … UPPER(pv.pitcher_throws)=…)`
counts; the walk-back uses a `cols` tuple (4 for switch, 2 otherwise). `get_hitter_bips`
gained a `bats` param; threaded from all 5 call sites. Consequence (intended, Zac
chose it over a 2× bump or leave-as-is): switch hitters pull WIDER date ranges to fill
the minority (LHP) hand — eyeball the `Data:` range on first run; easy dial = drop the
per-hand floor below 80 if windows come back too wide.

Commits: `79301c6e` (2-page split) → `efc3d4e7` (inline title fix) → `e1a74891`
(hand-aware scope).

## Verify on work laptop
`python scripts/generate_hitter_advance.py --level dsl` (DSL channel `C0AK777QM47`).
Pick a known switch hitter: confirm 2 pages (RHP then LHP), per-side `n=` sums to his
total, app inline stacks both, and the `Data:` window is reasonable.
