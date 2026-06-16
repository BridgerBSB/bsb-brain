---
name: Display-layer dedup for multi-position fielders
description: Players who switch positions mid-game get duplicate play rows from Players_Games. Dedup by highest out_prob in render layer only — data modules keep all rows for PAA/OAA math.
type: feedback
originSessionId: 6e112ece-a6dd-485d-86db-b836478bf5e1
---
When a fielder plays multiple positions in one game, Players_Games has multiple pos_id rows. DCBP assigns out_prob at each position for every event. This creates duplicate display rows.

**Why:** Players_Games JOIN produces one row per pos_id per event. Both have real DCBP data (different out_prob per position).

**How to apply:** Dedup in RENDER layer only (report + app display code), NEVER in data modules. Use groupby rank to preserve sort order:
```python
filtered["_op"] = pd.to_numeric(filtered["out_prob"], errors="coerce").fillna(-1)
filtered["_rank"] = filtered.groupby(["gcid", "sched_id", "event_id"])["_op"].rank(method="first", ascending=False)
filtered = filtered[filtered["_rank"] == 1.0].drop(columns=["_op", "_rank"])
```

**Applied to (8 files):** if/of_postgame_report.py, if/of_weekly_report.py, if/of_postgame_page.py (Streamlit app). NOT in data modules or fielding_base.py.

**Also fixed:** Page overflow was slicing leftover from pre-filter DataFrame. Fixed to slice from post-filter display_df. Combined reports force new page per level.
