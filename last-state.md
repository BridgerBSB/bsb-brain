# Last session state - 2026-08-02 15:25 (OF/IF Directional Progression - shipped + tempdb incident fixed)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` - branch `feature/astros-intangibles` (Monday wiring lives on `bsb-resources` / `feature/pd-goals`)
- **What we were doing:** Finished the OF/IF Directional Progression Report after a machine crash mid-session (all pre-crash work had survived and was pushed). Then its FIRST live run took out GCSQL02's tempdb, and most of the session was diagnosing and fixing that.
- **Shipped this session (all pushed):** `a0763d0f` refreshed sample renders - `ed85b890` sparkline draws THROUGH a no-data month (was severing at the `NaN`) - `223e16f2` colour rule documented on the page + single-month cells grey not red - `7ab3c483` dot colour **YTD -> MONTH OVER MONTH** - `88094c83` per-direction **Val + Lvl/MLB %ile** (6 cols per metric) - `869eacd3` pool memoisation - `073b715a` **the real fix**. Pre-crash: `c211537d` (8-metric p1 table + weekly OF/IF batch). Monday step is `8c37b6ea` on bsb-resources. LINEAGE.md entry written.
- **EXACT next step:** the **EOY P13 rose parity check** - the only remaining numbers-correct gate. Take one player, compare his PAA/EO rose percentile on the directional report against his **EOY P13 rose** (same engine underneath, so they must agree). The diff harness proved the rewrite did not CHANGE the numbers; it did NOT prove they were right to begin with. Do this **before** it reaches `org_pd_reports` on a Monday - that channel has an audience.
- **THEN:** `python scripts\generate_directional_progression_batch.py --family OF IF --test` (never run live). Watch runtime and confirm **ONE** `[pool] building` line per `(kind, scope)` for the whole run, not one per player - that is the memoisation working, and it is what stops a full roster re-spilling tempdb. Then swap `--test` for `--deliver`; Monday needs nothing further.
- **THE INCIDENT, worth carrying forward:** the league-wide TDM pool was `SELECT DISTINCT` over **seven** `PERCENTILE_CONT` window functions, rebuilt **once per player**. Its **first ever live run** succeeded on 8 players and in doing so **exhausted tempdb**; every run after failed err 1101. **The tell was "it worked once, then never again"** - that shape means WE consumed a shared server resource, not that the server broke. I called it server-side for three round-trips and was wrong. Zac pushed back with "it's never been an issue before" and was right.
- **The trap inside the trap:** the first fix (`869eacd3`) memoised the pools, 16 executions -> 5. It could not possibly help - the failure is **per-execution** and it died on execution #1. **Fixing frequency when the cost is per-call.**
- **The actual fix (`073b715a`):** pull raw rows (one calendar month per statement, **months 1..12 NOT the Apr-Sep `_MONTHS` list**, or March/October games silently drop) and compute percentiles in pandas. **Proven output-neutral on REAL data**, not asserted: `scripts/diff_directional_pool.py --scope afa` -> 6,832 rows both paths, identical row universe, 0 `n_plays` mismatches, **6/7 metrics exact**, `top_speed` `1.07e-14` (FP only - it is the one metric with a `CASE` cap). New path is ~4.3x slower (16.1s vs 3.7s); accepted, the old path cannot run at MLB scope at all.
- **Decisions Zac made this session:** (1) **YTD stays exactly as it is everywhere** - first-month-to-now, incl. the p1 YTD column and the fielder progression YTD Gain; only the sparkline DOT became month-over-month. (2) Bottom tables carry **both** Lvl and MLB %ile and **keep all five** columns (densest option, 24 numeric cols across). (3) Skip the shape test - I had oversold it, the rendered Val column already proves it.
- **PARKED (Zac):** *"maybe similarly built into a dashboard in the future, but for now these reports are great."*
- **Blockers / waiting on:** nothing blocking. tempdb had room again as of the diff run (the old query ran in 3.7s, impossible the day before) - unconfirmed whether IT reclaimed it or it recovered.
- **Flagged, not written:** a rule for the incident class - "a brand-new heavy query's FIRST live run can exhaust a shared server resource; the tell is worked-once-then-never-again." Offered to add to `.claude/rules/` + sync; Zac has not said go.
- **Uncommitted work:** 17 paths in intangibles, all pre-existing clutter (synced skills, `.claude/rules` copies, `output/`, `.planning/`). Nothing of this session's.

