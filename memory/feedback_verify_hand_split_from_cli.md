---
name: verify-tracker-hand-split-status-from-cli-source-not-category-reasoning
description: "Before claiming any tracker pin is \"hand-agnostic\" (or any property of what a pin writes), grep the pin CLI's bundle_key calls + header docstring. Don't infer from rule-text statements about physics or metric categories."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3bc2a9b3-7ab3-4bd7-a879-e18b5fecdf5e
---

When I'm about to claim a tracker's pin writes (or doesn't write) hand-
split variants — or any other dimension property — the source of truth
is the CLI script itself, not the rule files describing it.

**Why this exists:**

May 27 2026. The user pointed out their fielding pin build emitted a
"missing 60 keys" warning for fielding (60 = 10 prefixes × 3 H/A × 2
L/R variants). I diagnosed correctly: fielding is hand-agnostic, doesn't
write L/R, validation list is too aggressive. I shipped a fix to
`write_tracker_bundle` to accept an `expected_hand_splits` arg, then
updated three callers to pass `(None,)`:
- `pin_fielding_tracker_seasons.py` ✓ correct
- `repair_tracker_pin.py` (fielding only) ✓ correct
- **`pin_br_tracker_seasons.py` ✗ WRONG**

I claimed BR was hand-agnostic based on this line in `pooled-percentile-pattern.md`:
> BR TopSpd/React/T22/Split1/Accel: hand-agnostic (same physical sprint
> regardless of pitcher hand). NO hand split on the raw_obs pin.

The rule was technically correct — *for the sprint percentile metrics*.
But it has a second sentence I skimmed past:
> Lead distance metrics (PL/SL) ARE hand-dependent but they're means,
> not percentiles, so they live outside this rule.

The BR pin carries BOTH sprint percentiles AND lead-distance means. The
pin as a whole writes hand-split variants because PL/SL leads are
pitcher-hand-sensitive (a runner takes a different lead vs LHP because
of the pickoff angle). The header of `pin_br_tracker_seasons.py` says
it plainly on line 12:
    "x 3 hand splits (all, l, r)   <-- May 2026 design"

User caught it within minutes ("baserunning is not hand agnostic... we
have been using the pitchers hands.... why tf did u do tthat!??!!?").
Had to ship a revert commit (`71598e85`) and a meta-apology.

**How to apply:**

Before claiming a tracker (or any pinned data layer) has property X,
verify by reading the CLI:

1. Grep the CLI script's header docstring. It usually documents the pin
   matrix shape ("N prefixes × N HA × N hand").
2. Grep for `bundle_key(prefix, ...)` calls in the CLI to see which
   dimensions are actually iterated and written.
3. Grep for the `expected_hand_splits` / `expected_prefixes` arg the CLI
   passes to `write_tracker_bundle` — that's what the CLI itself thinks
   it writes.

NOT acceptable:
- Citing a rule-file sentence about physics or metric categories.
- Reasoning from "all the metrics I can think of are hand-agnostic."
- Pattern-matching on "fielding doesn't need it so BR probably doesn't
  either."

Rule files describe the *intent*. The CLI is the *implementation*. When
they disagree, the CLI wins because that's what actually got pinned.

**Tripwire:**

If I'm about to type "tracker X is hand-agnostic" (or "doesn't need Y
dimension"), STOP. Grep the CLI's header + `bundle_key` calls in the
last 60 seconds. If I haven't, I'm guessing.

**Related:**
- `pooled-percentile-pattern.md` — talks about percentile-metric hand
  agnosticism specifically. Read the WHOLE rule, not the headline.
- `feedback_no_design_doc_column_assertions.md` — same shape, different
  domain. Verify-before-asserting applies broadly.
