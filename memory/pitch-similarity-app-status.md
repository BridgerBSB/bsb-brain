---
name: pitch-similarity-app-status
description: "Pitch Similarity Finder — Arm Farm page 6 (DJ Engle ask), BUILT + COMMITTED, untested on DB"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9e45fff1-5504-461b-8a06-60a740d0c26c
---

**Pitch Similarity Finder** — a PAGE/CARD inside **Arm Farm**, NOT a standalone app. Generalizes the Jagger Beck FF/FT shape-comp query (`sql-queries/jagger-beck-fastball-shape-comps-mlb.sql`) into a coach-driven tool. Pitching-coordinator ask (DJ Engle): "find similar fastball shapes," then broadened to any pitch + configurable sample.

**ARCHITECTURE CORRECTION (Jun 20 2026):** First built standalone in `pitch-similarity/` on `feature/pd-goals` — WRONG. Zac always wanted it as "a square tab in Arm Farm just like Pitcher Postgame / Advance" (the jagger SQL comment literally said "seed for an Arm Farm app tab… lives in bsb-wt-bullpen"). Ported into Arm Farm and DELETED the standalone (commit `f6ce4f11` on feature/pd-goals removed `pitch-similarity/`). **Lesson saved as feedback memory.**

**Location now:** Arm Farm worktree `C:\Users\Owner\bsb-wt-bullpen`, branch `feature/bullpen-reports`, dir `bullpen-report/`. Commit `3f59bbd8`.
- `pages/6_Pitch_Similarity.py` — the page (anchor card + pool/match-on panels + progress bar + ranked table + CSV). Roster via `src.roster.get_roster(player_type='P')`.
- `src/pitch_similarity.py` — engine (`get_pitch_types` / `get_anchor_shapes` / `get_candidate_pool` / `rank_similar`). Reuses Arm Farm's `src/database.run_query`. Level helpers inlined — multi-level, dsl/rok via gc2_level_code.

