---
type: reference
domain: data
tags:
  - sql
  - groundcontrol2
  - table
---
# Astros.Events_View

One row **per event** — plate-appearance outcomes and mid-PA events (SB, passed ball). Part of [[MOC-groundcontrol-schema]].

## Join keys
- `event_id` = `cur_event_id` from [[pitches-view]]
- `sched_id` — game identifier
- `ab_event_id` — the PA identifier (despite the name)

## Gotchas
- **No `batter_id`/`pitcher_id`** — must join through [[pitches-view]] to attach a player.
- `so`, `bb`, `pa` are **bit** columns — **MUST `CAST(... AS int)` before `SUM`** (`SUM(CAST(ev.so AS int))`). See [[pitfalls]].
- `cur_event_id` ≠ `ab_event_id` for mid-PA events (stolen bases, passed balls don't end a PA) — this is why the two diverge.
- `event_result_id` → `Astros.LK_Event_Results` (51 codes: hits, outs, SB/CS, pickoffs, errors).
- Standard pitch→event join uses `pv.cur_event_id = ev.event_id`; pitching queries add `AND ev.pa = 1`. See [[db-joins]].
