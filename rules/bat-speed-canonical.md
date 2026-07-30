---
paths:
  - "**/src/*.py"
  - "**/scripts/*.py"
---
# Bat Speed at Contact — Canonical Cleaning (BLOCKING)

ONE filter. ONE helper. Every surface that aggregates per-batter bat
speed routes through it. If you write a new computation that doesn't
call `clean_bat_speed_per_player`, you are reintroducing the May 2026
bug class.

---

## The canonical rule (memorize this)

```
Pool = every event with a swing_contact_values row
       (BIP + fouls + foul tips + WHIFFS — bat speed at contact is
       tracked even on whiffs because HawkEye measures bat velocity
       at the contact-zone frame regardless of whether the ball was
       struck)

Per batter:
    Always: drop anything below 57 mph
            (catches bunts, check swings, tracking glitches —
             bunts physically cannot exceed 57 mph in a competitive swing)
    Conditional: if the batter has >= 20 swings in the pool,
                 also drop the bottom 10% (per-batter p10).
                 p10 is computed on RAW (pre-floor) speeds.
    No upper cap. At-contact distribution self-bounds.
    No +-2.5 sigma trim. Trims legitimate elite swings on small samples.
    No post-clean minimum count. Even one surviving swing publishes.

Cleaning NULLs the bat_speed_mph cell in place. Other columns
untouched. Downstream consumers compute mean() on the cleaned column.
```

---

## The canonical helper

`clean_bat_speed_per_player(df, batter_id_col="batter_id", bs_col="bat_speed_mph")`

Lives in TWO byte-identical copies:

| Worktree | Path |
|---|---|
| Barrelsville (`feature/barrelsville`) | `barrelsville/src/bat_speed_clean.py` |
| PD Goals (`feature/pd-goals`) | `pd-goals/src/bat_speed_clean.py` |

If the canonical changes, BOTH copies + this rule must update in lockstep.

---

## Surface map (all 8 routes through the helper as of May 2026)

### Barrelsville (6 surfaces)

| File | Function | Use |
|---|---|---|
| `tracker_data.py` | `_compute_batter_bat_speeds` | Affiliate Tracker per-batter |
| `tracker_data.py` | `_compute_bat_speed_per_org` | Affiliate Tracker org rankings |
| `hitter_kpi_data.py` | `_compute_bat_speed_per_batter` | Hitter KPI weekly Season + L2W |
| `weekly_hitter_data.py` | `_filter_bat_speed` | Weekly Hitter Player Report |
| `postgame_data.py` | `_enrich_pitches` (per-pitch column) + `_compute_summary_stats` (avg) | Postgame Report |
| `postgame_percentiles.py` | `_compute_bs_distribution` | Postgame percentile pool (with min 50 swings POOL inclusion gate, separate from per-batter publish) |

### PD Goals (4 surfaces)

| File | Function | Use |
|---|---|---|
| `stats.py` | bar chart `bat_speed_query` + Python | PD Goals app daily bar chart |
| `org_kpi_data.py` | `_compute_bat_speed_per_org` | PD Goals org KPI report |
| `percentiles.py` | `_get_bat_speed_distribution` | PD Goals percentile pool (with min 50 swings POOL inclusion gate) |
| `drift_hitting.py` | `_clean_bat_speed_avg` | PD Flag Tracker drift detection |

### Standalone scripts (deferred — not user-facing daily)

| File | Status |
|---|---|
| `barrelsville/scripts/generate_bat_speed_draft_class.py` | Has its own `_filter_bat_speed`. Update in follow-up. |
| `barrelsville/scripts/generate_bat_speed_report.py` | Pure SQL `AVG()`. Update in follow-up. |
| `barrelsville/scripts/generate_milb_org_rankings.py` | Pure SQL `AVG()`. Update in follow-up. |

---

## What the helper does NOT do

