# Last session state - 2026-08-21 10:39 (rule-injection tax cut; EOY Completion board fixed 3x)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `953f` - domain `bsb-resources/feature/pd-goals` - id `2559637ad3929415`. Ring buffer 4/10.
- **What we were doing:** Cut the `.claude/rules/` auto-injection tax (one Streamlit status-page edit was pulling 76 of 111 rule files, ~220K tokens, before any work), then chased the EOY Completion board through three real defects to a working Delivered column plus a way to undo a test player.
- **Shipped this session:**
  - `0375ebd2` + `784a726e` - rule routing. Always-on 34 files/293K -> 11/58K; mean per-edit ~185K -> ~92K tokens. Guard `.claude/scripts/test_rule_routing.py` (16 targets, 7 injections proven red). MY EMULATOR WAS WRONG first pass (trailing `**`); caught by validating against the loader's own `Loaded ...` lines: 16/22 -> 22/22.
  - `settings.local.json` 48K -> 10K (393 -> 155 entries), zero permissions widened. GITIGNORED = local only; work laptop still bloated.
  - EOY Completion board pinned to AAA..FCL with off-board players COUNTED not dropped; Delivered column (SENT / blank / `?`); OUTSTANDING now includes not-sent.
  - `clear_notes` + `--wipe-notes`. Zac ran it - Schiavone 218498 wiped, pin `20260821T114206Z-556e8`, AA now reads 0 of 36.
  - `mark_sent` return now checked at both call sites - a failed delivery RECORD used to be indistinguishable from success.
  - Docs: `windows-toolchain.md` (heredoc eats backslashes; assert every replace; py_compile is not a test), `tautological-display.md` 4c (two facts under one label), `LINEAGE.md`. Synced + green in all 4 worktrees.
- **EXACT next step:** On the WORK laptop, in `C:/Users/zbridger/bsb-resources/pd-goals`: `git pull`, then redeploy PD Engine (app-id `79f52369-8244-46da-a4d6-95df956bacad`). The `mark_sent` check landed AFTER the last deploy, so it is not live. Then open the Completion tab and confirm Delivered shows SENT / blank and NOT `?` - a `?` means the int-vs-str key fix did not take.
- **Blockers / waiting on:** Zac's call on whether OUTSTANDING should include not-delivered (I changed it unilaterally and flagged it). Board never eyeballed at full roster size.
- **Uncommitted work:** clean (1 modified PDF from the prior session; 76 untracked pre-existing).
