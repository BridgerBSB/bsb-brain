# Last session state — 2026-07-29 11:05 (IF/OF Range & Difficulty)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` · branch `feature/astros-intangibles`
- **What we were doing:** Brought the IF Range & Difficulty view to parity with OF, fixed the infield spray so dots sit where the ball MET the fielder (not at its first bounce), made the play population a user toggle, and rebuilt Out/Hit/Error labelling on official scoring. Ended on a performance question, not a bug.
- **Shipped this session (21 commits, `5e1f7241..7608c5fc`, all pushed; Zac deployed `3788a839` and confirmed "this looks great"):**
  - **Spray anchor** — `add_if_spray_coords`: point on the ball's path closest to the fielder's START, ball-landing fallback tagged in `spray_src` (square = anchored, diamond = fallback).
  - **Population toggle** — `First defender only`, sidebar, DEFAULT ON, both domains. ON = Tier 3 (pre-session behaviour, OF byte-identical); OFF = that domain's weekly-report display tier, shared with the weekly PDFs via `fielding_base.display_tier_filter_if/_of`.
  - **Outcome labelling** — `fielding_base.batted_ball_outcome` from `event_result_id` (verified against Zac's live 2026 dump). Out {14,18,19,17,24,10,39,37,16} / Hit {41,9,48,21} / Error {13,11} ONLY. Purple Err fill + Show Errors box + Err pill, both default ON.
  - **IF scatter rebuilt on the shared OF builder** (forked `_make_if_scatter_figure` deleted), domain-parameterized axes, launch-angle lever, IF ball time as a 2-handle range reaching 0.
  - **Code review** (workflow, high) — 10 findings, 7 CONFIRMED, 9 fixed in `3788a839`. Worst: hulls eating landing-fallback coords; IF difficulty bands FITTED IN OF UNITS; scatter axes mixing ball time with reaction time per play.
  - **Docs** — `.claude/rules/opida-infield-attributes.md` (new, all 4 worktrees); `LINEAGE.md` created at the intangibles root, 2 entries.
- **EXACT next step:** Collapse the 11 per-angle `Astros.Video_Network` LEFT JOINs in `_video_joins` (`intangibles/src/fielding_range_data.py:67`) into ONE derived table using conditional aggregation (`MAX(CASE WHEN angle='A' THEN video_url END) AS url_A, ... GROUP BY sched_id, pitch_id`) — 12 of the query's 22 joins, all idle until a dot is clicked. Build it as an OLD-vs-NEW diff harness asserting byte-identical video columns; it CANNOT be tested off the work laptop. (Zac agreed the approach; initial load is heavy, everything after is fast.)
- **Blockers / waiting on:** Work-laptop only — (1) does DCBP write `out_prob` per RESPONSIBLE fielder or per position? if per-position, toggle-OFF counts balloon; (2) HawkEye start-position coverage (diamonds vs squares); (3) the OPIDA diagnostic in `opida-infield-attributes.md` §5 — `fielder_dist_from1b_at_field` would fix the anchor's depth compression. MAZZO SIGN-OFF still gates the IF range page in any DELIVERED weekly PDF.
- **Uncommitted work:** 14 files in the intangibles worktree, ALL pre-existing (unrelated `.claude/rules` edits + `output/` artifacts). Nothing from this session is uncommitted.
- **Still broken, known, not fixed:** OF grounders still plot at the infield first bounce (the ORIGINAL bug, still live on the OF side — `add_if_spray_coords` is IF-only) · `_opportunity_counts` bins anchored + fallback dots together · summary-bar text collision · `if_weekly_report.py:52` dead import · `_add_play_markers` ignores `spray_x/y` (smoke-only landmine).
- **Verified dead ends — do NOT retry:** `Play_Event_Positions` event 17 and OPIDA `throw_xf/yf` as the anchor (exist only on plays he COMPLETED → delete the balls that got past him) · `pitch_result_id` as the outcome proxy (12 = "an out was recorded", so an OF single with a runner thrown out reads Out) · `fielders_choice` as an error (it is an OUT).

---

## ALSO OPEN — EOY position report + coordinator-notes app (`bsb-resources` / `feature/pd-goals`)

> Different repo/branch, still live. Preserved from the 2026-07-29 10:20 wrap.

- **Project / cwd:** `C:/Users/Owner/bsb-resources` · branch `feature/pd-goals`
- **What we were doing:** Wired the position-player EOY into the PD Engine app as a coordinator-notes in-app submission, then refined the EOY P13 fielding page per Zac's feedback (rose pool + column headers).
- **Shipped this session (all pushed, HEAD `935b7dde`, render/compile-verified locally, ALL UNVERIFIED vs DB/Connect):**
  - **`f79d1c70`** — position EOY in-app submission WIRED (was a stub scaffold). `src/eoy_notes.py` real `save_eoy_note`/`mark_sent`/`deliver_eoy_report`/`pin_write_notes` with PRP anti-wipe (strict board check + `_pin_write_notes` anti-shrink). **2 boxes only** (Hitting + Fielding/BR — Zac confirmed, no 3rd box), auto heading. `pages/14_EOY_Reports.py`: prefill (deferred-load) + PDF preview + Send (PDF-last, fp-cached) reusing `build_position_payload` + `build_position_eoy_pdf`. Pitcher/ODP tabs = not-wired placeholder (Camden). pin `zbridger/eoy_notes_<season>`.
  - **`66e4e736`** — P13 OF/IF direction roses colored **vs MLB pool** (was highest level). `eoy_fielding_data.py:580` `_DIR_POOL_QUERY` level_filter `hi_level`→`"mlb"`; caption "vs MLB" (EN+ES). Catcher NetK quad untouched.
  - **`935b7dde`** — **`%Hi` header → actual level** (`%A/%AA/%AAA/%A+/%Rok/%DSL/%MLB`) report-wide via `_hi_pct_label(payload)` threaded through P13 (2 tables)/P18/P19/P20/P21; caption `.replace`; P22 glossary `%Hi`→`%Level`. `%MLB` unchanged → reads `%AAA | %MLB`.
- **EXACT next step:** Zac's words — "continue on the next steps of editing the report and the coordinator notes in the actual app." Keep iterating `eoy_position_report.py`/`eoy_fielding_data.py` AND the notes flow (`pages/14_EOY_Reports.py` + `src/eoy_notes.py`). FIRST on work laptop: `git pull` + redeploy pd-goals app (GUID `79f52369-8244-46da-a4d6-95df956bacad`) `rsconnect deploy manifest .` + confirm `CONNECT_API_KEY` + `LOGIC_APP_URL` in Vars, then 1 real position test send → `#pd-automation-test`. **No re-pin.**
- **Blockers / waiting on:** Everything this session UNVERIFIED vs DB/Connect (personal laptop has neither). P18/19/20/21 header-swap not render-verified (only P13 has a synthetic harness; identical-slot swap into existing `%MLB` width, low risk). Pitcher EOY + ODP still stubbed (Camden).
- **Uncommitted work:** my work all pushed (HEAD==remote `935b7dde`); the ~84 `git status` entries are the pre-existing untracked scratch pile that predates this session.

## ALSO OPEN — R&D heavy-compute inventory (2026-07-28, awaiting R&D reply)

- **Doc SENT:** `pd-goals/docs/plans/2026-07-28-rd-heavy-compute-inventory.md` (HEAD was `3edbb62b`). Cadence corrected org-wide to **every 12h** across all 4 worktrees. `LINEAGE.md` entry written.
- **Findings worth keeping:** `batter_ev_p95` is a 3-app problem (PD Engine never got the fix — `org_kpi_data.py:640`, `eoy_hitting_percentiles.py:47`). Fielding combos heaviest + a live race condition (2 Connect contents RMW one pin). Insight: compliance + trackers + rolling chart + drift = "aggregate one player over a date range" → ONE daily per-player-per-metric fact table.
- **Zac rule:** external/R&D docs must NOT disclose our internal inconsistencies.
- **Next:** waiting on R&D response; optional work-laptop pull of Connect job-history/schedule to turn DOCUMENTED runtimes into MEASURED.