---

## ALSO OPEN - Decision Outcomes ledger + dashboard, promo-engine page 2 (`bsb-wt-modeling` / `feature/promotion-models`, from 2026-08-02 00:35, preserved)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-modeling` - branch `feature/promotion-models` (spec + mockups on `bsb-resources` / `feature/pd-goals`)
- **What we were doing:** Built the Decision Outcomes feature: every 2026 promote and release, where the released guys went, how they performed, measured against the grade the model had on them that day. Spec + mockups first, then 7 modules, then three rounds of review.
- **Shipped:** `429171ed` schema contract, `ad3db6bc` 5 modules repaired, `f72eed56` query perf, `b5488de3` org-initiated releases, `561ad09d` `diag_txn_codes.py`, `b04da28a` UNCRL, plus a LINEAGE.md entry. All pushed. Spec + both mockups on bsb-resources.
- **VERIFIED ON THE WORK LAPTOP:** 2025 boards written to `data/board_2025_{promote,release}.parquet` with NO pin touched. `get_decisions(2026)` = **61 promote / 53 release**. Dawil Almonte lands 2026-03-13 afa exactly as designed; Wes Clarke correctly excluded.
- **EXACT next step:** Fix the FOUR code-review findings that share one root cause. "He signed nowhere" and "we could not resolve this" are currently the SAME empty `next_stop_kind`, so a dropped DB connection renders as "Never resurfaced 100%" and scores CONFIRMED for every release, then an unguarded full rebuild writes it to the pin. Split those states in `decision_schema`, make the resolver REFUSE a full rebuild when its landing queries failed, and stop the page counting blank as `none`. Kills findings 1, 2, 6, 8 together. **Do this by hand, NOT a fan-out** - it touches schema + resolver + page together and two of three agent rounds produced defects from parallel agents not sharing state.
- **THEN:** the 3 wrong-row findings in the resolver, the 3 smaller ones, then `app.py` radio wiring + the 5 new modules in `promo-engine/manifest.json` **in ONE commit** or the app dies at import on Connect.
- **BACKFILL LANDMINE:** `PIN_NAME` is a hardcoded constant in BOTH scorers. `--year 2025` WITHOUT `--no-write` overwrites the LIVE 2026 board and appends 2025 grades to `promo_v3_score_history` stamped today. The board self-heals on the next daily run; the history does NOT. Always `--year YYYY --no-write --output <file>`.
- **CORRECTION that cost a round-trip:** the RELEASE grade is MULTI-LEVEL POOLED (`_pooled_no_future`, Phase 1a Jul 4 2026, blends across every gated cross-org level-row by SAMPLE SIZE). PROMOTE is current-level-only. The asymmetry is deliberate. `CUR_BUMP` was sweep-retired to 1.0 on Jul 5 2026; do not re-open.
- **The fallback trap (why `asof_roster.py` exists):** `_pooled_no_future` returns None when `cur_level` is absent, and `cur_level` comes from the CURRENT roster, which a released player is not on. CONFIRMED live: the scorer runs list Justin Trimble and Dawil Almonte under "not on the eBis roster map", ~80 per side.
- **THE PATTERN, worth carrying forward:** every bug found this session failed in the direction of making the release model look MORE accurate. Retirees scoring CONFIRMED (a retiree never resurfaces), a dropped connection scoring everyone CONFIRMED, never-resurfaced players relabelled TOO EARLY. On a page whose only job is grading our own decisions, that is the bias to keep hunting.
- **UNVERIFIED - do not claim otherwise:** only `decision_detect` has touched a DB. `asof_roster`, `decision_outcomes_resolve`, `decision_pins` and the page are static-verified only (pyflakes clean, 0 py3.11-illegal f-strings, 0 dashes, contract subset checked). Nothing has run end to end.
- **WATCH (now explained):** tempdb on GCSQL02 was full at 23:48 and this wrap noted "my query triggered it." The 2026-08-02 directional session found the fuller story - the directional pool's first live run is what filled it. Worth still checking whether the nightly Connect2 pin jobs failed quietly during the outage.
- **Process notes:** 3 quoting failures from `python -c` one-liners in PowerShell (it strips commas and single quotes) - commit a script instead. Local Python is 3.12, Connect pins 3.11, so `py_compile` passing locally proves nothing about a backslash inside an f-string expression.
- **Uncommitted:** 65 paths in bsb-wt-modeling, all pre-existing clutter, none of that session's.

