# Draft / College / Amateur Project Patterns

Guide for any project involving drafted players, amateur-signed (UDFA)
players, or amateur tracking data. Pairs with `draft-tables.md` (which is
the schema reference for `R4_Draft_Query`, `PP_MASTER`, etc.) and
`level-codes.md` (BBC=College and the rest of the amateur level codes).

This file captures the **decisions and patterns** that recur across draft
projects, not the SQL details. Read this before starting any new draft /
amateur-vs-pro / draft-class analysis.

---

## When this rule applies

Any project where the pool is "players the org drafted or signed as
amateurs" — explicitly:

- Draft-class progression (HS first-rounders, college SS draftees, etc.)
- Amateur → pro stat comparisons / development analyses
- Bat-speed-by-draft-class style multi-org reports
- UDFA-specific analyses (PP_MASTER `R4STATUS='P'` cohort)
- Any report where `R4_Draft_Query` or `PP_MASTER` is the roster source

If the project is just looking at current pro stats by org, this file
doesn't apply — see `gc2-metrics.md` and `kpi-weekly-charts.md` instead.

---

## Project catalog (read these before building a new one)

| Project | Year | Path | Highlights |
|---|---|---|---|
| HS first-round SS progression | Feb 2026 | `pd-goals/scripts/ss_draft_analysis.py` | Stint detection via `Pitches_View` per draft_year+1, percentile-colored progression PDF |
| 2025 HS first-rounder placement | Apr 2026 | `pd-goals/scripts/hs_firstround_2025_placement.py` | `R4_Draft_Query → PP_MASTER` current `LEVELOFPLAY_LK` lookup |
| Bat speed by draft class HOU/BOS/NYY | Apr 2026 | `barrelsville/scripts/generate_bat_speed_draft_class.py` | Multi-org draft-class detail PDF, per-season aggregation, gain/peak coloring |
| Amateur → Pro hitter development | Apr 2026 | `barrelsville/scripts/generate_amateur_vs_pro.py` | Drafted + UDFA, amateur level codes, org-tenure-gated pro, 30-org rank page, per-player vs pool agg modes |
| Power-5 college contact floor | Apr 2026 | `barrelsville/scripts/generate_power5_contact_floor.py` | PA-weighted regression of pro Ctct% on college Ctct% → per-player residual → 2pp bucket retention floor. Returned soft floor ~69% / strict floor ~62%. Power-5 4YR only (`school_type='4YR'`), draft years 2021–2026. Only draft project so far using regression+residual methodology rather than per-player aggregation. **User flagged uncertainty about repeating this approach** — surface this entry but ASK before applying same methodology. See `memory/power5-contact-floor-shipped.md` for limitations (survivorship bias, MIN_BUCKET_N=3 sensitivity at low end). |
| Historical RAR / asset value | (legacy) | `sql-queries/Historical RAR - Amat Population.sql` | RAR/WAR by draft class via `proj.Batting_MLEs` / `proj.Pitching_MLEs` |

When starting a new project, **copy the closest one as a template** and
adapt only what's necessary. The patterns below are extracted from these
existing impls.

---

## Pool definition

Two roster sources, almost always combined:

### 1. `MLB_eBis.R4_Draft_Query` — drafted players (all 30 orgs)
- One row per drafted player per draft.
- `draft_org` is **lowercase** (`'hou'`, `'bos'`).
- Pitcher exclusion (canonical list):
  ```python
  PITCHER_POSITIONS = ('RHP','LHP','RHS','RHR','LHS','LHR','P','SHS','TWP')
  ```
- `school_type` = `'HS'` / `'4Y'` / `'JC'` (per `db-columns.md`; the
  exact codes for `'4Y'` and `'JC'` were unconfirmed pre-Apr 2026 — first
  amateur-vs-pro run will surface the actual values).
- See `draft-tables.md` for full column reference.

### 2. `MLB_eBis.PP_MASTER` — UDFA path (Nick Arrivo's pattern)
```sql
SELECT a.groundcontrol_id, p.*
FROM MLB_eBis.PP_MASTER p
LEFT JOIN Astros.Players a ON a.ebis_id = p.player_id
WHERE p.R4YEAR IN ('2022','2023','2024','2025')   -- VARCHAR — quote it
  AND p.RULE51STYRELG IS NOT NULL                  -- confirms they signed
  AND p.R4STATUS = 'P'                             -- "Potential draftee"
```
- `ORG_LK` = current org (UPPER). For UDFAs who haven't been traded, this equals signing org.
- `POSITION_LK` = uppercase. Hitter whitelist:
  ```python
  ('1B','2B','3B','BAT','C','CF','DH','IF','LF','OF','PH','RF','SS','UN','UTL')
  ```

