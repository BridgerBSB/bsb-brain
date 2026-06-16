---
name: Always ask per-player vs pool aggregation for org rollups
description: Before building any org-comparison / org-ranking analysis, ask the user whether they want per-player simple mean (each player = 1 vote) or pool aggregation (volume-weighted). Don't default silently.
type: feedback
originSessionId: 58380251-d4ee-47b3-8b01-23f11b4f3e74
---
When building any analysis that rolls per-player metrics up to one
number per org, **ASK the user which aggregation mechanic they want**
before writing the rollup code. Two valid mechanics exist and they
answer different questions:

- **Per-player simple mean** — `mean(per_player_values)`. Each drafted /
  rostered player contributes 1 vote regardless of PA volume. Right for
  "what we are good at developing" framing (development is per-player).
- **Pool aggregation** — `SUM(numerator) / SUM(denominator)`. Volume-
  weighted. A 1500-PA vet dominates a 25-PA rookie. Right for "how is
  the org's pool actually performing right now" framing (matches Org KPI
  / Weekly KPI mechanics).

**Why:** They produce visibly different numbers, especially when the
pool has high PA-variance players (e.g. amateur-vs-pro analyses where a
2-AB amateur sits next to a 280-AB Cape Cod college guy). The user has
made it clear the choice is project-specific and shouldn't be defaulted
silently.

**How to apply:** In any prompt for a draft / amateur / org-rollup /
org-ranking project, surface the choice with the trade-off framed
concretely:

> "Org averages: do you want **per-player simple mean** (each
> drafted hitter weighted equally — best framing for 'what we
> develop') or **pool aggregation / volume-weighted** (matches Org
> KPI / Weekly KPI mechanics — better framing for 'how is the org's
> pool performing right now')? They produce different numbers; both
> are defensible."

If using a skill or building one (the user has flagged a future
draft-project skill), this question MUST be one of the gating
prompts — don't ship without an explicit answer.

History: the amateur-vs-pro hitter development report (Apr 28 2026,
`barrelsville/scripts/generate_amateur_vs_pro.py`) shipped with
`pool` as the silent default, then immediately surfaced as a problem
(Bryce Matthews's 123.7 mph max EV via pool MAX). Switched to
`per-player` default after user direction. The lesson: ask first,
don't assume — these projects vary on which framing the user wants.
