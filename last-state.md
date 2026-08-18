# Last session state - 2026-08-18 13:17 (EOY Care & Performance is WIRED; Zac is pinning + testing in-app)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `76c3` - domain `bsb-resources/feature/pd-goals` - id `71c412ff641a7432`. Ring buffer 10/10.
- **What we were doing:** Two threads. (1) Answered performance science's max-vs-average question on the EOY Care page by running a 6-block discovery query. (2) Discovered the Care page's four testing tables had rendered EMPTY in every EOY deck ever sent, and wired them in.
- **Shipped this session:** `6b0d7cf8` `c926693b` `97d99620` `aaa67d7a` (sportsmed max-vs-avg) - `4d51d489` `78f5bedf` (care wiring + fix). New: `src/eoy_care_data.py`, `scripts/test_care_wiring.py`, `sql-queries/sportsmed-max-vs-avg-discovery.sql`. Rule `sportsmed-schema.md` updated + synced byte-identical to all 4 worktrees.
- **EXACT next step:** WAIT for Zac's report - he is pinning EOY then opening the app + in-app PDF to see Care pages 3-4 inside a full deck. If they render, this thread is DONE. If blank in the app but fine standalone, suspect the payload pin was built BEFORE `4d51d489` (re-pin) before suspecting the renderer.
- **Blockers / waiting on:** Zac's in-app EOY test. Nothing else.
- **Uncommitted work:** 72 files, almost all pre-existing untracked from other threads. Everything this session is committed and pushed.

