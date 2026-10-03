# AC Dashboard — Open Questions Punchlist

Status: **ALL ANSWERED May 14 2026** — Q6 closed via Phase 2A `fd7e041`,
Q1–Q5 answered below. See "Decisions locked" section at top.

## Decisions locked (May 14 2026)

| Q | Decision | Implementation |
|---|---|---|
| Q1 — Defensive Grade composite | **SKIP** (A) | Remove TBD placeholder from Cards |
| Q2 — Hitting stats panel | **SKIP / DEFER** (D) | Remove TBD placeholder from Stats |
| Q3 — Per-pitcher approach matrix | **BUILD** (A) | Add to Pitchers tab |
| Q4 — 7-bucket framing | **STAY 5-bucket** (A) | No work needed |
| Q5 — Live scores | **MLB Stats API** (B) | Phase 2B: `/schedule?hydrate=linescore` |

### Work order
1. **Q5** — Phase 2B Scoreboard live scores (highest user value)
2. **Q3** — per-pitcher 5×6 approach matrix on Pitchers tab
3. **Q1 + Q2 + Q4** — TBD-placeholder cleanup (~30 min)

---

## Original punchlist (kept for reference)



Read each section, pick an option (or write Other), and reply. I'll
implement in priority order you set. Each question has a **recommended
default** so you can quick-approve if you don't want to deliberate.

---

## Q1 — Defensive Grade composite on Catcher Cards

**Context**: Cards has a TBD slot for a single "Defensive Grade" tile
(20-80 scale) that would composite Framing + Throwing + Blocking RV into
one number. KDB doesn't ship this; we'd be inventing.

**What's at stake**: Coordinators get a single "is this guy a good
defender?" number for at-a-glance ranking. Risk is editorial — the
weight mix is a value judgment that, once shipped, becomes hard to
change without coordinator pushback.

**Options**:

| Option | Pros | Cons |
|---|---|---|
| **A — Skip the composite entirely** | Honest. Three separate grades side-by-side. No editorial baggage. | No "one number" for at-a-glance ranking. |
| B — Equal weight (33.3% each) | Simple, defensible. | Framing volume >> throws >> blocks, so "equal weight" is misleading — Framing dominates the player's actual defensive value but counts the same. |
| C — Per-volume weight (FramRAA ~70%, Throws ~20%, BlockRAA ~10%) | Reflects how much each metric actually moves the needle. | Numbers are guesses; would need empirical RV-per-event analysis to pick well. |
| D — Just multiply each by a fixed conversion (FramRAA × 1, Throws RV × 1, BlockRAA × 1) and sum | True total defensive RV in runs. | Less interpretable as a 20-80 grade. |

**Recommended default**: **A — Skip the composite.** Show the three
grades stacked. Simpler, less editorial, easier to defend.

If we go A: remove the TBD placeholder from the Cards layout.
If we go B/C/D: I need a sign-off on the exact weights before
implementing.

**Your answer**: _____

---

## Q2 — Hitting stats panel on Stats tab

**Context**: Stats tab is defensive-only in v1 (Career defensive line
across all years × levels). KDB shows hitting context on their catcher
pages.

**What's at stake**: Catcher hitting is real signal — if a coordinator
is evaluating catchers, knowing AVG/OBP/SLG matters for the bench-or-
play call. But it's not the primary use case for AC Dashboard, which
exists for defensive analysis.

**Options**:

| Option | Metrics shown | Scope |
|---|---|---|
| **A — 5-tile standard** | PA · AVG · wOBA · xwOBA · K%-BB% | Single season selected at top |
| B — Full slash + advanced | AVG/OBP/SLG · wOBA/xwOBA · K%/BB% · Whf%/Chase% · Hard%/Barrel% | Single season |
| C — Splits view | A or B + vs RHP / vs LHP columns | Single season |
| D — Defer entirely | nothing | — |

**Recommended default**: **A — 5-tile standard, single season.**
Mirrors how Pitchers tab handles pitcher context. Splits / advanced
metrics can be a v1.5 ask.

**Your answer**: _____

---

## Q3 — 5×6 approach matrix per-pitcher (Pitchers tab)

**Context**: Pitch Calling tab has the AGGREGATED approach matrix (all
pitchers, count state × pitch type %). The question is whether to ALSO
add a per-pitcher version inside the Pitchers tab.

**What's at stake**: Aggregated tells you "what does this catcher call
on 1-1?" — useful for game-prep but not pitcher-specific. Per-pitcher
tells you "what does this catcher call for [Brown / Verlander / Pena]?"
— more useful for matchup planning.

