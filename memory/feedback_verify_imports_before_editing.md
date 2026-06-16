---
name: Verify imports before editing any module
description: ALWAYS grep pages/ + scripts/ for imports before editing any src/*.py module — don't pattern-match on filenames
type: feedback
originSessionId: 2f326d35-2456-4767-9e09-8aded11fa014
---
Before modifying ANY `src/*.py` file, run:
```bash
grep -rn "from.*<module_name>\|import <module_name>" intangibles/pages/ intangibles/scripts/ pd-goals/pages/ pd-goals/scripts/ bullpen-report/pages/ bullpen-report/scripts/ barrelsville/pages/ barrelsville/scripts/
```

Zero hits = dead code. Do not edit.

**Why:** Wasted 4+ commits editing dead files across multiple sessions.
- Intangibles has DEAD per-domain tracker files (`of_tracker_page.py`, `of_tracker_data.py`, `if_tracker_page.py`, `if_tracker_data.py`) that were replaced by the unified `fielding_tracker_page.py` + `fielding_tracker_data.py`.
- I pattern-matched on "IF tracker → `if_tracker_*.py`" without verifying imports.
- Rules files listed both dead + live files as needing parallel fixes, reinforcing the illusion the dead ones were live.
- Prior session had the same mistake with `get_arm_angle()` — function written, drawing code written, never wired to CLI.

**How to apply:**
1. When user says "fix the X tracker / Y report / Z module," NEVER grab files by name.
2. Run the grep above first to find what's actually imported.
3. If multiple candidates exist (e.g. `fielding_tracker_data.py` + `if_tracker_data.py`), edit the one that's imported by the live page. Confirm with `head pages/<page>.py`.
4. If the rules files contradict (list both as "needs fixing"), trust the grep over the docs.
5. Intangibles specifically: live fielding tracker = `fielding_tracker_*` (powers both OF + IF via `domain` parameter). Dead = `of_tracker_*` + `if_tracker_*`. See `.claude/rules/intangibles.md` "Affiliate Tracker — Live vs Dead File Map".
