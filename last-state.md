# Last session state - 2026-09-09 19:45 (Powell winter-ball case + /player-comparison skill)

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
- **NOTE:** commits `a4bc0827` / `e9956859` / `7c3a064d` on this same branch are **if-positioning work from a different thread**, not this session.

---

## ALSO OPEN - Last session state - 2026-09-09 19:26 (hiring app: magnet notes + polls, resume upload cured)

- **Project / cwd:** `C:/Users/Owner/hiring` (cage-sandbox on Railway, hirehou.up.railway.app) - branch `main` @ `4573b34`
- **Recall checkpoint (SOURCE OF TRUTH):** session `92be` - domain `hiring/main` - id `e1986a237fc99192`
- **What we were doing:** Sam's magnet-board asks (notes in the card as bubbles, an ESPN-strip ticker of everyone's notes, a news marker on noted magnets, an owner/admin poll board) and the hiring board's resume upload, which turned out to be FOUR stacked defects under one symptom.
- **Shipped this session:** all pushed to `BridgerBSB/hiring` main, Railway auto-deploys, no migrations.
  - 09-07: `fc3b033` bare URL -> /dashboard for admins - `aed7c85` magnet NOTES (per-person doc, never on Current, own share list) - `1ec4944` deck/ ignored.
  - 09-09 resume: `6e63073` PDF hex-Tj parser + unreadable-file attach - `c756949` DOM-attached picker (Chrome GC'd the detached one) - `b8b4e50` findConflicts null-csvJob guard. Jim Miksis's PDF verified stored on live (board v266, 247,957 bytes).
  - 09-09 magnets: `bd78508` news marker + All-notes ticker + compose box - `bff776b` POLL board (owner/admin, private to author) - `4573b34` marker svg un-pinned from `.field svg{position:absolute}` + notes-only click.
  - Suites: hiring 750 pass; `tools/drive_notes.py` 42/42. Renders: `Desktop/magnet-notes-mocks/`, `Desktop/hiring-resume-fix/`.
- **EXACT next step:** Zac hard-refreshes the magnet board and confirms (1) the marker sits beside the name in a diamond slot and its click opens the notes alone, (2) Poll shows left of Add player and a poll saves. Then answer one question: may resume text leave Railway to the Claude API? If yes, build the model call in the existing `analyzeResumeWithAI` slot (`cage-sandbox/app/private/hiring/index.html`, search for that name) plus a GC2 org gazetteer, and clear org "MAKING" off CAND-00106.
- **Blockers / waiting on:** Sam's feedback on the poll (votes by others / visibility / live results deferred by design). Zac's call on the drawer overlaying the right third of the diamond, and on dropping "Open full card" from the notes-only box. `winterball_hitting_2026.csv` in Downloads never explained. Astro World viewer onboarding (sec_app_astroworld group + SITE_LIVE flag) parked for its own session. Recall `answer` tool is broken (no Azure endpoint) - use raw `recall`.
- **Uncommitted work:** hiring 6 paths (re-rendered PNGs from the last drive, nothing code). bsb-resources untouched by this session.

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
