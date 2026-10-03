# Verification Backlog — "UNTESTED on live DB" punch list

**The L1 (Parity & Verification) loop's first concrete output.** Everything DB-touching is
authored blind on the personal laptop (no DB access) and must be smoke-tested on the **work
laptop** after `git pull`. This is the living punch list for that post-pull sweep so nothing
ships unverified. Tick items off; add new ones the moment a DB-touching surface is authored.

> Source: the Jun 27 2026 ecosystem inventory. Confirm exact commands against each app's
> README / the cascade scripts before running — paths/flags may have drifted.

## How to use (work laptop)
```powershell
git pull
$env:CONNECT_API_KEY = "<key>"   # PER PowerShell session — pin reads fail silently without it
# work an item, verify output, redeploy if it's an app, tick the box
```
Watch for the silent-failure signatures while testing: hidden `logger.warning` (use `print`),
Logic App returning 200 on a malformed payload, phase exiting 0 while 0/23 Slack sends land.

## Punch list

| # | Surface | App / branch | Verify | Rough command | Status |
|---|---|---|---|---|---|
| 1 | ACWR feasibility diagnostic | bsb-resources | Pitch-count density by level (incl. DSL/FCL) + DL_Stints validation sample | run `sql-queries/acwr-feasibility-pitch-count-density.sql` | ☐ |
| 2 | Pitch Similarity Finder (pg 6) | Arm Farm / `feature/bullpen-reports` | Pool query returns; multi-pitch combo match; z-score toggle | pull → smoke the page → redeploy Arm Farm | ☐ |
| 3 | Pitch-efficiency (P/Out·P/PA·P/K·P/BB) | Arm Farm | Values populate after re-pin | `python scripts/pin_tracker_seasons.py --year 2026` → redeploy → check tracker | ☐ |
| 4 | Trend Leaderboards sub-tab | all 6 trackers (3 apps) | WoW/MoM/YoY boards render, ranks correct | pull bullpen + barrelsville + intangibles → live-test → redeploy 3 Connect apps | ☐ |
| 5 | Swing Decision Grader v1 | Barrelsville | Batch PDF renders for a real player; FOUL_CODES confirmed vs LK table | `python scripts/generate_swing_decision_grade.py` (a known gc_id) | ☐ |
| 6 | Zero-count phase 2 + weekly | Arm Farm | App Visuals view + `--weekly` trailing-7 vs YTD + Slack to #weekly-iz-vs-usg | `python scripts/generate_zero_count.py --weekly` | ☐ |
| 7 | Swing Path 3D arc | Barrelsville | Eyeball arc-through-contact shape on a real swing | Postgame → Visuals on Riley (gc 4773) | ☐ |
| 8 | Contact Map gcOBA parity | Barrelsville | Parity row: Contact Map vs Postgame Report vs GC2 (known IBB/p95 divergence) | compare same hitter's gcOBA TOTAL across the 3 | ☐ |
| 9 | Promotion models v1 deploy | `feature/promotion-models` | 9-step DEPLOY.md: train→publish→schedule→redeploy; confirm scores render | walk `pd-goals/modeling/DEPLOY.md` | ☐ |
| 10 | v2 wRC+ projection (PARKED) | modeling | Re-run eval; confirm MiLB-only signal honestly (R² mirage) before any un-park | `RUNBOOK_V2.md` Steps 1–6 | ☐ |
| 11 | Fielding advance OF 3×5 grid | Intangibles | scipy bump + `show_images` skip clears KDE "black balls" | redeploy after env rebuild | ☐ |
| 12 | Promotion-velocity one-off | bsb-resources | 3 QA bugs: AV formula, PA undercount, censoring | re-run + diff vs expected | ☐ |

## Future (the runner half of L1, not yet built)
A `verify-pull.ps1` that auto-runs the smoke checks above against the live DB on the work
laptop and reports pass/fail per surface — so the sweep is one command, not a manual walk.
Until then this list IS the loop.
