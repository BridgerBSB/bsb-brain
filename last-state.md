# Last session state - 2026-10-15 18:40 CT (BR item 6 steal matchups + BR definitions PDF for Mazzo + tracker fixes)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` - branch `feature/astros-intangibles` (+ rule copy in bsb-resources / bullpen / hitting)
- **What we were doing:** Steal matchup cards research (what each colour means on 50,321 real 2021-26 steals; 3-colour split; 3B ~1 tier too red), BR tracker fixes from Zac's questions, a coach-facing definitions PDF answering Mazzo's questionnaire, and a 1->H video list.
- **Shipped this session:** intangibles `4fe38d02d` (0 SB/CS judged by attempts, leads combine by lead count, full precision, guard test_br_zero_attempts.py), `0213dc7b4` (GRD text filter removed: probe showed 0 GRDs in 1->H chances), `5038f89aa`/`322b397aa` (one_to_home_video_list.py), `8837fd7d0`+ (docs/glossary/br-metrics-definitions.html + Desktop Baserunning-Metrics-Definitions.pdf), `f70f586ab`/`fb9ab6818` (2021-26 curves, plain labels), `080c5daed` (WAITING ON table), lineage `94c813e61`. R&D SQL sql-queries/sb-matchup-inputs-for-rnd.sql (sent to JJ). Recall checkpoint 9c4804e829bbce2b, session 347a.
- **EXACT next step:** BR item 6 + BR definitions session. Next session: Zac flagged the waiting list is a lot - split it into what Claude can take without him (audit bug fixes once approved, 3B shift if approved, back-year re-pin commands) vs Zac-only decisions; still waiting on JJ (R&D) for the 6 steal-timing answers. Start by re-sorting the WAITING ON table in `intangibles/docs/plans/2026-10-12-mazzo-of-br-wishlist.md` (item 6) into Claude-can-do vs Zac-only.
- **Blockers / waiting on:** JJ (R&D) answers. Zac: `connect_pins_br\deploy.ps1` (~2h50m) + Intangibles redeploy `295a5205-5568-4fb6-a759-26dc63bc9439`, THEN forward the definitions PDF to Mazzo; 3-colour call; 3B shift; rule-16 + 4 audit bugs; send glossary R&D questions. Cael: Stats API 1006/1040-1042 MiLB probe.
- **Uncommitted work:** intangibles clean (tracked); untracked output/ pre-existing.

---

