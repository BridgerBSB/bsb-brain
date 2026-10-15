---
type: project
share: true
title: 'Pitcher metric parity: tracker vs Profiler vs GC2'
lane: next
owner:
- zac
source: zac
tag: Arm Farm
stage: building
waiting_on: zac
next: Run sql-queries/barrel-definition-probe-2026.sql in SSMS and paste the 3 grids
repo: C:/Users/Owner/bsb-wt-bullpen
grep: parity|barrel|IBB|kpct
updated: '2026-10-15'
---
# Pitcher metric parity: tracker vs Profiler vs GC2

## Steps
- [x] IBB double-count in batters faced fixed (28dd6d76b)
- [ ] Barrel% definition probe run
- [ ] Fix whichever side does not match GC2
- [ ] Profiler ?diag=1 timing table, then the postgame pin decision

## Notes
-
