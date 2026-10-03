---
type: inbox
created: '2026-07-16'
tags: [inbox, session-digest, needs-processing]
session: 5267af4f
corrections: 2
---
# Session digest — 2026-07-16 16:27:46UTC · 5267af4f

- cwd: `C:\Users\Owner\bsb-resources` · end: clear · 154 turns · 6 files · 14 bash
- raw: [[transcripts/2026-07-16_5267af4f.jsonl]]

## Files touched
- `pitcher_analysis.py` ×8
- `usage_count_table.py` ×5
- `hitter_analysis.py` ×3
- `swing_path_data.py` ×2
- `last-state.md` ×2
- `usage_count_smoke.py`

## ⚠️ Possible teaching moments (curate → golden set)
> "I thought about this. Maybe we need a skill for this in the future, but I don't really know. You've been pretty good at this in the past, so my... My appearance is put in a code apprentice has put in a PR review, and here it is. And let me know if it's valid. …"
>   ↳ after: (session start)

> "this is incorrect - we dont auto deploy off main we autodeploy off branches: - It's feature/bullpen-reports, not main. Nothing auto-deploys off it - the cascade only runs when you pull on the work laptop and run it. So a wrong-xSLG version sitting on the branc…"
>   ↳ after: Short answer: **yes, you can merge-then-fix here** - but do the fix before the next Monday…

## Conversation skeleton (first 30 of 154)

**You:** I thought about this. Maybe we need a skill for this in the future, but I don't really know. You've been pretty good at this in the past, so my... My appearance is put in a code apprentice has put in a PR review, and here it is. And let me know if it's valid. What he's doing here…
→ I'll review this properly. It's an Arm Farm (bullpen-report) change touching canonical metrics (gcPerf, xSLG, IZ%, Whiff%) and PDF layout, so I need to verify it against our reference implementations …
→ `Skill`
→ `Glob`
→ `Glob`
→ `Read`
→ `Read`
→ `Read`
→ `Read`
→ Good — I have the canonical gcPerf/whiff/InZ formulas. Now I need to verify the PR against the actual surrounding code: what columns `_query_pitch_data` selects (does `pitch_df_cur` even carry `called…
→ `Read`
→ `Grep`
→ `Grep`
→ `Grep`
→ `Astros.Hits_Probabilities` and those `prob_*` columns appear **nowhere** in the Arm Farm codebase — this is a brand-new table+column set the apprentice introduced with no existing reference. Let me v…
→ `Grep`
→ `Grep`
→ `Read`
→ `Astros.Hits_Probabilities` is real (holds xBA/xSLG/xwOBA), and the canonical expected-stats impl is `barrelsville/src/hitter_kpi_data.py` — which combines the prob columns with **exponents from `Guts…
→ `Read`
→ `Grep`
→ `Grep`
→ `actual_shift = 1` matches canonical — good. Two things left: the exact xSLG **formula** (does canonical apply `hit_specs_ratios` exponents to the prob columns, vs the apprentice's flat linear weights…
→ `Grep`
→ `Read`
→ xSLG is the key open question. The canonical hitter expected-stats block carries `exp_1b/2b/3b/hr = 5.0` exponents from `hit_specs_ratios`. I need to see exactly how the canonical SQL combines the `pr…
→ `Read`
→ `Read`
→ I have what I need on gcPerf/whiff/InZ (they're correct, including the subtle gcPerf-uses-(10,22,23) vs Whiff%-uses-all-6 distinction). The last thing to nail is xSLG: our codebase DOES have a canonic…
→ `Grep`
