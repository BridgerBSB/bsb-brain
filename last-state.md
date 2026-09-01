# Last session state - 2026-09-01 08:49 (magnet board batch + two access fail-opens)
- **Project / cwd:** `C:/Users/Owner/hiring` branch `main` (+ `bsb-resources` `feature/pd-goals` for the roster SQL)
- **What we were doing:** Shipping Sam's and Zac's magnet-board list - multiple project boards, SP/RP instead of RHP/LHP, the field reflecting the grid, the release boxes, MNFA/Rule 5 years, board delete, sharing - then chasing why granting a coordinator "was being weird".
- **Shipped this session:** 13 commits, `24e1da0..d2dcc17` on `hiring/main`, all pushed. Railway auto-deploys every commit on main (Watch Paths unset).
  - `24e1da0` multiple project boards at `board:<email>:<slug>`; `board:<email>` untouched
  - `d62c2b8`/`7cfaa49` the drag fix - a fixed dock was painting OVER the magnet being dragged (measured with elementFromPoint); replaced with edge auto-scroll
  - `15a5034` the importer silently dropped `r5_first_year`/`mnfa_year` - why no chips ever appeared
  - `d8d8434` SP/RP + field-follows-grid + UTIL + delete + no self-share
  - `2be5e5b` outbox is not a delivery; `9348527` a coordinator that fails to set is disabled, not left an admin
  - `d2dcc17` lineage
- **NOTHING ANYONE SET UP WAS TOUCHED** - verified, not assumed. Only two paths write or delete a board (`magnet_api.py:602`, `:782`) and both build the id from the SESSION (`_board_id(me, slug)`); no parameter can name another person's board. SP/RP migrates ON READ (`ROW_MIGRATE`), zero stored rows rewritten. No existing account's role was changed - `access_add` was only made stricter.
- **EXACT next step:** open `https://multi-purpose-ston.up.railway.app/admin/access` and look for the red banner naming **RESEND_API_KEY**. If it is there, email is not configured on this deployment and that alone explains the coordinator trouble - the fix is a Railway service variable, not code. Then re-run `sql-queries/magnet-board-roster.sql` on the work laptop and re-import to light up the MNFA/R5 chips.
- **Blockers / waiting on:** Zac confirming the batch renders live; whether RESEND_API_KEY is set (only Railway can say); the MNFA 18-and-under branch (+7) is fitted to Zac's correction and only Soto is verified against a GC2 card.
- **Uncommitted work:** clean (untracked `deck/` only, 294MB, deliberately ignored)

---

## ALSO OPEN - Barrelsville advance / two-way pitcher (previous session, different repo)

# Last session state - 2026-08-31 (two-way pitcher in Advance + NordBord answer)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-hitting` branch `feature/barrelsville` (+ `bsb-resources` `feature/pd-goals` for rules/SQL)
- **What we were doing:** Grayson could not find Seong-Jun Kim (two-way, Hickory/TEX) in Barrelsville Advance before facing them next week. Found why, fixed it, Zac deployed and confirmed. Earlier: answered Tina's NordBord max-force question from the live DB.
- **Shipped this session:**
  - `cb6be9ca` (bsb-wt-hitting) - Advance pitcher SEARCH qualifies on "eBIS says pitcher OR has thrown a tracked pitch in 12 months", not on `POSITION_LK`.
  - `9dd072d7` (bsb-wt-hitting) - `_apply_unclassified_fallback`: label NULL `pitch_type` as `UN` **only when nothing in the sample is typed**. `get_scouting_pitches` is now a thin wrapper over `_get_scouting_pitches_impl`.
  - `27aa7762` - `.claude/rules/advance-non-ebiz-pitchers.md` gains the two-way + unclassified failure modes.
  - `sql-queries/two-way-pitcher-lookup-kim.sql`, `kim-pitch-classification-check.sql`, `sportsmed-vald-metric-inventory.sql`.
  - `sportsmed-schema.md` + `sport-science-data-methodology.md` - NordBord re-check, the empty torque types, and the ownership correction.
  - LINEAGE entry in `bsb-resources/LINEAGE.md` covering both threads.
