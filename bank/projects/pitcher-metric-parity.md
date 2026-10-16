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
updated: '2026-10-16'
---
# Pitcher metric parity: tracker vs Profiler vs GC2

## Steps
- [x] IBB double-count in batters faced fixed (28dd6d76b)
- [ ] Barrel% definition probe run
- [ ] Fix whichever side does not match GC2
- [x] Profiler ?diag=1 timing table, then the postgame pin decision (pinned 7f571dc9e Oct 10; Profiler 2.9s / 5.0s; Postgame Visuals confirmed fast on Connect by Zac Oct 16)

## Notes
- Oct 16: Postgame Visuals load closed. Side note, not acted on: zero_count_report.py builds with plt.figure (blocking rule #24); low risk, nothing else in the file uses pyplot global state.
