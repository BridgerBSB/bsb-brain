# Last session state — 2026-09-18 09:20
- **Project / cwd:** `C:\Users\Owner\bsb-resources\command-cv` · branch `feature/pd-goals`
- **What we were doing:** Command CV miss-distance. Built the first MiLB ball training set,
  trained a detector on it, and replaced the frame-differencing pipeline with detector-based
  tracks. Retracted two inherited blockers that had been shaping plans for six days.
- **Shipped this session:** 18 commits, `af26dcee` → `4c084179`, all pushed.
  - `data/yolo_milb` — 2,484 images / 2,136 labelled / 348 neg / 0 skipped, 4 parks, 3 levels,
    split BY PARK (leakage-checked). First MiLB training set in the project.
  - **Detector trained: 30 epochs in 33.4 min on the laptop GPU.** Held-out park: top-1
    **2.15 px** median, 96% within 8 px, med rank 1.0. MLB detector is 3.77-4.49 px.
    Works on full 1280x720 frames → replaces the seeder AND the harvest, needs no pose.
  - **BLOCKER RETRACTED #1:** "this box cannot train" was wrong for six days — RTX 3050 Ti +
    torch cu128 were installed all along; `train_ball_detector.py` defaults to `--device cpu`.
    The memory file had escalated to "buy a PC with an NVIDIA card". New rule
    `.claude/rules/probe-capability-before-accepting-a-blocker.md`, synced to all 4 worktrees.
  - **BLOCKER RETRACTED #2:** "MiLB inches need a landmark" — OpenCommand pins Cy=400 on all
    499,800 rows (30 parks, ALL MLB, zero MiLB) and still gets 0.04-0.13 in. Ours measure
    Isotopes +0.21 in / Frawley +0.22 in. Already metric to ~half an inch.
  - **Durham recovered:** size ratio 1.37 → **0.98**, camera `f/Cy` 29.4 → **39.4**.
  - New scripts: `audit_seed_tracks`, `verify_ball_dataset`, `snap_harvest_labels`,
    `detect_ball_tracks`, `eval_ball_detector`, `plate_scale_check`.
  - Clips expanded with no browser step: Isotopes 50→327, Frawley 50→276.
- **EXACT next step:** Run iteration 2 — rebuild the dataset from DETECTOR labels on the
  expanded clip sets and retrain (33 min):
  `cd C:\Users\Owner\bsb-resources\command-cv`
  `python scripts/detect_ball_tracks.py --dir data/clips/aaa_815419 --game 815419 --weights data/yolo_ball_runs/milb4park/weights/best.pt --lo 178 --hi 232`
  then the same for `aplus_821819`, then `audit_seed_tracks --seeds detect_tracks_<g>.csv --write-labels`,
  then `build_ball_dataset`, then `train_ball_detector --device 0 --epochs 30`.
- **Blockers / waiting on:** Zac owes two calls — (1) more games via his browser pull (AA is
  effectively empty; the browser-side snippet is NOT committed and died with the 09-17
  scratchpad, so paste it or say where it lives), (2) Astros affiliates vs camera variety.
  Open technical: Riders' pose failure unexplained (2 hypotheses dead), Hops unsolved.
- **Uncommitted work:** `command-cv` clean; ~80 pre-existing untracked paths repo-wide from
  before this session.
