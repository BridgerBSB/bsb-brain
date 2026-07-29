# Last session state — 2026-07-29 10:20 (EOY position report + coordinator-notes app)

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
