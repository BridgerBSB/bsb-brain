---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# Event-Anchored vs Pitch-Anchored Queries — Decision Guide

**When drafting any per-batter or per-event aggregation against GroundControl2, pick the driver table FIRST. The driver choice determines whether your SUMs are correct or inflated.**

## The decision

| What you're computing | Drive FROM | JOIN pattern |
|---|---|---|
| **Per-batter event aggregation** (PA, wOBA, wRC+, xwOBA, gcOBA, K%, BB%, BA/OBP/SLG) | `Astros.Events_View ev` | `LEFT JOIN Astros.Pitches_View pv ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id` |
| **Per-pitch aggregation** (zSw%, OSw%, Sw%, InZ%, Whf%, Ctct%, Barrel%, any pitch-level rate) | `Astros.Pitches_View pv` | `JOIN Astros.Events_View ev ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id` (only if you need event-level columns on each pitch) |
| **Mixed (both per-pitch and per-event on same query)** | `Astros.Pitches_View pv` | Dual-join pattern from `rules/db-joins.md` — `aev` on `ab_event_id` + `cev` on `cur_event_id` |

## Why this matters — the PA inflation trap

If you drive FROM `Pitches_View` and JOIN to `Events_View` on `ab_event_id`, you get ONE ROW PER PITCH with the event columns broadcast. Then:

```sql
-- WRONG — each PA counted N times (N = pitches per PA, avg ~4)
SELECT pv.batter_id, SUM(CAST(ev.pa AS INT)) AS pa_count
FROM Pitches_View pv
JOIN Events_View ev ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id
GROUP BY pv.batter_id
```

A batter with 300 true PAs shows ~1,200. Every SUM(ev.*) is inflated by pitches-per-PA.

## Why `cur_event_id` solves it

`cur_event_id` is ONLY populated on the terminal pitch of each PA (NULL on the prior 75% of pitches in an AB). So when you drive FROM Events_View and LEFT JOIN Pitches_View on `cur_event_id`, at most ONE matching pitch row comes back per event — natural dedup to one row per event.

```sql
-- RIGHT — one row per event, no inflation
SELECT pv.batter_id, SUM(CAST(ev.pa AS INT)) AS pa_count
FROM Astros.Events_View ev
LEFT JOIN Astros.Pitches_View pv
  ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
WHERE pv.batter_id IS NOT NULL
GROUP BY pv.batter_id
```

This is the GC2 production pattern. See `rules/db-joins.md` for the full cur_event_id/ab_event_id reference.

## The `Pitches.batter_id IS NOT NULL` filter

When driving FROM Events_View, you need `pv.batter_id IS NOT NULL` in the WHERE clause. This filters to events where the LEFT JOIN found a matching terminal pitch (i.e. events that had at least one pitch). Without it, you get NULL-batter-id rows that break the GROUP BY.

## Cross-reference

- Mechanics: `rules/db-joins.md` — cur_event_id vs ab_event_id, dual-join pattern, event_id uniqueness
- wOBA specifics: `rules/woba-rules.md` — denom rule, weight JOIN, numerator patterns
- Reference implementations: `rules/reference-impl-index.md` — per metric