**Expanded Jun 20 2026 (commit `9dc29133`) per Zac feedback:**
- **10 match-on metrics** (was 4): velo `release_speed`, ivb `inducedvertbreak`, hb `horzbreak`, spin `spin_rate`, eff `spin_eff` (stored 0-1 → surfaced ×100 as %), ext `extension`, vaa `vert_appr_angle`, haa `horz_appr_angle`, rel_h `release_z`, rel_s `release_x`. ALL direct `Astros.Pitches_View` columns (verified vs Arm Farm postgame/bullpen — VAA/HAA are NOT trajectory-math; they're stored). `release_x`/`horzbreak` raw (Arm Farm negates for catcher view); matching sign-consistent.
- **Multi-pitch-type "combination"** (Jagger Section 3): pitch type is now a MULTISELECT. Pick 2+ → candidate qualifies only if EVERY selected pitch type is present AND within tol on every selected metric; ranked by total normalized distance across all (type×metric). Results table widens per-type when 2+; single type stays clean. Anchor shown as a per-pitch-type shape table.
- **Arm Angle = 11th metric, SHIPPED Jun 21 2026 (commit `235f5af5`).** NOT a Pitches_View column — Brodie release-geometry formula (`_ARM_ANGLE_EXPR`, verbatim from `postgame_data.py` per db-columns.md) + data-cleaning.md step-1 `>90°` cap inline (step-2 2.5σ deferred). Perf-safe: heavy HawkEye joins (`pitch_hit_trajectories`/`play_starting_positions`/`mlbam.players`) added to the candidate pool ONLY when arm is selected (`include_arm` param); anchor always computes it. NULL where untracked → dropped if matched on arm.

**v2 ROADMAP + side experiment (Jun 21 2026, commit `16e35e44`) — documented + exploratory, NOT wired into the live app (Zac: keep the working app, explore on the side):**
- `bullpen-report/docs/PITCH_SIMILARITY_ROADMAP.md` — v2 (similarity % 0-100 + population z-score normalization, decouple tolerance-as-gate from distance-scaler), v2.1 (Bauer units spin/velo, spin axis/tilt), v3 (Mahalanobis covariance-aware, era normalization, arsenal usage weighting), + engineering robustness (pin pools to parquet, surface exclusions, low-sample flag, shareable URL). Methodology grounded in research: tjStats, Model 284, Baseball Analytica, FanGraphs Pitch Arsenal Scores, Savant — all do normalize-then-Euclidean-NN (confirms our baseline is the standard).
- `bullpen-report/scripts/explore_pitch_similarity_v2.py` — sandbox: reuses live engine for DATA ONLY, prototypes z-score / z-score-within-season (era) / Mahalanobis / Bauer / similarity% and prints each ranking next to the LIVE method on the same pool. Requires DB (work laptop). NOT in manifest → never deploys. Run: `python scripts/explore_pitch_similarity_v2.py --gc-id 269548 --season 2026 --pitch-types FF FT --levels mlb`.

**v2 SHIPPED Jun 21 2026 (commit `b2337a95`) — z-score "Similarity %" as an OPT-IN mode (working app preserved):**
- Page has a **"Scoring" toggle**: default "Tolerance bands" = original behavior UNCHANGED; "Similarity %" = z-score mode.
- Decisions (Zac, asked + confirmed): **pure ranking** (no hard gate — every pitcher scored, top-N control) + **z-score basis = the selected pool, per pitch type**.
- `rank_similar_zscore` (engine): standardize each metric by pool σ per pitch type → z-space Euclidean → `sim% = 100·exp(−dist/√n_dims)` (run-independent: 100%=identical, ~37%≈1 SD off avg). Surfaced as "Sim%" column. Still requires all selected pitch types present; carries arm + all 11 metrics. ± tolerance inputs only render in tolerance mode; Top-N only in z-mode.
- Validate in-app on work laptop by flipping the toggle (no separate script needed). Sim% k = √n_dims is the tunable knob if % spread feels off.
- Roadmap doc updated: v2 marked SHIPPED; v2.1 (Bauer/tilt) + v3 (Mahalanobis/era-norm/arsenal usage weighting) + robustness still pending.

**Visual polish SHIPPED Jun 22 2026 (commit `084336e8`):** "Arm"→"Arm Angle" rename; results table = Rank # + player HEADSHOTS (mlbam_id carried through pool query + rank fns → `get_player_photo_url` + `st.column_config.ImageColumn`) + green→red gradient on score (Sim% in z-mode, Dist in tolerance mode) + Dist hidden in z-mode; **movement plot** `_movement_fig` (IVB×HB, pitcher's view x=−hb, navy-star anchor + orange rank-numbered comps, pitch-type selector + comp multiselect). Render-and-look'd (PNG, clean). UNTESTED on live DB.

**UI iteration Jun 22 2026 (commit `7c902ad9`):** (1) Decimals — one dp on every metric + Δ + Sim%/Dist/WAR, spin = 0 dp, season no comma (Styler.format display-only, values stay numeric for gradient). (2) Movement view replaced the single overlay scatter with a **per-pitcher movement-profile picker** (like the old daily tracker): select a comp (or anchor) → his per-pitch dots + 2σ ellipse per pitch type, anchor's ellipses overlaid dashed-navy, arm angle shown alongside (from the pin). New `get_pitcher_movement(gc_id,season,levels)` (on-demand, cached) + `_cov_ellipse`/`_movement_profile_fig` (pitcher's view x=−hb, Arm Farm pitch colors). Used a SINGLE selector not per-row expanders (Streamlit renders all expander bodies → 25 plots slow; matches daily-tracker pattern). Render-and-look'd.

**ARM ANGLE PERF — the 3-min cold load (Bryce Mayer test, Arm checked):** root cause = arm angle is computed live from raw HawkEye tracking (`pitch_hit_trajectories`/`play_starting_positions`/`mlbam.players`) across the whole MLB pool × 9 yrs. Cached 30 min after first run; uncheck Arm or narrow years = fast. Infra audit (Explore agent, Jun 22): arm angle IS already precomputed **per-pitcher-season** as `avg_arm_angle` in the Arm Farm tracker pin (`zbridger/arm_farm_tracker_{year}`, `pitchers_*` prefix) — but coverage is likely OUR pitchers, not the league-wide comp pool, and there is **NO daily auto-refresh** (pins are seasonal/manual; `run_daily.ps1` does postgames not pins). Template reused. **FIX SHIPPED Jun 22 2026 (commit `1c6f66ac`) — dedicated daily arm-angle pin (Zac picked this):**
- `pins_config.py`: `ARM_ANGLE_PIN_FMT` / `arm_angle_pin_name(year)` → `zbridger/arm_farm_arm_angle_{year}` (per-season joblib pin, one row per pitcher: gc_id, season, arm, n_arm).
- `pitch_similarity._load_arm_pin` + pin-first logic in `get_candidate_pool`: when Arm selected AND pin exists, SKIP heavy live tracking joins + merge arm by (gc_id, season); else live fallback (graceful None when no board → app keeps working until pin lands). Arm ≈ release-slot property, one per-(gc_id,season) value applies to all his rows.
- `scripts/pin_arm_angle.py`: CLI, league-wide per-pitcher avg arm angle per season (Brodie formula, >90 cap, joblib pin). Heavy scan runs OFFLINE. Default years 2018-2026.
- `connect_pins_arm_angle/` deploy bundle (notebook + deploy.ps1 + .gitignore), mirrors `connect_pins/`. Schedule ~2am in Connect UI.
- **WORK-LAPTOP STEPS (untested on DB/Connect):** (1) `$env:CONNECT_API_KEY=...` then `python scripts/pin_arm_angle.py` (pins all years 2018-2026 once — slow). (2) `.\connect_pins_arm_angle\deploy.ps1` to deploy the notebook. (3) In Connect UI: set Vars (CONNECT_API_KEY, DB_USER, DB_PASS) + schedule daily ~2am. (4) Redeploy Arm Farm so the app reads the pin. After that, "Similarity %" with Arm checked is instant.
- `Arm_Farm.py` — 6th nav-card "PITCH SIMILARITY" tagged `[ NEW ]` (arcade landing, `href="Pitch_Similarity"`).
- `manifest.json` — both new files registered for deploy.
py_compile clean; level predicate + ranking verified on synthetic data. Naming: Zac chose "Pitch Similarity Finder" (rejected "Pitch Twins").

