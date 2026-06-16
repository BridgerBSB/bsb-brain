---
name: IF Catch Position Exploration — Bearing Divergence Findings
description: Apr 30-May 1 2026 exploration of catch position vs ball-flight for IF spray. Findings, methodology, query template, prediction math. Parked while pivoting to OF positioning per Mazzo (OF coordinator).
type: project
originSessionId: c0bb79da-67cb-471a-9f9d-349e1195ea7d
---
## Status: PARKED May 1 2026

Exploration shown to be conclusive — catch-position bearing diverges from ball-flight bearing meaningfully for soft/short contact. Decision deferred on whether to swap the IF spray source. Pivoting to OF positioning work per OF coordinator (Mazzo) parameters next.

When resuming, read this file + `.claude/rules/tracking-schema.md` (especially §3 Play_Event_Positions, §8 May 1 2026 bug history corrections).

## The question

Replace IF spray source from ball-flight `(hit_bearing, hit_distance)` with catch-position `(field_x, field_y)`. Worth it?

## The answer (short)

**Yes for soft/short contact, basically equivalent for hard grounders.** Mean abs bearing diff overall = ~5.5° (~12.5 ft at IF depth). Diverges to ~7° on 0-30 ft hits, ~11° on choppers (LA < -20°). Tightens to ~1.5° on 100-150 ft hits and ~1.9° on low liners.

## Methodology — 4 columns we ended up using

Per-BIP:
1. `hit_bearing` from `Astros.Hits` — where ball landed (current spray source)
2. `catch_bearing = DEGREES(ATN2(field_x, field_y))` — where actual fielder caught it
3. `abs_diff = ABS(catch_bearing - hit_bearing)` — magnitude of angular gap
4. `bias_foul = SIGN(hit_bearing) * (catch_bearing - hit_bearing)` — directional shift, folded across pull/oppo

`bias_foul` is the prediction engine. `abs_diff` is the uncertainty / error bar. They answer different questions.

Aggregate by 4 slices: overall, by `hit_distance` bucket, by `hit_vertical_angle` (LA) bucket, by `fielder_pos`.

## Final query (EXACT — copy-paste ready)

```sql
WITH bips AS (
    SELECT
        h.hit_distance,
        h.hit_vertical_angle,
        h.hit_bearing,
        pep.pos_id,
        pep.pos_x,
        pep.pos_y,
        SQRT(POWER(pep.pos_x, 2) + POWER(pep.pos_y, 2)) AS catch_dist_ft,
        DEGREES(ATN2(pep.pos_x, pep.pos_y)) AS catch_bearing,
        ABS(DEGREES(ATN2(pep.pos_x, pep.pos_y)) - h.hit_bearing) AS abs_diff,
        ABS(DEGREES(ATN2(pep.pos_x, pep.pos_y)) - h.hit_bearing)
            * SQRT(POWER(pep.pos_x, 2) + POWER(pep.pos_y, 2))
            * PI() / 180.0 AS abs_diff_ft,
        -- Directional bias folded across pull/oppo:
        --   positive = catch shifted TOWARD foul line vs where ball landed
        --   negative = catch shifted TOWARD CF vs where ball landed
        SIGN(h.hit_bearing)
            * (DEGREES(ATN2(pep.pos_x, pep.pos_y)) - h.hit_bearing) AS bias_foul,
        CASE
            WHEN h.hit_distance < 30  THEN '00-30 ft'
            WHEN h.hit_distance < 60  THEN '30-60 ft'
            WHEN h.hit_distance < 100 THEN '60-100 ft'
            ELSE                           '100-150 ft'
        END AS dist_bucket,
        CASE
            WHEN h.hit_vertical_angle < -20 THEN '<-20 chopper'
            WHEN h.hit_vertical_angle <   0 THEN '-20 to 0 grounder'
            ELSE                                 '0 to 15 low liner'
        END AS la_bucket,
        CASE pep.pos_id
            WHEN 1 THEN 'P' WHEN 2 THEN 'C'
            WHEN 3 THEN '1B' WHEN 4 THEN '2B'
            WHEN 5 THEN '3B' WHEN 6 THEN 'SS'
        END AS fielder_pos
    FROM Astros.Pitches_View pv
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    JOIN Astros.Events_View ev
        ON pv.sched_id = ev.sched_id AND pv.ab_event_id = ev.event_id
    JOIN groundcontroltracking.Tracking.Plays pl
        ON pv.sched_id = pl.sched_id AND pv.pitch_id = pl.astros_pitch_id
    JOIN groundcontroltracking.Tracking.Play_Event_Positions pep
        ON pl.sched_id = pep.sched_id
       AND pl.tracking_play_id = pep.tracking_play_id
       AND pep.groundcontrol_id = ev.first_defender_id
       AND pep.tracking_play_event_type_id = 17
    JOIN Astros.Hits h
        ON pv.sched_id = h.sched_id AND pv.pitch_id = h.pitch_id
    WHERE sv.year IN (2024, 2025, 2026)
      AND sv.sched_type = 'R'
      AND pv.pitch_id > 0
      AND pv.pitch_result_id IN (12, 13, 14)
      AND h.hit_vertical_angle < 15
      AND h.hit_distance < 150
      AND pep.pos_id IN (1, 2, 3, 4, 5, 6)
      AND h.hit_bearing IS NOT NULL
      AND pep.pos_y > 0
      AND ev.play_by_play NOT LIKE '%singles on a ground ball to pitcher%'
      AND ev.play_by_play NOT LIKE '%singles on a soft bunt ground ball to pitcher%'
      AND ev.play_by_play NOT LIKE '%deflected by pitcher%'
)
SELECT 'overall' AS slice, 'all' AS bucket, COUNT(*) AS n_bips,
    CAST(AVG(abs_diff)      AS DECIMAL(5,2)) AS mean_abs_diff_deg,
    CAST(AVG(abs_diff_ft)   AS DECIMAL(5,2)) AS mean_abs_diff_ft,
    CAST(AVG(bias_foul)     AS DECIMAL(5,2)) AS mean_bias_foul_deg,
    CAST(AVG(catch_dist_ft) AS DECIMAL(5,2)) AS avg_catch_depth_ft
FROM bips
UNION ALL
SELECT 'by_distance', dist_bucket, COUNT(*),
    CAST(AVG(abs_diff)      AS DECIMAL(5,2)),
    CAST(AVG(abs_diff_ft)   AS DECIMAL(5,2)),
    CAST(AVG(bias_foul)     AS DECIMAL(5,2)),
    CAST(AVG(catch_dist_ft) AS DECIMAL(5,2))
FROM bips GROUP BY dist_bucket
UNION ALL
SELECT 'by_la',       la_bucket, COUNT(*),
    CAST(AVG(abs_diff)      AS DECIMAL(5,2)),
    CAST(AVG(abs_diff_ft)   AS DECIMAL(5,2)),
    CAST(AVG(bias_foul)     AS DECIMAL(5,2)),
    CAST(AVG(catch_dist_ft) AS DECIMAL(5,2))
FROM bips GROUP BY la_bucket
UNION ALL
SELECT 'by_pos',      fielder_pos, COUNT(*),
    CAST(AVG(abs_diff)      AS DECIMAL(5,2)),
    CAST(AVG(abs_diff_ft)   AS DECIMAL(5,2)),
    CAST(AVG(bias_foul)     AS DECIMAL(5,2)),
    CAST(AVG(catch_dist_ft) AS DECIMAL(5,2))
FROM bips GROUP BY fielder_pos
ORDER BY slice, bucket;
```