## ALSO OPEN - 2026-10-15 17:06 CT (Baseball Command Center v2: Houston world + Cael's shared copy)
- **Project / cwd:** `C:/Users/Owner/bsb-brain` - branch `master` (+ new repo `C:/Users/Owner/pd-command-center` main)
- **What we were doing:** Recovered last night's Twitter research (all 15 links already filed, `07df173`), then built the one-stop Baseball Command Center Zac asked for: projects with progress bars, jobs, idea bank, library, as a Houston / Daikin Park isometric world, plus a shared copy for Cael.
- **Shipped this session:** vault `5b050d0`..`53f06df` (generator v2, `bank/projects` 18 cards, `bank/processes` 7 jobs, design doc, LINEAGE). Repo `zbridger_astros/pd-command-center` (Cael = cmagill_astros added). Scheduled task = pyw v2 `--open-once-daily --publish` every 15 min. `~/.claude/commands/wrap.md` step 6 -> v2. Recall checkpoints 54e9b32b6fd769e2 + 3606d906ededaf7a, session 947c.
- **EXACT next step:** Nothing active ("the dash is at a solid point"). When Zac reports progress (Cael, Mazzo details, Monday/daily cascade ran), edit the matching `bsb-brain/bank/projects/*.md` / `bank/processes/*.md` note; the 15-min run republishes both copies.
- **Blockers / waiting on:** Optional repo transfer to Baseball-Operations for a click-to-open link (Zac's command). Mazzo details on the Outfield Daily Review Dash; whether "Accuracy or Useless React" = Mazzo #3.
- **Uncommitted work:** vault: pre-existing inbox/digest files only; pd-command-center clean.

---

## ALSO OPEN - 2026-10-15 16:50 CT (Manager Game Card guide for MT; winter catching probe)
- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **What we were doing:** Found Camden's Manager Game Card docs (cq/* branches only), re-verified the guide against live code and shipped a corrected PDF that Zac sent to MT. Then MT asked about winter catcher postgames: probed winter catching data coverage.
- **Shipped this session:** `09c861ff8` corrected guide (`pd-goals/docs/mgr-card-guide/` + `C:/Users/zbrid/OneDrive/Desktop/Manager_Game_Card_Guide.pdf`). `790ec57a4` `sql-queries/winter-catching-coverage-probe.sql`, run by Zac (cwin1-7.csv in Downloads). Recall checkpoint session 0e40.
- **EXACT next step:** Nothing active. Winter catching parked by Zac ("no catching reports for winter ball is chill"). Findings: only HOU catcher this winter = Cesar Salazar (1 LMP game); AFL full tracking, LIDOM 79% framing-only, LMP/LVBP/ABL/CS 0% tracked, PWL no pitch rows; "Unknowns" = NULL pitch types in untracked games. If MT wants card fixes in the offseason, start with the 3 code issues in LINEAGE 2026-10-15.
- **Blockers / waiting on:** MT offseason refinement asks.
- **Uncommitted work:** bsb-resources 9 pre-existing untracked items only.

---

## ALSO OPEN - 2026-10-15 10:31 CT (Command CV: season run recovered after a reboot; failure diagnosis handed to the CV session)
- **Project / cwd:** `C:/Users/Owner/bsb-resources/command-cv` - now its OWN repo BridgerBSB/command-cv (moved 10-14, history kept; bsb-resources ignores `command-cv/`). The CV thread is OWNED by session `bsb-resources-21` (laptop workers + Hostinger GPU server).
- **What we were doing:** Windows Update force-restarted the laptop 10-14 04:29 CT and killed the 3 season workers. Relaunched them, eye-checked 7 waiting parks, then dug into why so many games fail.
- **Shipped this session:** `e6708ede7` (bsb-resources, carried into the new repo as `0e318ab`): Momentum Bank, Isotopes, Arvest, L.P. Frans, Pelicans, Las Vegas, Nymeo ready (35 parks). Run at 10:00: 260 graded (171 PASS / 89 FAIL), 192 left, 69/95 pitchers carded, 24% of pitches. Findings sent to `bsb-resources-21` (SendMessage 66f28ba9): (1) the 0.47 in gate is a coin flip near the line - near-miss FAILs pass on 13-49% of bootstrap resamples; propose ~0.75 in (broken cameras start 1.13); (2) Asheville HomeTrust window opens ~20 frames late (ball f177-186 vs lo 203) and the ladder moved it LATER to 323-390, where all 7 games failed 59-2,284 in; propose ~175-260. Recall checkpoint 318615999f2bd1f9, session 0e82.
- **EXACT next step:** Nothing here. In `bsb-resources-21`: Zac decides `GATE_BOK_IN` (`command-cv/scripts/miss_season.py:79`, 0.47 -> ~0.75) and Asheville's window (`docs/miss_park_registry.csv` venue 2807 -> lo 175 / hi 260, and check the window ladder's shift direction), then `python scripts/miss_season.py --retry-failed`.
- **Blockers / waiting on:** Zac's gate + Asheville calls. Laptop battery fell to 16% while plugged in (charging at 10:00). Windows Update can reboot again (pausing offered, not done). 5 finished `cv-detached-*` tasks in Task Scheduler (harmless; delete offered).
- **Uncommitted work:** command-cv 3 files (ledger/landmarks, written by the running workers); bsb-resources pre-existing only.

---

## ALSO OPEN - 2026-10-13 21:40 CT (Astro World: drill deck as one document card; prod disk full)
- **Project / cwd:** `C:/Users/Owner/astroworld` - branch `main` (feature branches merged) (+ `bsb-wt-hitting` feature/barrelsville, `bsb-resources` feature/pd-goals)
- **What we were doing:** Putting the Catcher Plyo Exercises drill deck (6 slides + 4 videos) on Astro World as ONE square on the Practice Design grid that opens as a scrolling, PDF-like document with the videos playing inline. Built and merged it; 9 of 10 files uploaded, then every upload started failing "The server has run out of disk space".
- **Shipped this session:** astroworld-dev PRs #91 (SectionLayout table, batch filename order + "Put every file under"), #92 (section on catching/drills), #93 (8 in-app-deleted pages -> RETIRED_SLUGS so Load structure stops recreating them), #94 `6b8f041` (document card: "Show as one card"). Barrelsville `59110dd07` (AFL column reorder for Kyle) + `ecfd9e960` (AFL lookup of any MiLB/MLB pitcher under a picked club). bsb-resources `0b02c6198` (Staff ID "Building a Player Plan" slide). gh CLI signed in on the ASUS. Recall checkpoints e50df0377079651f / 335949153a86e551 / 3b14fc2fb9d01f42, session aa2f.
- **EXACT next step:** Field assessment is ON MAIN (Zac pushed 21f36cf..11c6a6a). Zac is testing it live: hard-refresh the dashboard -> "Manager / Dev Coach Assessment" tile -> Sandbox (3 prompts) -> drag pieces -> Submissions view + PDF. Fix whatever he reports; Sam edits brief wording in `cage-sandbox/constraints/field-*.json`.
- **Blockers / waiting on:** Zac's live test results. Sam feedback on the Pitch Design deck (drop blurry Wells Capture (8)? order? add to app stage_docs?). Deck generator content/pitching.json is behind the app's dop-case-assessment.pptx (slides 5, 14).
- **Uncommitted work:** astroworld 1 pre-existing untracked export (LINEAGE.md is gitignored, entry written); bsb-wt-hitting/bsb-resources pre-existing only.

