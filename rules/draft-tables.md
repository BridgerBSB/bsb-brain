# Draft / UDFA / Amateur Tables Reference

How to query players who entered the org via the draft or as undrafted free
agents, and how to fetch their amateur (pre-pro) tracking data.

This file does not cover scouting reports / showcase metadata — only the
tables that join cleanly to `Astros.Pitches_View` for stat lookups.

---

## 1. `MLB_eBis.R4_Draft_Query` — Drafted players

One row per drafted player per draft. League-wide (all 30 orgs).

| Column | Type | Notes |
|---|---|---|
| `groundcontrol_id` | varchar (cast to INT) | Primary join key. Some rows have NULL — `TRY_CAST IS NOT NULL` filter. |
| `mlbam_id` | varchar (cast to INT) | Statcast/MLBAM cross-ref. |
| `first_name`, `last_name` | varchar | |
| `draft_year` | int | E.g. 2022, 2023, 2024, 2025. |
| `draft_round` | varchar (cast to INT) | Round number; some special rounds may be non-integer. |
| `overall_pick` | int | Overall pick number. |
| `position` | varchar | Drafted position — HS/college style codes (`SS`, `OF`, `RHP`, etc.). Use to filter pitchers vs hitters. |
| `school_type` | varchar | `'HS'` (high school), `'4Y'` (4-year college), `'JC'` (junior college). **No `school` name column** (verified missing Apr 2026). |
| `draft_org` | varchar **lowercase** | `'hou'`, `'bos'`, `'nyy'`. **Quirk: `'ny'` = NYM (Mets), Yankees = `'nyy'`.** |
| `signing_org` | varchar | Usually = `draft_org` unless something exotic happened. Use draft_org as the canonical "where they came from." |
| `signing_bonus` | numeric | |
| `age_at_draft` | numeric | |
| `signed` | bit/int | 1 if signed, 0 if didn't. |

**Join to `Astros.Players`:**
`R4_Draft_Query.groundcontrol_id` = `Astros.Players.groundcontrol_id`. Direct.

**Join to `MLB_eBis.PP_MASTER`:**
`R4_Draft_Query → Astros.Players → PP_MASTER` via
`Players.ebis_id = PP_MASTER.PLAYER_ID`.

**Pitcher exclusion list** (per existing reference impls):
```python
PITCHER_POSITIONS = ('RHP', 'LHP', 'RHS', 'RHR', 'LHS', 'LHR', 'P', 'SHS', 'TWP')
```
Inverse for hitters: `position NOT IN PITCHER_POSITIONS`.

---

## 2. `MLB_eBis.PP_MASTER` — Roster master (also UDFA path)

PP_MASTER holds all professional players including UDFA signings. Nick
Arrivo's UDFA-detection pattern (Apr 28 2026):

```sql
SELECT a.groundcontrol_id, p.*
FROM MLB_eBis.PP_MASTER p
LEFT JOIN Astros.Players a ON a.ebis_id = p.player_id
WHERE p.R4YEAR = '2025'           -- year they were eligible for the draft
  AND p.RULE51STYRELG IS NOT NULL  -- confirmed first year on a roster
  AND p.R4STATUS = 'P'             -- "Potential draftee" status
```

Returns players who were eligible for the 2025 draft and signed UDFA. To
include drafted-and-signed players too, drop the `R4STATUS='P'` filter.

| Column (relevant to draft / UDFA) | Notes |
|---|---|
| `R4YEAR` | varchar — the draft year the player was eligible for. **Cast or quote** (`'2025'`). |
| `R4STATUS` | varchar — `'P'` = potential / pre-pro signee, etc. Filter set by Nick. |
| `RULE51STYRELG` | first year on a roster — `IS NOT NULL` confirms they actually signed. |
| `ORG_LK` | varchar **uppercase** — current org. For UDFAs who haven't been traded, this equals signing org. |
| `LEVELOFPLAY_LK` | uppercase: `ML`, `3A`, `2A`, `1A`, `1F`, `R`, `DS`. Lower-case before comparing. |
| `POSITION_LK` | uppercase. Hitter whitelist: `('1B','2B','3B','BAT','C','CF','DH','IF','LF','OF','PH','RF','SS','UN','UTL')`. |
| `EMPLOYEE_FLG` | 0 = active player, 1 = staff. Always filter `= 0` for player queries. |
| `MNROSTERSTATUS_LK`, `MJROSTERSTATUS_LK` | Inactive codes: `('REL','FA','VOL','RES','DIS','PAC','TI')`. |

**See `db-columns.md` PP_MASTER section** for the full inactive-status list
and the canonical `LOWER(LEVELOFPLAY_LK)` mapping.

---

## 3. Org-tenure mechanic for cumulative pro stats

