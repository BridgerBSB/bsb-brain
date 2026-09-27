# Last session state - 2026-09-27 (Postgame V2 tabs 4-6)
- **Project / cwd:** bsb-wt-bullpen (feature/bullpen-reports); rules synced to all 4 worktrees
- **What we were doing:** built + corrected V2 Postgame tabs 4-6 (Location, Pitching, Glossary), took pBarrel off the card, moved the Pitching surface to the season while the dots stay the selection, and wrote the lot up.
- **Shipped this session:** 56e2995c (Location+Pitching were MIRRORED - both re-negated an already-enriched plate_x, and BOTH test suites certified it), 007220c8 (empty cell draws no panel, V1 parity), 3d88fef0 + c27ff4a8 (Glossary, derived from the shipped column constants; deduped on the PRINTED LABEL after the key-based version printed Whiff%/Z-Whiff%/CSW%/Barrel% twice), acd3133b (pBarrel off the card + its own barrel_mlb_pct pool, fingerprint -> e51e4430; season surfaces; blank-panels expander removed), 5832a1c71 (LINEAGE + docs/DASHBOARD_ISSUES.md + 2 rules synced to 4 worktrees). Guards 13+8 checks / 8+7 injections, all proven red.
- **EXACT next step:** ask Zac whether to build the COMBINED multi-level percentile pool for V2 (he left it "potentially open"). It needs no re-pin - `get_level_percentiles` returns sorted LISTS of per-pitcher values, so AA+AAA is concatenation, and both levels are already in the same season pin. The binned league SRV surface is the one piece that must be re-aggregated per bin (weighted mean of srv by n) rather than concatenated. It REVERSES his 09-01 "use the players current level" call, so do not start without a yes.
- **Blockers / waiting on:** Zac has not yet deployed the last two commits (`git pull` + `rsconnect deploy manifest . --app-id 13482bcb-8ff2-4f20-92c9-5465f49e5846`); the pool re-pin already ran (his log shows `mlb_2026_e51e4430 from PIN`). A CONCURRENT SESSION is editing V2 pool behaviour in the same worktree (HEAD moved to 76f20905a, incl. `81bef7745 v2 stuff: fallback reads last season's pools pin only`) - re-verify any pool conclusion against current HEAD.
- **Uncommitted work:** 24 entries in bsb-wt-bullpen, NONE mine (verified 0 matching postgame_v2/test_v2/render_v2/DASHBOARD); everything of mine is pushed.

## ALSO OPEN - canonical pitcher pools (2026-09-25)
- **Project / cwd:** bsb-resources (feature/pd-goals) + bsb-wt-bullpen (feature/bullpen-reports) + bsb-wt-hitting (feature/barrelsville)
- **What we were doing:** wired the canonical pitcher percentile rule (overall 300 / hand 300 / pitch type 100 / type x hand 50, 5+ pitchers, fallback last season -> next level up, fallback named on page) into every pitcher surface; fixed EOY decks going illegible on Posit, the never-SENT Delivered column, intrasquad pools using the schedule level, and moved Toolbox pins off Camden's account.
- **Shipped this session:** Arm Farm 9327bc7a/87ee495e..ad6fa44f/01c7ae49/9670d1d1/f6436c56/a6e086ff/90fc98ef; PD Engine 8a810e5e/4f1e25f7/2a00f599/6535da1d; Barrelsville ec7e5fe5/90d73352; rules blocking #24 + percentile-golden-gates PITCHER POOLS -- CANONICAL (WIRED). Zac rebuilt every pin and redeployed all 3 apps + pin jobs.
- **EXACT next step:** run the verification test table (recall checkpoint 5f39b86f / image 1242), first `py -3.11 scripts\generate_postgame.py --date 2026-09-21 --pitcher 1273220 --sched-type intrasquad` in C:\Users\zbridger\bsb-wt-bullpen\bullpen-report -> slider cells colored, no blue.
- **Blockers / waiting on:** Posit UI schedules + Vars (Zac key) on toolbox / v2_pools / eoy / tracker jobs; unschedule Camden's old toolbox job; ROTATE the two API keys pasted in chat; Arm Farm connect_pins deploy notebook was still running.
- **Uncommitted work:** only pre-existing untracked scratch in bsb-resources; everything this session pushed.

## ALSO OPEN - hiring app (2026-09-23)

## Where things stand
All work is COMMITTED + PUSHED to `BridgerBSB/hiring` `main` (head `af2f833`).
Railway redeploys from main. **Zac has NOT yet confirmed the live site picked up
the new code** - he reported Resources looking empty, which points at the deploy,
not the data (prod DB verified to hold everything).

## Shipped today (hiring repo, cage-sandbox)
1. **Alt view** on the hiring board (`39ea098`, `b8f9108`) - read-only, all names on
   one screen; Non-Renews gets its own row. "Astros Multipurpose" renamed "Astros".
2. **Hiring Processes + `lim` level** (`ee50b2b`, `f044f31`, `7e97136`, `5114453`) -
   committee sees only shared searches (default Director of Hitting/Pitching),
   allowlisted fields, resume on top (PDF inline), ONE named notes thread shared
   with the Hiring Board drawer, owner share/hide switches, MS Forms link per search.
   Board intake notes (`notesShared`, may hold salary) deliberately NOT crossed over.
3. **Resources** (`a836d0e`, `af2f833`) - owner-only page, links + file uploads
   (64 MB), now with FOLDERS (nest, breadcrumbs, drag-to-move, rename, search,
   same-name replaces, removing a folder lifts its contents).
   PROD holds 3 folders (Hitting / Pitching / Manager-Dev-Field) + 11 real documents
   (92 MB, verified byte-for-byte vs SharePoint) + 6 MS Forms links + SharePoint link.
4. **Internal board** (`4bba913`, `3bfa1d3`, `a2dbc0f`) - "Clear names" (project
   boards only, keeps structure, people to Not Placed) and MULTIPLE named project
   boards (+ New / Rename / Delete, new `/api/staff/board/delete`). Autosaves.
5. **Security (pre-existing holes closed)** (`dc3271a`, `95abade`) - the cage/pitching
   JSON API and `/api/admin/*` invite codes were open to ANY staff level; assessments
   are now OWNER-ONLY (admin lost AREA_CAGE/AREA_PITCH at Zac's instruction).
6. **Coordinator notes app** (separate repo) - Aaron Westlake fully locked out
   (`aa8cb52`), notes kept; reusable `scripts/offboard_user.py EMAIL --apply`.

## Migrations APPLIED to prod Supabase from this laptop
011 (lim role), 012 (process_note/process_setting), 013 (value_text),
014 (resource_item/resource_blob), 015 (folders + process_setting kind 'form_url').

## Open items for Zac
- **Confirm the Railway deploy** and walk the 3 pages (Resources / Hiring Processes /
  internal board project boards).
- Sam to decide who sees which questionnaire links (per-search link exists; not
  per-person).
- Office files download rather than preview (PDF preview possible if wanted).
- Hiring Board stays reachable by the one admin account (Zac's call, revisit later).
- Committee notes/uploads spec: `hiring/docs/plans/2026-09-21-candidate-review-committee-spec.md`.

## Lesson worth keeping (already in the commit message)
SQLite tests cannot see a Postgres CHECK constraint. 968 green tests hid a prod bug
where `process_setting` refused `kind='form_url'` and the route blamed an applied
migration. Third occurrence (008, 011, now 015) - any value the app hands out must be
legal in the hosted schema, and that pairing needs a test that greps migrations.
