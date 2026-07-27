# Last session state — 2026-07-27 (Barrelsville hitter_analysis: Swing-by-Count + Zone-Production pages)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-hitting` · branch `feature/barrelsville`
- **What we were doing:** Built two new per-player pages in `barrelsville/scripts/hitter_analysis.py` — "Swing Decisions by Count" (Page A) + "Zone Production Map" (Page B) — with league percentile coloring, iterating on Zac's asks.
- **Shipped this session (feature/barrelsville, HEAD `8fd7edfe`, all pushed; layout+coloring render-verified SYNTHETIC only, UNRUN vs DB):** Page A = ALL/FB/SEC blocks × count buckets 0-0/Ahead/Even/Behind/2-Strk; rows Pitches/Freq%/Swing%/HrtSw%/ZSw%/OSw%/Ctct%/Whiff%; PA%-reached top table; 3-bar Swing% chart. Page B = 3 region tables (ALL/FB/Sec); full-plate bands+quadrants+Heart+In/Out-Zone; cols n/Sw%/Ctct%/HH%/Dmg%/EV/BatSp; Freq% col on FB+Sec only; Swing%/Damage% zone-heat grids; ALL-block In/Out-Zone cells show ours+(canonical ZSw/OSw/ZCon)*. Metric defs mirror `compute_game_stats`. League coloring: shared `_all_cell_values` (player+pool zero drift), `_build_swing_zone_pools` (50 PA gate, pooled across levels, pitch-group-specific, FAIL-SAFE→uncolored). Ranked per exact slice (group×count/region×metric). Gate doc = `percentile-golden-gates.md` (bsb-resources `6d11e2b5`). Freq% (fix `8fd7edfe`) = pitch-type usage by count (FB/Sec = group share of pitches at that count, replaced old FB% row; ALL = count-volume share).
- **EXACT next step:** Zac said "move these 2 pages down" → move the Page A+B render block (`hitter_analysis.py` ~line 4270, currently right after Page 1) to the END of the report — full mode: after ball-flight page; `--no-heatmaps`: after the condensed zone page (keep them showing, that branch `continue`s early). **CONFIRM placement first** (end vs before swing-path). THEN build "Page C" that combines A+B (Zac to describe; my proposals = summary page [zone heat + count bars] OR crossed zone-region×count view).
- **Blockers / waiting on:** WORK-LAPTOP (DB) validation: `cd C:\Users\zbridger\bsb-wt-hitting; git pull; python barrelsville\scripts\hitter_analysis.py --season 2026 --no-heatmaps` → watch `[SWING-ZONE POOLS]` timing (runtime UNKNOWN) + confirm colors on a real hitter. Queued: Whiff%→ZCon%/OCtct% on Page A + canonical ZSw/OSw/ZCon/OCtct reference strip up top. Open decisions: Page C design; positional-vs-evaluative coloring (same red/green now — maybe blue scale for Swing%/Freq%); ALL-block Freq% count-volume vs blank. Rule doc pending `/sync-rules` to bullpen+intangibles.
- **Uncommitted work:** all my work committed+pushed; 63 untracked in worktree are pre-existing, not mine.

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