When you want a player's pro stats *only while they were with the drafting
org* (not after a trade), gate on the batting team's org via
`MLBAM.Teams`:

```sql
JOIN Astros.Pitches_View pv ON ...
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
LEFT JOIN Astros.Events_View ev1
    ON pv.sched_id = ev1.sched_id AND pv.ab_event_id = ev1.event_id
LEFT JOIN MLBAM.Teams mt
    ON mt.team_id = ev1.batting_team_id
   AND mt.season = sv.year
WHERE UPPER(mt.org_abbrev) = UPPER(:drafting_org)   -- gate to tenure
```

`R4_Draft_Query.draft_org` is **lowercase** (`'hou'`); `MLBAM.Teams.org_abbrev`
is uppercase (`'HOU'`). Always `UPPER(...)` both sides.

**Plus 4 cross-source org-code mismatches that need a CASE remap**
(see `.claude/rules/org-codes.md` for canonical SQL templates):

| R4 / PP_MASTER form (UPPER) | MLBAM.Teams.org_abbrev |
|---|---|
| `CHI` | `CHC` (Cubs) |
| `LA`  | `LAD` (Dodgers) |
| `NY`  | `NYM` (Mets) |
| `OAK` / `ATH` | `OAK` / `ATH` (rebrand — either side can flip) |

Without the remap, those 4 orgs silently drop from per-org rollups.
Use `IN (<codes>)` (matching the `_R4_TO_MLBAM_ORG` dict) or a CASE
remap to a canonical form before JOINing.

Trade out → `mt.org_abbrev` no longer matches → those pitches don't pass the
WHERE → silently dropped from cumulative. No date column needed; the team
assignment per pitch handles trade timing automatically.

---

## 4. Amateur stats — what level codes apply

Amateur tracking lives under four `level_code` values in
`Astros.Schedule_View`:

| Code | What |
|---|---|
| `bbc` | 4-year college baseball (NOT "Big League Camp" — see `level-codes.md` correction note) |
| `jcb` | Junior college |
| `hsb` | High school showcase |
| `sum` | Summer leagues (Cape Cod, Northwoods, etc. — amateur college players) |

These are normally on the junk-exclusion list for pro reports. For
draft / amateur-vs-pro analysis they MUST be included on the amateur side:
`level_code IN ('bbc','hsb','jcb','sum')`.

For the amateur side, all `sched_type`s are valid (R/E/V/I — showcases run on
multiple sched types). For the pro side use `sched_type = 'R'` only.

---

## 5. Reference scripts

| Use case | Script | Highlights |
|---|---|---|
| HS first-round SS progression (one-off) | `pd-goals/scripts/ss_draft_analysis.py` | Stint detection via Pitches_View per draft year+1, percentile coloring. |
| 2025 HS first-round placement (one-off) | `pd-goals/scripts/hs_firstround_2025_placement.py` | R4_Draft_Query → PP_MASTER current LEVELOFPLAY_LK lookup. |
| Bat-speed by draft class HOU/BOS/NYY (one-off) | `barrelsville/scripts/generate_bat_speed_draft_class.py` | Per-org draft roster + per-season aggregation, multi-page PDF. |
| Amateur → Pro hitter development (one-off) | `barrelsville/scripts/generate_amateur_vs_pro.py` | Drafted + UDFA, amateur level codes, org-tenure gate, 30-org rank page. |
| RAR / Asset Value by draft class | `sql-queries/Historical RAR - Amat Population.sql` | proj.Batting_MLEs/Pitching_MLEs join pattern. |

---

## 6. Common pitfalls

- **Quote `R4YEAR`.** It's a varchar in PP_MASTER. Use `R4YEAR = '2025'`, not `R4YEAR = 2025`.
- **`groundcontrol_id` may be NULL** in R4_Draft_Query (rare). Use `TRY_CAST(... AS INT) IS NOT NULL`.
- **`'ny'` = NYM, NOT Yankees.** Yankees is `'nyy'`. Same in `R4_Draft_Query.draft_org` and `MLBAM.Teams.org_abbrev` (uppercase variants `NY` / `NYY`).
- **Lower vs upper case org abbreviations.** R4_Draft_Query lowercase, MLBAM.Teams uppercase, PP_MASTER.ORG_LK uppercase. Always `UPPER(...)` before comparing across tables.
- **No `school` name column** in R4_Draft_Query. Use `school_type` (HS/4Y/JC) for segmentation. School name lookup would require `MLB_eBis.pp_playerdata` or scout reports.
- **PP_MASTER UDFA `ORG_LK` reflects CURRENT org**, not the original signing org. If the UDFA was traded, the analysis attributes their entire amateur+pro stat line to whichever org they're currently with. Document this assumption when relevant.