---

## ALSO OPEN - 2026-10-13 20:20 CT (hiring: Manager/Dev Coach FIELD assessment on main, Zac testing; itineraries; DoP Pitch Design deck)
- **Project / cwd:** `C:/Users/Owner/hiring-wt-field` - branch `feature/field-assessment` (+ `C:/Users/Owner/hiring` main, `C:/Users/Owner/hiring-wt-deck` director-deck-philosophy)
- **What we were doing:** Built the Manager / Dev Coach Assessment as a third hiring-app track on a full baseball field (Sam's equipment, OF 45 min / 13, IF 45 min / 12, Open Practice 90 min / 18, 4 coaches + 1 S&C). Earlier: candidate itineraries (Gargas, Clayton Thompson, Spencer Medick), the DoP Pitch Design deck, DoP case deck Scaling slide.
- **Shipped this session:** hiring `11c6a6a` on feature/field-assessment (app/tracks.py one track table; app/field_surface.py field shapes drawn by page, evaluator and PDF; readable 20 ft symbols; /admin/field/*; 14 palette items; suite 1221 pass / 7 skip; renders cage-sandbox/docs/renders/field-assessment/). hiring main `21f36cf` (DoP case deck slide 5 four topic boxes, LIVE). hiring-wt-deck `e87941e` (Pitching_Pitch_Design.pptx, 5 slides, name-covered edgers, Wells replaces Oakes). Itinerary PDFs in C:/Users/zbrid/Downloads (== C:/Users/Owner/Downloads), scripts on C:/Users/zbrid/OneDrive/Desktop/*_itinerary.py. Recall checkpoint ca1c4398a2a40b28, session e514.
- **EXACT next step:** DEPLOY the field assessment (my push to main was blocked by the auto-mode classifier as a production deploy). Zac runs: `! cd /c/Users/Owner/hiring && git merge --ff-only feature/field-assessment && git push origin main` (Railway redeploys), then opens the new tile, runs its Sandbox, and Sam edits brief wording in `cage-sandbox/constraints/field-*.json`. Zac: "we will reconvene on such and attack this".
- **Blockers / waiting on:** Zac's deploy push; Medick's assessment Wed 10-14 3:45-5:45 PM (do not deploy mid-assessment). Sam feedback: Pitch Design deck (drop blurry Wells Capture (8)? order? add to app stage_docs?). Deck generator content/pitching.json is behind the app's dop-case-assessment.pptx (slides 5, 14).
- **Uncommitted work:** hiring 3 pre-existing untracked renders; hiring-wt-field clean; bsb-resources pre-existing only.

---

## ALSO OPEN - 2026-10-13 13:01 CT (GC2 Asset Value: SP probability found, exact owner-deck ranks)
- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **What we were doing:** Hunted down how GC2 computes Asset Value for young pitchers. Zac pulled GC2's page SQL: the blend weight is `Player_Val.SP_Prob` (our login could not see it; SELECT granted 10-13). Documented GC2's full formula and got exact class ranks for the owner deck.
- **Shipped this session:** rule `asset-value-canonical.md` (final e10c95f65, synced to 4 worktrees); `sql-queries/gc2-asset-value-reference.sql` (GC2 verbatim) + `owner-deck-av-gc2-exact.sql` (replica + ranks) 4a3fd856a; discovery/check queries 456e647d6 eaac98ffc 42097ff7f 137711afe 83ae2e00c; lineage 84b023ffe. Exact ranks: Spence #3 of 54 hitters / #5 of 131; Ullola #12 of 849 / #6 of 459 P, $16.72M (sp_prob 0.155120). Recall checkpoint ec285a1c2fd40047, session 69aa.
- **EXACT next step:** Topic closed by Zac. If reopened: (1) ask Zac whether the deck + one-pager should swap "Top 15 of 849" -> "#12 of 849" and $16.5M -> ~$16.7M (deck already delivered, his call); (2) promotion-velocity BUG 1: replace the `per_season` `MAX(mkt_sv)` CTE at `pd-goals/src/promotion_velocity_data.py:190` with GC2's formula from `sql-queries/owner-deck-av-gc2-exact.sql`.
- **Blockers / waiting on:** Zac's deck decision only.
- **Uncommitted work:** bsb-resources 83 pre-existing (none of this session's).

---

## ALSO OPEN - 2026-10-08 09:50 CT (fielding pin rebuild: Stage 1 done, Stage 2 spec'd)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` - branch `feature/astros-intangibles` (+ bsb-resources `feature/pd-goals` pin map doc)
- **What we were doing:** Replacing the 41h fielding pin job (336 heavy SQL queries) with one raw pull + Python. All 8 slices now match the old SQL same-day, 6/6 each; Stage 2 (shadow job writing a test pin) is specced, not built.
- **Shipped this session:** intangibles 152d7f6f..67b79e41 (8 builders, A/B harness modes, 49-check DB-free test, raw queries + game_month/fielding_team_id, Stage 2 spec), lineage entry. bsb-resources a26d5e74 / 676d16cb (pin map: Barrelsville 12h24m, catcher 19h53m). Recall checkpoint 4270fa59203bef3b, session 3292.
- **EXACT next step:** Fielding pin rebuild: Stage 1 complete (all 8 slices pass same-day A/B vs old SQL, 49 DB-free checks). Stage 2 shadow spec at bsb-wt-intangibles/astros-intangibles/intangibles/docs/plans/2026-10-08-fielding-rebuild-stage2-shadow-spec.md (67b79e41). Open decision for Zac: morning-check option A/B/C. Then build `scripts/pin_fielding_rebuild.py` (--dry-run first) per the spec.
- **Blockers / waiting on:** Zac's A/B/C choice; whether the hung `-fielding` job was cancelled / its schedule turned off. Catcher fix (org work 3x) not started. Other session owns pitching pins.
- **Uncommitted work:** none from this session (intangibles 28 synced-rule files + bsb-resources 81 pre-existing, not mine)

## ALSO OPEN - 2026-10-07 19:43 (tracker vs Profiler metric parity: IBB double-count fixed; Barrel% probe next)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-bullpen` - branch `feature/bullpen-reports` (+ bsb-resources `feature/pd-goals`)
- **What we were doing:** Making every pitcher metric on both the Affiliate Tracker and the Profiler give the same number, with GC2 as referee. Found + fixed intentional walks counted twice in batters faced (K%/BB% low); gcERA kept identical. Started on postgame visual speed.
- **Shipped this session:** bullpen 0cdce61aa (parity check CLOSE/diff), 06de8b86a (diag_kpct), 28dd6d76b (BF fix, 5 files + test_bf_ibb_once), 875fc64f2 (lineage); pd-goals 9972a9752 (EOY port), 93a78e200 (barrel probe); db-columns.md all 4 worktrees. Zac re-pinned + deployed: K%/BB%/K-BB% IDENTICAL MLB-FCL, gcERA unchanged. Recall checkpoint 154b08ca05a3bd53, session 2175.
- **EXACT next step:** "and then we will contjnue on what we were all woring on" - Zac runs `C:\Users\zbridger\bsb-resources\sql-queries\barrel-definition-probe-2026.sql` in SSMS (git pull first, <1 min), pastes the 3 grids (cast round vs truncate, column types, MLB barrels tracker/V2/GC2). Fix whichever side does not match GC2. Then: Profiler card with `?diag=1` -> paste timing table -> decide postgame season-frame pin.
- **Blockers / waiting on:** Zac's probe output + diag table. Open: R2K% grain, gcERA tracker vs V2 (0.08), small gaps, DSL +2, hitting-side IBB double-count (own step), pitcher_kpi_snapshot gcERA.
- **Uncommitted work:** none from this session (pre-existing untracked files untouched)