---

## ALSO OPEN - Non-roster pitcher / Jona Widmann (bsb-wt-bullpen, from 2026-08-01 10:45, preserved)


- **Project / cwd:** `C:/Users/Owner/bsb-wt-bullpen` - branch `feature/bullpen-reports` (rule also on `bsb-resources` / `feature/pd-goals`)
- **What we were doing:** Zac asked why sessions tagged `INT R` show up in Arm Farm runs (they are DSL Live AB scrimmages, working as designed) and why a signed pitcher, gcid 252980, throws in our data but appears nowhere under HOU. Then ran a one-off postgame for him, which crashed.
- **The answer:** **Jona Widmann, LHP, DOB 2007-05-14, has NO eBIS record at all** - `ebis_id` AND `mlbam_id` both NULL on `Astros.Players`, so there is no key to join `MLB_eBis.PP_MASTER` on. Not a wrong-org or wrong-level filing; there is no row to evaluate. Roster surfaces INNER JOIN PP_MASTER, `Pitches_View` gates on nothing (`pitcher_id` IS `groundcontrol_id`), hence fully present in the data and invisible everywhere a human looks. 2026 sessions: 04-16 `V`, 07-25 `B`, 07-31 `int`+`R` Live AB, all `is_int_level=1`.
- **Shipped this session:** `937c32a5` reusable diagnostic `sql-queries/gcid-252980-roster-vs-pitchdata-diagnostic.sql` (set `@gcid`; Q2 tests each roster clause independently) - `f21c8a7b` fix the `'NoneType' has no attribute 'upper'` crash - `fd8f4b59` narrow that fix - `7340b555` + `b7bae15f` new rule `non-roster-player-reports.md`, synced + committed on all 4 worktree branches. All pushed, HEAD == origin everywhere.
- **The crash:** `roster.py::_get_player_direct` sets `level_code=None`, and `player.get('level_code','')` returns **None, not `''`** - a dict default fires only on a MISSING key, never on a present-but-None value. Two sites exposed: `_draw_percentile_key` `.upper()` (hit) and `_report_title` `.lower()` (latent, masked because `is_live_ab` returns early above it).
- **The narrowing, which matters:** my first fix forced `level_code='dsl'` for Live AB, but `level_code` feeds THREE renderers - title, percentile subtitle, and the pitch-log card header. That would have relabeled the card INT->DSL, asserting a level the game was not played at. Split into a separate `pool_level_code` local passed ONLY to the subtitle.
- **Parity bug found en route (real, now fixed):** `pages/2_Postgame.py` overrides `player['level_code']` with the game level, so the **app** printed "Percentiles based on 2026 INT" for Live AB games while pulling from the DSL pool (`p_pool_lc='dsl'`, `2_Postgame.py:2146`). The CLI printed DSL. App and CLI disagreed on the same game (blocking rule #11). **This is the ONLY change to any existing report's output** - Zac checked a pre-change report and confirmed it still renders fine.
- **EXACT next step:** WORK LAPTOP: `cd C:\Users\zbridger\bsb-wt-bullpen ; git pull ; cd bullpen-report ; python scripts\generate_postgame.py --date 2026-07-31 --pitcher 252980 --output reports\oneoff` then **hand-post the PDF - never pass `--deliver`**, he has no `slack_channels.csv` row. No re-pin (rendering only). Arm Farm app redeploy optional, only for the INT->DSL subtitle on Connect.
- **UNVERIFIED - do not claim otherwise:** the POST-fix CLI run has never touched a database. No DB access on the personal laptop. Zac ran the pre-fix build; the fixed one is unrun.
- **The real fix is not code:** Widmann needs an eBIS record under HOU (Josefy / eBIS side). Until then he is invisible to the daily cascade, trackers, KPI and every dropdown, and every report on him is a hand-run.
- **Flagged, not acted on:** only Arm Farm has the `_get_player_direct` fallback. Barrelsville, Intangibles and PD Goals `get_player_by_id` return `None`, so a non-roster player **silently skips** there ("not found in roster, skipping") rather than crashing - quieter and worse. Also: `postgame_report.py::generate_reports_for_date` (line 2733) is dead code (the live one is in `src/report.py`), and the bullpen worktree has no `LINEAGE.md` to record that in.
- **Skill bug worth fixing:** `document-pattern` Step 4 copies the intangibles rule to `bsb-wt-intangibles/.claude/rules`, which is OUTSIDE that git repo. Tracked path is `bsb-wt-intangibles/astros-intangibles/.claude/rules`. Both dirs exist, so it silently succeeds untracked. Corrected by hand this session, not in the skill.
- **Uncommitted work:** bullpen 14 paths, bsb-resources 85 paths - all pre-existing clutter from earlier sessions. Nothing of this session's.

---

## ALSO OPEN - Gyro SL + cutter starter screen (bsb-resources/feature/pd-goals, from 2026-07-31 16:45, preserved)


- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **What we were doing:** Built a one-off SQL screen for MLB starters who throw BOTH a gyro-shaped slider and a cutter that still carries. Zac gave the movement thresholds verbally, then added a 10+ GS starter gate, then asked what share of all 10+ GS starters that is.
- **Shipped this session:** NEW `sql-queries/gyro-sl-plus-cutter-mlb-2026.sql` - `a6f33bfc` base screen - `269f3db5` GS >= 10 gate - `79d7fc85` share-of-population result set. All pushed, HEAD == origin.
- **The spec, as implemented:** FC avg IVB >= 4.0 (min 30 thrown); SL avg |HB| <= 8.0 AND avg IVB >= -10.0 (min 30); >= 10 MLB GS. All six thresholds are `DECLARE`s at the top, so retuning is a one-line edit.
- **Three interpretation calls I made** (all stated to Zac, none corrected): (1) the HB gate is on the ABSOLUTE value so one threshold covers RHP and LHP - a signed threshold would pass every LHP sweeper; (2) SL minimum sample = 30, same as FC - Zac only ever specified 30 for the cutter, so this one is mine; (3) -10 SL IVB is a FLOOR not a ceiling (-6 passes, -14 fails), which is what makes it gyro rather than a downer.
- **Canon applied:** movement-cleaning (drop |IVB| or |HB| >= 30 glitch reads, keep NULLs); GS from the official box `mlbam.ytd_player_pitching_stats` and never pitch-derived, SUMmed across `team_id <> 0` rows so a traded pitcher's 6 + 5 starts totals 11 instead of failing twice; OAK -> ATH on display. Built off the near-twin `ff-cu-separation-26-30in-2026.sql`.
- **EXACT next step:** Zac runs the file WHOLE on the **work laptop** (`git pull` on `feature/pd-goals`; **no `GO`** between the first two statements or the share query loses the `@variables`) and pastes the two result sets back. Then: if `[matched]` is well under `[SP w/ 10+ GS]`, an mlbam_id mapping gap is eating the numerator and the % is understated - check that before quoting it. If `[% of all SP]` and `[% of FC+SL SP]` are far apart, the rarity is mostly "few starters throw a cutter at all", not the shape pair.
- **Blockers / waiting on:** Zac on standby - "waiting on standby here". Nothing to do until he runs it.
- **UNVERIFIED - do not claim otherwise:** this has never touched a database. No DB access on the personal laptop, so the SQL has not even been parsed by a server, let alone produced a number.
- **Worth asking when he's back:** what the screen is FOR (acquisition list? pitch-design comp set for one of ours? a Sam/DJ ask?) - it shapes whatever the output becomes.
- **Uncommitted work:** 85 paths, all pre-existing untracked clutter from earlier sessions (`.agents/`, `.codex/`, `awesome-claude-skills/`, `design-system/`, `gcpy/`, `pd-goals/output/`, loose `sql-queries/*.sql`). Nothing of this session's.
- **Not mine, same branch:** `b4c31051` `563366ec` `1bcbff51` (Addari pitching-box style rewrites + a revert) belong to a concurrent thread.

---

## ALSO OPEN - Onboarding report / 2026 draft class (bsb-resources/feature/pd-goals, from 2026-07-31 06:38, preserved)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **What we were doing:** Took Camden's onboarding-meeting report (merged from `origin/cq/onboarding-report`) and finished it for the 2026 draft class. Real headshots out of the recruiting deck, page 1 filled from the department Slack threads, page 2 filled from the PD Handoff deck.
- **The pivotal fact:** Zac + Sam confirmed the report is **ATHLETE-FACING**. The source material is staff notes written ABOUT the player, so this was never a transcription job. Every note is second person, and staff-evaluation language was reframed or pulled (Galloway's "concerning/disordered eating habits", Nowak's "poor understanding of body awareness", buy-in skepticism, "extreme loner", agent criticism, a body-fat position-viability judgement, third-party family medical detail).
- **Shipped:** `9f9f2add` merge - `b54f2aa3` headshots + rectangular frame (border OUTSIDE the image, per Zac) - `3492cd7d` `extract_headshots_from_deck.py` - `9cf90d3c` staff-to-box map - `f8d0a529` page 1 for 19 players, player-facing - `27ae8256` page 2 for 22 of 23 + page 1 forced to ONE page - `cd31016d` Durnin rewrite + OUTSTANDING banner - lineage entry + `parse_pd_handoff_deck.py`. All pushed.
- **Also fixed along the way:** `_wrap_note_lines` preserves pasted Slack line breaks (the shared `_wrap_lines` was reflowing every note into one run-on paragraph); page 1 shrinks type to a 7pt floor instead of spilling a lone box; `_hard_break` stops an unbroken token running off the box; long names shrink to fit.
- **Verified:** 23 reports, 0 failed, **every one exactly 2 pages**. Voice audit returns zero third-person references to the player.
- **EXACT next step:** On the **work laptop**, pull `gc_id` / bats / throws / age / school for **John Carver, Carson Estridge and Drew Wyers** from `MLB_eBis.PP_MASTER` + `Astros.Players` **by name** - do NOT wait on `build_onboarding_scaffold.py`, the two UDFAs have no `R4_Draft_Query` row so it will never build them. Type them into the TODO markers in `pd-goals/data/onboarding_notes.yaml`, re-run `scripts/extract_headshots_from_deck.py`, then `generate_onboarding_report.py --all`.
- **Blockers / waiting on:** **Sam's review is the gate** - he said "I will need to make some edits to make sure it is all kosher." Nothing reaches a player before that. Also waiting on Butler's page-1 notes (he was absent from the Slack threads) and on Wyers, who has nothing: no headshot, no page 2, no bio.
- **Open decisions for Zac/Sam:** does Galloway's brother-with-autism detail go back in? Where do Sam Niedorf's own notes belong (currently in DEFENSE with Mazzo's)? Should notes carry the staff member's name?

---

## ALSO OPEN - PD Goals cockpit (2026-07-30, DONE + PARKED)
> Same repo/branch, different thread. Its one loose end is the Connect
> **redeploy** - the live app still serves the old build, so the deleted Goal
> Compliance tab is still visible until it ships.

- **What we were doing:** Putting a bow on the PD Goals org cockpit. Zac had already set + staggered the 12h pin schedules on both Connect pin contents, which made the "Recompute current phase (live)" button redundant - so the whole **Goal Compliance view got deleted** rather than ported. Its one genuinely unique bit (the goal window) moved onto the cockpit.
- **Shipped:** `fb73f639` - deleted the `if _view == _V_COMPLIANCE:` block (292 lines) + its constant + view-radio entry + the imports/helper only it used; added **Start / End** columns immediately after Phase on the cockpit player table (guarded for old pins). `7cbdea7b` - LINEAGE entry, corrected the two live runbooks that pointed at the deleted button (`rules/pd-goals.md`, `rules/prp-correction-resend.md`), banner-stamped the Jul 8 compliance spec **PARTIALLY SUPERSEDED** (UI dead, data model still canonical). 37 tests pass, render verified. Rules synced to all 4 worktrees.
- **Status: DONE and PARKED.** Zac: *"looks great and functions great ... for now untill we have more goals to add!!!!"* Resumes only when new goals get added. Do not invent follow-up work on it.
- **EXACT next step:** Nothing on this thread. The one loose end is a **redeploy** on the work laptop:
  `cd C:\Users\zbridger\bsb-resources ; git pull ; cd pd-goals ; rsconnect deploy manifest --server https://connect2.astros.com --api-key "$env:CONNECT_API_KEY" --app-id 79f52369-8244-46da-a4d6-95df956bacad --title "PD Goals" .\manifest.json`
  (display-only change - **no re-pin**).
- **Honest caveat, do NOT claim otherwise:** the acceptance check carried through two wraps - cockpit matrix Total vs Goal Compliance Total - was **never run, and now cannot be**. I flagged before deleting that Compliance was the only cross-check surface; Zac chose to delete anyway.
- **Known, not blocking:** at ~50% a domain bar draws nearly invisible (white midpoint on a `#eef2f6` track); contrast fix offered twice, no answer. `docs/ARCHIVED_REFERENCES.md:354` still has the Connect API key in PLAINTEXT and is git-tracked.

---

## ALSO OPEN - Range & Difficulty (`bsb-wt-intangibles` / `feature/astros-intangibles`)

From the 2026-07-30 15:38 wrap. **Zac closed it out fully** - both pins live on Connect (`intangibles_range_plays_of_2026` 38,555 x 75 / `_if_2026` 55,436 x 77), Vars + 12h schedule set on `intangibles-pin-range-plays-2026` (GUID `eb324534-ebb9-409f-a027-a716f591688b`), OF and IF both fast. Kept only for its loose ends.

- **Known, not blocking:** OF 400k-row league band read still untouched (`_fetch_league_band_plays`, `_BAND_LEVEL_FILTER` hardcoded to all 7 levels - violates `scope-percentile-pools-to-run.md`); `pd.concat` FutureWarning at `fielding_range_data.py:1074` (cosmetic now, hard error on a future pandas); any pin bundle scaffolded between the parser regression and `ac171cc6` may have a broken notebook (tell: the title line sits in a code cell - `connect_pins_fielding` and `connect_pins_br` verified good).
- **If a play ever looks wrong:** `scripts/diff_range_pin.py` is the tool (`--mode batch` for the IN-list change, `--mode pin` for the parquet round-trip; exit 0 clean / 1 real differences / 3 wrong domain for that player / 4 inconclusive).

---

## ALSO OPEN - BR 1->3 canonical rollout (`bsb-resources` / `feature/pd-goals`)

Concurrent thread on the same branch. Commits `06fcfa58` `5ee45396` `aa006003` `ff3e3bf5` belong to it (BR true 1->3 on EOY P21 + Org KPI, diff harness) - do not attribute them to the cockpit or range work. Also produced `dbe05d31` `9f00b23d` `064e5be0` `b90708ad` (br-advance-3rd-out-wash rule syncs).

**Correction carried forward:** an earlier wrap listed `ac171cc6` under this thread. It is not - `ac171cc6` is the scaffold-pin-deploy notebook-parser fix from the 2026-07-30 evening range session.
