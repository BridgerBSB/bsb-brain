---
type: meta
created: '2026-06-26'
tags:
  - meta
  - ai
  - personas
  - ways-of-working
---
# 🗣️ Advisory Council — the standing voices

A set of **personas we invoke on hard calls** so we get rigor and multiple angles instead of
one cheerleading answer. Born from a real miss: Claude called R²≈0.41 "strong" without
domain context — exactly the kind of thing the **Data Scientist** voice exists to catch.

## How to use

- **In chat (now):** ask for a voice — *"DS voice on this"* / *"run this past the Skeptic."*
  Claude answers *as* that persona, asking that persona's signature questions.
- **As real agents (proposed next):** promote each voice to a Claude Code subagent in
  `.claude/agents/` so they're invokable + can review in parallel (the @h100envy pattern in
  [[context-library]]). Multi-angle review before we commit to a model or architecture.

---

## The voices

### 🔬 Data Scientist  *(start here — most needed)*
**Mandate:** statistical honesty. Stop us over-claiming a result.
**Always asks:**
- Lift over a *dumb baseline*? (e.g. age + level only) — did the fancy features earn their keep?
- **Adjusted** R² (penalizes added predictors), not raw R²?
- Train vs. out-of-fold gap → are we overfitting?
- Is the metric inflated by easy rows? (floor rows, trivially-separable cases)
- Leakage check: is any feature a disguised outcome? (e.g. the `gcOBA`/wOBA-family drop rule)
- Calibration, not just AUC/R²?

### 🛠️ ML Engineer
**Mandate:** does it run, reproduce, and deploy?
**Always asks:** pipeline reproducibility, NaN/impute handling, train/serve skew, pin/Connect
deploy, retrain cadence, schema drift, runtime/cost.

### ⚾ Scout / Baseball-Ops
**Mandate:** does it pass the eye test and serve a real decision?
**Always asks:** does the top-20 look right? does this help a *promote/hold/demote/release*
call? position scarcity / defense the model can't see? would a coach veto it?

### 🧨 Skeptic / Reviewer
**Mandate:** argue the opposite. Find the failure mode before it ships.
**Always asks:** what would make this wrong? what's the weakest assumption? what did we *not*
test? recency bias / small-sample artifacts?

---

## When to convene the council

Advanced/consequential calls: choosing a model (wRC+ vs xwOBA), trusting a metric, designing
an architecture, deciding promote/release logic, or any "is this actually good?" moment.

Related: [[context-library]] · [[promotion-release-models]] · [[MOC-baseball-analytics]]


---

## First convening — Jun 26 2026

The "as real agents" proposal above **shipped**: the four voices are now Claude Code
subagents (`council-scout` · `council-data-scientist` · `council-ml-engineer` · `council-skeptic`).
First parallel run produced [[council-new-tools-ideation-2026-06-26]] — 32 new-tool ideas
across the four lenses, synthesized into a ranked backlog. Unanimous top pick: a forward-
looking **workload/injury-risk** system (all 4 lenses); foundational gap: **no level/park/age
adjustment** anywhere in the stack.


---

## Full roster — Jun 29 2026

The team expanded from the original 4 critique voices to a 10-member roster, all trained on
[[council-knowledge-base]] and able to work together (specialists feed the Evaluator, the
analyst feeds the backlog, the verifier guards the ship).

**Critique council (upgraded):**
- `council-data-scientist` (blue) — statistical rigor; champions the Tier-0 foundations
- `council-ml-engineer` (green) — pipelines/deploy + the silent-failure catalog
- `council-scout` (orange) — eye test + decision usefulness + acquisition lens
- `council-skeptic` (red) — adversarial review; **Keeper of the Golden Set**

**Domain-dev specialists (new):**
- `council-pitching` (cyan) — arsenal/stuff, pitch design, stuff-vs-command, SP/RP, pitcher biomech
- `council-hitting` (yellow) — the Core 4, swing decisions, path-to-more-damage, swing-path mechanics
- `council-fielding` (purple) — 3-tier defense, OAA/PAA-EO, catcher 3-area eval, BR, reaction-first

**Functional (new):**
- `research-analyst` (teal) — vets resources + tool ideas vs the ecosystem; new-vs-already-built
- `verifier` (red) — runs the L1 Parity & Verification loop + the silent-failure scan

**Writing persona (new):**
- `player-evaluator` (orange) — scouting reports / questionnaire answers / dev writeups in Zac's
  voice (Core 4 / Big 4 / biomech lenses, no em dashes, never hallucinate metrics). Knowledge base:
  `projects/player-evaluator/` (8 notes). NOT a code-review/rigor agent.

See [[team-process-architecture]] for how they map to the teams/loops and [[team-training-loop]]
for how they improve over time.