- **Does not exclude bunts via `hit_trajectory_id`.** The 57 mph floor catches every bunt because bunts physically can't exceed 57 in a competitive swing. Don't add `hit_trajectory_id NOT IN (2,3,4)` to your queries — it's noise.
- **Does not exclude whiffs.** Whiffs DO have bat-speed-at-contact readings — HawkEye tracks the bat continuously through the contact zone whether the ball was struck or not. Confirmed empirically May 2026 with whiff rows showing ~70 mph BS values.
- **Does not enforce a min-swings hard cutoff for publishing.** Even 1 swing that survives the floor publishes a value. Pool inclusion gates (e.g. min 50 for percentile distributions) are separate concerns applied at the OUTER layer, not inside the helper.
- **Does not apply ±2.5σ trim.** Removed because: (1) trims legitimate elite swings on small samples, (2) σ is unstable on small samples → erratic behavior, (3) bottom-10% + 57 floor already handles the low end.
- **Does not round.** Returns full-precision floats. Display layers round at presentation.

---

## Bug history — why this rule exists

### Bug 1 — Tracker `cur_event_id` INNER JOIN silently dropped foul balls + whiffs (May 2026)

`tracker_data.py::_BS_QUERY` and `_AACON_QUERY` both had:

```sql
JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
```

`cur_event_id` is NULL on ~70-75% of pitches (only set on PA-ending pitches per `db-joins.md`). INNER JOIN → mid-AB foul balls and mid-AB whiffs silently dropped. Tracker bat speed reflected ONLY PA-ending swings — typically harder, more aggressive contact — pushing values 1-2 mph above the cleaned multi-swing-type pool.

JOIN was added Apr 27 2026 to support the `{ha_filter}` substitution which references `ev.top_of_inning`. The fix wasn't to remove the JOIN — it was to JOIN on `ab_event_id` (every pitch) instead. H/A filter still works because `top_of_inning` is on the AB event row, identical to the cur_event row.

### Bug 2 — Postgame double-filter (May 2026)

`postgame_data.py` ran TWO independent filter passes:
- Pass 1 in `_enrich_pitches` (line 1020): NULLed bat speeds outside ±2.5σ of bottom-10%-trimmed mean. NO 57 floor.
- Pass 2 in `_compute_summary_stats` (line 1428): re-applied bunt exclusion + bottom-10% trim + 57 floor + ±2.5σ — on the column Pass 1 had ALREADY trimmed.

Net effect: each ±2.5σ trim shaves the tails. Doing it twice on a left-skewed distribution (bat speed at contact is left-skewed by check swings + defensive contact) shaves more aggressively from the high end than the low. Mean drifted DOWN ~0.5-1 mph below the canonical. Pass 1 was originally written for the per-pitch table display; Pass 2 was written later by someone who didn't realize the column had already been touched.

### Bug 3 — PD Goals bar chart had NO cleaning at all (May 2026)

`pd-goals/src/stats.py::bat_speed_query` did `AVG(SQRT(...) * 0.681818)` directly in SQL. No bottom-10% drop, no 57 floor. Meanwhile the percentile pool (`percentiles.py::_get_bat_speed_distribution`) DID apply cleaning. Result: a player's bar value was their RAW average, but their percentile was computed against the CLEANED pool — pushing percentiles UP for any player with check-swing-heavy data.

### Bug 4 — ±2.5σ trim across the codebase

Six surfaces all had their own copy of a 3-step filter (bottom 10% + 57 floor + ±2.5σ trim). The σ trim was a "belt-and-suspenders" defensive add-on that nobody could justify on inspection. It pulled means down by trimming legitimate elite swings on small samples (any player with 25-40 contact swings would have their hardest swings disproportionately cut). User direction May 2026: drop it everywhere.

### Bug 5 — Foul ball exclusion belief

I (Claude) claimed in this conversation that whiffs "physically can't have bat speed at contact" because no contact = no SCV row. User corrected with a screenshot of postgame report showing whiffs (Cutter, Slider, Fastball results = "Whiff") with BS values (70.7, 73.8, 67.4). HawkEye measures bat velocity at the contact-zone FRAME regardless of whether the ball is struck — SCV row exists for whiffs. Wrong assumption baked into prior comments and excluded a major sample category.

