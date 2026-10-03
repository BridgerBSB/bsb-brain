---
name: feedback_confirm_integration_target_before_building
description: "When asked to build a new tool/app, confirm whether it's a standalone app or a tab/page inside an existing app BEFORE building"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e4e180a0-5ce3-4def-a271-8fc45ff80905
---

When the user asks for "an app" / "a tool" that relates to an existing app, CONFIRM the integration target before building: a brand-new standalone Posit app, or a new page/tab/card inside an existing app (Arm Farm, Barrelsville, Intangibles, PD Engine)? Default assumption should lean toward **a tab in the relevant existing app** unless they say standalone — that's how this codebase is organized (each domain app has numbered `pages/` + a landing with cards).

**Why:** Jun 20 2026, the Pitch Similarity Finder. The /goal said "create an app… it's gonna be a Posit app," which I read as standalone and built `pitch-similarity/` top-level. The user was frustrated: *"it should be a square tab in arm farm!!! just like pitcher postgame, or advance!!!"* I had the signal and missed it — the seed query (`sql-queries/jagger-beck-fastball-shape-comps-mlb.sql`) literally said "the seed for an Arm Farm app tab… that build lives in the bsb-wt-bullpen worktree." Had to re-port the whole thing into Arm Farm (`pages/6_Pitch_Similarity.py`) and delete the standalone.

**How to apply:**
- New pitching tool → Arm Farm page (`bsb-wt-bullpen`, `feature/bullpen-reports`, `bullpen-report/pages/N_*.py` + a landing nav-card in `Arm_Farm.py` + manifest entry).
- New hitting tool → Barrelsville. Fielding/BR/catcher → Intangibles. Goals/org/cross-domain → PD Engine.
- Standalone is the EXCEPTION (e.g. injury_tracker is private under pd-goals; indy-ball-scraper is its own repo) — only when the user explicitly wants it separate or it has a distinct audience/access model.
- Check for a seed SQL / design doc comment naming the intended home before choosing placement.
- Adding an Arm-Farm-style page is cheap: page file (sys.path + `from src.X import`), a landing `nav-card` `<a href="PageName">`, register both new files in `manifest.json`, reuse the app's `src/database.run_query` + `src/roster`.

Related: [[pitch-similarity-app-status]], [[player-development-dual-track]].