### Combine + dedup
```python
combined = pd.concat([drafted, udfa], ignore_index=True)
combined = combined.drop_duplicates(subset=["groundcontrol_id"], keep="first")
# drafted takes precedence — R4_Draft_Query has cleaner draft data
```

### International filter — DEFAULT: NONE (Bazzana case)
We **do not filter on birth country** for these projects. Travis Bazzana
(born in Australia, drafted out of Oregon State) is the canonical
counter-example to a `BIRTHCOUNTRY_LK = 'USA'` filter. "Drafted is
drafted, regardless of country."

If a future ask explicitly excludes IFA-pipeline players, that's a
different filter (probably `i.signed = 1 AND school_type IS NOT NULL`),
not a country filter. Discuss with user before adding any pool restriction.

---

## Amateur stats sourcing

### Level codes (BBC = College, NOT Big League Camp — see `level-codes.md`)
```python
AMATEUR_LEVELS = ("bbc", "hsb", "jcb", "sum")
```
- `bbc` = 4-year college
- `hsb` = HS showcase
- `jcb` = junior college
- `sum` = summer leagues (Cape Cod, Northwoods, etc. — amateur college players)

### Year scope
**Calendar year of the draft / signing year only.** A 2025 draftee's
amateur season = their 2025 spring + summer amateur tracking (whatever
pre-draft college spring + Cape Cod they had on `bbc`/`sum`/`hsb`/`jcb`).

```sql
WHERE YEAR(sv.sched_date) = drafted.draft_year
  AND sv.level_code IN ('bbc','hsb','jcb','sum')
```

### Sched type
**Allow all** (`R`/`E`/`V`/`I`/`S`) on the amateur side. Showcases run
on multiple sched types. Don't restrict to `R` for amateur.

### Sample sizes — be aware
- HS draftees typically have **10–30 PAs** on `hsb` only (showcase events).
- College draftees have **150–350 PAs** depending on conference + summer-league participation.
- JUCO is in between.

This sample-size variance is real and matters for downstream aggregation
choices (see "Aggregation patterns" below).

---

## Pro stats sourcing

### Levels + sched type
```python
PRO_LEVELS = ("mlb", "aaa", "aax", "afa", "afx", "rok", "dsl")
```
- `sched_type = 'R'` only on the pro side.
- `YEAR(sched_date) >= drafted.draft_year` for cumulative.

### Org-tenure gating — BLOCKING

When the analysis should reflect **what the drafting org actually
developed** (not what happened to the player after a trade), gate pro
stats to the drafting org's tenure:

```sql
LEFT JOIN MLBAM.Teams mt
    ON mt.team_id = ev1.batting_team_id
   AND mt.season = sv.year
WHERE UPPER(mt.org_abbrev) IN (<accepted MLBAM codes>)
```

A trade out of the drafting org → `mt.org_abbrev` no longer matches →
those pitches don't pass the gate → silently dropped from cumulative.
Symmetric for league-wide ranking: every org gets credit only for its
own developmental window.

### R4 → MLBAM org abbreviation mapping — BLOCKING

> **See `.claude/rules/org-codes.md`** for the universal cross-source
> canonicalization rule. The chi/la/ny shorthand below applies not only
> to R4_Draft_Query but also to **`MLB_eBis.PP_MASTER.ORG_LK`** and
> **`MLB_eBis.GBL_CLUB_LKUP.ORG_LK`** — every JOIN from MLB_eBis to
> MLBAM.Teams needs this remap, not just draft analyses.

Three R4_Draft_Query codes do NOT match MLBAM.Teams.org_abbrev (verified
Apr 20 2026 in `barrelsville/src/advance_data.py:123-127`):

| R4_Draft_Query.draft_org | MLBAM.Teams.org_abbrev |
|---|---|
| `chi` | `CHC` (Cubs) |
| `la`  | `LAD` (Dodgers) |
| `ny`  | `NYM` (Mets) |

**A naive `UPPER(mt.org_abbrev) = UPPER(draft_org)` gate drops every
Cubs/Dodgers/Mets drafted player's pro stats** because the abbreviations
never match. If you see "28 of 30 orgs in pivot" in a draft analysis,
this is the cause.

