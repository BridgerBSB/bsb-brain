# Last session state - 2026-08-30 06:42
- **Project / cwd:** `C:/Users/Owner/astroworld` (Baseball-Operations/astroworld-dev, remote `prod`) - branch `feat/aerollo-attachments`
- **What we were doing:** Built **Aerollo**, our Trello, inside Astro World. PR #44 (the Kanban) is MERGED and LIVE - Zac ran the migration. PR #45 is OPEN: rearranged the card back from Zac's recording of a real Trello board (work in the middle, chat on the right) and added real file attachments, including video that plays inline in the chat.
- **Shipped this session:**
  - **PR #44 MERGED** - Aerollo Kanban live: boards/lists/cards, hand-written pointer drag with edge auto-scroll, card back, labels, members, Central-time due dates, checklists, comments, activity, filter, archived-items + restore, clear-a-list, copy-a-card, 12s background refresh, 8 generated SVG backgrounds, top bar right of ManagerHUB. **Open to ANY signed-in user** - the gate is `getSessionUser`, deliberately not a role check.
  - **PR #45 OPEN** (`9f05670`, `c53ab3d`) - two-column card back (action row under the title; description + **Attachments** in the middle; **Comments and activity** on the right, own scroll, one merged feed). Move/Copy/Archive/Delete into the header `...` menu. "Due date" renamed "Dates". New `AeroAttachment` table. Files pinned to a card OR posted in a comment (`commentId` is the only difference). Chunked upload always (the platform silently truncates bodies over 10MiB). Range/206 streaming. New OPTIONAL `VideoStorage.remove()` for local+azureBlob so deleting a file deletes the bytes.
  - **All green on a production build:** 150 browser checks (files 36 / drive 34 / drag 30 / stress 20 / copy 16 / archive 14) plus unit suites (pos 32, dnd 35, time 30, files 51, migrations 85, migration-status 16, aerollo-db 31), signed in as a **viewer**.
  - Deliverables on the Desktop: `aerollo-screens/` (screenshots + AEROLLO-RUNBOOK.md).
- **EXACT next step:** Sam Niedorf asked in Slack for (1) upload video/photo - **done in PR #45** - and (2) **"a time and date stamp to each time a comment is entered so we can track it"** - **NOT done**. Comments show only relative time (`formatWhen` -> "just now"). Edit `src/components/aerollo/CardBack.tsx`, in the `Conversation` feed where it renders `{formatWhen(item.comment.createdAt)}` (and the activity line beside it), to show an **absolute Central date+time** like Trello's "Feb 20, 2020, 4:28 AM". Helpers already exist in `src/lib/aerollo-time.ts` (`formatDue`, `CENTRAL`). Central time is BLOCKING rule #20. Add checks to `scripts/test-aerollo-time.ts` and the `files.mjs` browser suite. Zac has already told Sam it is coming.
- **Blockers / waiting on:**
  - PR #45 not merged. After merge, run **Admin > Database > "Aerollo attachments"**.
  - **STORAGE_DRIVER is `local` in production and the App Service filesystem is EPHEMERAL** - uploaded videos will not survive a deploy (the row survives, the bytes do not). The UI warns before upload; the real fix is `STORAGE_DRIVER=azureBlob`, which needs a storage account + role assignment from Peter/IT. Flag before coaches put real clips on cards.
  - Sam's Trello board is private (401) and the Chrome extension would not connect - Aerollo copies Trello behaviour, not that board's columns. Closed unless Zac pastes them.
- **Uncommitted work:** astroworld clean except 1 pre-existing untracked file (`migrations/content-export-2026-07-15.json`, not mine). Local test rig left RUNNING on the personal laptop: postgres 5434 + app 3210 (restart recipe in the runbook).

---

## ALSO OPEN - pd-goals: EOY notes deletion + the 8-hour outage (2026-08-29)

## What happened

Two separate bugs in `pd-goals`, one day, both mine. The second deleted
coordinators' End-of-Year notes across the org.

**1. Eight-hour outage.** `pins_config._patch_ssl()` ran on every pin read and
write, re-wrapping `requests.Session.send` each time. ~975 layers deep, every
HTTP call died with `RecursionError`. Both surfaced error messages were false
("CONNECT_API_KEY set in Vars?", "pin pd_goals_data does not exist") — the
network was never reached. Fixed with an idempotency marker on the patched
function; all four worktrees. **A poisoned worker stays poisoned until restart.**

**2. The deletion.** The EOY page saves `st.session_state.get(key, "")` for
every box in a group, and hydration sets `saved = {}` on any read miss then
marks the player hydrated. One transient read renders every box blank; the next
Save persists that over real text. Bug 1 is what put the app in that state.

## Recovery status

- **Neyens (244959) — RECOVERED** from saved PDFs. `~/Desktop/eoy_notes_recovered.txt`.
  Diffing his 2:01pm vs 2:02pm Aug 29 decks dated the loss to the minute
  (31176 → 30843 chars, exactly the Aug 26 length).
- **Curry — RECOVERED** from a July deck.
- **Schiavone — NOT recoverable.** His decks are Jul 19, old 12-page format,
  page 1 still shows the placeholder. Nothing was in them.
- **53 surviving boxes**: Nutrition ~42, Fielding 5, goal_3 ×5, one ATC "test".
  Zero hitting summaries, zero pitcher narrative, zero goals 1–2, zero S&C.
- **`zbridger/eoy_pitcher_notes` does not exist.** Dead lead.

## Zac's next steps (he is testing these now)

1. `python scripts\diag_eoy_notes.py --harvest --pin ...` / `recover_pin_bundles.py`
   — **UNRUN**, the last technical avenue. A pin version IS a Connect bundle and
   Connect retains those separately; every tool built today asked `pin_versions`,
   the layer that had already said no.
2. `diag_eoy_notes.py --seed-history --yes` — freeze the 53 survivors. Pruning
   is active (13 → 3 versions during the session).
3. Redeploy PD Engine `79f52369-8244-46da-a4d6-95df956bacad` — the blank-overwrite
   fix and audit trail do nothing until restart.
4. **IT**: are `eoy_notes_2026` versions before ~08:00 Aug 29 in server storage
   or backup? Only route to text in no deck.
5. **Coordinators**: saved decks in their Downloads, plus whatever they drafted
   *from*. For Schiavone-shaped cases that is the only copy.
6. **Arm Farm redeploy** `13482bcb-8ff2-4f20-92c9-5465f49e5846` — same
   `_patch_ssl` bug, and its EOY page writes the SAME `eoy_notes` pin.

## Shipped

Rules: `monkeypatch-idempotency.md` (#21), `blank-must-not-overwrite.md` (#22),
synced to all four worktrees, routing guard green in each.

Tools in `pd-goals/scripts/`: `diag_eoy_notes.py` (`--list --current --player
--all --harvest --seed-history`), `recover_notes_from_pdfs.py` (**personal
laptop** — that is where the decks are), `recover_pin_bundles.py` (work laptop,
unrun).

Code: blank can no longer overwrite text; all-blank submissions create no row;
per-column anti-wipe guard; append-only `eoy_notes_history_<season>`.

## The thing to carry forward

Connect keeps a fixed **number** of pin versions, not a span of time. EOY writes
one per box-group save → hours of history. PRP writes one per section → days.
PRP was not built more carefully; it writes less often.

Both protections EOY needed already existed: PRP's strict read (`if df is None:
return False`) and `compliance_history_pin`, in the same file as the notes pin.
Zac asked three times for durable safeguards before I wrote one — I kept fixing
the thing in front of me. See `feedback_apply_existing_rules_to_new_surfaces`.
