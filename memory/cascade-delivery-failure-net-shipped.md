---
name: cascade-delivery-failure-net-shipped
description: Daily/Monday cascade now FAILs (not OK) when Slack delivery fails; two-layer guard shipped + pending work-laptop steps
metadata: 
  node_type: memory
  type: project
  originSessionId: d41cb551-6bcf-492d-a8fc-39aad76a32a5
---

**2026-06-05 SHIPPED + PUSHED (all 4 branches). Work-laptop `git pull` + 6-04 re-sends both DONE by user same day. Only remaining is OPTIONAL: inline-script `sys.exit`.**

## The bug
A DNS/VPN drop mid `run_daily` (MaxParallel 10) made pit-pg + br-pg deliver
`0 sent, 23 failed` (`getaddrinfo failed`) while the summary printed "All
steps OK" — `generate_postgame.py` discarded the delivery result and exited
0. Tell that it was a network outage not a code bug: the same `getaddrinfo`
error hit headshot/mlbstatic loads in the same run.

## The two-layer guard (in `.claude/rules/cascade-orchestrators.md`, synced 4 worktrees)
- **Layer 1 — `src/deliver.py` (4 worktrees):** `send_reports_via_logic_app`
  + `send_to_channel` now `sys.exit(1)` when `failed > 0`.
- **Layer 2 — `Invoke-Pool` net in BOTH `run_daily.ps1` + `run_monday.ps1`:**
  after a phase reaps exit 0, scans the phase log for delivery-failure
  markers and forces FAIL + **exit 90** (sentinel). Regex (case-insensitive):
  `\[FAIL\]\s.*->|Delivery complete:\s*\d+\s*sent,\s*[1-9]\d*\s*failed|Delivery failed|Delivery error`.
  Broadened 2026-06-05 to bare `Delivery failed`/`Delivery error` after the
  user caught that mazzo/hexbin/paa-eo print `Delivery error: <exc>` /
  `Delivery failed (<status>)` from inline `requests` delivery (original
  regex missed both). Verified vs 13 real lines: every failure form matches,
  success summary + Headshot/query/render/`Failed: N` do not.
- **daily `MaxParallel` default 10 → 3** (matches Monday). Mitigation only —
  outage was DNS, not concurrency.

## Commits
- `feature/pd-goals`: `cf2ea747` (initial) → `63e0b944` (broadened net)
- `feature/bullpen-reports`: `03e7b81f` → `ce15657d`
- `feature/barrelsville`: `305606a8` → `9ee32e2f`
- `feature/astros-intangibles`: `2f7bae43` → `7e29d88a`
- Rule md5 across 4 worktrees: `f90a7c9bf98eff50f850a26b0a896b41`

## DONE by user (2026-06-05, same day)
1. Work-laptop `git pull` on all worktrees — guard + daily MaxParallel 3 now live.
2. 6-04 re-sends (pit-pg, mazzo, c-pg, br-team, br-pg) — all re-delivered.

## REMAINING (optional, not blocking)
3. **OPTIONAL — Layer-1 `sys.exit` for inline-delivery scripts** (mazzo,
   catcher-hexbin, paa-eo-direction, the KPI/advance scripts): they still
   exit 0 STANDALONE. In-cascade Layer 2 covers them. User undecided; not done.
4. No `.graduation-log.md` entry written (rule is the canonical doc).

## Caveat
Layer 2 only fires when phases run THROUGH `run_daily`/`run_monday` (it scans
each phase's per-phase log). A hand-run standalone script still exits 0; user
sees the error in the terminal directly. See [[cascade-orchestrators]] rule.
