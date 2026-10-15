---
type: project
title: Baseball Command Center + library - design
status: building
created: '2026-10-15'
tags:
  - command-center
  - idea-library
  - project-bank
---
# Baseball Command Center + library - design (Oct 15 2026)

**Ask (Zac, Oct 14-15):** one place that shows everything and actually updates as things
happen. A project bank with progress bars (mine and Cael's), an idea bank (every link fed,
later coach ideas), the automated processes (did AFL send, did the nightly run), and the
second brain shown as a library. Look: like Kyle Boddy's isometric Driveline world
(buildings, avatars, live pop-ups), not a plain dashboard. Clip: `Downloads/ex.mp4`.

## Decisions (asked one at a time)
- **Audience v1: Zac only**, on the personal laptop. Cael's progress comes in through his
  GitHub pushes (add `repo` + `author` to his card). Sharing with Cael / coaches = later.
- **Bars = steps**, with live counts where a job has one (Command CV games graded). Where
  steps are not clear yet, the card shows a stage track (idea > scoping > building >
  review > shipped) and never a made-up percentage.
- **Look:** World tab first (isometric campus), then Command (panels) and Library tabs.
- **Updates Claude cannot see** (Posit jobs, Cael's status, the podcast): Zac says it in
  chat, Claude edits the card note, the next refresh shows it.

## How it is built
- Generator `meta/generate_command_center_v2.py` writes `Command-Center.html` (one file,
  data embedded as JSON). Reuses v1 helpers (worktree triage, last-state).
- Scheduled task "BSB Command Center": `pyw.exe ... --open-once-daily`, every 15 min,
  no console window; opens the browser on the first run of the day only.
- World = three.js r128 from cdnjs (needs internet); Command + Library work offline.

## Data (plain notes, edit in Obsidian or ask Claude)
| What | Where | Key fields |
|---|---|---|
| Project | `bank/projects/*.md` | lane now/next/later/done, owner, source, tag, stage, status, waiting_on, next, due, `## Steps` checklist, repo/branch/paths/grep/author (commit feed), counter |
| Process | `bank/processes/*.md` | check task/log/manual, task or task_glob, log + summary regex, expect_every_h, active_until; manual: entered, last_run, result |
| Idea | `ideas/*.md` | unchanged; source / owner / link where known |
| Library | concepts / drills / cues / sources / MOC-* | type + domain; rejected + duplicate sources hidden |

## The world
- **Project Yard:** a building per Now/Next project. Lit floors = progress, orange frame =
  still to build, crane = Now and being built. Later = empty lots with a sign.
- **The Library:** a tower per shelf, height grows with note count (log scale).
- **Idea Bank**, **The Port** (research batches as ships), **Ballpark** (scoreboard =
  process lights).
- Avatars Z / C stand on the project they last committed to. The freshest commits cycle
  in the top-right card while their building pings.
- Click anything: a drawer with the card, the shelf, the ideas, the jobs or the research.

## Checks
- Process lights proven both ways on fixtures: ok / late / failed / running / manual /
  old entry / none / ended (9 of 9).
- `Command-Center.html?selftest=1` opens all 7 building kinds and logs `SELFTEST OK`.
- Renders inspected at 1600x1000 and at phone width.

## Not built yet
Sharing slice for Cael / coaches; coach idea input; Cael's repo wiring; podcast card
content; Posit entries (manual until Zac reports runs).
