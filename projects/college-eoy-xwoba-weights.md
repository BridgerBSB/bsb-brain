---
status: active — decision pending Zac
created: 2026-08-05
tags:
  - eoy
  - amateur
  - college
  - xwoba
  - woba
  - research
project: EOY position report — college (BBC)
---
# College (BBC) xwOBA — Linear Weights Research

**Why this note exists.** The EOY position report was wired for college on
2026-08-05 (Logan Hughes 197939, drafted 2026, college-only season). Page 2's
season line came back blank because **`Guts.woba_lwts` has no `bbc` row** —
verified on the live DB, its level codes are exactly `aaa, aax, afa, afx, asx,
mlb, rok`. No per-PA weights for college means no canonical wOBA/xwOBA.

Zac: *"college xwoba we should just use basic xwoba rates from fangraphs ...
we will have to make this work."* This note is the research behind that call.

Related: [[power5-contact-floor-shipped]], [[draft-projects]],
`.claude/rules/amateur-data-guardrails.md`, `.claude/rules/xwoba-canonical.md`,
`.claude/rules/woba-rules.md`.

---

## 1. FanGraphs MLB wOBA constants ("Guts")

Source: <https://www.fangraphs.com/guts.aspx?type=cn> · fetched 2026-08-05 via WebFetch

| Season | wOBA | wOBAScale | wBB | wHBP | w1B | w2B | w3B | wHR | R/PA | R/W |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026 | .316 | 1.234 | .698 | .729 | .889 | 1.260 | 1.593 | 2.045 | .119 | 9.845 |
| 2025 | .313 | 1.232 | .691 | .722 | .882 | 1.252 | 1.584 | 2.037 | .118 | 9.774 |
| 2024 | .310 | 1.242 | .689 | .720 | .882 | 1.254 | 1.590 | 2.050 | .117 | 9.683 |
| 2023 | .318 | 1.204 | .696 | .726 | .883 | 1.244 | 1.569 | 2.004 | .122 | 10.028 |
| 2022 | .310 | 1.259 | .689 | .720 | .884 | 1.261 | 1.601 | 2.072 | .114 | 9.524 |

**Formula + denominator.** Source:
<https://library.fangraphs.com/offense/woba/> · fetched 2026-08-05

```
wOBA = (wBB*uBB + wHBP*HBP + w1B*1B + w2B*2B + w3B*3B + wHR*HR)
       / (AB + BB - IBB + SF + HBP)
```

Note this is the **wOBA** denominator (IBB excluded). Our **xwOBA** denominator
is deliberately different — `AB + BB + HBP + SF`, **IBB IS counted** — per
`xwoba-canonical.md` (May 19 2026, GC2 parity). Do not silently adopt the
FanGraphs denominator for an xwOBA.

`wOBAScale` converts to runs: `wRAA = ((wOBA - lgwOBA) / wOBAScale) * PA`.

---

## 2. THE FINDING THAT MATTERS — college is a different run environment

Source: Robert Frey, *Collegiate Linear Weights* ·
<https://rfrey22.medium.com/collegiate-linear-weights-f0237cf40451> · fetched 2026-08-05

Method: scraped stats.ncaa.org play-by-play 2013-present, all three NCAA
divisions, via Bill Petti's `baseballr`. Built a run-expectancy matrix per
base-out state, then averaged run values per event — i.e. the FanGraphs method
applied to college data.

**2019 Division 1, scaled relative to an out:**

| Event | **D1 (2019)** | MLB (2026) | D1 is |
|---|---|---|---|
| Walk | 0.64 | 0.698 | **lower** |
| HBP | 0.66 | 0.729 | lower |
| 1B | 0.79 | 0.889 | lower |
| 2B | 1.12 | 1.260 | lower |
| 3B | 1.40 | 1.593 | lower |
| HR | **1.74** | **2.045** | **~15% lower** |
| League wOBA | **.363** | .316 | **+47 pts higher** |
| wOBA Scale | 1.194 | 1.234 | similar |

Read that table carefully — the two facts point in **opposite** directions and
that is the whole story:

- **League wOBA is ~47 points HIGHER** in D1. College is a high-scoring
  environment (metal-ish bats, wider talent spread, weaker pitching depth).
- **Every event weight is LOWER** relative to an out. Precisely *because* runs
  are cheap, a single buys you less. Same logic as `library.fangraphs.com`'s
  point that weights are recalculated yearly to the era's run environment.

**Consequence for us: applying MLB weights to a college line inflates the
number twice over** — the college event mix is already richer, and each event
gets an MLB weight that is too generous for the context. The result is not a
small bias; a college hitter would print a wOBA that reads like an elite MLB
season.

