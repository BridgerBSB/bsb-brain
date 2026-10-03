---
name: baseball-sql
description: Baseball analytics SQL verification. Use when writing ANY SQL query against Astros/MLBAM/GroundControl2 databases, when user asks for a query, or when modifying existing SQL in src/ or scripts/ files.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Baseball SQL Verification Checklist

Before writing or modifying ANY SQL query, you MUST complete this checklist. Do NOT skip steps.

## Step 1: Verify Column Names
- [ ] Check `.claude/rules/db-columns.md` for the tables you're querying
- [ ] If the table isn't documented there, grep existing queries in `src/` that use the same table: `grep -r "FROM TableName" --include="*.py"`
- [ ] If still not found, check `sql-queries/DATABASE_REFERENCE.md`
- [ ] If the table is completely undocumented, STOP and provide an `INFORMATION_SCHEMA` query first

**Common traps:**
- `balls_before` NOT `balls`, `strikes_before` NOT `strikes`
- `sched_date` NOT `game_date`, `bat_side` NOT `batter_side`
- `called_strike_chance_mlb` NOT `csc` (Python alias only)
- `hit_bearing` NOT `hit_spray_angle`
- `gumbo_description` NOT `description`

## Step 2: Verify Join Patterns
- [ ] Check `.claude/rules/db-joins.md` for Pitches_View joins
- [ ] Use `ab_event_id` for pitch-level Events_View joins (NOT `cur_event_id`)
- [ ] Use `(sched_id, event_id)` pairs for unique PA identification
- [ ] Events_View and Hits have NO `batter_id` — must join via Pitches_View

## Step 3: Check Pitch Result IDs
- [ ] If filtering by pitch outcome, verify IDs against `.claude/rules/pitch-codes.md`
- [ ] Use the code group constants (WHIFF_CODES, BIP_CODES, etc.) not raw ID lists
- [ ] Remember: `is_whiff` MUST be gated by `did_swing == 1`

## Step 4: Level Code Safety
- [ ] Check `.claude/rules/level-codes.md` for safe query patterns
- [ ] Include level_code whitelist OR `_build_level_filter()` — `sched_type='R'` alone is NOT safe
- [ ] DSL uses `gc2_level_code = 'dsl'` (NOT `sv.league`)

## Step 5: Data Type Safety
- [ ] CAST BIT columns before SUM: `SUM(CAST(col AS int))`
- [ ] Filter NaN from DataFrame ID lists: `[int(x) for x in df['col'].dropna()]`
- [ ] Use full schema prefixes: `MLB_eBis.PP_MASTER`, `Guts.woba_lwts`

## Step 6: Player ID Lookup
- [ ] If querying a specific player, look up their `groundcontrol_id` from `pd-goals/data/slack_channels.csv`
- [ ] Use the concrete ID — NEVER use `LIKE '%Name%'` subqueries

## Step 7: Dual Query Path Check
- [ ] If modifying a query in `src/`, check `.claude/rules/dual-query-path.md`
- [ ] If a parallel app/CLI query exists, update BOTH
