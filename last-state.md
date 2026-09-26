# Last state - 2026-09-23 (hiring app session)

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
