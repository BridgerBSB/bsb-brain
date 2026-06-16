---
name: PD Goals defense fetches MUST fall back to 'ALL', NEVER roster pos_cat
description: Every defense data fetch in PD Goals (bar chart, rolling chart, percentile lookup, PDF report) must scope position as `defense_pos_override or 'ALL'`. Roster pos_cat fallback silently drops plays for utility / mid-season-position-swap players.
type: feedback
originSessionId: e28fae83-ba75-4764-9e98-b29c4b89d8c3
---
# The rule

```python
_eff_pos = goal.get('position_override') or 'ALL'   # ← 'ALL', NEVER pos_cat
```

**Why:** Roster `position_category` is stale. Players get promoted, demoted,
swap positions mid-season. Caden Powell (gc_id 283965) is rostered SS at
A Fayetteville but has been playing mostly OF. His "Have a positive PAA/EO"
goal has no position keyword. Bar chart correctly used `'ALL'` and showed
0.004. Rolling chart had `position_override or pos_cat` (roster fallback) →
scoped to INF only → dropped every OF play → blank chart. Burned an entire
debug session before the user surfaced the rule.

The 'ALL' fallback is INTENTIONAL — it lets us capture every play regardless
of where the player is currently rostered. Goal-text position keywords (e.g.
"PAA/EO at 1B") still scope correctly via the parser's
`_extract_position_override()`.

# How to apply

Before adding ANY new defense data fetch to PD Goals (`get_defense_stats`,
`_fielding_per_play`, `get_per_game_data` for fielding, anything that takes
a `position_category` arg), use the canonical formula:

```python
_eff_pos = goal.get('position_override') or 'ALL'
```

Three live surfaces that follow this rule:
- `pd-goals/pages/1_PD_Goals.py::fetch_player_stats` (line ~578) — canonical bar chart
- `pd-goals/pages/1_PD_Goals.py::_fetch_one` (line ~1410) — rolling chart app
- `pd-goals/src/report.py` (line ~1144) — rolling chart PDF

**Test for any new surface:** pull a player rostered at one position who has
been playing elsewhere (Powell SS→OF, Brutcher OF→1B), and confirm the new
surface returns the same value as the bar chart. If it returns less or empty,
the position scope is too narrow.

Full doc + checklist: `.claude/rules/pd-goals.md` § "Position Override — Goal
Text Drives Defense Routing — BLOCKING"

Fix commit: `5a85752` on `feature/pd-goals`.
