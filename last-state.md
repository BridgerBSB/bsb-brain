# Last State — 2026-08-29

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