- **The finding that mattered:** eBIS stores **ONE primary position**. Kim is `SS` while starting games, so widening the whitelist to include `'TWP'` would NOT have found him. Any gate on an eBIS label keeps missing two-way players - the qualifier has to be behavioural. Second: his `pitch_type` is all NULL, and `dropna(subset=["pitch_type"])` blanked every pitch table while BB%/GB-FB% kept populating off the event path. **That combination is the diagnostic signature.**
- **Kim's facts:** gc_id `1288000`, ebis 10020324, mlbam 834605, DOB 2007-05-01, throws R. 2026: afx 54 pitches/2 games (8/19-8/26), rok 138/5, min 11/1.
- **EXACT next step:** **NOTHING - Zac called it done and deployed both fixes.** If it resurfaces, the only unverified thing is the rendered look of the `UN` row in a real report (never rendered locally; his deploy check was the verification). Do NOT "finish the job" by changing `advance_data.py:191` (org roster dropdown) or `:303` (IL query) - those keep the position gate on purpose.
- **Blockers / waiting on:** none on our side. Tina owes a decision on dominant-shoulder-only vs both (128-day L/R shoulder gap); a call about Claude was requested and not scheduled. **The R&D NordBord ingest ask is performance science's to file - do not re-raise it as Zac's item.**
- **Uncommitted work:** `bsb-wt-hitting` 41, `bsb-resources` 77 - all pre-existing scratch, nothing from this session.
- **Heads up:** `bsb-wt-hitting` HEAD has moved past my commits to `30d2957f` (swing-angle work from a concurrent session). `sync-rules.sh` timed out at 2 min, so the 3 sibling worktrees may not have the updated rule files - re-run `/sync-rules`.

---

## ALSO OPEN - pitch tempo for DJ Engle (`bsb-resources` `feature/pd-goals`)

Still live, waiting on DJ. Preserved from the 2026-08-30 wrap:

- **Project / cwd:** `C:/Users/Owner/bsb-resources` branch `feature/pd-goals`
- **What we were doing:** Answering DJ Engle (pitching coordinator): can we pull per-pitch timestamps to see rest time between pitches. Yes - shipped the query.
- **Shipped this session:**
  - `sql-queries/pitch-tempo-by-pitcher.sql` (`de5caeb8`) - seconds between pitches, per pitcher, per game, rendered Central. THE deliverable.
  - `sql-queries/pitch-timestamps-discovery.sql` - the discovery trail, dead ends, and the coverage probes.
  - `.claude/rules/central-time-not-utc.md` + **blocking rule #20** - every timestamp a human reads is Central. Synced to all 4 worktrees, `test_rule_routing.py` PASS.
  - `db-columns.md` / `DATABASE_REFERENCE.md` / `tracking-schema.md` corrected; LINEAGE entry appended.
  - `MEMORY.md` 35.8KB -> 17.5KB (it was past its 24.4KB read limit, trailing sections loading as nothing); 07-24..08-17 split to `memory/session-log-2026-07-08.md`.
