# EOY Position-Player Report — handoff (2026-07-18, updated post-feedback)

- **Project / cwd:** `C:\Users\Owner\bsb-resources` · branch `feature/pd-goals`
- **What we were doing:** EOY Position-Player HITTING report. First real-DB run
  (Jason Schiavone, gcid 218498) came back; worked Zac's page-by-page feedback.
  All concrete fixes SHIPPED; 4 decisions remain (need Zac).
- **Shipped this session (feature/pd-goals, pushed):**
  - `a26dd20a` Pg3/5/7/11 — spray click-to-video (sporty-clips CF) · "pool's"→"group's"
    + last name · dropped % chips on both Launch Direction rows · hand-aware
    Pull/Mid/Oppo % row · Pg5 "Distributions" + last name + High/MLB ridges populated ·
    Pg7 "your" · Pg11 POC density granular (adaptive KDE).
  - `67b16d55` Pg2 — AvgEV before 90EV · Sqr%→SqrUp% · LA%→LA10-30 · ZCon before OSw% ·
    **percentile coloring root-cause fix** (per-metric ÷100 scale; ZSw/OSw route via
    `ZSwing%`/`OSwing%`; direction owned; Sw% uncolored).
  - `a4624e31` docs — `pd-goals/docs/plans/2026-07-18-eoy-position-discussion-next-steps.md`
    (the 4 open decisions, full context).
  - Earlier: `e93b4832` (P5/P7), `1fa2db5d` (P3 pools), `513f3390` (P2 coloring).
- **EXACT next step:** Get Zac's 4 answers (asked via AskUserQuestion; he was away) in
  `2026-07-18-eoy-position-discussion-next-steps.md`. Most likely first build =
  **clone `barrelsville/src/postgame_percentiles.py::get_level_percentiles` into
  pd-goals** → rewire `_build_page2_pct_grid` (Pg2 coloring) + `_build_page5` (ridges);
  then add IdAAC + SqrUp net-new pools (only metrics with NO pool in either engine).
  Then Pg6 scope + launch-direction pull-signed normalization per Zac's calls.
- **Blockers / waiting on:** Zac's 4 decisions (engine clone · Pg6 scope · launch-dir
  normalize · pool min) + work-laptop re-run to verify the Pg2 scale fix + pool numbers
  vs GC2. Pg6 Internal Grades still BLANK (pending scope).
- **Uncommitted:** EOY clean (all pushed).