**How it works (v1):** pick a HOU-roster pitcher + anchor season + one of his tracked pitch types → define pool (levels MLB→DSL, year range 2018-2026, role any/starter/reliever, min IP per level/season, min career MLB WAR, same-hand toggle, min pitches) → check which characteristics to match (velo=`release_speed`, IVB=`inducedvertbreak`, HB=`horzbreak`, spin=`spin_rate`) each with its own ± tolerance → candidate must be within ± on EVERY selected metric (AND) → ranked by normalized distance (each metric / its tolerance). One row per pitcher-season-level. CSV export. Pool query cached (`@st.cache_data`) so changing tolerances re-filters in Python without re-querying.

**Gates grounded + VERIFIED against canonical refs (Jun 20 2026, commit `59975d14`):** Read `sql-queries/jagger-beck-fastball-shape-comps-mlb.sql` (the anchor/shape pattern) + `sql-queries/mlb-sp-2plus-war-aball-ff-2seam-usage.sql` (the WAR+IP+role pool pattern) to validate the two memory-grounded gates.
- **WAR gate** (`Proj.Pitching_MLEs`, `bat_side='-' AND role='--'`, MLB team_ids only = pure MLB WAR) is byte-identical to the canonical `war_career` CTE — CORRECT, no change.
- **IP/role gate FIX:** my `ytd_gate` CTE was MISSING `team_id <> 0`. `mlbam.ytd_player_pitching_stats` carries a per-player total row (`team_id=0`) the `GROUP BY (player,season,level)` would sum alongside per-team rows → ~DOUBLES outs/gs, corrupts the IP + role gates. Added `yg.team_id <> 0` to match canonical `mlb_sp` CTE. (This was the "may not bind" open item below — now resolved.)
- ytd `level` casing CONFIRMED lowercase matching `sv.level_code` ('mlb','afx') in both refs → `yt.level = sv.level_code` join is right for regular levels (DSL/rok edge case still unverified, but WAR/role-gated DSL pitcher is an implausible query).
- roster via `MLB_eBis.PP_MASTER` ORG_LK='hou' pitcher POSITION_LK set.

**NOT done / open:**
- UNTESTED on live DB (personal laptop = no DB). Work-laptop, in the ARM FARM worktree: `cd C:\Users\zbridger\bsb-wt-bullpen` (or wherever Arm Farm is checked out) → `git pull` (feature/bullpen-reports) → `cd bullpen-report` → `streamlit run Arm_Farm.py`, click the new PITCH SIMILARITY card → smoke test. Then redeploy Arm Farm via `rsconnect deploy manifest .` (Arm Farm GUID `13482bcb-...`). DB_USER/DB_PASS Vars already set on that content.
- HB + Rel S sign: raw `horzbreak`/`release_x`; Arm Farm card negates for catcher view, so displayed sign may differ. Matching is sign-consistent.
- Tracking-derived metrics (eff/vaa/haa/ext/rel_h/rel_s + ivb/hb) are sparse at non-HawkEye MiLB venues — a candidate with NULL on a matched metric is dropped. Fine for default MLB pool; widen tolerances or pool if MiLB matches come back thin.
- First-run watch: if the pool is empty with an IP/role filter on, suspect `yt.level` casing for that level.
- Future (Zac, Jun 20 2026 — confirmed "exactly what was asked," keep it simple for now, expand "in the near future"): a **similarity %** / **similarity score** column (e.g. convert `similarity_dist` → a 0-100% match score) so coaches read "92% similar" instead of a raw normalized distance. Likely a normalization of the distance per metric/overall.
- Future: performance metrics (coordinator wants pitch-characteristics-only for now), modeling backend, save/share a query.

Related: [[player-development-dual-track]], [[connect-offload-migration]], [[feedback_confirm_integration_target_before_building]].