- **The source (canonical, R&D's path):** `Tracking.Plays.pitch_release_tracking_timestamp_id` -> `Tracking.Timestamps.[timestamp]` (datetime2, **UTC**, verified). Bridge `Plays.astros_pitch_id = Pitches_View.pitch_id`. `Statcast_Plays.pitch_release_utc` gives byte-identical coverage but is one ingest partition.
- **What the data settled:**
  - MLB game 1298131: **231 pitches, 4 pitchers, ZERO missing.** within-PA median **20s** (IQR 18-24), new batter **36s**, new inning **~9.7 min**. Within-PA p75 (24) sits below the batter-change MIN (27) - that separation is the pitch timer, the only check measured against something OUTSIDE the DB.
  - Coverage: mlb 99.88 / aaa 99.81 / afx 78.48 / aax 77.94 / afa 76.16 / rok 50.98 / dsl 0. Gap is **whole GAMES, not scattered pitches** -> inside a covered game every interval is real at every level.
  - **DSL is an INGEST gap, not untracked** (Schedule_Link says Trackman recorded both games). Never say DSL is untracked.
  - DEAD END: `Pitches_View.tracking_timestamp` exists and is EMPTY (231/231 NULL).
- **EXACT next step:** **NOTHING TO BUILD - waiting on DJ.** He was sent the tempo output and has not expanded. Do not build a per-pitcher tempo report on spec. When he answers, the fork is: tempo inside a PA (this query, done) vs recovery between innings/outings (needs NO timestamps - `sched_date` deltas, see `sql-queries/acwr-feasibility-pitch-count-density.sql`). If work resumes first, the one cheap open probe is step 11 of `pitch-timestamps-discovery.sql` (what ARE the three `*_Plays` tables) - explanatory only, blocks nothing.
- **Blockers / waiting on:** DJ Engle's answer on which quantity he wants. Coverage measured on ONE date - want a second before quoting ~77% affiliate to a coordinator.
- **Uncommitted work:** 77 in `git status --short`, all pre-existing untracked scratch from prior sessions. Nothing from this session uncommitted.
- **The lesson, written into LINEAGE:** three wrong turns, one shape - **I trusted a NAME over a COUNT.** Said no timestamp column existed (our hand-written docs are incomplete); named `tracking_timestamp` off the SCHEMA without counting a value in it; read three vendor-named tables as three SENSORS and told Zac "Statcast is the only feed" when **Statcast IS Hawkeye**. Brodie's 2023 query had the right join all along.

---

## ALSO OPEN - swing angles (bsb-wt-hitting / feature/barrelsville)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-hitting` branch `feature/barrelsville` (rules + SQL in `bsb-resources` / `feature/pd-goals`)
- **What we were doing:** Making HBA legible, then VBA and AA, then measuring them on Christian Walker + Xavier Neyens, then speccing the org-wide "optimal angles on damaged contact" study.
- **Shipped this session:**
  - Three DB-free geometry explainers, each drawn in the plane its angle is measured in: `hba_explainer.py` (overhead), `vba_explainer.py` (catcher's view), `aa_explainer.py` (side view, ONE panel - AA has no bat_side term so a mirrored second panel could only repeat the first). PNGs in `barrelsville/docs/plans/mocks/hba/`.
  - `hba_distribution.py` - 4-row per-player viewer (all swings / contact / whiffs / hard-hit EV 95+), reads the CSV, no DB.
  - `sql-queries/hba-walker-neyens-per-swing-2026.sql` - Zac ran it, 1,561 rows.
  - `.claude/rules/swing-characteristics-canon.md` - all eight characteristics; synced to all 4 worktrees.
  - `barrelsville/docs/plans/2026-08-30-optimal-swing-angles-spec.md` - the study spec.
- **What the data settled:**
  - **Whiffs DO have SCV frames** - 486 rows vs 497 BIP. `db-columns.md` said they did not; corrected.
  - **So do TAKES** - 24 rows with `did_swing = 0`, HBA junk from -80 to +63. `e1x_con IS NOT NULL` is not a swing filter.
  - HBA: Walker +12.9 / +11.8 contact / +18.7 whiffs; Neyens +7.3 / +8.0 / +9.4. Both POSITIVE-centred. **Whiff IQR is 2.2x contact IQR for both hitters.** Hard-hit HBA is NOT tighter than contact - that hypothesis was measured and died.
  - VBA never goes positive in practice (max seen -2.3 across 1,537 swings). AA barely differs contact vs all swings, unlike HBA.
  - **Damage is per-batted-ball already** (`pd-goals/src/metrics.py::calculate_damage_vectorized`); Damage% is just its mean. But Walker's median ball scores 0.0010 - it behaves like a top-third detector.
- **EXACT next step:** Spec section 6 - **run the CHECK before building anything.** Pull FCL + A hitters' per-BIP EV/LA for 2026, score damage per ball, and see whether the distribution separates at all at those levels. If it is degenerate, damage is out there and LA+top50EV becomes the candidate. Cheap query: driven from `Pitches_View` on indexed `batter_id`, one season, order 20-40k rows, seconds.
- **Blockers / waiting on:**
  - Four decisions for Zac in spec section 7 (joint objective with contact rate? show unresolved players? switch hitters? keep wOBAcon?).
  - **NOT fixed, needs Zac's call:** `tracker_data.py`'s `_HBA_QUERY` / `_VBA_QUERY` / `_AACON_QUERY` / `_BATSPEED_QUERY` have zero `did_swing` references, so shipped HBACon/VBACon/AACon/BatSpdCon include takes (1.5% here, extreme values). Four metrics x three surfaces - needs `metric-audit`.
- **Rules drift found and fixed:** blocking rule **18b** + `query-cost-before-handoff.md` existed in `bsb-wt-bullpen` ONLY. `sync-rules.sh` would have deleted them. Recovered into canonical, synced; all 114 rule files byte-identical across 4 worktrees, `test_rule_routing.py` PASS.
- **Uncommitted work:** all session work committed and pushed on 4 branches. Pre-existing untracked: bsb-resources 77, bsb-wt-hitting 41, bullpen 11, intangibles 14 - none from this session.

---

## ALSO OPEN - EOY notes incident (separate thread, do not delete)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` branch `feature/pd-goals` (also `bsb-wt-bullpen` / `feature/bullpen-reports`)
- **What we were doing:** Day 2 of the EOY notes incident. Everything from day 1 is deployed. Today was proving nothing is still being deleted, and building the report Zac hands colleagues who ask.
- **Shipped this session:**
  - `6de05226` **`audit_eoy_notes.py`** - one page: current boxes by department and level, every EMPTIED box by name with its old text, and an explicit "WHAT THIS CANNOT TELL YOU".
  - `5484f71e` prints people AND report rows. 167 vs 184 is one dataset at two grains (17 players hold both a coordinator report and an off-season plan); side by side without the reason it reads as 17 players vanishing.
  - `5d7bb861` `--since` filters **Central**, not UTC (blocking #20). It had reported 161 creates for "today" that were the weight load at 8-9pm CT the night before.
  - `ce20eaa3` prints a 5-sentence Slack reply with the numbers, so the answer and its evidence come out together.
  - Yesterday's work, all live: `40c77bf1` merge fix, `0313f6fc` Arm Farm blank guard, `57f4192a` nightly payloads, `ce5fbefd` pyarrow, `677d81bc` LINEAGE.
- **State of the data:** **CLEARED 0** on four runs through the afternoon while boxes climbed 242 -> 250. Coordinators saving cleanly (four history-then-notes pairs in the 3-4pm log, no errors). Loss landed on **Coordinator 16 / ATC 5 / Strength 8** vs Goals 179 and Nutrition 42 - the three thin ones are the departments whose text lived only in the pin.
- **EXACT next step:** Get the S&C coordinator's `s_c_offseason_recommendations` text out of the export, then RENDER the care page at production dpi and look. `[EOY care] S&C offseason recommendations overflows even at 6.0pt -- 4 item(s), budget 0.638` fired at 4:15pm; `eoy_care_page.py:853` sets `y_floor=0.035` (bottom of page) so the overflow runs OFF the page. The code is correct - it shrinks to 6pt then draws and warns rather than clipping silently. Do not guess at the layout (render-and-look.md).
- **Blockers / waiting on:**
  - **Slack delivery was never used for EOY decks** (Zac confirmed) - the "pull PDFs from player channels" recovery avenue is DEAD. What is left: someone's downloaded PDF, their own draft, or IT backups.
  - rsconnect on the work laptop still needs `$env:RSCONNECT_EXE = "C:\Users\zbridger\AppData\Roaming\Python\Python314\Scripts\rsconnect.exe"` or `connect_pins_eoy/deploy.ps1` grabs a non-whitelisted exe. Probe unfixed.
  - Next Arm Farm scheduled pin run unverified: look for `[notebook] STEP 2 -- payloads` and the ABSENCE of the pyarrow ImportError.
  - Zac told the group "overwrote old versions of the app with new versions" (not what happened) and offered to "enter the items that were overwritten" (he cannot - only coordinators know what they wrote). Flagged; his call whether to follow up.
- **Read the action labels carefully:** `create` fires only when a new player ROW appears. Filling an empty box on an existing row logs as `edit`. So "created 0, edited 9" still means real new content.
- **Uncommitted work:** bsb-resources 77 paths, bsb-wt-bullpen 11 - all pre-existing untracked dirs.