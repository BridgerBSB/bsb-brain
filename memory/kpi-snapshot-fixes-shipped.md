---
name: kpi-snapshot-fixes-shipped
description: SHIPPED May 22-24 2026 — 10 user fixes (c4c27aba) + eligibility fix (5ade27a7). KPI snapshot PDFs Catcher/BR/OF/IF. NEEDS USER VERIFICATION on next run.
metadata: 
  node_type: memory
  type: project
  originSessionId: ca41c98c-a631-46fa-9e29-eaacefc4d9fc
---

# KPI Snapshot Fixes — SHIPPED May 22-24 2026

Commits on `feature/astros-intangibles` (all pushed):
- **`c4c27aba`** — 10 user-voice-transcript fixes (May 22)
- **`5ade27a7`** — eligibility = Players_Games (May 24, Bush 1B fix)

## What got fixed (10 items from user voice transcript)

| # | Fix | File(s) |
|---|---|---|
| 1+2 | Prior-year (YoY) rows now percentile-colored against THEIR year's level pool, not just trend arrows. PAA/EO + RAA/EO key mismatch fixed (was reading `paa_eo` but source emits `paa_eo_dist`). `raa_eo_dist` added to OF + IF percentile modules. | snapshot_report.py, of_postgame_percentiles.py, if_postgame_percentiles.py |
| 3 | Verified during investigation — pool already whole-level (30 orgs), no HOU filter. No change. | — |
| 4 | MLB-only players excluded from snapshot (if `_levels == {"mlb"}` only, skip). Multi-level mlb+MiLB stays. | generate_kpi_snapshot.py |
| 5+8 | BR: SB column now percentile-colored (hib=True against per-runner SB pool). CS pctile added (hib=False). ft3%/s2h%/sb_pct pools no longer empty. | br_percentiles.py, snapshot_report.py |
| 6+7 | Catcher: NEW "NetK" col (Total NetK cumulative SUM) BEFORE existing "NetK/P" col. NetK/P now derived in Python as total_netk/n_pitches on canonical edge-zone pool (CSC 0.05-0.95). Was null. | snapshot_data.py, snapshot_report.py, catcher_percentiles.py |
| 9 | Catcher: AugPop2B column added directly after Pop2B (P01 percentile on aug_pop_time, ≥3 throws gate). | snapshot_data.py, snapshot_report.py, catcher_percentiles.py |
| 10 | Verified — per-player SQL already pools raw obs across all levels via PARTITION BY gcid. No change. | — |

## Files touched (7)

- `intangibles/src/snapshot_data.py` — Catcher metric config + NetK/P derivation + AugPop2B SQL.
- `intangibles/src/snapshot_report.py` — Coloring loop removes `_skip_pctile` early-exit, pctile cache includes YoY years, year parser handles "R 25"/"ST 26", C_COL_SPECS gains NetK + AugPop2B, BR SB gets pctile_key, OF/IF/C/BR mapping rewrites.
- `intangibles/src/catcher_percentiles.py` — `_NETK_SEASON_DIST_QUERY`, `_CS_PCT_DIST_QUERY` added; result dict gains `netk_season_total`, `netk_per_pitch`, `cs_pct`.
- `intangibles/src/of_postgame_percentiles.py` — `raa_eo` added to `_VALUE_DIST_QUERY`, `raa_eo_dist` added to result.
- `intangibles/src/if_postgame_percentiles.py` — same as OF.
- `intangibles/src/br_percentiles.py` — `_BR_COUNTS_DIST_QUERY` (per-runner sb/cs/sb_pct/ft3_pct/s2h_pct, ≥10 TimesOn gate). Result dict gains 5 new keys.
- `intangibles/scripts/generate_kpi_snapshot.py` — MLB-only player skip.

## What to verify next session

1. **Pull on work laptop**: `git pull` in `bsb-wt-intangibles/astros-intangibles`.
2. **Run a snapshot**: `python intangibles/scripts/generate_kpi_snapshot.py --position all --season 2026 --yoy`
3. **Eyeball the output PDFs**:
   - Catcher: NetK col before NetK/P; NetK/P populated (not null); AugPop2B after Pop2B; CS% colored; SB count colored.
   - BR: SB / CS / SB% / 1-3% / 2-H% all colored.
   - OF/IF: PAA/EO + RAA/EO colored on BOTH years (R 26 + R 25 rows).
   - All 4: MLB-only players (e.g., bench callups) no longer appear.
4. **Expect**: smaller dists for fresh 2026 pools — distributions log lines should show `>0 values` for cs_pct, sb_pct, etc. If empty, the gate threshold (e.g., ≥5 SBA, ≥10 TimesOn) may need lowering for early 2026 data.

## Eligibility fix (May 24, commit `5ade27a7`)

User flagged: "Bush is not on IF which is an issue because he plays
1B a lot." Root cause: `build_player_list` filtered by
`roster["position_category"].isin(("INF",))`. Bush's position_category
is "C" (primary catcher), so he was excluded from IF snapshot despite
his 1B time.

**NEW**: `build_player_list` queries `Astros.Players_Games` for HOU
gc_ids that actually appeared at any target pos_id during `season`
at `level_filter` (or cross-level if None). Falls back to
position_category if `season=None` (legacy callers).

- `_POS_IDS["IF"] = (3,4,5,6)` → 1B/2B/3B/SS appearances qualify
- `_POS_IDS["OF"] = (7,8,9)` → LF/CF/RF
- `_POS_IDS["C"] = (2,)` → C

A player can appear in multiple snapshots (Bush in BOTH C and IF).
BR unchanged (all hitters). MLB-only exclusion (CLI downstream)
unchanged. Min 1 game; no eligibility-layer min gate per user spec
"everyone that has played."

Files: `intangibles/src/snapshot_data.py` (helper +
`build_player_list` signature gains `season` + `sched_types`),
`intangibles/scripts/generate_kpi_snapshot.py` (passes args through).

Same eligibility pattern shipped same day for PAA/EO direction PDF
(commit `4312d31a` — see `paa-eo-direction-status.md`).

---

## Known caveats

- **AugPop2B**: gates on `≥3 throws` (matches Pop2B); pool gates min ≥10 from base percentile loader. Early-season may have insufficient data; falls back to prior year per `get_catcher_percentiles` logic.
- **SB / CS percentile coloring**: counts have a "U-shape" — players with 0 SBAs vs 50 SBAs both extremes. Coloring against the all-runner pool will paint low-attempt runners blue/grey. May want to gate or use rate-based coloring instead in v2.
- **CS column (BR)** uses `hib=False` (more CS = bad). User said "stolen bases and times stolen" — interpreted as SB+CS coloring both. If they meant something else (e.g., "stolen attempts" = SBA), revisit.
- **CS% in BR**: not in BR config (BR has SB% which is the inverse). Catcher has CS%. The user "Cost selling percentage as well" referred to Catcher CS% — already in catcher config + now has pool.

## What NOT to touch

- Per-player SQL aggregation pattern (PARTITION BY gcid pooling raw obs across all levels) — already canonical per `multi-level-rollup.md` Iron Rule. Don't refactor to weighted-mean per-level pattern.
- Pool queries — they already use `level_filter` only (no HOU). Don't add HOU filter.

## Cross-references

- `.claude/rules/multi-level-rollup.md` — Iron Rule + canonical pooling.
- `.claude/rules/three-surface-parity.md` — different concern (snapshot is its own surface, not in the 3-surface family).
