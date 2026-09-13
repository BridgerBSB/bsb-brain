# Last session state - 2026-09-13 16:10 (Command CV: the zone graphic IS in our clips, at all five parks)

- **Project / cwd:** `C:/Users/Owner/bsb-resources/command-cv` - branch `feature/pd-goals`
- **Recall checkpoint (SOURCE OF TRUTH):** session `8d5d` - domain `bsb-resources/feature/pd-goals` - id `19ca4520af299bfd`
- **What we were doing:** Zac asked to SEE the strike-zone box. That question overturned a written
  finding, and the session became: prove the graphic is really there, prove our camera can draw the
  zone blind, then try to replace OpenCommand's ball detections with our own.
- **Shipped:** 15 commits `1929e62e`..`1a887b48`, every one SHA-verified local==remote.
  - **THE CORRECTION (supersedes the block this replaced).** `docs/2026-09-11-step2-pinhole-parity.md`
    said "our copy of the video does not have it" and "no angle MLB serves us carries the graphic",
    citing frames 0-240 of play `c4958213`. **Wrong on its own test case** - `c4958213` frame 0
    scores 15.1 with the box plainly visible. A per-frame sweep now covers **five parks**: BAL 37-51,
    DET 47-66, COL 51-55, MIA 59-63, LAA 52-60. Every clip carries it; the four new parks score equal
    to or higher than Camden. hi% varies but tracks INVERSELY with clip length (1602/1678-frame clips
    ~21%, 396-456-frame clips 100%) = replay footage, self-consistent. **Verified by eye** at a Coors
    day game and a loanDepot night game (`output/zone_zoom_COL.png`, `zone_zoom_MIA.png`).
  - **The blind camera holds.** `ablate_no_box.fit_joint`, 59 clips, 297 params, **ball pixels only,
    no box in the fit**: camera `Cx -13.697 Cz 33.138` vs box-assisted `-14.040/32.552` (off
    0.34/0.59 ft, reproducing Sep 11 exactly), drawn zone reproduced to **0.84 in median**. It came
    back WORSE than the box-assisted render (0.5-6.5 px vs 0.1-0.3) - that is the evidence it is real.
  - **Detector:** dataset `yolo_ball5` verified two ways (800-sample contrast +21.7 at the label vs
    +2.0 at a deliberately-offset control; 6x zoom on 12 crops). Gate at epoch 13: top-1 **167 px ->
    44 px**, tile found% **29% -> 61.9%**, med rank 1.0. Epochs worked - but `mAP50` sat flat
    0.08-0.12 the whole time, because mAP at fixed IoU is a poor proxy for pixel distance to a ~16 px
    ball. 44 px is ~13 in vs OpenCommand's 0.4 in, so the real gate stays UNRUNNABLE.
  - **Two aggregates misled us in one day** (top-1 hid a ranking problem; mAP hid pixel progress) ->
    `.claude/rules/metric-must-separate-failure-modes.md`, byte-identical in all 4 worktrees.
- **EXACT next step:** training is stopped ON PURPOSE - do NOT fire another cycle on this box. Either
  free real RAM (10 claude processes ~2.8 GB is the cheapest win) then
  `cd C:\Users\Owner\bsb-resources\command-cv ; python scripts/train_ball_detector.py --data data/yolo_ball5/data.yaml --epochs 30 --batch 8 --device 0 --name ball_3park_b8 --resume`
  (picks up at epoch 17; resume is verified working, boundaries at 5 and 9), or move training to a
  machine that can hold a 335 s epoch, or park the detector.
- **Blockers / waiting on:** **the paced resume cycle was SPINNING** - cycles 5/6/7 each ran 23-84 s,
  died, and added ZERO epochs against a ~335 s epoch; `results.csv` sat at 16 for 2+ hours while the
  loop looked healthy from outside. 16 GB with ~13 GB held by Chrome/VS Code/Slack/claude cannot hold
  an epoch. Arithmetic, not tuning. Weights safe at epoch 16 in `data/yolo_ball_runs/ball_3park_b8/weights`.
- **Uncommitted work:** 78 paths in bsb-resources, ALL pre-existing untracked from before this session.
- **Still open, NOT refuted:** only BROADCAST clips are on disk, so the Sep 11 claim about CENTERFIELD
  / HIGH_HOME / PITCHCAST is untested. The detector blocks **A+ only** - MLB never needed it, because
  `ball_clock_align.py` finds the ball with no detector at 17x over baseline.

