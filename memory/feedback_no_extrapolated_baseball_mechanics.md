---
name: Don't extrapolate baseball metric mechanics from textbook knowledge
description: Verify metric computation mechanics in the actual code/DB before publishing them. Don't assume "this is how Statcast does it" without grepping our impl.
type: feedback
originSessionId: 7d997549-27b1-48e2-b481-d59230e40942
---
When documenting how a metric is computed, distinguish what's
verified from the codebase / canonical rules vs. what's extrapolated
from public Statcast / Baseball Savant / FanGraphs documentation.
**Verify in the code before publishing specifics.**

**Why:** May 9 2026 incident — wrote a worked example in the PD
Apprentice Handbook (Ch 6) showing a 2B getting -0.20 PAA on a play
the SS made (out_prob 0.6 vs 0.2 distribution). The "no gate" rule
itself was verified in `fielding.md` and `pd-goals/src/stats.py`. The
exact multi-fielder out_prob distribution mechanics --- whether DCBP
actually gives multiple fielders rows for the same `(sched_id,
event_id)`, and how out_prob splits across them --- I extrapolated
from how Statcast OAA is publicly documented. Our queries always
filter DCBP to ONE fielder, so the multi-fielder claim was invisible
from the source code I had access to. User caught it: "so you fact
checked this?"

**How to apply:**

When writing handbook / doc / PR description text that describes:
- How a metric is computed across rows
- How a value distributes across players, plays, or events
- What a column means at the row level
- How an aggregation handles edge cases (multi-fielder, multi-runner, etc.)

…always verify by:

1. Grepping the actual computation in our `src/*.py` (the canonical
   location, usually `stats.py`, `tracker_data.py`, or
   `kpi_data.py`).
2. Checking `.claude/rules/<topic>.md` for the canonical rule.
3. If the rule references DB schema mechanics, run a diagnostic
   query against the actual DB (or note that the audit hasn't been
   done).

If you can verify the high-level rule but NOT the row-level
mechanics, write the rule confidently and the mechanics with hedge
language ("we haven't audited this directly --- run diagnostic X if
the question comes up").

**Don't:**

- Write specific numerical worked examples (out_prob 0.6 / 0.2) when
  you haven't seen the actual distribution in our DB.
- Claim "Statcast does X, so we do X" without grepping our code.
- Conflate the high-level rule (which IS verified) with the
  implementation details (which may not be).

Pairs with `feedback_no_inventing_titles.md` (don't guess people's
roles), `feedback_no_design_doc_column_assertions.md` (verify DB
columns), and `feedback_no_made_up_effect_sizes.md` (don't fabricate
magnitude estimates). Same root cause across all four: confidently
asserting things I haven't verified.
