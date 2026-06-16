---
name: When swapping SQL JOINs, grep every alias downstream
description: SQL refactor lesson — when removing/replacing a JOIN, every WHERE clause and template-substituted filter using the old alias breaks silently
type: feedback
originSessionId: e660ac27-fcaa-4fa7-87c6-512adb18d3d8
---
When swapping out a JOIN (e.g., `Bat_Tracking_Metrics bt` → `tracking.plays tp + swing_contact_values scv`), the old alias may be referenced not just in the SELECT but in:

1. WHERE clauses elsewhere in the same query
2. **Template-substituted filters** like `{ha_filter}`, `{sched_filter}` which inject `ev.top_of_inning = 0` or `s.sched_type IN ('R')`
3. ORDER BY, GROUP BY columns
4. Other JOIN ON conditions chaining off the dropped alias

**Why:** Apr 27 2026 Barrelsville bat speed at-contact refactor — I swapped `Astros.Bat_Tracking_Metrics bt` JOIN for the `tracking.plays tp + swing_contact_values scv` JOIN chain in `_BS_QUERY` and `_AACON_QUERY` in `barrelsville/src/tracker_data.py`. The previous query had `Events_View ev` JOINed (used by `ha_filter` template substitution which inserts `ev.top_of_inning = 0` for Home, `= 1` for Away). My new query dropped the `Events_View ev` JOIN because I was focused on swapping BTM. Silent failure: H/A=None worked fine; selecting H or A produced `'ev.top_of_inning' could not be bound` SQL error. Discovered when running `pin_tracker_seasons.py` which iterates all H/A states across all years.

**How to apply:** Before committing any SQL JOIN swap, run this check:

```bash
# 1. Identify every alias the new query introduces or removes
# 2. Grep the entire query string for `<old_alias>.` references — must be zero hits
# 3. Grep `{ha_filter|{sched_filter|other f-string substitutions for old alias references
grep -n "ev\.\|aev\.\|btm\.\|bt\." <new_query.py>

# 4. Trace every {template_sub} to see what aliases it requires
# 5. Confirm every alias the templates touch is JOIN'd in the new query
```

For the bat-speed/AA case: `ha_filter` requires `ev.top_of_inning` — therefore must add `LEFT JOIN Astros.Events_View ev ON ev.sched_id = pv.sched_id AND ev.event_id = pv.ab_event_id` (per `db-joins.md` dual-join pattern — `ab_event_id` always populated, `cur_event_id` is for PA outcomes only).

**Checklist for any JOIN refactor:**
- [ ] Grep new query string for every alias used in the OLD query — confirm none remain unbound
- [ ] Test EVERY parameter combination the script supports (H/A=All AND H AND A; sched_type variants; per-year)
- [ ] Run via the actual entry-point CLI before committing — pin scripts iterate all combinations, so they catch this faster than a one-off `--level aax` test