---

## ALSO OPEN - earlier wraps (preserved)

# Last session state - 2026-09-12 08:40 (Internal Board drag + per-board people + MAGNET chip; rubric revamp next)

- **Project / cwd:** `C:/Users/Owner/hiring` - branch `main` @ `72b692d`
- **Recall checkpoint (SOURCE OF TRUTH):** session `30b3` - domain `hiring/main` - id `ab0e73186781d355`
- **What we were doing:** the multipurpose hiring app. Started with the Internal Staff Board's dragging and scrolling, ended up rebuilding what a board OWNS (people as well as boxes), turned a person into a name card, merged a resume fix, added the MAGNET chip that sends a hire from the hiring board to the Internal Board, and closed by designing the Candidate Rubric revamp.
- **Shipped this session:** 6 commits pushed to `hiring/main`, Railway auto-deploys, NO migrations.
  - `82a2a5b` - a drop KEEPS the scroll (both boards rebuild their scroller, and a new one starts at 0, so every drop past the first screen snapped back: tree 579 -> 0, grid 144 -> 0), edge drag-scroll gained a SIDEWAYS half on the internal tree and the player magnet grid, section reads **Coordinator**, and the late-save reply is MERGED (`mergeKeyed`, a port of `magnet_merge._merge_key`) - a person deleted while their add was still saving used to come back.
  - `96c2474` - Headcount on the bar, and a box created on Current now reaches every saved project, EMPTY and under the SAME BOSS, tracked by `current_seen`.
  - `ba41f1d` - **PEOPLE ARE PER BOARD.** A project carries its own `staff` + `staff_seen`; planned hires never reach Current, and a delete on one board never crosses. Bar became **Headcount + Positions** (distinct role names, level ignored - Zac's call).
  - `787ee94` (merge of `ceb02b9`) - a resume on **+ Candidate** now gets the same Candidate Detected review a profile upload gets, and career history reads BLOCK layouts (Company - League / Title / April 2024 - Present / bullets). Real PDF: 10 jobs.
  - `ef92e74` - **a person is a NAME CARD.** No Position or Where on the card, the Add staff form, the magnet, or a pasted line. The box holds role, level and bosses.
  - `72b692d` - **MAGNET chip** on a Hired card, owners only, writes `/api/staff/roster` (name-deduped, unplaced) and marks the candidate with `internalStaffId`. `/auth/whoami` now returns `role`, because `is_admin` is true for an owner AND an admin.
  - Guards: `drive_internal.py` 89/89, new `drive_magnet_chip.py` 13/13, new `drive_magnet_scroll.py` 10/10, `test_whoami_role.py` 3/3, full suite **797 pass / 7 skip**. Every new check was proven RED against the pre-change file first.
- **EXACT next step:** step 1 of Zac's three, in his words - *"we design and format what this will look like on the microsoft form front and back end so i can assign camden this task"*. Write the Microsoft Form spec for the Candidate Rubric: one page per criterion (title carries the weight, anchors 0-4 in the description), the QUOTE box required ABOVE the score, prefilled candidate + search + set from a link our app generates, grader from their org sign-in. Then the CSV column contract we import by hand: `submitted_at, grader_email, candidate, search, instance, set_id, <criterion>_quote, <criterion>_score, overall_notes`, keyed so a re-import double-counts nobody. THEN step 2 (Rubrics tabs + kanban) and step 3 (the owner-facing screens).
- **Blockers / waiting on:** the rubric QUESTIONS are TBD until Zac talks to Sam - the criteria and weights are a data file (`cage-sandbox/data/rubric_criteria.json`), so nothing blocks the layout. Zac's unanswered question from earlier: keep the MAGNET chip on hover, or always show the full label and let the MLB/REF badges be covered. He is checking the chip and the resume review on the live site.
- **Uncommitted work:** `hiring` 7 paths, all re-rendered PNGs from earlier drivers, no code. `bsb-resources` 78 pre-existing untracked paths, untouched by this session (its `72f22ba3` command-cv commit belongs to another thread).
- **Rubric, as it stands TODAY (so the revamp does not re-learn it):** the instrument is DATA (`director-written-2026`, `scale_max` 4, weights forced to sum to 100, 0-4 anchors). The app computes the weighted score, rounds ONCE at two decimals with the band read off the DISPLAYED value, applies hard floors that force do-not-advance, and REFUSES a score with no quote. `/admin/rubrics` (fill) is owner+admin+coordinator; `/admin/rubrics/results` is owner+admin and invisible to a coordinator. **Zac's change: Candidate Rubrics becomes OWNERS-ONLY**, since all other use happens outside the app. New shape: MULTIPLE graders per candidate, and a candidate can interview for MULTIPLE positions and instances, so a row is per candidate x position/search x instance x grader.
- **Measured facts worth keeping:** a magnet card in a column is **146px** wide, so a labelled chip at `right:21px` sits exactly on the MLB badge (chip 1382-1435, badge 1382-1406), and `padding-right` on `.mag-ind` does nothing because badges are left-aligned. The hiring page is **CRLF** while the internal board page is **LF**. Printing a badge glyph (U+2197) crashes this cp1252 console. A Playwright wait on `boardKind` returns BEFORE the board loads, so two checks read Current's boxes and passed on nothing - wait on the `#hint` text instead.

---

## ALSO OPEN - Last session state - 2026-09-10 10:40 (IF positioning + direction %ages one-pager)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **Recall checkpoint (SOURCE OF TRUTH):** session `7643` - domain `bsb-resources/feature/pd-goals` - id `92d9bd20c9b73559`
- **What we were doing:** a one-page MLB visual, 2023-2026, showing where each infield position stands on average and what share of the balls it fields come to its left vs its right. Then writing the process down so the next positioning question does not re-learn it.
- **Shipped this session:** 10 commits `ea9814b6`..`69231c71`, all pushed. **Pushing to `feature/pd-goals` WORKS** - protection bypasses with a warning; the memory saying it needed a PR was wrong and is corrected.
  - `pd-goals/scripts/generate_if_positioning_onepager.py` - the deliverable. Zac's title: **"Avg MLB Positioning + Direction %ages"**. Defaults: LA < 10, `first_defender_id`, `DCBP.out_prob > 0`, fielder started within 2.5 deg of his position's average angle, all base-out states, gap measured from the league-average X.
  - `.claude/rules/tracking-position-exploration.md` - NEW, byte-identical in all 4 worktrees (`7c3a064d` / `00115544` / `d8dce576` / `fd58f34d`), CLAUDE.md pointer added.
  - `sql-queries/if-positioning-spray-probe-mlb.sql` (the calibration probe) + `if-positioning-vs-spray-player.sql` (Blocks 0+A good, **Block C superseded and banner-stamped**). LINEAGE entry `69231c71`.
  - **THE FINDING:** `shift_type_id` is unusable - **77% of 2026 MLB balls in play carry "Not Quite Ted Williams Shift", which is illegal post-ban**, and `count_as_shift = 0` still contains Infield Up / Corners Up / No Doubles / DP Depth. Alignment comes off the tracking coordinates instead.
  - **Coordinates settled:** feet, origin home plate, +x toward 1B/RF, +y toward CF. Confirmed twice for free - each position's average standing angle matches the average angle of the balls it fields within a degree, and 1B sits 118 ft bases-empty vs **93.6 ft on DP depth**, which is him holding a bag 90 ft away.
  - **2026 bases-empty averages:** 1B +63.5/+90.7 (111 ft, +35.0 deg) - 2B +31.4/+143.9 (147 ft, +12.3) - 3B -61.2/+99.4 (117 ft, -31.6) - SS -29.7/+144.2 (147 ft, -11.6). Coverage 99.7% of MLB BIP with all four infielders.
  - **First real run** (LA<10, before the out_prob + 2.5 deg gates): 1B 29/71, 2B 44/56, 3B 73/27, SS 61/39 left/right. All four lean toward the MIDDLE of the diamond; the corners lean hardest because the foul line pins them.
  - **Four things I got wrong, each caught by Zac:** a +/-20 deg reach wedge extrapolated from ONE player (moved 1B from 41/59 to 24/76 across plausible widths); a bases-empty filter throwing away 44% of BIP; the X drawn at the league average while the gap was measured per-play (two reference points, and per-play ABSORBS the shading being studied); and a trajectory+distance ball filter instead of launch angle. All four are in the rule.
  - Plus one SQL defect worth remembering: a repeated named parameter inside a GROUP BY expression. SQLAlchemy expands each `:b3` into its own `?`, so the SELECT and GROUP BY copies became different expressions and SQL Server blamed an innocent column (`e9956859`).
- **EXACT next step:** run it with the current defaults - `cd C:/Users/zbridger/bsb-resources ; git pull ; python pd-goals/scripts/generate_if_positioning_onepager.py` (backslashes on the real command line). **Read the gate table first** (`all / no outprob / off spot / kept / kept%`). Zac's only real run predates the out_prob and 2.5 deg gates, so their cost is unmeasured - if the start gate eats most of the sample, revisit the tolerance before anyone reads the percentages.
- **Blockers / waiting on:** nothing blocking. One thing to carry with the artifact: this measures a position's **workload**, not the raw spray - a fielder who ranges better to one side reaches more balls on that side. Zac has the forwardable wording for Sam. Also note the start gate is ANGULAR, so it does not catch infield-in (that changes depth, not bearing); `--base-state in` isolates it.
- **Uncommitted work:** 78 paths in bsb-resources, all pre-existing untracked from before this session. Nothing from this session is uncommitted.

---

## ALSO OPEN - Last session state - 2026-09-09 19:45 (Powell winter-ball case + /player-comparison skill)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **Recall checkpoint (SOURCE OF TRUTH):** session `9658` - domain `bsb-resources/feature/pd-goals` - id `6adaf540aafdb60a`
- **What we were doing:** building the case for Caden Powell (283965) as a winter-ball outfield add against four comps, then turning the process into a reusable skill.
- **Shipped this session:** 9 commits `b93aaa5e`..`5e6ec583`, all pushed.
  - **THE DISCOVERY (Zac caught it):** the league-wide percentile pools are ALREADY PINNED for 2026 - `barrelsville_tracker_2026` `batters_all_all` (12h), `intangibles_of/if/br_tracker_2026` (6h), all 30 orgs, permissive gate. I had started a league-wide SQL scan. **`barrelsville/scripts/pin_tracker_seasons.py`'s docstring still says "2026 runs live (never pinned)" and is STALE** - that caused the wrong turn.
  - `pd-goals/scripts/winterball_comp_pools.py` - reads the 4 pins, per-domain CSVs with `*_pctile`. Golden gates (50 PA / 10 comp plays / 30 on-base); percentile = `bisect_left/len` within own level.
  - `pd-goals/scripts/build_winterball_onepager.py` - landscape PNG. `Desktop/powell_winterball.png`, mock at `pd-goals/docs/plans/mocks/winterball/`.
  - `sql-queries/powell-winterball-comp-5players-2026.sql` - pool half SUPERSEDED by the pin reader; STILL-WIRED for the position matrix + SB/CS.
  - `.claude/skills/player-comparison/SKILL.md` = **`/player-comparison`**, 10 sections written from 5 real failures this session.
  - **READ:** Powell 94th pctile bat speed / 93rd Hard% / 89th Avg EV at A+, but 13th Ctct%. Defense HURTS the case - PAA/EO 28th (rate), OAA 2nd (cumulative, inflated by his 97th-pctile opportunity count); Diaz is the better OF. Season SB: Gourson 37, Powell 30, Youngblood 29, Diaz 19. Gourson + Ortega are INFIELDERS.
- **EXACT next step:** GREEN-test section 1 of the skill - it shipped WITHOUT a test and is the only untested part. Give a fresh agent a vague comp-set ask and verify it STOPS and asks the 3 blocking questions (decision+audience, comp-set role, position needed) instead of diving into SQL.
- **Blockers / waiting on:** Zac's call on three - (1) propagate the skill to the 3 sibling worktrees? `sync-rules.sh` copies `rules/` + `scripts/` only, NOT `skills/`; (2) blank percentile shading below the 10-play pool gate (Ortega is shaded off 1 competitive play); (3) multi-level pooled fielding via the pin's `indiv_pooled_2026_<levels>_all` combos. BR pin never ran - `--domains br` if sprint-speed percentiles are wanted.
- **Uncommitted work:** 78 paths in bsb-resources, all pre-existing untracked from before this session. Nothing from this session is uncommitted.

---

## ALSO OPEN - Last session state - 2026-09-09 04:05 (MiLB salary: what we paid released in-season signings)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **Recall checkpoint (SOURCE OF TRUTH):** session `6ef0` - domain `bsb-resources/feature/pd-goals` - id `bf679082e9b70af6`
- **What we were doing:** Sam asked how much money we spent on minor leaguers signed after Mar 28 whom we have since released. Nothing in `.claude/rules/` covered MiLB pay at all, so this was a discovery run into the eBIS contract tables, then the answer, then the rule so it never has to be rediscovered.
- **Shipped this session:** 4 commits `65d13471` / `2f41068a` / `d63e50e9` / `a313be8b`, all pushed, 0 unpushed.
  - **THE ANSWER: ~$186,954** salary, **10 released players**, 619 service days, **zero signing bonuses**. Artifact for Sam (private): https://claude.ai/code/artifact/bfb33faf-edbb-40b1-aac0-523c8b40c19b
  - Finding: the cost is veteran AAA depth, not churn volume. Thaiss / Yajure / D.Johnson = **$102,720, 55% of the spend on 18% of the days**; the other 7 cost $84,234 over 510 days.
  - `.claude/rules/milb-salary-and-contracts.md` - NEW. Where MiLB pay lives (`MN_CONTRACT` / `MN_ADDENDUM_C` / `MN_ADDENDUM_CSAL`, clocks `PP_MNSERVICE` / `Rosters_Daily`), and that `Astros.Contract_Data` is the MAJOR league surface and the wrong place to look.
  - `sql-queries/milb-salary-discovery.sql` (the 6-grid probe) + `milb-released-in-season-signings-2026.sql` (pool + release shape) + `...-2026-ANSWER.sql` (reproduces the figure, unit test appended).
  - **`MONTHLYSALARY` holds a WEEKLY rate.** Confirmed against full-season single-level players: A+ weekly = $27,537/yr vs CBA min ~$27,300 (within 1%); monthly = $6,332, impossible. Zac independently confirmed ~$20k for a non-40-man AAA guy - same order as weekly, 4x off monthly.
  - **Two bugs caught before they shipped.** (1) $20,098 double count - Daniel Johnson signed twice, `PP_MNSERVICE` is per PLAYER while CSAL is per CONTRACT, so one 18-day stint billed against both; naive sum was $207,053 and the tell was on screen (59 contracts vs 58 players). (2) `Rosters_Daily.parent_team_name` holds the ORG CODE, not a club name, so `LIKE '%Astro%'` matched nothing and the LEFT JOIN returned NULL dates that read as missing data rather than a broken filter.
  - Also: `feature/pd-goals` is **push-protected** (needs a PR), and `fix/eoy-sc-card-height` - a topic branch that had absorbed 21 unrelated commits - is now merged into it, both remote branches identical.
- **EXACT next step:** nothing to build. Zac: *"he might ask us some shit in the morning, so be ready for it. We don't need to make any plans or guesstimation."* If Sam follows up, every likely question is a rerun of `sql-queries/milb-released-in-season-signings-2026-ANSWER.sql`: who cost most (Thaiss $46,800 / 39 d) - is that everyone (10 of 58, other 48 still here) - guys signed BEFORE Mar 28 (one filter change) - same for 2025 (swap the year).
- **Blockers / waiting on:** nothing blocking. One loose end that is finance's, not ours: a single payroll record for a full-season A+ player moves the weekly rate from inferred to confirmed permanently (~$27,000 = weekly, ~$4,700 = monthly). Zac said he can fact-check with other employees. Also `CONTRACTSTATUS_LK` codes are undecoded - 9 of the 11 released contracts read `TM`, do not read that as "terminated" without a lookup.
- **Uncommitted work:** 78 paths in bsb-resources, nearly all pre-existing untracked from before this session (`.agents/`, `design-system/`, `gcpy/`, assorted `sql-queries/`, `pd-goals/output/`). Nothing from this session is uncommitted.

---

## ALSO OPEN - Last session state - 2026-09-08 15:54 (Sam's stolen-base components study)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` - branch `feature/astros-intangibles`
- **Recall checkpoint (SOURCE OF TRUTH):** session `b8e8` - domain `bsb-wt-intangibles/feature/astros-intangibles` - id `177c7c79883232c2`
- **What we were doing:** answering Sam (assistant GM) on the stolen base -- how tightly sprint speed tracks value on the bases, what the pieces of a steal are, and whether success rises with lead length off 1B and 2B. MLB 2023-2026, outcome ORP BR. Built the extract, the puller, the findings and two decks of athlete-facing visuals.
- **Shipped this session:** 12 commits `c98fcbb4`..`059f2488` on `feature/astros-intangibles`, all pushed, LINEAGE entry `059f2488`.
  - `sql-queries/sb-components-mlb-2023-2026.sql` - 6 result sets, cheap-first, every one bounded to MLB + season.
  - `sql-queries/gc2-baserunning-page-reference.sql` - GC2's own Baserunning page SQL verbatim, gates decoded.
  - `intangibles/scripts/pull_sb_components.py` - one command, no SSMS. `--only` / `--force` / `--adopt` / `--summary`.
  - `intangibles/scripts/generate_sb_components.py` - 2 PDFs + 11 PNGs.
  - `intangibles/scripts/check_sql_structure.py` - CTE-chain guard, `--self-test` proven red 3 ways.
  - Rules: NEW `gc2-lead-metric-variants.md` + a new section in `db-columns.md`, synced byte-identical to all 4 worktrees, routing guard PASS.
  - **ANSWERS.** Sam's hypothesis is WRONG: sprint speed r=+0.51 vs lead r=+0.37 against ORP BR/600 (partial +0.42 vs +0.17). But question B is YES at both bases and monotone (2nd: 77%->90%; 3rd: 78%->94%), it is NOT a slow-delivery proxy (lead vs time-to-plate r=-0.016), and within one runner his longest quarter of leads beats his shortest by **+6.0 points** (201 runners, 8,953 attempts, p<0.0001). Long leads are worth ~3x more to the SLOWEST third of runners (+12.9 pts) than the fastest (+4.8). Jump is the biggest term in the 5-piece model.
  - Two decks on the Desktop at `C:\Users\Owner\Desktop\sb-components`: `sb_components.pdf` (8 pages, the lead case) and `sb_components_speed.pdf` (3/4/5 rebuilt on top speed). Speed loses badly - not monotone stealing 2nd, backwards stealing 3rd, and exactly "no difference" within a runner.
- **EXACT next step:** fold the two end-of-session stress tests into `intangibles/docs/plans/2026-09-07-sb-components-design.md` as a new section 6h -- they exist ONLY in chat right now. TEST 1 (passed, and it is the strongest defence of the whole finding): within a runner lead and jump correlate just +0.028, and controlling for jump+speed+delivery+pop the lead coefficient GROWS from +0.174 to +0.347, p=5.6e-22, so the lead is not the jump in disguise. TEST 2 (null): the between-season design gives r=+0.05, slope +0.7 pts/ft against +2.3 within-attempt, terciles out of order, league-drift removal no help; 118 season-pairs with ~9pt SE, so underpowered rather than refuting. THEN build whichever route Zac picks - see blockers.
- **Blockers / waiting on:** Zac's pick between two routes for "the most compelling and most significant case, easily understandable to an athlete": **(1)** convert the +6.0 points into RUNS, the GM-legible currency, cheap and honest; **(2)** run the between-season test on **MiLB** - the backlog population, 5-10x the season-pairs, the only thing that turns this from an association into something you can put in a player's ear. **I pushed for (2).** For (2): `sb-components-mlb-2023-2026.sql` hardcodes `sv.level_code = 'mlb'` in all 6 result sets, so it needs the MiLB whitelist plus a level column carried through - and note the 1B/2B lead cleaning bounds were written FROM MiLB HawkEye evidence, so they will bite far harder than the 0.6% they bite at MLB.
- **Uncommitted work:** intangibles 4 modified `.claude/rules/*` (synced copies from other threads, pre-existing, left alone) + 13 untracked. bsb-resources sits on `fix/eoy-sc-card-height` from an unrelated EOY thread and carries the `db-columns.md` rule edit + `.gitignore` + 2 pre-existing binary diffs.
- **Also live, deliberately not carried here** (Zac: wraps are session-specific): the Arm Farm Postgame V2 Overview thread from 09-06 lives in the recall brain at session `8d5b`, domain `bsb-wt-bullpen/feature/bullpen-reports`, checkpoint `e83411b5e9fd1d1e`.
