# Last session state — 2026-09-19 17:31
- **Project / cwd:** `C:\Users\Owner\bsb-resources\command-cv` · branch `feature/pd-goals`
- **What we were doing:** Command CV. Scaled the ball-detector dataset from 4 ballparks to
  13 by building the whole pull pipeline: enumerate venues off the public schedule endpoint,
  harvest clip URLs with Zac's Okta token, then download/detect/label/cut-crops/prune
  unattended. Found five silent defects along the way, four of them mine.
- **Shipped this session:** 25 commits, `6e3215c5` → `00652795`, all pushed.
  **19 park-games, 13 venues, 2,983 clips, 31,699 labelled points** (v1 had 2,136).
  New: `affiliate_schedule.py` (700 games / 63 level-venues / 348 away),
  `harvest_pull_csvs.py` (4,813 clips banked in `output/cvpull/`),
  `rolling_pull.py`, `labels_from_detector.py`, `park_scoreboard.py`,
  `browser/cv_pull.js`, rule `long-jobs-on-this-laptop.md` (synced to 4 worktrees).
  Corrections: the POSE was vetoing good tracks (81 of 212 Isotopes clips);
  the SCAN WINDOW was truncating flights (Greensboro's plate is f277 vs a f250 window;
  Constellation 31%→47%); my `--angle` default was CENTERFIELD; a documented cv2 seek
  bug reappeared and made 9 parks' labels look wrong; the loop deleted video before
  cutting crops. Retracted "low-yield parks share tight framing" — corr is +0.52, opposite.
- **EXACT next step:** `cd C:\Users\Owner\bsb-resources\command-cv` then
  `python scripts/rolling_pull.py --weights data/yolo_ball_runs/milb4park/weights/best.pt --games 827291,827289,821925,821924,817525,817522,816448,816447,814875,814874 --labels-only --min-free-gb 6`
  (crop recovery, was at 5,451 of ~31,700; resumes from disk). Then build the val split
  for Asheville 822515 separately, then train 12 epochs `--device 0` and read the
  held-out Asheville pixel error against v1's **2.15 px**. Never read mAP.
- **Blockers / waiting on:** Nothing blocking. Would help: launch Claude Code with
  `CLAUDE_CODE_DISABLE_BG_SHELL_PRESSURE_REAP=1` (7 reaps today); a fresh Okta token for
  more venues (only 8 of 63 banked); a decision on the Colab notebook (not written).
- **Uncommitted work:** 81 untracked paths, ALL pre-existing from before this session.
