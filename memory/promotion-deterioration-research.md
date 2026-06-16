---
name: promotion-deterioration-research
description: wRC+ promotion deterioration & MLB WAR prediction research (barrelsville exploration, started Mar 17 2026)
type: project
---

Two-track research project on barrelsville branch (`scripts/exploration/`):

**Track 1 — Deterioration Profiling:** Score players by how much they deteriorate vs. the baseline at each promotion. Resilience z-score = (player_delta - mean) / std per transition.

**Track 2 — MLB Success Prediction:** Combine wRC+ progression patterns with MLB WAR (from `proj.batting_MLEs`) to predict WAR >= 1.

**Why:** Zac wants to evaluate whether warranted players deserve negative judgment based on performance deterioration, and whether progression profiles predict MLB success. Planning to make this a formal document.

**How to apply:** All findings go into `barrelsville/docs/PROMOTION_DETERIORATION_RESEARCH.md` (living document). Scripts in `barrelsville/scripts/exploration/`. Data source for WAR is `proj.batting_MLEs` (hitters) and `proj.pitching_MLEs` (pitchers). Arjun from R&D provided the table names.

**Key baselines (2021-2025, 50 PA min):**
- Rookie→A: -26.8 mean delta (76.8% decline)
- A→A+: -15.2 (65.6%)
- A+→AA: -15.2 (67.5%)
- AA→AAA: -15.9 (68.9%)
- AAA→MLB: -38.3 (85.8% decline, hardest jump)

**Next steps:** Run check_war_data.py on work laptop to discover WAR table schema, then run war_wrc_combined.py.