## Empirical results — EXACT (May 1 2026, league-wide 2024-2026)

| slice | bucket | n_bips | mean_abs_diff_deg | mean_abs_diff_ft | mean_bias_foul_deg | avg_catch_depth_ft |
|---|---|---:|---:|---:|---:|---:|
| overall | all | 334,287 | 5.50 | 9.45 | 0.39 | 119.93 |
| by_distance | 00-30 ft | 241,626 | **6.91** | **11.50** | 0.16 | 114.69 |
| by_distance | 30-60 ft | 39,376 | 2.14 | 4.80 | 1.53 | 133.02 |
| by_distance | 60-100 ft | 29,054 | 1.78 | 3.94 | 1.03 | 133.61 |
| by_distance | 100-150 ft | 24,231 | **1.41** | **3.07** | 0.03 | 134.58 |
| by_la | <-20 chopper | 107,854 | **11.00** | **16.18** | -1.76 | 100.18 |
| by_la | -20 to 0 grounder | 155,264 | 3.41 | 7.35 | 1.69 | 127.84 |
| by_la | 0 to 15 low liner | 71,169 | 1.74 | 3.80 | 0.80 | 132.61 |
| by_pos | P | 29,387 | 12.01 | 10.37 | -7.92 | 52.08 |
| by_pos | C | 2,795 | 35.35 | 12.08 | -26.78 | 21.54 |
| by_pos | 1B | 48,077 | 5.57 | 10.03 | 2.23 | 108.70 |
| by_pos | 2B | 85,111 | 3.49 | 8.26 | 0.50 | 141.69 |
| by_pos | 3B | 77,361 | 6.51 | 11.50 | 3.10 | 108.77 |
| by_pos | SS | 91,556 | 3.48 | 8.12 | 0.52 | 139.82 |

### Reading notes