Caveat on the source: Frey publishes D1/D2/D3 "Guts!" tables for 2013-2020, but
**as images** — only the 2019 D1 row above is transcribed in the text. There is
no machine-readable college constants feed. Anyone wanting a full college table
must re-derive it or read the images.

Supporting: *Adjusting Linear Weights for Extreme Environments* ·
<https://blogs.fangraphs.com/adjusting-linear-weights-for-extreme-environments/>
— linear weights are one-size-fits-all estimates from a particular sample and
"might not reflect reality ... in environments not reflective of the original
sample." That is exactly the MLB-weights-on-college case.

---

## 3. Takeaways for us (the part the links can't give)

### 3a. RANK is safe; the NUMBER is not

Our college percentile pool is **college** (decided 2026-08-05: 16,772 BBC
hitters, 797k tracked BIP in 2026 — measured, not assumed). If a college
hitter's xwOBA is computed with MLB weights and then ranked against *other
college hitters whose xwOBA used the same MLB weights*, the bias is common-mode
and the **percentile is essentially unaffected**. It is only near-monotone, not
exactly (two hitters with different event mixes can swap under a reweighting),
but the distortion is second-order.

So: **an MLB-weighted college xwOBA is defensible as a ranking input and
indefensible as a displayed absolute.**

### 3b. Whatever we build, it must NOT be called "xwOBA"

`xwoba-canonical.md` is blunt: *every xwOBA value MUST match GC2*. And the GC2
amateur pitch page (Zac's paste, 2026-08-05) shows RV, swing-decision grades,
bat tracking and swing shapes — **no xwOBA**. So GC2 has no college xwOBA to
match. If we display a bare "xwOBA" on a college page we become the only
surface in the org showing one, and it silently means something different from
every other xwOBA we publish.

Naming options, least-bad first:
1. **`xwOBAcon (MLB wts)`** — explicit on both counts: it is contact-only, and
   the weights are MLB. Reads as "what his college contact would be worth in
   MLB terms," which is arguably the useful question for a draftee.
2. Show the **college percentile only**, no absolute. Zero naming risk,
   loses the number.
3. Re-derive true BBC weights from our own data (§3c) and call it xwOBA
   properly. Correct, most work.

### 3c. The real fix, if we want it

We have the college run environment in-house. `College.YTD_Player_Batting_Stats`
plus `Astros.Events_View` at `level_code='bbc'` is the same raw material Frey
scraped from stats.ncaa.org — and ours is cleaner. Deriving a `bbc` row for
`Guts.woba_lwts` per season is the FanGraphs method on our own data, and it
would make college wOBA/xwOBA canonical rather than borrowed. Cost: one
run-expectancy build per season. That is a real project, not a patch.

### 3d. Cheaper alternative Zac already has

`draftproj.YTD_Player_Batting_Stats_SOS_Adj_View` (found in Zac's GC2 paste,
2026-08-05) carries a **strength-of-schedule-adjusted college `woba`** plus
`adj_1b/2b/3b/hr/fo/hbp`, `bbr`, `sor`, `ba/obp/slg/ops`, keyed
`college_splits_id + season + level + team_id`. For the **season line** (page 2)
that is strictly better than anything we'd assemble from borrowed weights —
already college-scaled AND SOS-adjusted.

It does **not** solve xwOBA (it is a finished box number, not decomposable into
per-PA weights), and it is **box-derived** while pages 3-11 are **tracked** —
the split `amateur-data-guardrails.md` §1 insists on keeping straight. Label
which is which on the page.

**Recommended split:** page 2 season line ← SOS-adjusted view (box, college
scale). Contact-quality xwOBA ← MLB weights, labelled `xwOBAcon (MLB wts)`, or
percentile-only. Re-deriving real BBC weights (§3c) is the someday-correct
answer.

---

## Capture record

| Source | Fetched via | Date |
|---|---|---|
| <https://www.fangraphs.com/guts.aspx?type=cn> | WebFetch, direct | 2026-08-05 |
| <https://library.fangraphs.com/offense/woba/> | WebFetch, direct | 2026-08-05 |
| <https://rfrey22.medium.com/collegiate-linear-weights-f0237cf40451> | WebFetch, direct | 2026-08-05 |
| <https://blogs.fangraphs.com/adjusting-linear-weights-for-extreme-environments/> | WebSearch excerpt only | 2026-08-05 |
| <https://library.fangraphs.com/principles/linear-weights/> | WebSearch excerpt only | 2026-08-05 |
