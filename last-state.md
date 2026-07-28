# Last session state — 2026-07-28 11:45 (R&D heavy-compute inventory — SENT, awaiting reply)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` · branch `feature/pd-goals`
- **What we were doing:** Compiling a complete, ranked inventory of every pinned / precomputed / cached heavy computation across all 4 worktrees, as a document to send Astros R&D for the Connect-offload effort. **Doc is finished and sent. Zac is pivoting to a new project.**
- **Shipped this session (all pushed, HEAD `3edbb62b`):**
  - **`pd-goals/docs/plans/2026-07-28-rd-heavy-compute-inventory.md`** — `13e4f06b` → `70560e66` → `05118aca`; `8161cccd` added a "Who owns what" section, **`3edbb62b` reverted it** (Zac didn't like it). Built from a 4-agent parallel worktree sweep; ~978K subagent tokens stayed out of main context.
  - **Cadence corrected org-wide, ~12 sites, all 4 worktrees** (`ff4922e7` + `0438efa1` bullpen / `eb6efd07` hitting / `db2b5ccb` intangibles). ALL Connect pin jobs run **every 12 h (twice daily)**, not 6h — trackers, fielding combos, compliance, Defense Matrix. Rules synced, 0 checksum mismatches, HEAD==remote on all 4.
  - **`LINEAGE.md`** entry for the invalidated 6h claim + the superseded June preface §2 diagnosis.
- **Findings worth keeping:** `batter_ev_p95` is a **3-app** problem — Barrelsville has 10 heavy-CTE call sites left, **PD Engine never got the fix at all** (`org_kpi_data.py:640`, `eoy_hitting_percentiles.py:47`). Fielding combos = heaviest job (3,600 DataFrames/domain-year, ~132 min daily, but pure-pandas → CPU on a viz server; real DB cost is the 8 base slices, `monthly_fielders` MEASURED at 8,203 s). Fielding job carries a **live race condition** (two Connect contents read-modify-writing one pin). **Big insight:** compliance + trackers + rolling chart + drift report are all "aggregate one player over an arbitrary date range" → **ONE daily per-player per-metric fact table** serves all four; leads the suggested sequence at #4.
- **Zac editorial rule for any external/R&D doc:** do NOT disclose our internal inconsistencies — that's a "me thing." Cut the 25-vs-50-PA gate mismatch, "three other modules rebuild separately", the DuckDB dead-code confession, "Open items on our side", and "one definition, four implementations" (→ "no shared home today").
- **EXACT next step:** **Ask Zac what the new project is**, then `/load-rules <domain>` for whatever it touches. Do NOT carry the pd-goals / tracker-pin / PRP rule context forward — it auto-injected from file paths and is dead weight on a different domain. R&D doc needs nothing further unless they reply.
- **Blockers / waiting on:** R&D response to the inventory. Optional work-laptop item: pull the Connect job-history + schedule table per content item — every runtime is still tagged DOCUMENTED (script headers) rather than MEASURED, and row counts/sizes are UNKNOWN.
- **Uncommitted work:** all session work committed + pushed on all 4 worktrees. Pre-existing untracked/modified files in the worktrees are NOT mine.

---

## ALSO OPEN — Barrelsville hitter_analysis Page A/B (bsb-wt-hitting/feature/barrelsville, from 2026-07-28 00:40, preserved)

- **What:** Per-player hitter PDF (`barrelsville/scripts/hitter_analysis.py`). Page A dropped Whiff% → added ZCon%/OCtct% (canonical CSC-weighted parens in ALL block only) + Dmg% row (`bd0f8f73`, `3e6256ae`). Page C prototyped twice (`50da3d79`, `3628721a`) then **pulled** (`17d712d1`) — structurally identical to Page A once region was dropped. Pages A/B moved to positions 4/5 (`34840730`). HEAD `34840730`, pushed, synthetic-render-verified, UNRUN vs DB.
- **EXACT next step:** work-laptop DB validation — `cd C:\Users\zbridger\bsb-wt-hitting; git pull; python barrelsville\scripts\hitter_analysis.py --season 2026 --no-heatmaps` → confirm page order (A=4/B=5), real league colors on a live hitter, watch `[SWING-ZONE POOLS]` timing.
- **Zac to remember:** "this PDF isn't really ever finished — I edit it for analysis." Living doc, expect more ad-hoc edits. Page C parked ("different routes later"; most-distinct option = FB region×count).

## ALSO OPEN — EOY P20 throwing density + P21 base-running (bsb-resources/feature/pd-goals, from 2026-07-27, preserved)

- **Shipped (4 commits, `9ac5c677` → `27787d09`, pushed, synthetic, UNRUN vs DB):** P20 Throwing → DENSITY (throw-arrival 2D KDE white→navy). P21 Base Running (SB count graded w/ %Hi chip + BR 30-on-base gate; per-base lead panels PL vs LHP/RHP + dashed league-avg). Zac: "looks fantastic."
- **EXACT next step:** ASK Zac for the "decently hefty" EOY report changes he mentioned. Also open: offer to flip P20 density to `contourf`. Work laptop: `python pd-goals/scripts/generate_eoy_position.py --gcid <base-stealer> --season 2026` (P21) + `--gcid 218498` (P20).
- **Dead code:** `_LEAD_SAMPLES_QUERY` (`eoy_br_data.py:122`) — delete next cleanup.
- **Note:** a separate EOY in-app-submission spec landed this session as `4582ee2b` (not from this thread).

## ALSO OPEN — Opportunities bot: golden gates + bat-speed P90 (bsb-resources/feature/pd-goals, from 2026-07-26, preserved)

- **What:** Pitcher HB anchors, percentile golden gates (`percentile-golden-gates.md` ×4 worktrees + `/percentile` skill), `run_opportunities.ps1` `-PitcherGcids`/`-PitcherGcidFile`, bat-speed ceiling `max_bs`→`bs_p90`.
- **EXACT next step:** work laptop `git pull` (bullpen + hitting + bsb-resources) → `powershell -ExecutionPolicy Bypass -File opportunities\run_opportunities.ps1 -Season 2026 -PitcherGcidFile .\opportunities\pitcher_gcids.txt` for corrected `bs_p90` values, then Zac updates goals CSV.
- **Open:** quadrant-NetK 300-vs-500 gate, per-PT pitcher shape gate 30-vs-300 units, Lucas Spence dropped from ranked output.

## ALSO OPEN — EOY IF/OF/C fielding tools (bsb-resources/feature/pd-goals, from 2026-07-21, preserved)

- **What:** P13 "Fielding Season Review" shipped; P18-P21 catching/BR pages built. IF/OF/Catcher 1-2-page detail tools still to design.
- **EXACT next step:** **ASK Zac for his 1-2-page-per-tool concept for IF/OF/Catcher FIRST, then mock** (his words). Resolve PARKED: multi-position-family player → pages per family, cloned block, or primary only?
