---
name: feedback-raw-obs-compute-minutes-not-seconds
description: "Raw_obs Python pooled compute for fielding multi-level queries takes 1-2 minutes (sometimes more), not 1-2 seconds. The combo precompute layer is load-bearing for production UX, not overkill."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 21bc0474-692b-4cf5-99ef-22ebf56366e7
---

When discussing fielding tracker pooled-percentile paths, NEVER claim
the raw_obs Python compute path (`_compute_pooled_from_raw_obs` +
`_compute_pooled_org_from_raw_obs`) is "1-2 seconds." It's actually
**1-2 minutes, sometimes more** per multi-level/multi-year query.

**Why:** Raw_tdm has ~30k+ rows for fielding per (domain, year);
multi-year ranges concat to 60-150k rows; per-fielder pandas
`groupby` + `np.percentile` across 9 metrics for ~800 fielders +
DCBP re-derivation + per-position pivots is genuinely slow in pandas.
Plus joblib pin download is 5-10 sec on its own.

**Implications:**
1. The combo precompute layer (`POOLED_LEVEL_COMBOS` × 4 year ranges)
   exists because raw_obs compute is too slow for production UX. It is
   NOT "overkill optimization." Coaches would feel the 1-2 min delay
   on every multi-level page change.
2. The DuckDB pilot's value proposition lives or dies on whether
   DuckDB can do those same pooled queries in ~1-3 sec on the
   parquet pins. If DuckDB is 5+ sec, Phase 5 cleanup (deleting the
   combo precompute loop) is NOT safe — combo precompute stays.
3. The parity diag (`diag_pooled_parity.py --all-cases`) will take
   ~12-20 min total because each case runs Path A (raw_obs Python) +
   Path B (live SQL) + Path C (DuckDB) sequentially. Set expectations
   accordingly.

**Why I had it wrong:** I read the code's comment "~1-2 sec" in
`fielding_tracker_data.py::get_org_rankings_pooled` (line ~5093)
which described an optimistic single-level case, not the typical
multi-level/multi-year case the coach hits in production. Always
defer to the user's lived experience over code comments when
performance estimates conflict.

How to apply: when discussing tracker latency / architecture, ask
the user for measured timings before claiming any speedup or
dismissing any optimization layer. If they tell me a number, it's
the canonical number — not my guess from reading code.
