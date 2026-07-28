# Last session state — 2026-07-28 00:40 (Barrelsville hitter_analysis: Page A OCtct/Dmg + A/B to pages 4/5, Page C pulled)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-hitting` · branch `feature/barrelsville`
- **What we were doing:** Iterating `barrelsville/scripts/hitter_analysis.py` per-player hitter PDF — Page A metric swap + Dmg%, a prototyped-then-pulled Page C, and relocating Pages A/B to positions 4/5.
- **Shipped this session (HEAD `34840730`, all pushed; layout render-verified SYNTHETIC only, UNRUN vs DB):**
  - **Page A**: dropped Whiff%, added **ZCon%/OCtct%** (geometric zone-split contact) with **canonical CSC-weighted parens in the ALL block only** (`geo (canon)*`, same pattern+footnote as Page B) — `bd0f8f73`. Directions per `compute_game_stats`: ZCon% higher=better, OCtct% lower=better. Added **Dmg% row** per count bucket (`3e6256ae`); refit table (scale_y 1.1→0.9, font 6.3→5.8) for 34 rows.
  - **Page C prototyped in 2 designs then PULLED**: v1 region×count single-metric bat speed (`50da3d79`), v2 "Production by Count" broad-metrics × count × 3 group blocks (`3628721a`). Zac saw v2 = structurally identical to Page A (region was the only distinguisher), so pulled entirely (`17d712d1`). Recoverable from those 2 hashes; in-code recovery note in `_render_swing_zone_pages` docstring.
  - **Pages A/B moved to pages 4/5** (right after EV/Whiff Page 3), NOT the end where I first wrongly put them (`34840730`). Full order: 1 Results, 2 AA/LA, 3 EV/Whiff, **4 Page A, 5 Page B**, 6+ Swing/Contact, Swing Path, Ball-Flight last. `--no-heatmaps`: Results/condensed/A/B.
- **EXACT next step:** WORK-LAPTOP DB validation (only remaining action): `cd C:\Users\zbridger\bsb-wt-hitting; git pull; python barrelsville\scripts\hitter_analysis.py --season 2026 --no-heatmaps` → confirm page order (A=4/B=5), real league colors on a live hitter, watch `[SWING-ZONE POOLS]` timing (unknown runtime). Zac: "this PDF isn't really ever finished — I edit it for analysis" → living doc, expect more ad-hoc edits.
- **Blockers / waiting on:** work-laptop run pending. Still-open Page A choices Zac may revisit: parens on FB/SEC blocks (currently ALL-only), keep overall Ctct% on Page A. Page C parked ("different routes later"; most-distinct option = FB region×count).
- **Uncommitted work:** all my work committed+pushed; 63 untracked/modified in worktree are pre-existing (mostly `.claude/rules/*`), NOT mine — only `hitter_analysis.py` touched.

---

## ALSO OPEN — EOY P20 throwing density + P21 base-running (bsb-resources/feature/pd-goals, from 2026-07-27, preserved)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` · branch `feature/pd-goals`
- **What we were doing:** Reworking the EOY position report's P20 (catcher throwing) and P21 (base running) pages from Zac's chat feedback, then he /wrapped saying "decently hefty changes to make to the report" come next.
- **Shipped (4 commits, `9ac5c677` → `27787d09`, pushed, render-verified synthetic, UNRUN vs DB):** P20 Throwing → DENSITY (throw-arrival 2D KDE white→navy + throw dots; AugPop/Pop stay in table). P21 Base Running (SB count graded w/ %Hi chip + `_sb_count_pool_list` BR 30-on-base gate; per-base lead-distribution panels PL vs LHP orange/RHP blue + dashed league-avg via `_LEAD_PL_BY_HAND_QUERY`). Footnote overflow fixed (`878d394c`); P21 TL label level (`27787d09`). Zac: "looks fantastic."
- **EXACT next step:** ASK Zac for the "decently hefty" EOY report changes he wants. Also open: offer to flip P20 density to `contourf`. Work laptop: `python pd-goals/scripts/generate_eoy_position.py --gcid <base-stealer> --season 2026` (P21) + `--gcid 218498` (P20); metric-audit new SB-count %ile + by-hand PL leads vs intangibles BR tracker.
- **Blockers:** all synthetic — live verify work-laptop-only. Dead code: `_LEAD_SAMPLES_QUERY` (eoy_br_data.py:122) — delete next cleanup.

## ALSO OPEN — Opportunities bot: golden gates + bat-speed P90 (bsb-resources/feature/pd-goals, from 2026-07-26, preserved)

- **What:** Hardened opportunities/goals bot — pitcher HB anchors, percentile golden gates (`percentile-golden-gates.md` ×4 worktrees + `/percentile` skill), `run_opportunities.ps1` `-PitcherGcids`/`-PitcherGcidFile`, bat-speed ceiling `max_bs`→`bs_p90` (P90). Production apps unaffected.
- **EXACT next step:** Work laptop `git pull` (bullpen + hitting + bsb-resources) → `powershell -ExecutionPolicy Bypass -File opportunities\run_opportunities.ps1 -Season 2026 -PitcherGcidFile .\opportunities\pitcher_gcids.txt` for CORRECTED `bs_p90` values (prior output had the stale 332 glitch), then Zac updates goals CSV.
- **Blockers:** work-laptop-UNRUN vs DB. Open: quadrant-NetK 300-vs-500 gate, per-PT pitcher shape gate 30-vs-300 units, Lucas Spence dropped from ranked output.

## ALSO OPEN — EOY IF/OF/C fielding tools (bsb-resources/feature/pd-goals, from 2026-07-21, preserved)

- **What:** P13 "Fielding Season Review" shipped; P18-P21 catching/BR pages now also built this cycle. IF/OF/Catcher 1-2-page detail tools still to design.
- **EXACT next step:** **ASK Zac for his 1-2-page-per-tool concept for IF/OF/Catcher FIRST, then mock** (his words). Resolve PARKED: multi-position-family player → pages per family, cloned block, or primary only?
