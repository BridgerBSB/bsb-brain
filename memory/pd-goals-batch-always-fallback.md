---
name: pd-goals-batch-always-fallback
description: generate_goals_batch.py always includes every player in goals.csv — never filter by end_date >= --end. Players in the gap between 6-week cycles still get PDFs delivered against their most-recent (closed) goal period.
metadata: 
  node_type: memory
  type: project
  originSessionId: 1350278f-8a7d-4154-a34b-53684cad1db9
---

## The rule

`pd-goals/scripts/generate_goals_batch.py` MUST include every row in
`goals.csv`. Do **not** filter by `goals_df['end_date'] >= end_date`.

**Why:** `goals.csv` stores **one row per player** = that player's
current-or-most-recent 6-week goal period. The CSV is updated in-place
each cycle (start_date / end_date rewritten on the same row, never a new
row appended). So filtering to `end_date >= --end` silently drops every
player whose 6-week window closed before the run date — exactly the
group that needs the report most in the gap between cycles.

**How to apply:** when Monday runs land between cycles (most weeks of
the year, briefly), coaches still get weekly PDFs against the players'
last-known goal targets. Active-period players behave identically to
before. The stdout summary breaks out active vs closed counts.

## Bug history

- **May 18 2026** (`ee610fca` on `feature/pd-goals`) — User ran Monday
  batch with `--end 2026-05-18`. Only 9 of 97 PDFs generated because
  88 players had `end_date = 2026-05-05` (prior cycle close). Filter
  removed in the same commit. See [[generate_goals_batch.py]] line ~85.

## What NOT to do

- Don't re-add an `end_date >= --end` filter. Use the active-vs-closed
  count in stdout instead if you want visibility.
- Don't add a cutoff ("don't fall back if period ended >N days ago").
  User explicitly rejected that — always fall back, regardless of
  staleness, until the row is rewritten in `goals.csv`.
- Don't add an "EXPIRED" badge to the PDF header. User didn't ask for
  it. If they ever do, only modify [[report.py]] header rendering,
  never the batch filter.
- Don't assume multiple rows per player in `goals.csv`. As of May 2026
  it's strictly one row per `groundcontrol_id`. If that ever changes,
  the always-include behavior needs a `drop_duplicates(subset=["groundcontrol_id"], keep="first")` after `sort_values('end_date', ascending=False)`.

## Rolling chart decoupled from goal dates (May 18 2026, `e46e0085`)

Companion change shipped same session: the 6 Week Rolling Value chart
(both PDF report.py and Streamlit pages/1_PD_Goals.py) is hardcoded to
`today - 42 days -> today`. NOT goal_start -> goal_end anymore.

**Implications:**
- Fallback players see real recent form data, not a frozen chart at their cycle close date.
- Chart final-tick value no longer matches the Goal Period stats column (different windows).
- Target / direction lines and grey sample-size text are still goal-driven.
- Season + Goal Period stats columns are unchanged.

**What NOT to do:**
- Don't try to "fix" the parity break between chart endpoint and Goal Period column. User asked for it explicitly.
- Don't put a cap on the chart's right edge at goal_end. The chart deliberately extends past goal_end.
- Don't extend the window past 42 days without explicit user direction. 6 weeks ending today is the contract.

## Cross-references

- [[pd-goals.md]] — rules file, PD Goals app family overview
- `pd-goals/data/goals.csv` — canonical source
- `pd-goals/scripts/pin_goals.py` — push CSV edits to Connect pin
