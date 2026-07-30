# Last session state — 2026-07-30 09:49 (PD Goals cockpit — Phase 2)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` · branch `feature/pd-goals`
- **What we were doing:** Built Phase 2 of the PD Goals cockpit — the org-wide
  Level × Domain landing view — and retired `st.tabs` for a keyed `st.radio` so
  changing Year/Phase stops snapping back to tab 1. Then walked Zac through the
  work-laptop deploy; he's 1 of 4 steps in.
- **Shipped this session (all pushed to `feature/pd-goals`):**
  - `372ca801` — cockpit view + `st.tabs` → keyed `st.radio`. Conversion verified
    safe FIRST by AST cross-reference of assigned-vs-used names per tab block
    (zero cross-view deps), because only the selected view's body runs now.
  - `a0d9618d` — cockpit → Player Goals hand-off (picker + button, deliberately
    NOT `st.dataframe(on_select=)`; row clicks are canvas and can't be verified
    headless).
  - `fb236058` — fixed `stamp_goal_domains.py --dry-run` crashing with
    `TypeError: Invalid value '' for dtype 'Int64'` + 3 regression tests.
  - `LINEAGE.md` entry: "PD Goals landing becomes an org cockpit; st.tabs retired".
  - New: `src/cockpit.py`, `tests/test_cockpit_shape.py` (15),
    `tests/test_stamp_goal_domains_dtypes.py` (3),
    `scripts/_render_cockpit_live.py` (offline render harness).
    Renders committed at `docs/plans/mocks/pd-goals-cockpit/phase2-app-*.png`.
    23 tests pass. No new pin, no new SQL, no new metric.
  - **Work laptop, step 1 of 4 DONE:** `stamp_goal_domains.py` wrote 202 rows /
    540 derived cells, goals pin `20260730T113236Z-01996`. `blank season = 0`,
    `blank phase_label = 0` — the Phase-1 mixed-date bug never damaged the live
    pin; only `domain_1/2/3` needed stamping.
- **EXACT next step:** On the work laptop, from
  `C:\Users\zbridger\bsb-resources\pd-goals` with `$env:CONNECT_API_KEY` set,
  resume at step 2 of 4:
  `rsconnect deploy manifest . --app-id 79f52369-8244-46da-a4d6-95df956bacad`
  → `.\connect_pins_compliance\deploy.ps1`
  → `python scripts\pin_compliance.py --season 2026` (~3-8 min, this is what
  FILLS the matrix). Then compare the cockpit matrix **Total** cell against the
  Goal Compliance view **Total** for the same Year+Phase — same pin, same
  helper, must match exactly.
- **Blockers / waiting on:** Steps 2-4 above (work laptop only). Between steps 2
  and 4 the cockpit renders with every domain column empty and only Total
  populated — expected degraded state, not a bug. Zac has not yet SEEN the
  cockpit, so three design calls are unconfirmed: cockpit-as-default-landing,
  trend defaults to by-Level, matrix click filters the whole page.
- **Uncommitted work:** 84 files, ALL pre-existing and unrelated (slide-deck
  scripts, an eoy-catching png, untracked `.claude/` scaffolding). Nothing from
  this session is uncommitted.

---

## ALSO OPEN — IF/OF Range & Difficulty (intangibles)

Previous wrap, a DIFFERENT repo/branch — still live, preserved.

- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` ·
  branch `feature/astros-intangibles`
- **What we were doing:** Brought the IF Range & Difficulty view to parity with
  OF, fixed the infield spray so dots sit where the ball MET the fielder (not at
  its first bounce), made the play population a user toggle, and rebuilt
  Out/Hit/Error labelling on official scoring. Ended on a performance question,
  not a bug.
- **Shipped:** 21 commits `5e1f7241..7608c5fc`, all pushed; Zac deployed
  `3788a839` and confirmed "this looks great at the moment". Spray anchor
  (`add_if_spray_coords`), `First defender only` sidebar toggle (default ON),
  `fielding_base.batted_ball_outcome` from `event_result_id`.
- **EXACT next step:** Collapse the 11 per-angle `Astros.Video_Network` LEFT
  JOINs in `_video_joins` (`intangibles/src/fielding_range_data.py:67`) into ONE
  derived table with conditional aggregation — 12 of the per-play query's 22
  joins, all idle until a dot is clicked. Build it as an OLD-vs-NEW diff harness
  asserting byte-identical video columns; it CANNOT be tested off the work laptop.
- **Blockers:** Phase-06 UAT unrun vs live DB; Mazzo sign-off still required
  before the IF range page ships in a DELIVERED weekly PDF.
- **Still broken, known:** OF spray still plots grounders at the infield first
  bounce (`add_if_spray_coords` is IF-only) — the original bug of that session,
  still live on the OF side.
