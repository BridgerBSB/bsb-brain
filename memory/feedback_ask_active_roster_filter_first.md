---
name: Ask About Active-Roster Filter Before Building Any Player-Flag Project
description: For new player-flagging / intervention-candidate projects, ASK as design step 1 whether to filter by current PP_MASTER active roster. Released/traded players leaking into output is a design bug, not a data bug.
type: feedback
originSessionId: 28f6e904-6554-438b-a427-98d7522dcb9f
---
# Rule
Before writing the first line of SQL for any project that surfaces players (drift detection, intervention candidates, weekly flag reports, KPI snapshots, anything where "the output is a list of players"), ASK the user whether the player pool should be **filtered to currently-rostered HOU PP_MASTER active players** (Alvaro's pattern, codified in `pd-goals/src/roster.py`).

**Why:** "Played for HOU this year" is NOT the same as "currently rostered." Released / traded / DFA'd players keep showing up in flag outputs for the rest of the season otherwise. PD Flag Tracker shipped May 10 2026 with Willingham/Sanchez (released) appearing in flags — caught and patched same-day, but it would have been the right design choice from day 1.

**How to apply:**
- Project category trigger: drift detection, intervention compilation, weekly flag report, player KPI surface, anything where the *output rows are players*
- Question to ask up front (BEFORE writing SQL): "Should we filter by currently rostered HOU active per `MLB_eBis.PP_MASTER` (Alvaro's pattern), or include everyone who played for HOU this year regardless of current status?"
- The canonical filter pattern lives in `pd-goals/src/roster.py:120-138` and is the same one `kpi-roster-filter.md` codifies for KPI weekly Season tables
- Don't assume — different projects have different answers (e.g. a "season recap" project might want every player who appeared; a "this week's intervention candidates" project wants currently rostered only)

**Behavioral cue:** if the user says something like "use eBis guys only" or "the guys who are currently Astros" or "active roster only" — that's PP_MASTER filtering. If they don't volunteer it, ask anyway.

This pairs with `kpi-roster-filter.md` (BLOCKING rule for KPI weekly Season tables) and `org-board.md` (Org Board's two roster query sources).
