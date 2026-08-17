# Last session state - 2026-08-17 13:20 (Care page's stand-in rows are wired to the DB)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `51ed` - domain `bsb-resources/feature/pd-goals` - id `01b505e9b94d80b2`. **Ring buffer 10/10 - the next checkpoint EVICTS the oldest.** Durable material is in `LINEAGE.md` (`e62e16c2`) and `.claude/rules/sportsmed-schema.md`, not the checkpoint.
- **What we were doing:** closing the Care page's last open sources. The hamstring / shoulder / groin rows had been stand-ins with "source is being confirmed" in the code. All three found, wired, and rendered for a real player.

- **Shipped:** `3dd808af` extract + CSV render - `c954ee58` SQL fixes - `2439ee1e` three cards wired + the bodyweight retraction - `c3542e76` Nordbord test split + shoulder date gap measured - `94d63e83` `render_care_page_db.py` (direct-to-DB, the version that fills all six jump rows) - `fd8520e3` null-test guard - `6227dcf4` **`.claude/rules/sportsmed-schema.md`**, synced to all 4 worktrees - `e62e16c2` LINEAGE.
- **The answer:** everything is `SportsMed.Metrics`, an EAV store. Hamstring = Nordbord 78/79. Shoulder = GB Shoulder 1104/1105/1107/1108. Groin = GB Groin 1114/1115/1117/1118. One-to-one onto the card's row keys. Found from the COMMITTED schema snapshot with no DB run, then confirmed live. Coverage 237-247 players per device, 218 have all three.
- **RETRACTED mid-session:** entering bodyweight is NOT wired. `metric_type_id 116` has ZERO HOU rows. Finding a metric TYPE is not finding the number. Stays a pin.
- **Bug the data caught:** Nordbord logs `Nordic` AND `ISO 30` into the same id 78/79. Mixing them read Mitchell's Nordic entering against his ISO 30 current and drew a red arrow on a leg that went **up 18%**. `m.test` is in the grain everywhere now.
- **New finding, open:** the shoulder card's four values are a **median 128 days apart** (right newer 82% of 211 players; median last left Mar 23 vs right Aug 2) because only the throwing side is monitored in season. Groin is 100% same-day.

- **EXACT next step:** read Zac's terminal output from `python scripts\render_care_page_db.py --gcid 218498` (Jason Schiavone), which he was running on the work laptop as the session ended. Confirm **Time to Takeoff and Eccentric Duration actually populate** - they are the entire reason that script exists - and that the lower-is-better rows draw GREEN on a decrease. If it errors, look first at the `_FORCEDECK` conditional-aggregate CTE or the `_ROSTER` self-join.
- **Blockers / waiting on:** Tina on the shoulder date gap (show a date, suppress the stale side, or ship as-is) - Alvaro on which Nordbord test the card means, and on whether `Contraction Time` really is "Time to Takeoff" (still an inference, and a player-facing label on a guess).
- **Uncommitted work:** 72 untracked/modified paths, all pre-existing at session start.
