---
name: Power-5 College Contact Floor — shipped to AGM
description: One-off Power-5 hitter contact-translation analysis shipped to AGM Gavin via Slack on 2026-04-30. Regression + residual scoring + retention-floor recommendation. User uncertain about repeatability.
type: project
originSessionId: e531482a-bcff-4dbd-b829-437cc5e54bc4
---
# Power-5 College Contact Floor — shipped 2026-04-30

One-off analysis answering Gavin's (AGM) ask: "what's the absolute floor for
college contact rate that translates to the pro level?" Built on
`feature/barrelsville` worktree.

**Final commit on the analysis:** `b167666` (R + R² display + cover glossary
update). PDF + script: `barrelsville/scripts/generate_power5_contact_floor.py`.

## What was delivered

PDF with 6 pages:
1. **Cover** — terms + methodology only (sample, glossary including R/R²/slope, methodology blocks for typical drop line / residual / retention floor, page guide). No charts, no tables.
2. **Lowest 30 retention winners** — lowest college Ctct% players who still beat typical loss (residual > 0).
3. **Linear retention scatter** — college vs pro Ctct% with PA-weighted regression line, R/R² in legend.
4. **Retention floor bar chart** — % of each 2pp college Ctct% bucket that beat typical loss. Floor reads off where curve crosses 50%.
5. **Bubble scatter** — reference visual of pass-rate distribution.
6. **Floor by pass-rate bucket** — supporting-evidence table.

## Methodology summary

- **Sample:** Power-5 4-year-college hitters drafted 2021–2026, pitchers excluded (`R4_Draft_Query` + `school_type = '4YR'`).
- **Volume gates:** ≥50 amateur PA at BBC, ≥50 PA per pro level counted, ≥50 total pro PA.
- **Amateur:** BBC level only, draft year only, all sched_types.
- **Pro:** A/A+/AA/AAA/MLB regular-season only.
- **Ctct% formula:** `(swings − whiffs) / swings`, sums-then-divide (no mean-of-rates).
- **Regression:** PA-weighted least-squares of cumulative pro Ctct% on college Ctct% via `np.polyfit(x, y, 1, w=w)`. Yields `pro = 0.65 × college + 21.25`, R = 0.71, R² = 0.51.
- **Residual:** `actual_pro − predicted_pro` in raw pp. Positive = beat typical loss.
- **Retention floor:** lowest 2pp bucket where ≥50% of players have residual > 0. With `TRANSLATION_MIN_BUCKET_N = 3`, the strict floor came out at ~62% college Ctct% — but that's a thin-sample bucket.

## What user actually told Gavin (final Slack message, sent 2026-04-30)

> Most confidently I'd say ~69 Contact% and would not venture beyond that if you're looking to confidently predict contact% floor. There are anomalies lower than that pocket, but realistically from this sample I'd say - although limited - the success rate ~69% would allow one way more confidence in predicting translation of contact to the professional level over that of selection like Tim Elko (~62%).
>
> Honest answer: it depends. College contact rate alone explains a decent amount of what we see in their pro contact rate (R = 0.71, R² = 0.51).
>
> What I see in the data:
> - Average Power-5 hitter loses ~6–7 pp of contact going from college to pro. The drop scales with starting point — guys at 90%+ college can give back 10pp; guys around 70% give back ~3pp.
> - Strict statistical floor lands at ~62% college Ctct% — that's the lowest 2pp bucket where ≥50% of players still beat the typical drop. But it's a thin sample. I wouldn't draft off it.
> - More confident floor: ~69% college Ctct%. Below that, basically nobody in the dataset held contact at every level they reached, let alone passed pool average everywhere. Once you hit the 68–69% range, you start seeing names that filled all the pass-rate buckets (above league avg at every level).
> - Players DO outperform their college contact more often than people think — about a third of the cohort lands above the regression line. Translation is real and partly captured by the residual on page 2 of the PDF.
>
> Bottom line: I'd treat ~69% college Ctct% as the soft floor, with 62% as the absolute statistical floor that I'd only invoke if a player has multiple other elite tools to compensate.

## User's stated uncertainty about this work

User explicitly said "I don't really know if this is how I wanna go about this in the future. I mean, like, this wasn't really modeling, but I don't know. It's just something I did. I don't even know if it holds any significance, but I ripped it." Treat this as: **don't preemptively codify the methodology as a reusable pattern.** If a similar question lands later, surface this work but ASK the user whether they want to repeat the approach or do it differently.

## Methodology limitations to surface if they ever come back

These are real but were NOT addressed in the shipped PDF / Slack reply. Document so future-me doesn't accidentally treat the analysis as more rigorous than it was:

- **Survivorship bias (unaddressed).** The ≥50 pro PA gate excludes guys who washed out completely. So population is "Power-5 hitters who survived to ≥50 pro PA," not "all Power-5 hitters drafted." The "typical drop" is conditional on surviving — actual avg drop including washouts would be larger.
- **62% floor is mechanically thin.** Sensitive to `TRANSLATION_MIN_BUCKET_N = 3`. If a 60–62% bucket has 3 players and 2 happen to beat typical, floor reads 62%. User correctly flagged this in the Slack message.
- **"About a third lands above the regression line" claim is unverified.** OLS construction puts ~50% of (unweighted) residuals on each side. PA-weighted skews slightly. User said "about a third" — this could be true if AAA/MLB high-PA guys cluster above and A-ball low-PA guys cluster below, but next time verify the actual count from `compute_residuals()` output before stating publicly.
- **Linear assumption** is fine within observed 60–92% range. Don't extrapolate.
- **Cumulative pro Ctct% pools across levels.** Two players with same pro Ctct% but different level mixes (one 800 PA at A vs one 80 PA at AAA) are treated identically by the line. Not level-adjusted.
- **No statistical significance test.** No p-values, no confidence intervals on the floor estimate. The 62% / 69% distinction is descriptive, not inferential. If Gavin or anyone asks "is the 69% floor statistically distinguishable from 65%?", the honest answer is "we don't have the tests to say."

## When this kind of analysis is/isn't appropriate

Pattern: amateur input → PA-weighted regression → residual scoring → bucketed empirical floor.

**Works for:** descriptive "what does the data show?" questions where the audience is comfortable with caveats and you're not making forecast/decision recommendations.

**Doesn't work for:** decision-grade modeling (player draft rankings, $/value attribution, predictive forecasting at the player level). For that, would need: proper held-out validation, confidence intervals, survivorship-adjusted population, level-adjusted pro outcomes, test for floor robustness.

## Cross-references

- `.claude/rules/draft-projects.md` — pattern catalog this fits into (companion to `amateur-vs-pro-development-report` from same week).
- `.claude/rules/draft-tables.md` — schema reference used (R4_Draft_Query + PP_MASTER UDFA path, school_type='4YR').
- `.claude/rules/level-codes.md` — BBC = College (4-yr amateur).
