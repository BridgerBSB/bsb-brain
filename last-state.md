# Last session state - 2026-09-27 (pitcher pools verified + EOY speed)
- **Project / cwd:** bsb-resources (feature/pd-goals) + bsb-wt-bullpen (feature/bullpen-reports)
- **What we were doing:** Zac ran the 10-row verification of the canonical pitcher pools (all passed live), then fixed what testing surfaced: Toolbox now colours every pitch, V2 Stuff cold load trimmed, EOY pitcher decks finally read their nightly payload pin, EOY note boxes no longer cut off.
- **Shipped this session:** bullpen 81bef7745 (V2 fallback reads last season's pools only), 1bf4e6250 (Toolbox subject no longer gated; n= shown), 1b3a71714 (EOY pin-miss + [EOY-RENDER] timing logs), 4b28c2cdc + 76f20905a (text fit, wrap 65). PD Engine dc9b76d13, 91bb6e122 + 80e468f07 (payload pin read: was keyed _affiliate vs _pro, never hit; goals re-resolved live), 30a8aaa44, a40731c3f, lineage df335ef31. Verified on Connect: '69773 served from the pin (mlb)', data build ~14s -> ~3s.
- **EXACT next step:** nothing active (Zac parked EOY drawing speed). If resumed: add `compliance_pin` to `bsb-wt-bullpen/bullpen-report/src/pins_config.py` (mirror `pd-goals/src/pins_config.py`) so CLI EOY decks + nightly payloads stop showing 'No Data' on compliance goals.
- **Blockers / waiting on:** Zac redeploys Arm Farm (check Toolbox colouring + V2 log shows 3 pin hits not 4) and PD Engine (65-wrap boxes); confirm Toolbox nightly pin fires; Min processes = 1 recommended on both apps.
- **Uncommitted work:** bsb-resources 81 pre-existing entries, none from this session; all my work pushed.

## ALSO OPEN - Postgame V2 tabs 4-6 (2026-09-27)
- **Project / cwd:** bsb-wt-bullpen (feature/bullpen-reports); rules synced to all 4 worktrees
- **What we were doing:** built + corrected V2 Postgame tabs 4-6 (Location, Pitching, Glossary), took pBarrel off the card, moved the Pitching surface to the season while the dots stay the selection, and wrote the lot up.
- **Shipped this session:** 56e2995c (Location+Pitching were MIRRORED - both re-negated an already-enriched plate_x, and BOTH test suites certified it), 007220c8 (empty cell draws no panel, V1 parity), 3d88fef0 + c27ff4a8 (Glossary, derived from the shipped column constants; deduped on the PRINTED LABEL after the key-based version printed Whiff%/Z-Whiff%/CSW%/Barrel% twice), acd3133b (pBarrel off the card + its own barrel_mlb_pct pool, fingerprint -> e51e4430; season surfaces; blank-panels expander removed), 5832a1c71 (LINEAGE + docs/DASHBOARD_ISSUES.md + 2 rules synced to 4 worktrees). Guards 13+8 checks / 8+7 injections, all proven red.
- **EXACT next step:** ask Zac whether to build the COMBINED multi-level percentile pool for V2 (he left it "potentially open"). It needs no re-pin - `get_level_percentiles` returns sorted LISTS of per-pitcher values, so AA+AAA is concatenation, and both levels are already in the same season pin. The binned league SRV surface is the one piece that must be re-aggregated per bin (weighted mean of srv by n) rather than concatenated. It REVERSES his 09-01 "use the players current level" call, so do not start without a yes.
- **Blockers / waiting on:** Zac has not yet deployed the last two commits (`git pull` + `rsconnect deploy manifest . --app-id 13482bcb-8ff2-4f20-92c9-5465f49e5846`); the pool re-pin already ran (his log shows `mlb_2026_e51e4430 from PIN`). A CONCURRENT SESSION is editing V2 pool behaviour in the same worktree (HEAD moved to 76f20905a, incl. `81bef7745 v2 stuff: fallback reads last season's pools pin only`) - re-verify any pool conclusion against current HEAD.
- **Uncommitted work:** 24 entries in bsb-wt-bullpen, NONE mine (verified 0 matching postgame_v2/test_v2/render_v2/DASHBOARD); everything of mine is pushed.


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