Canonical mapping helper:
```python
_R4_TO_MLBAM_ORG = {
    "chi": ("CHC",),
    "la":  ("LAD",),
    "ny":  ("NYM",),
    "ath": ("ATH", "OAK"),  # Athletics rebrand 2024
    "oak": ("OAK", "ATH"),
}
def _mlbam_codes_for(draft_org: str) -> tuple[str, ...]:
    return _R4_TO_MLBAM_ORG.get(draft_org.lower(), (draft_org.upper(),))
```

Then `UPPER(mt.org_abbrev) IN (<codes>)` instead of `=`.

### Athletics rebrand 2024 (OAK → ATH)

The Athletics franchise rebranded from OAK to ATH around 2024. R4_Draft_Query
records both codes depending on draft year:
- 2022 + most 2023 drafts: `draft_org = 'oak'`
- Late 2023 + 2024 + 2025 drafts: `draft_org = 'ath'`

For any project ranking the franchise as a single org, **collapse
`oak` → `ath` at the roster layer**:
```python
combined.loc[combined["draft_org"] == "oak", "draft_org"] = "ath"
```
And keep the dual-code acceptance in `_R4_TO_MLBAM_ORG['ath'] = ('ATH','OAK')`
so pre-rename pro stats still count.

---

## Aggregation patterns — BLOCKING: ALWAYS ASK USER

When rolling per-player metrics up to an org-level number for ranking /
comparison, **two valid mechanics exist** and they answer different
questions:

### Per-player simple mean (1 vote per player)
```python
org_value = mean(per_player_values)   # equal-weights every player
```
- Each drafted / signed hitter contributes 1 vote regardless of PA volume.
- Right framing for: "what we are good at developing" (development is per-player).
- Risk: small-sample players (a 2-AB amateur, a 5-PA just-drafted prospect) carry full vote weight. Their noise pulls org averages around for no signal reason. Mitigation: add a per-side min-PA gate (typical 30 PA).

### Pool aggregation (volume-weighted)
```python
org_value = SUM(numerator) / SUM(denominator)   # across all the org's players
# e.g. Ctct% = SUM(swings - whiffs) / SUM(swings)
```
- Volume-weighted: a 1500-PA vet dominates a 25-PA rookie.
- Right framing for: "how is the org's hitter pool actually performing right now" (matches Org KPI / Weekly KPI mechanics).
- Auto-handles small-sample noise (a 2-AB amateur contributes 2 ABs to numerator + denominator; minimal influence).

### BLOCKING — ALWAYS ASK BEFORE BUILDING

Before writing any org-rollup analysis with this report shape, ASK the
user which mechanic they want and why. Don't default silently. Both are
defensible — they answer different questions.

When asking, frame it concretely with the trade-off:
> "Org averages: do you want **per-player simple mean** (each drafted hitter weighted equally — best framing for 'what we develop') or **pool aggregation / volume-weighted** (matches Org KPI / Weekly KPI mechanics — better framing for 'how is the org's pool performing right now')? They produce different numbers; both are defensible."

Default for the amateur-vs-pro report family: **per-player** (after Apr
2026 user direction). But that decision is project-specific.

### Min-PA gate (companion to per-player mode)

When using per-player mode, consider gating who counts toward the org
mean by minimum PA per side:
- 30 PA per side → drops actual showcase / cup-of-coffee outliers, keeps most amateurs
- 50 PA per side → matches PD-Goals K%/BB% pool gate; tighter
- Or skip the gate and just be honest about the sample sizes via a "Amat PA" column on the detail page

Detail pages should show every player ≥1 PA regardless — gate is for
org-mean inclusion only.

---

## Display patterns

### Postgame-style table layout
Per-draft-class detail pages use the `barrelsville/src/postgame_report.py`
plottable / matplotlib hybrid layout — copy from `generate_bat_speed_draft_class.py`
or `generate_amateur_vs_pro.py`.

Standard column order for player rows:
```
Name -> Rd -> Pick -> Pos (drafted) -> Sch (school_type) -> Amat PA -> Pro PA -> [9 metric columns]
```
Sort by `overall_pick`, UDFAs sorted to bottom under their own visual
indicator (light violet tint).

### School type column
- Use `school_type` from `R4_Draft_Query` — codes are `'HS'`/`'4Y'`/`'JC'` (per `db-columns.md`).
- **Always fall back to the raw uppercase code** if the value isn't in your display dict — surfaces unexpected codes on first run instead of silently displaying blank:
  ```python
  sch_raw = str(r.get("school_type") or "").strip().upper()
  display = SCHOOL_TYPE_DISPLAY.get(sch_raw, sch_raw)
  ```

