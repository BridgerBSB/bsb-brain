---
name: advance-opponent-window-and-ha
description: "Advance reports — opponent-window bug fix (all 3 worktrees) + Barrelsville H/A toggle, Jun 23 2026"
metadata: 
  node_type: memory
  type: project
  originSessionId: 843d9e43-ef5b-41d5-a2ee-82b75a77b360
---

**Advance reports — two things shipped Jun 23 2026 (Drew Saylor asks).**

**1. Opponent-window bug FIXED + VERIFIED LIVE (all 3 worktrees + run_monday).**
Advance picked opponents by `--series` COUNT, not a date window → FCL/DSL/MLB
(multiple single games vs different opponents per week) got only ONE advance.
Fix: date window (`--days 7`) returns ALL opponents in the week; `--series`
default → 0 (manual override). `run_monday.ps1` advance steps now pass `--days 7`
(was `--series 1`). Barrelsville extra bug: `--series` default 1 (truthy) made the
existing `--days` window dead code. **Durable rule written + synced 4 worktrees:
`.claude/rules/advance-opponent-window.md` (BLOCKING).** Commits: barrelsville,
bullpen, intangibles, pd-goals run_monday — all pushed. **User confirmed runs work
("list multiple opponents now").** Multi-level one run: `--level dsl rok` (FCL=rok).

**2. Barrelsville hitter advance H/A toggle BUILT + LIVE.** Sidebar All/Home/Away
radio on `pages/3_Advance.py` (Series Scouting + Pitcher Look-up); toggles on-screen
report AND batch ZIP (App↔Report parity) + `--ha` CLI flag. Filters the SCOUTED
PITCHER's own H/A outings (home = top_of_inning=1). Sample stays SAME size (scope
walks back to hit same IP from H/A games — switch-hitter mechanic); percentiles stay
whole-league. Data layer: `is_pitcher_home` (MAX top_of_inning) on outings query +
top_of_inning splice on pitch query — NO new tables. `src/advance_data.py` +
`pages/3_Advance.py` + `scripts/generate_advance_batch.py`. Committed/pushed
feature/barrelsville. **OPEN polish (not done):** no H/A scope label on the PDF/app
header yet (a coach can't tell Home-only from All at a glance) — render-and-look gated.

**Same session also: contact-quality metrics** (see [[contact-quality-metrics-status]])
— Smash/Square%/AA4-16% pinning 2026 + app redeploys in progress.

**Deploy procedure confirmed (work laptop):** app = `rsconnect deploy manifest
--server https://connect2.astros.com --api-key $env:CONNECT_API_KEY --app-id <GUID>
manifest.json` (Barrelsville `bbb53548-a7c5-4a03-9146-44647e7c88c0`, Arm Farm
`13482bcb-8ff2-4f20-92c9-5465f49e5846`). Pin-job bundle = `.\connect_pins\deploy.ps1`
per worktree. **GOTCHA: redeploy the pin BUNDLE too or tonight's scheduled job
re-pins 2026 with OLD code and reverts new columns to blank.**