### The two findings worth keeping
1. **Shoulder + groin ARE max; NordBord is the only average.** Established without a vendor export, by reconciling our components against the ratios VALD derives FROM them. The positive control (NordBord's own imbalance) is what makes it mean anything, and it is disambiguated ONLY by the 25 rows where LEFT > RIGHT. Gap priced at **+5.07%**.
2. **The data corrected me twice.** `trial` was never dead (the rule had said so since 08-17), and my own "output-neutral" claim about the AVG->MAX switch was wrong - 96 player-days carry a second row, spreads to 250.75 N. I also retracted an over-flag of my own after Zac pushed back: independent per-metric MAX is fine, because the care path pulls no imbalance/ratio id at all.

### Pin semantics (Zac asked directly)
`zbridger/eoy_position_payloads_{season}` - re-pin in the SAME year overwrites that season's pin; 2027 gets its own. Better than plain overwrite: `pin_eoy_position.py` MERGES (a scoped `--gcid` run cannot un-pin anyone) and has an anti-shrink guard, with `--force` as the deliberate-reset hatch.

---

## ALSO OPEN - 2027 Projection Magnet Board (session `96c3`, still live)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`. New app at repo-root `magnet-board/` (SIBLING of pd-goals/, not inside it).
- **Recall checkpoint (SOURCE OF TRUTH):** session `96c3` - domain `bsb-resources/feature/pd-goals` - id `b59c57b332af3513`. Ring buffer 1/10.
- **What we were doing:** Designed and built the 2027 Projection Magnet Board - a standalone FastAPI + SQLite + vanilla-JS app (deliberately NOT Posit) where Zac + Sam drag ~230 HOU players into a 7-level x 5-group grid to assert where each opens 2027. Got it running on the work laptop for a Peter demo.
- **Shipped this session:** `b2daeea5` locked CONTRACT.md - `0f8ffeab` v1 app - `1a0920ea` README - `0e700b9d` demo seeder + showcase render - `51ce725e` SP/RP rows. 231 tests pass. Design brief at `pd-goals/docs/plans/2026-08-15-org-magnet-board-design.md`, renders at `pd-goals/docs/plans/mocks/2026-08-15-org-magnet-board/`.
- **EXACT next step:** On the work laptop, before showing Peter - drag a magnet, hit SAVE BOARD, confirm `POST /api/moves 200` in the terminal, then Ctrl+Shift+R and confirm it stayed. Then fix `magnet-board/README.md`, which tells you to build a venv - that FAILS on the work laptop because `python -m venv` routes through the IT-blocked `uv.exe`. Replace with the no-venv `pip install fastapi uvicorn` path.
- **Blockers / waiting on:** Sam's feedback on the board (rows + levels are each one constant in `src/groups.py`, cheap to reshape). `scripts/export_roster.py` (real roster) has NEVER been run - do not demo it.
- **Uncommitted work:** 72 files in the working tree, almost all pre-existing untracked from other threads. magnet-board/ itself is fully committed and pushed.

### Two runbook corrections learned the hard way
1. `magnet-board/` is at the REPO ROOT. From `pd-goals/` it is `cd ..\magnet-board`.
2. **`python -m venv` is blocked on the work laptop** - it routes through `uv.exe`, which trips the Astros IT allowlist dialog. Skip the venv: `pip install fastapi uvicorn` installs to user site-packages under Python 3.14 and works. Only those two packages are needed to run (pytest/httpx are test-only).

### Design decisions locked (Zac)
- Org-wide, not DSL-only. A magnet asserts "where he opens 2027". One board, notes deferred.
- **NOT Posit** - so SQLite gives real row-level INSERT and the entire pin-clobber class evaporates.
- Rows are **SP/RP by ROLE** (2026-08-17, reversing an earlier RHP/LHP call). `POSITION_LK` encodes BOTH axes - RHS = right-handed STARTER, RHR = right-handed RELIEVER - so this needed no GS/G query and handedness survives on the card badge.
- loft/tilt is DEAD as a metric question (2026-08-18). Card metrics are phase 3 and unbuilt.

---

## ALSO OPEN - Care page / sportsmed (wrap of 2026-08-17, session 51ed)

Different work thread on the SAME repo+branch. Kept so this wrap does not flatten it.

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `51ed` - domain `bsb-resources/feature/pd-goals` - id `01b505e9b94d80b2`. **Ring buffer 10/10 - the next checkpoint EVICTS the oldest.** Durable material is in `LINEAGE.md` (`e62e16c2`) and `.claude/rules/sportsmed-schema.md`, not the checkpoint.
- **What we were doing:** closing the Care page's last open sources. The hamstring / shoulder / groin rows had been stand-ins with "source is being confirmed" in the code. All three found, wired, and rendered for a real player.

- **Shipped:** `3dd808af` extract + CSV render - `c954ee58` SQL fixes - `2439ee1e` three cards wired + the bodyweight retraction - `c3542e76` Nordbord test split + shoulder date gap measured - `94d63e83` `render_care_page_db.py` (direct-to-DB, the version that fills all six jump rows) - `fd8520e3` null-test guard - `6227dcf4` **`.claude/rules/sportsmed-schema.md`**, synced to all 4 worktrees - `e62e16c2` LINEAGE.
- **The answer:** everything is `SportsMed.Metrics`, an EAV store. Hamstring = Nordbord 78/79. Shoulder = GB Shoulder 1104/1105/1107/1108. Groin = GB Groin 1114/1115/1117/1118. One-to-one onto the card's row keys. Found from the COMMITTED schema snapshot with no DB run, then confirmed live. Coverage 237-247 players per device, 218 have all three.
- **RETRACTED mid-session:** entering bodyweight is NOT wired. `metric_type_id 116` has ZERO HOU rows. Finding a metric TYPE is not finding the number. Stays a pin.
- **Bug the data caught:** Nordbord logs `Nordic` AND `ISO 30` into the same id 78/79. Mixing them read Mitchell's Nordic entering against his ISO 30 current and drew a red arrow on a leg that went **up 18%**. `m.test` is in the grain everywhere now.
- **New finding, open:** the shoulder card's four values are a **median 128 days apart** (right newer 82% of 211 players; median last left Mar 23 vs right Aug 2) because only the throwing side is monitored in season. Groin is 100% same-day.

- **EXACT next step:** read Zac's terminal output from `python scripts\render_care_page_db.py --gcid 218498` (Jason Schiavone), which he was running on the work laptop as the session ended. Confirm **Time to Takeoff and Eccentric Duration actually populate** - they are the entire reason that script exists - and that the lower-is-better rows draw GREEN on a decrease. If it errors, look first at the `_FORCEDECK` conditional-aggregate CTE or the `_ROSTER` self-join.
- **Blockers / waiting on:** Tina on the shoulder date gap (show a date, suppress the stale side, or ship as-is) - Alvaro on which Nordbord test the card means, and on whether `Contraction Time` really is "Time to Takeoff" (still an inference, and a player-facing label on a guess).
- **Uncommitted work:** 72 untracked/modified paths, all pre-existing at session start.