**Options**:

| Option | Build |
|---|---|
| **A — Yes, add per-pitcher matrix** | Click any pitcher in the Pitchers list → expand sub-panel with their personal 5×6 matrix |
| B — No, aggregated is enough | Skip. Coordinator drills into Pitch Calling tab if they want pitcher-specific |
| C — Pivot existing aggregated to support a "filter by pitcher" dropdown | Less work than A, but shifts UX away from per-pitcher discovery |

**Recommended default**: **A — Add per-pitcher matrix.** Coordinator
mental model is matchup-driven. The query is a copy of the aggregated
one with `WHERE pitcher_id = :pid` added.

**Your answer**: _____

---

## Q4 — 7-bucket framing detail (Catcher Cards)

**Context**: AC currently uses the 5-bucket canonical framing (E Stl /
Stl / Mid / Loss / B Loss) per `.claude/rules/intangibles.md`. KDB
shows 7 buckets — they split Mid into Mid+ (Edge call, leans strike)
and Mid- (Edge call, leans ball).

**What's at stake**: Granularity. The 5-bucket version is enough to
separate good framers from bad. 7-bucket lets you see WHICH side of the
zone the framer is most influential on — useful for coaching specific
edge-pitch tendencies. But it's a new internal canonical that we'd
have to maintain across surfaces (postgame, KPI weekly, tracker, PD
Goals — see `rules/three-surface-parity.md`).

**Options**:

| Option | Cost |
|---|---|
| **A — Stay 5-bucket** | Zero work. Matches current canon. |
| B — Add 7-bucket as Cards-only display | Light work (CSC range split for Mid+/-). Doesn't change the canonical 5 elsewhere. Risk of confusion ("why does Cards show different buckets than postgame?"). |
| C — Promote 7-bucket to canonical | Major refactor — all 6 catcher surfaces need updates (`three-surface-parity.md`). Probably 2-3 days of work. |

**Recommended default**: **A — Stay 5-bucket.** Defer 7-bucket to v2
if a coordinator asks for it. Maintaining cross-surface parity is more
valuable than KDB-display-matching here.

**Your answer**: _____

---

## Q5 — Live / final game scores on Scoreboard

**Context**: Scoreboard slate shows the games but not their R-H scores.
Two paths to fill the gap.

**What's at stake**: Scoreboard's whole purpose is "what happened
yesterday across affiliates?" — showing 5-3 final next to each row is
table stakes.

**Options**:

| Option | Path | Notes |
|---|---|---|
| A — Internal DB probe | Find score columns on `Astros.Schedule_View` or join to `MLBAM.Gamelog_*` | Need a schema probe SQL — likely a `home_score` / `away_score` exists somewhere |
| **B — MLB Stats API live** | `/api/v1/schedule?sportId=N&date=...&hydrate=linescore` returns linescore inline | Architecture already proven (design doc Phase 2B). Single API call per date, cacheable |
| C — Skip live scores | Show matchup only | Probably the wrong call — coordinator complaint guaranteed |

**Recommended default**: **B — MLB Stats API.** Per the existing
design doc, this is exactly the Phase 2B ship: one new function
`fetch_schedule_with_scores(date, sport_ids)` in `mlb_stats_api.py`,
plug into `data/scoreboard.py`, done. ~2 hours of work. No DB probe
needed.

If you want Option A instead, I'll write a `sql-queries/schedule-score-
columns-probe.sql` for you to run on the work laptop.

**Your answer**: _____

---

## Q6 — Umpire schema probe — ✅ CLOSED May 14

Brodie confirmed `MLBAM.PBP_PreGame` as the source. Probe ran on work
laptop. Phase 2A shipped Umpire tab on commit `fd7e041`. No action
needed.

---

## How to reply

Drop a line per question like:

```
Q1: A
Q2: A
Q3: A
Q4: A
Q5: B
```

Or freeform per question. I'll implement in the order you list them.
Quick-approve all defaults with "ship all A".

## Implementation order if all defaults approved

1. **Q5 → Phase 2B**: Scoreboard live scores via MLB Stats API. ~2 hours.
2. **Q3**: Pitchers tab per-pitcher approach matrix. ~3 hours.
3. **Q2**: Stats tab hitting panel (5 tiles). ~2 hours.
4. **Q1 + Q4**: Cleanup — remove the Defensive Grade TBD placeholder
   (Q1=A), no work for Q4=A. ~30 min.

Total ~7-8 hours. Could ship over 1-2 sessions.