### PA, not pitches
Display sample-size columns as PA (plate appearances), NOT pitches.
Requires the `cur_event_id` LEFT JOIN per `db-joins.md` dual-join pattern,
and `n_pa = SUM(CAST(pa AS int)) + SUM(CAST(ISNULL(ibb, 0) AS int))` per
`pitfalls.md` (BIT cast + IBB inclusion).

### HiB-aware percentile coloring
Each metric has a HiB direction (Ctct%/ZCtct%/SwDec/Barrel%/AvgEV/MaxEV/LA10-30
= HiB; Whiff%/ZWhiff% = LiB). Color cells gradient red→green per metric
direction. Same percentile_to_color helper as PD-Goals
(`pctile_to_color(pctile, higher_is_better=...)`).

### Cover page + org rank page composition
- **Cover (portrait, page 1):** League avg + HOU avg + HOU rank per metric. Show all 9 metrics in one table.
- **Org rank (landscape, page 2):** All 30 orgs ranked per metric, HiB-aware. ΣRk = simple mean of 9 ranks. HOU row highlighted.
- **Per-draft-class detail (landscape):** One page per draft year. HOU only. Stacked Amat (top, grey) / Pro (bottom, percentile-colored) sub-cells per metric.

---

## Common pitfalls

- **"Big League Camp" mislabel of BBC.** `bbc` is **4-year college**, not Big League Camp. Multiple historical rules files were wrong about this. See `level-codes.md` correction note.
- **`R4YEAR` is varchar.** Quote it: `R4YEAR IN ('2022','2023','2024','2025')`. Casting may fail on some PP_MASTER rows.
- **`groundcontrol_id` may be NULL** in R4_Draft_Query for certain rows. Always `TRY_CAST(... AS INT) IS NOT NULL`.
- **`'ny'` = NYM (Mets), NOT Yankees.** Yankees = `'nyy'`. Both in R4_Draft_Query.draft_org and PP_MASTER.ORG_LK.
- **Lower vs upper case org abbreviations.** R4_Draft_Query lowercase, MLBAM.Teams uppercase, PP_MASTER.ORG_LK uppercase. Always `UPPER(...)` before comparing across tables.
- **No `school` name column.** Use `school_type` (HS/4Y/JC) for segmentation; school name lookup would require `MLB_eBis.pp_playerdata` or scout reports.
- **PP_MASTER `ORG_LK` = current org**, not original signing org. UDFA who got traded post-signing has stats attributed to current org. Document this assumption.
- **MAX of pool ≠ org max.** When aggregating Max EV across an org, take **per-player MAX → mean across players**, NOT MAX of the pool (= single hardest hit). Pool MAX is meaningless as an org metric.
- **Org-tenure JOIN must use `ab_event_id`** for `batting_team_id` (per `db-joins.md` dual-join), NOT `cur_event_id` (which is NULL on 75% of pitches).
- **Don't filter pro level codes too aggressively.** `dsl` and `rok` are both legitimate pro levels — keep them in the pro whitelist for international amateur signees who started at DSL/ACL after their amateur year.

---

## Future skill candidate

The user has flagged that draft / amateur / college projects come up
often enough that a dedicated skill may be worth building. If a 4th or
5th project in this family lands, consider creating a
`.claude/skills/draft-project/` skill that:
- Walks the agent through pool definition (always ask drafted-only vs +UDFA, country filter)
- Walks through aggregation choice (per-player vs pool — ALWAYS ask)
- Walks through min-PA gate (none vs 30 vs 50)
- Surfaces this rule + `draft-tables.md` automatically
- Suggests the closest reference impl from the project catalog above

Don't build the skill yet — wait until pattern is firmly established
across more projects.

---

## Cross-references

- `draft-tables.md` — schema for R4_Draft_Query, PP_MASTER UDFA, org-tenure JOIN
- `level-codes.md` — BBC = College correction, full amateur level code reference
- `db-columns.md` — column meanings, ID mapping
- `db-joins.md` — `ab_event_id` vs `cur_event_id` dual-join pattern
- `pitfalls.md` — BIT cast on PA + IBB columns, NaN in IN clauses
- `gc2-metrics.md` — canonical metric formulas (Ctct%, Whiff%, Barrel%, EV cleaning)
- `multi-level-rollup.md` — per-metric n_obs weighting (the org-KPI mechanic)