---

## Implementation playbook for ANY new bat-speed surface

1. **Pull raw per-pitch rows** from the SCV path:
   ```sql
   SELECT pv.batter_id,
          SQRT(POWER(scv.batvx_con, 2) + POWER(scv.batvy_con, 2)
             + POWER(scv.batvz_con, 2)) * 0.681818 AS bat_speed_mph
   FROM Astros.Pitches_View pv
   JOIN groundcontroltracking.tracking.plays tp
       ON tp.sched_id = pv.sched_id AND tp.astros_pitch_id = pv.pitch_id
   JOIN groundcontroltracking.tracking.swing_contact_values scv
       ON scv.sched_id = tp.sched_id AND scv.tracking_play_id = tp.tracking_play_id
   JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
   WHERE scv.batvx_con IS NOT NULL
     AND pv.pitch_id > 0
     -- Plus: level / season / sched_type / batter_id / date scope per use case
   ```
2. **If you need H/A filter**, JOIN `Events_View` on `ab_event_id` (NOT `cur_event_id` — that's the May 2026 bug).
3. **Apply the helper** in Python:
   ```python
   from .bat_speed_clean import clean_bat_speed_per_player
   cleaned = clean_bat_speed_per_player(raw_df)
   ```
4. **Compute downstream stat** as `mean()` of the cleaned column. No re-filter, no double-trim.
5. **For org rollup**: per-batter `mean()` first, then per-org `mean()` of per-batter values (unweighted).
6. **For percentile pool**: apply pool inclusion gate (e.g. min 50 swings) BEFORE calling helper, so the gate operates on raw counts.

---

## Cross-references

- `gc2-metrics.md` — Bat Speed at Contact section (canonical SQL + intent)
- `data-cleaning.md` — codebase-wide cleaning patterns (now superseded by this rule for bat speed specifically)
- `three-surface-parity.md` — at-contact metrics audit (should be updated to 4-surface for postgame inclusion)
- `db-joins.md` — `cur_event_id` vs `ab_event_id` (the JOIN bug at the root of Bug 1)
- `pitfalls.md` — general T-SQL + Python gotchas

---

## What NOT to do

- **Don't write a new inline 3-step filter.** Call the helper. Even if it's "just one place." Six surfaces drifted apart by following that logic.
- **Don't add `hit_trajectory_id NOT IN (2,3,4)` to your bat speed query.** The 57 floor catches bunts. Bunt exclusion is redundant noise.
- **Don't filter out whiffs.** They have valid bat-speed-at-contact readings.
- **Don't INNER JOIN Events_View on `cur_event_id`.** It silently drops mid-AB foul balls and mid-AB whiffs. Use `ab_event_id` (every pitch) instead — `top_of_inning` is on the AB event row regardless of which pitch ended the PA.
- **Don't add a ±2.5σ trim.** Removed for Bug 4 reasons.
- **Don't enforce min-swings inside the helper.** Pool inclusion gates (e.g. min 50 for percentile distributions) belong at the caller layer, not in the helper. Per-batter publishing has NO minimum.
- **Don't double-filter.** If the column has been through the helper once (Pass 1 in postgame), summary stats are just `mean()` — never re-apply the filter.
- **Don't pre-round in SQL.** `AVG(...) * 0.681818` in SQL skips the per-batter cleaning step entirely. Always pull raw rows and clean in Python.
- **Don't diverge between the two helper copies.** Barrelsville and PD Goals copies must stay byte-identical. If you change one, change the other in the same commit.
- **Don't add a "Pool" inclusion min to the helper itself.** The helper is per-batter cleaning only. Pool inclusion is a separate concern (e.g. percentile pool: filter to batters with ≥50 raw swings BEFORE calling helper).
