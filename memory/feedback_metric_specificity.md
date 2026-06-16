---
name: Metric Specificity in Communication
description: Always specify which base (1B/2B), which context (daily/season/percentile), and which filters when discussing leads, tracking, or any metric
type: feedback
---

When discussing queries and metrics, ALWAYS be specific about:
- **Which base:** 1B leads vs 2B leads (different filters apply)
- **Which context:** daily display vs season average vs percentile pool (different gates)
- **Which filters:** fielder <= 10, runner_going, NOT EXISTS next base — name them explicitly

**Why:** User flagged (Apr 8, 2026) that vague metric communication causes confusion. Saying "leads don't filter on fielder distance" without specifying "1B primary lead season averages in br_data.py" is ambiguous and misleading. The same metric can have different filter tiers in different contexts (daily shows all, averages gate on fielder <= 10, percentiles gate further).

**How to apply:** When auditing or discussing any metric, always state: the metric name, which base/position, which file, and which tier (display/average/percentile). Never say "we don't filter X" without specifying where.