- **Headline:** overall mean abs diff = **5.50°** (= **9.45 ft** lateral at avg 120 ft catch depth). Catch-position bearing diverges meaningfully from ball-flight bearing.
- **Distance pattern:** 0-30 ft hits diverge 11.5 ft (catch position is at 115 ft depth, vs ball "landed" at 0-30 ft — that 100+ ft gap is the IF / P / C ranging in to glove the ball). 100-150 ft hits diverge only 3 ft because catch happens at 134 ft depth (very close to where ball landed at 100-150 ft).
- **LA pattern:** choppers diverge 16 ft (catch at 100 ft depth, ball landed close to HP). Low liners diverge 4 ft (caught at 132 ft, near where they hit).
- **Position pattern:** P diverges most (12°, ranging in from 52 ft mound to glove off-axis balls). C extreme (35°) but tiny n=2,795 — catcher fields at 21 ft depth, small geometry → small absolute angles get amplified to big degrees. 2B/SS smallest divergence (3.5°) — they handle "true" grounders to their depth.
- **bias_foul direction:** mostly slightly positive overall (catches drift toward the foul line on average) but dominated by very negative C (-27°) and P (-8°) which pull catches toward CF. The pure IF positions (1B/3B/2B/SS) trend positive (catches drift toward foul) — IF ranging toward the line on cuts.

## Glossary (for sharing externally)

- **slice** — which kind of cut: overall, by hit distance, by launch angle, or by fielder position
- **bucket** — the specific value within that slice
- **n_bips** — count of fielded balls in the group
- **mean_abs_diff_deg** — average angular gap (degrees) between where ball landed and where fielder caught it; magnitude only, no direction
- **mean_abs_diff_ft** — same gap converted to feet at each play's actual catch depth
- **mean_bias_foul_deg** — folded directional bias: positive = catch shifts TOWARD foul line vs where ball landed; negative = shifts TOWARD CF; ~0 = no systematic bias
- **avg_catch_depth_ft** — average distance from home plate to where fielder caught the ball, for context

## Prediction math

Using `bias_foul` + `avg_catch_depth_ft` (current columns) you can predict catch position from a hit position:

```
1. bearing_shift = bias_foul × SIGN(hit_bearing)
   (unfolds the side-folded bias back onto the actual side)
2. predicted_catch_bearing  = hit_bearing + bearing_shift
3. predicted_catch_distance = avg_catch_depth_ft (slice-typical)
4. predicted_catch_x = predicted_catch_distance × sin(predicted_catch_bearing × π/180)
5. predicted_catch_y = predicted_catch_distance × cos(predicted_catch_bearing × π/180)
```

`abs_diff_deg` = uncertainty / error bar around the central prediction (NOT used to compute the prediction itself).

To predict hit position from catch position, just invert:
```
predicted_hit_bearing  = catch_bearing - (bias_foul × SIGN(catch_bearing))
predicted_hit_distance = catch_distance - mean_depth_shift
```

Note: `mean_depth_shift = AVG(catch_dist - hit_distance)` is NOT in the current query columns. Add it via:
```sql
SQRT(POWER(pep.pos_x, 2) + POWER(pep.pos_y, 2)) - h.hit_distance AS depth_shift_ft
```
in the bips CTE if needed for hit-from-catch prediction.

## Open caveats / known limitations

1. **Handedness fold not validated.** The `SIGN(hit_bearing)` fold assumes RHH-pull and LHH-oppo behavior is symmetric on the same physical side of the field. Probably true for hard grounders, possibly not for choppers. Verification = add a `bat_side` (R/L) split slice and compare bias_foul values. If they diverge meaningfully (~3°+), prediction should split by bat_side.

2. **Coverage check incomplete.** Sample query was Unroe-only — saw 26.1% coverage at AAA with the over-restrictive earlier query (later loosened with `first_defender_id` JOIN). Need a league-wide tracked-vs-total coverage check before deciding production-readiness.

3. **`hit_bearing`/`hit_distance` semantics not verified.** I'm 90% sure these are bounce-point or first-contact-with-field, but didn't formally verify against a known grounder example. If the convention is something else (e.g. contact-trajectory projection), the divergence interpretation shifts.

4. **Pitcher-primary play exclusions only cover 3 of 4 shelved patterns.** Group A applied (`%singles on a ground ball to pitcher%`, `%singles on a soft bunt ground ball to pitcher%`, `%deflected by pitcher%`). Group B (`%reaches on a missed catch error by first baseman%`) NOT yet applied — that's the 4th shelved pattern, sign-flip case for pos_id 4/5/6.

## What's next

- **OF positioning work** (May 1 2026 onward, Mazzo's parameters)
- **Apply OF version of this exploration** to OF coverage zones if the same question comes up there
- **Re-evaluate IF spray source** when OF work surfaces patterns that argue for / against catch-position rendering across the board
- **Verify handedness fold** before any production usage of `bias_foul` for prediction

## References

- `.claude/rules/tracking-schema.md` — full Tracking schema reference + May 1 corrections
- `intangibles/scripts/generate_hitter_advance.py` — current IF spray uses ball-flight (hit_bearing + hit_distance)
- `intangibles/src/hitter_advance_report.py` — wedge-chart definition (LA<15 AND dist<150 = IF zone)
- `if-paa-description-exclusions-shelved.md` — the 4 shelved play description patterns we used 3 of
