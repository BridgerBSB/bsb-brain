---
name: session-2026-06-03-cascades-and-acq
description: "Jun 3 2026 — cascade parallelization (UNVERIFIED, user testing daily tmrw) + pitcher_analysis acquisition mode (CONFIRMED working) + docs"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2d2b5c12-cc2b-451f-b462-62f4376aa484
---

Jun 3 2026 session. All committed + pushed across 4 worktrees; nothing uncommitted.

## Shipped

1. **Cascade parallelization** — `run_daily.ps1` + `run_monday.ps1` now run phases
   concurrently via a `Start-Job` worker pool with `-MaxParallel` (daily default
   10 full fan-out, Monday default 3). Monday splits at the stapler barrier
   (Stage 1 = pre-stapler incl 6 KPIs → barrier → Stage 2 = stapler-gated +
   post-work). `-MaxParallel 1` = old serial. Commit `fb395242` on
   `feature/pd-goals`. **STATUS: NOT YET RUN FOR REAL — user testing the daily
   tomorrow.** Two engine gotchas already fixed in testing (ComSpec full path,
   `@(Receive-Job).Count` vs falsy-zero). If tomorrow's run misbehaves: drop to
   `-MaxParallel 4` (TCP/Slack load), or `1` for serial. Full pattern +
   bug history in **`.claude/rules/cascade-orchestrators.md`** (synced 4 worktrees).

2. **Daily pit-pg → zzz COACH channel** (not z athlete) — `run_daily.ps1` pit-pg
   uses plain `--deliver` (`$d`), not `$dz`. Commit `bd73e618`.

3. **pitcher_analysis `--pitcher-ids` acquisition mode** — scout non-HOU arms by
   gc_id, bypasses the `ORG_LK='hou'` gate, local-only (no delivery), writes
   `output/..._ACQ.pdf`. Commit `9c3ae2c3` on `feature/bullpen-reports`.
   **STATUS: USER-CONFIRMED WORKING** (ran Jack Dashwood gc_id `73573`, "worked
   flawlessly"). Normal org run + Monday `pit-analysis` are byte-identical
   (flag is purely opt-in). Documented in **`arm-farm.md`** "Acquisition mode"
   subsection. Data caveat: Pitches_View only holds a target's vs-HOU outings —
   watch the `[ACQ] N/M ... have <season> data` line. If it ever returns
   fuller-than-just-vs-HOU, GC2 has broader pro coverage → worth widening this.

## Open / deferred

- Parallel cascade first-real-run (daily) pending — see #1.
- `advance-non-ebiz-pitchers.md` is DIVERGENT across worktrees (intangibles copy
  hash differs from the other 3) — pre-existing drift, NOT reconciled this
  session. Candidate for a rules-sync sweep. Left untouched on purpose.
- Possible follow-up: widen acquisition mode if the diagnostic shows GC2 carries
  league-wide pro pitch data (currently assumed vs-HOU-only).
