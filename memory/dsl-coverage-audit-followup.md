---
name: DSL coverage audit — pending follow-up
description: Apr 29 2026 audit identified DSL coverage gaps; user spotted a broader pattern ("interesting gap that happens everywhere") to elaborate next session. Don't lose context — read this first when DSL comes up again.
type: project
originSessionId: 333de7e0-094e-475d-a8ca-262974033de7
---
# DSL coverage audit — picking back up

**Context:** Kyle Brennan asked Apr 29 2026 if DR (DSL) postgame
reports are working. User had run a diagnostic SQL on three DSL kids
(William Perez 1330305, Tomas Sveyda 1341670, Cesar Pastrano 1341673)
showing their 2026 activity is `sched_type='B'` (bullpens) at the
ROK facility, NOT DSL R-games — because DSL season hasn't started.

User asked for a documentation + app audit of where DSL is dropped.
Audit ran Apr 29 (this session). Right after audit, user said:
> "could we query Yensi De la cruz recent stats? since he has a gc id?
>  actually nvm i realized the gaps here!!!!!! its quite an interesting
>  gap that happens everywhere and im going to elaborate once we clear
>  context right now"

User is going to elaborate the "gap that happens everywhere" in a
fresh context. Wait for them to describe it before chasing fixes.

## What the audit found (so we don't redo this)

### Confirmed gaps (action items)
1. **Transition Report routing** — `pd-goals/src/transition_channels.py:31`
   has `"dsl": None  # TODO — user providing later; falls through to
   overflow`. Any DSL transition currently goes to pd-automation-test.
2. **DSL org Slack channel** — `pd-goals/scripts/generate_org_kpi.py:51`
   maps DSL → `C030F214ZLL` which is the generic `player-development`
   channel, not a DSL-specific operations channel. Confirm with user
   if a dedicated DSL channel should exist.
3. **slack_channels.csv DSL roster coverage** — Perez/Sveyda/Pastrano/
   Yensi De La Cruz (282878, line 284) are in. Full 2026 DSL roster
   should be audited before June (DSL season open).
4. **Tracker pin CLIs** — verify each app's
   `scripts/pin_*_tracker_seasons.py` includes 'dsl' in level loop.
   Not yet checked because pin CLIs live in respective worktrees;
   this audit ran from `feature/pd-goals` (main repo).

### Confirmed correct (no action needed)
- Percentile pools — `_build_level_filter('dsl')` correctly emits
  `gc2_level_code = 'dsl'` everywhere it's used
- PD Goals Org KPI per-level — DSL explicitly in `LEVEL_CONFIGS`
- WPA Plays daily — DSL in 7-affiliate scope
- Intangibles BR/OF/IF/Catcher KPI weekly — skips empty levels
  early-season (commit `6942d4b`)
- Postgame batch (Barrelsville/Arm Farm) — no level-based DSL
  exclusion; generates per-player per-game regardless

## Critical level-code distinction (for context next session)
- DSL: `gc2_level_code = 'dsl'` (gc2_level_id=24)
- FCL/ACL: `gc2_level_code = 'rok'` (gc2_level_id=20)
- BOTH share `level_code = 'rok'` — filtering ONLY on `level_code`
  conflates them
- Canonical helper: `_build_level_filter(level_code)` in each app's
  `database.py` — does `gc2_level_code` for dsl/rok, `level_code`
  for the rest
- DSL kids 2026 are showing up under `gc2_level_code='rok'` (FCL
  facility bullpens) and `'int'` because DSL R-season hasn't started

## When user re-engages
Don't dive into fixes until they explain "the gap that happens
everywhere." Whatever pattern they spotted is broader than just DSL
and needs their description first. Then prioritize fixes against the
4 audit action items above.
