---
name: feedback_ship_correctness_not_just_rate_movement
description: "Don't gate a metric-correctness fix on how much it moves the number. Wrong data on a coach-facing metric ships regardless of magnitude."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6d791984-ad56-4db1-a757-d171a77833e6
---

Jun 7 2026: after auditing the 1→3 run-attribution fix and finding it changed
the AAX rate by only 0.1pp (1 play), I recommended NOT shipping it. Zac
overruled, bluntly: "that one play is definitely worth shipping. I don't know
where you got that fucking idea." The play was a video-confirmed real success
the old proxy wrongly failed.

**Why:** These metrics are coach- and coordinator-facing. A play that IS a
success but reads as a failure is wrong data, and "it barely moves the
aggregate" is irrelevant to the player/coach looking at that specific line. We
"get fired if management catches us off" (see xwoba-canonical discipline) —
correctness is the bar, not materiality. Small-magnitude does not mean
low-importance.

**How to apply:** When a fix corrects a genuine bug (especially one a human has
eyeball/video-confirmed), default to SHIPPING it. Report the measured impact as
information, never frame "small rate movement" as a reason to skip. If there's a
real cost/risk to shipping (deploy churn, perf, ambiguous correctness), name
THAT specifically and let Zac decide — don't substitute "immaterial number" for
that judgment. Measuring impact first (the audit harness) is good and stays;
using the result to talk myself out of a correct fix is the error.

Related: [[2h-1to3-run-attribution-status]], [[feedback_never_defer_to_tomorrow]].
