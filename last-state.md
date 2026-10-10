# Last session state - 2026-10-10 01:52 (Owner PD deck for Sam)
- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals` (deck itself is a claude.ai Slides artifact, not in git)
- **What we were doing:** Built the owner-facing deck "What Player Development Means to the Astros Organization" for Sam: purpose, Sam's Core Pillars, scope (DSL to AAA, 42 staff, 230 players), plus two slides proving PD value with Lucas Spence ($150K undrafted 2024) and Miguel Ullola ($75K intl 2021): bonus vs GC2 Asset Value, class rank across 30 orgs, 0.4 rookie bWAR each.
- **Shipped this session:** Deck https://claude.ai/artifact/UVm5wbrjeuh7nbwArw2Lyd (8 slides). Query 385c1b67b `sql-queries/owner-deck-av-spence-ullola.sql` (ran on work laptop, results in vault note). Research note `projects/owner-pd-deck-mlb-value-research.md`. Recall checkpoint 8cc02cce6a053c9a, session 62c6.
- **EXACT next step:** Owner PD deck (What Player Development Means to the Astros Organization) built; waiting on Sam's feedback. On resume: apply Sam's revisions to the artifact (read `project/deck.json` + the slide files first). If Zac sends Ullola's/Spence's GC2-displayed AV, update slide `developed` (AV value, bar width on the shared 740px scale, AV/bonus multiple, speaker notes).
- **Blockers / waiting on:** Sam's feedback. Ullola AV UNVERIFIED vs GC2 (our max-per-season rollup $56.0M; pitcher formula read ~80% high on Mayer). Keep/cut the Approach slide (overlaps Core Pillars). Maybe add "HOU holds 3 of the top 4 hitters in the 2024 undrafted class".
- **Uncommitted work:** none from this session (bsb-resources 81 pre-existing, not mine)

---

## ALSO OPEN - 2026-10-08 12:35 (BR affiliate tracker - Mazzo layout)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` - branch `feature/astros-intangibles` (+ rule doc synced to all 4 worktrees)
- **What we were doing:** Rebuilt the Baserunning affiliate tracker to Mazzo's layout: every new/renamed column, all orgs and levels, all on at launch, grouped headers. Speed/read now split by run type (home to first vs steal attempts from 1B/2B), GC2 definitions.
- **Shipped this session:** 19d7973f7 (build), f608469b1 (lineage), 8c583130b (DoubledUp probe), spec a0f7847d3/8d512f250, probe+results b78945215/f4c8d89d3, rule fix 8e0983a7e. 2026 re-pin DONE on work laptop (7858s measured). Recall checkpoint 2ca8861c545eb8c5, session bd89.
- **EXACT next step:** On the work laptop: `.\connect_pins_br\deploy.ps1` in one terminal (ships new code to the nightly job, else it reverts the pin), and in a second terminal `rsconnect deploy manifest . --app-id 295a5205-5568-4fb6-a759-26dc63bc9439` from `bsb-wt-intangibles\intangibles`. Then run `sql-queriesr-doubled-up-pbp-probe-2026.sql` in SSMS and decide: drop DoubledUp or define it (0 rows at every level).
- **Blockers / waiting on:** Zac's deploys + DoubledUp decision; older seasons 2025-2022 re-pin with `--skip-pools`; check ORP-BR populated in app.
- **Uncommitted work:** none of this session's (intangibles worktree has 6 pre-existing rule-file mods from other syncs).

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
