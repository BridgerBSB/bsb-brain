---
name: Match reference implementations BEFORE writing new code
description: When building new queries/reports, ALWAYS diff against the reference app line-by-line before committing — user was burned by gcPerf divergence
type: feedback
originSessionId: 07d26e72-c3dd-4006-8ca0-aa5327d16d8a
---
When building any new query or report that has a reference implementation in another app, ALWAYS audit every metric calculation against the reference BEFORE the first commit. Don't just match column names — match the exact pitch result codes, RV values, filter conditions, and code group constants.

**Why:** On Apr 11, the org KPI pitching gcPerf used flat ±0.02 RV values instead of Arm Farm's zone-differentiated whiff RVs (-0.10/-0.08), wrong called strike codes (5 vs 1), and wrong ball codes (11 vs 3). User had to catch this after multiple rounds of testing. This is CLAUDE.md Rule #1 ("Always read existing sibling/reference implementations before writing new code") and it wasn't followed.

**How to apply:** Before committing any new query that computes a metric another app already computes:
1. Read the reference app's actual SQL/Python for that metric
2. Diff every CASE expression, code group, filter, and formula
3. Present a comparison table to the user showing match status
4. Only commit after confirming parity

This applies to ALL new reports, not just org KPI. The pattern: grep the codebase for the metric name, find who computes it, match exactly.
