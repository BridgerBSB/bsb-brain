---
name: Always diff against the reference system before shipping
description: When changing a metric or aggregation, build a side-by-side comparison against the app/report the user considers canonical (PD Goals org KPI, postgame, KPI weekly) and verify BEFORE pushing. "My code matches my code" is not verification.
type: feedback
originSessionId: 3cb1f083-436b-47f9-82cd-292567632efd
---
When modifying any metric, filter, or aggregation in an app/report that has siblings (catcher tracker ↔ PD Goals org KPI, catcher tracker ↔ catcher postgame, etc.), the verification loop MUST compare the app's output against the reference system's output for the same org/player/level — not just against the app's own previous behavior.

**Why:** User explicitly called this out after I shipped a chain of "Phase B" catcher tracker changes that passed my internal diff harness (tracker-OLD vs tracker-NEW) but diverged from PD Goals org KPI on NetK, Pitches, CS%, Pop 2B. They pushed broken code to work laptop based on my false "0 drift" signal. Wasted hours of their time. "The fact that u havent side by side compared both is painful. And you're really doing me a fucking disservice."

**How to apply:** For any cross-app metric change:

1. Identify the reference system the user trusts (usually the one they mentioned: KPI weekly, PD Goals org KPI, postgame, etc.)
2. Read the reference system's SQL filter-by-filter — level filter, sched_type, date cutoff, JOIN order, attribution dimension, GROUP BY keys, the exact aggregation (COUNT DISTINCT vs COUNT *, PERCENTILE_CONT floor, AVG vs SUM/COUNT)
3. Build a harness that fetches the SAME org/player/level from BOTH the changed app AND the reference system, cell-by-cell diffs them, tolerates nothing more than float dust
4. Run the harness on work laptop; only ship when the diff is clean
5. If the user asks "does this match X?" and I haven't actually compared against X, say "I haven't diffed against X yet — want me to build that comparison?" — do NOT infer equivalence from code reading alone

Internal diff harness (app-OLD vs app-NEW) verifies that refactors preserve existing behavior. That is NOT verification that the app matches the reference system — the app could have been wrong before the refactor. Both diffs matter; only cross-system diff answers the user's actual question.
