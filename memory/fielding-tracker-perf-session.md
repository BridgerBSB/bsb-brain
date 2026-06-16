---
name: fielding-tracker-perf-session
description: "Fielding tracker multi-level slowness + 404 + slow-pin-build saga (Jun 6-8 2026) — RESOLVED. Combos build on Connect (~132 min) + are scheduled; multi-level is pin-fast. Durable speed architecture + don't-repeat list for porting to catcher/BR."
metadata:
  node_type: memory
  type: project
  originSessionId: 89dad825-b4f8-4d2c-893f-24ef6f0a6068
---

# Fielding Tracker — Multi-Level Speed + Daily-Refresh (RESOLVED Jun 8 2026)

Branch `feature/astros-intangibles` (worktree `bsb-wt-intangibles/astros-intangibles`).
App content GUID `295a5205-…` (ID 663).

## ✅ FINAL STATE — works + scheduled, nothing operational left
- Multi-level fielding (any of the 120 level combos, multi-year) is **fast** — pin-backed
  lookup, no live recompute.
- **Combos build on Connect** via content **909** `intangibles-pin-tracker-2026-fielding-combos`
  (`--year 2026 --combos-only`, ~132 min). Proven: `Done in 7947.6s, Exit code: 0`, both OF+IF
  pins written with combos. **SCHEDULED every 12h** (more often than needed — fielding
  percentiles barely move; harmless extra DB load).
- **Base / single-level / Trends stats** refreshed by content **785**
  `intangibles-pin-tracker-2026-fielding` (`--skip-combos`), which **PRESERVES** the combos.
- Both jobs preserve each other's work → base fresh, combos fresh, no 404, no stale pin.
- Pin health verified: `diag_raw_obs_keys.py` → **HEALTHY | checked=7200 ok=7200 empty=0**.

## KEY CORRECTION — combos DO build on Connect (~132 min). OOM theory was WRONG.
Earlier I concluded "combos OOM / can't build on Connect, must stay a laptop job / split across
2 runs." **Wrong.** Content 909 ran to completion in one shot (7947.6s, exit 0).
**The deploy-render quirk that fooled us:** Connect auto-renders the notebook ONCE at *deploy*
time to validate it; that render got `signal: killed` at ~18 min (`launch-error` / "Unable to
render the deployed content"). But the content still got created (Content ID 909, GUID
735dea48-…) and the actual scheduled / Run-Now execution completed fine.
**Deploy-render-kill ≠ job failure.** When a freshly-deployed Connect notebook shows a
launch-error but the content exists, ignore it and trigger a real run.

## THE SPEED ARCHITECTURE (reusable — port to catcher/BR pooling)
Two decoupled facts make this fast:
1. **`--combos-only` flag** (commit `f9279a1d`): loads the existing pin, rebuilds ONLY the cheap
   raw_obs (`raw_tdm`/`raw_dcbp`/`raw_games`, ~6 min) + recomputes the 120 combos, OVERLAYS them
   onto the existing base slices, writes back. **Skips the 2.3h-per-slice base SQL.** ~132 min
   vs 10-12h.
2. **Vectorized combo compute** (commit `b06dd755`): `_per_fielder_percentile_values` uses one
   `groupby().quantile()` + `.count()` per metric instead of a per-group Python loop (~1,900
   groups × 120 combos). pandas `.quantile()` = same linear interpolation as `np.percentile`,
   both skip NaN → value-identical (parity-proven old-vs-new). Per-combo ~10-40s → sub-second.
   Also speeds **live multi-level app reads** (15-30s → instant on the fallback path).
3. **Quantile dtype guard** (commit `8a6d53d6`): `pd.to_numeric(col, errors="coerce")` before
   `.where()/.quantile()`. Without it an all-NULL/object metric col (OF `exchange`) raises
   `TypeError: dtype 'object' does not support operation 'quantile'`, the combo `try/except`
   swallows it, and an ENTIRE domain's combos come out EMPTY (the OF=3600-empty bug; IF had
   float cols so it survived — clean 50/50 in the diag).

**"The old long one" to AVOID:** a flagless FULL build pays the base SQL — `monthly_fielders`
alone = **8203s (2.3h)** for ONE slice, ×~8 base slices ×3 H/A ×2 domains = 10-12h+ and
TCP-drops on the laptop VPN. **NEVER schedule a flagless full build on Connect.** The base
slices feed Trends + org-rankings and are owned by the 12h skip-combos job (785), NOT the
combos job. Combos depend ONLY on the cheap raw_obs, which is why `--combos-only` is fast.

Diag scripts (`intangibles/scripts/`): `diag_raw_obs_keys.py` (120-combo scan + one-line
VERDICT), `diag_of_empty.py` (per-domain raw + live recompute w/ traceback — surfaced the
TypeError), `diag_pooled_parity.py` (vectorized raw_obs == SQL).

## DON'T REPEAT (failed approaches)
- **DuckDB backend**: broken — org path `KeyError: 'org'`, indiv path leaks (re-reads parquet
  per query, 31s→172s, grows per click). Slower than plain Python. Defaulted OFF (`30ecae68`).
  Don't enable without a rewrite (register parquet as a table ONCE; fix org KeyError).
- **`--common-combos`** (`a1d29f34`): precompute only a "common" subset — WRONG, this user uses
  ~all 120 combos. Harmless/opt-in, not the answer.
- **Scheduled full builds with combos**: brings back the 404 + stale data. Not viable on Connect.
- **Combos-only OOM / split-across-2-runs / laptop-only**: unnecessary — completes on Connect in
  one run. (See KEY CORRECTION.)
- **Chasing the speed SYMPTOM** (DuckDB on/off, fielder_id dtype) instead of diffing the pin
  bundle. The morning-fast bundle had `indiv_pooled_*` keys; the slow one didn't = combos got
  WIPED by an old skip-combos run. LESSON: fast-then-slow → diff the fast artifact vs the slow
  one FIRST.

## Other fixes shipped this saga (feature/astros-intangibles)
- `ec85db09` + `d8396492` — org rankings `int64 vs object` merge crash: coerce fielder_id dtype
  in `_filter_raw_to_scope` + normalize groupby tuple key.
- `e8a0a379` — skip-combos job PRESERVES combos (was wiping them → the "fast then slow" regression).
- `b1e0f61c` — pyarrow added so raw_obs parquet writes.

## Commit chain (newest last)
`b1e0f61c` pyarrow → `30ecae68` duckdb OFF → `e8a0a379` preserve-combos → `a1d29f34`
--common-combos → `b06dd755` **vectorize** → `f9279a1d` **--combos-only** → `8a6d53d6`
**quantile dtype coerce**. Combos notebook bundle `e1a0a626` (`connect_pins_fielding_combos/`).
Rule §9c correction on `feature/pd-goals` `cfd3ebf9`.

## ⚠️ Loose ends (non-blocking)
- **Cross-worktree rule sync**: §9c edits in `tracker-parquet-pins.md` are in `bsb-resources`
  only → run `/sync-rules` to propagate to the other 3 worktrees. Also worth adding the
  "combos-only completes on Connect ~132 min + deploy-render-kill quirk" fact to §9c.
- **Org pooled combos** showed `orgs_pooled … 0 rows` in an earlier log — possible separate
  org-combo precompute bug; org may compute live. Investigate `_compute_pooled_org_from_raw_obs`
  / org branch of `_compute_all_combos_for_year` ONLY if org rankings stay slow.
- **Port vectorize + `--combos-only` + raw_obs pattern to catcher/BR** pooled paths (check for
  the same `_per_*_percentile_values` per-group loop). Capture in `pooled-percentile-pattern.md`.
