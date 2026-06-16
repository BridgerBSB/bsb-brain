---
type: project
domain: hitting
source: personal-bsbres/notebooks
created: '2026-06-15'
---
# Youth HP Analytics

**What it is:** A pre-Astros (Driveline-era) R + SQL workflow Zac built to track
**youth athletes' high-performance (HP) development** — force-plate strength,
exit velocity, bat speed, pitch speed — pull it out of the lab databases, merge it
with a Notion roster, compute **who improved most ("gainers")**, and surface
"trios" of strength metrics. Plus a Shiny scatter app (the **OBP/HP app**, a
spin on Driveline's public Open Biomechanics Project viewer) for free-form
"metric vs metric" exploration across playing levels.

This is the same *assessment → development* idea as Driveline's
[[big-3-hitting|Big 3]] / [[hitting-biomechanics]] framework, but at the
**youth program-ops** level: are our kids actually getting stronger / faster
month over month, and who do we post on Instagram for it.

> Files live in `personal-bsbres/notebooks/r-analytics/` (root scripts) and
> `…/youth_hp_data/` (youth-specific scripts + CSVs + the gainers subfolder).
> Working dirs in the scripts point at `C:/Users/zachary.bridger/Documents/…`
> (the work machine of that era).

---

## The data model — POI / trials / sessions / users + hp_tests

Two completely separate databases feed this, both MariaDB/MySQL:

### 1. `theia_hitting_db` — the swing/lab capture DB (StatcastDB)
A classic **4-table OpenBiomechanics-style relational chain** (Driveline's "Theia"
markerless mocap hitting DB). One row per *trial* (one swing/capture), keyed up
through sessions to a user:

```
poi  ──session_trial──>  trials  ──session──>  sessions  ──user──>  users
```

| Table | Grain | Key columns used |
|---|---|---|
| `poi` | one **point-of-interest** row per trial (the swing's headline metrics) | `poi_id`, `session_trial`, `blast_bat_speed_mph`, `exit_velo_mph` |
| `trials` | one row per **trial** (individual swing/capture) | `trials_id`, `session`, `trial`, `session_trial` |
| `sessions` | one row per **lab session** (a day in the lab) | `user`, `session`, `date`, `lab` |
| `users` | one row per **athlete** | `user`, `name`, `traq`, `dob` |

- **POI = "Points Of Interest"** — Driveline's term for the per-swing summary
  row (the metrics extracted at key swing events: load, launch, contact, etc.).
  Here only the two headline scalars are pulled: `blast_bat_speed_mph` (Blast
  Motion sensor bat speed) and `exit_velo_mph`.
- The canonical join is the whole point of `poi_trials_sessions_users.sql` /
  `ALL_DATA_SQL.R` — flatten `poi.* JOIN trials JOIN sessions JOIN users` so each
  swing carries the athlete's name, dob, and session date.
- `session_trial` is the composite key gluing a POI row to its trial; `session`
  glues trials→sessions; `user` glues sessions→users. **Same join chain Driveline
  publishes in the OpenBiomechanics repo** — see [[swing-path-bat-tracking]] for
  the bat-tracking analog and [[statcast-pipeline]] for the broader data-spine idea.

### 2. `hp_data.hp_tests` — the force-plate / strength DB (HP CV)
A **wide, flat** "high-performance test" table (one row per athlete per test date),
hosted on a DigitalOcean MySQL cluster (`computer-vision-cluster…`). This is the
**force-deck / jump-test** data — exactly the [[biomech-scores|force-plate strength
family]] (CMJ, SJ, IMTP). Heavily special-charactered column names (have to
`make.names()` them in R):

| Column | What |
|---|---|
| `athlete_name` | clean display name |
| `athlete` | raw label, e.g. `"Aaron Gaddy 111280 Youth"` — note the `Youth` tag, used to filter the youth cohort via `athlete LIKE '%Youth%'` |
| `test_date` | test day (drives "newest test" / gainer diffs) |
| `peak_power_[w]_mean_cmj` | **CMJ** (counter-movement jump) mean peak power, watts |
| `peak_power_[w]_mean_sj` | **SJ** (squat jump) mean peak power, watts |
| `net_peak_vertical_force_[n]_max_imtp` | **IMTP** (isometric mid-thigh pull) max net peak vertical force, newtons |
| `peak_power_/_bm_[w/kg]_mean_cmj` / `…_sj` | body-mass-normalized power |
| `relative_strength` | strength-to-bodyweight |
| `predicted_imtp` | modeled IMTP |
| `pitch_speed_mph`, `bat_speed_mph` | on-field velo + bat speed |
| `body_weight_[lbs]` | bodyweight (drives weight-gain tracking — youth getting bigger) |

The three core jump tests are the **"trio"** (see [[hp-trios]]):
**CMJ power · SJ power · IMTP force**.

### 3. The Notion roster — `notion_csv.csv`
Program-ops metadata exported from a Driveline Notion DB
(`drivelinebaseball/Exported-csv-files…`). Supplies what the lab DBs don't:
`coach`, `playing_level` (age group: 11U/12U/…/18U), and a dated
`height_(cm)_YYYY-MM-DD` column. Merged onto the HP data by `athlete_name`.
Some kids (Lino Smith-Salazar, Thomas Weirich, Gavin Shultz, Alex O'Donnell)
get coach/level hardcoded in R because they were missing from the export — a
classic manual-patch-on-merge step that gets re-edited "for future dates."

---

## "Trios" — the strength snapshot (hp_trios.R)

**`hp_trios.R` builds `complete_youth_trios.csv`.** A "trio" = the three jump-test
strength metrics for a youth athlete at their **most recent** test:

1. Connect to `hp_data.hp_tests`, pull the youth cohort
   (`athlete LIKE '%Youth%'`) with the trio columns + relative strength.
2. **Keep most-recent test per athlete**:
   `youth_test_data[, .I[which.max(ymd(test_date))], by = athlete]`, then gate to
   `test_date >= 2024-09-01` (current training block).
3. Merge the Notion roster (coach / playing_level / height).
4. Patch the few missing coach/level rows by hand.
5. Write `complete_youth_trios.csv`.

So a "trio" row is essentially: **athlete + coach + age group + height +
{CMJ power, SJ power, IMTP force} at their latest test.** It's the cross-sectional
"where does each kid stand right now" snapshot. The `hp_youth_trios.csv` header
(`athlete, test_date, athlete_name, relative_strength, body_weight, predicted_imtp,
SJ power, IMTP force`) is an earlier/leaner cut of the same idea.

> See [[hp-trios]] for the concept note (why these three tests, what they measure).

---

## "Gainers" — biggest improvers over time (the headline analysis)

**The marquee deliverable.** "Gainers" = the youth athletes who **improved the most**
between tests — the Instagram-post / coach-bragging-rights list. Two parallel
implementations:

### A. SQL-side diff (gainers_query_OG.sql / gainers_final.R) — the clean way
A single self-joining query computes per-athlete **deltas** for every metric, two
ways:

- **`*_diff_from_previous`** — current test minus the *immediately prior* test
  (recent momentum).
- **`*_diff_from_baseline`** — current test minus the athlete's *first* test
  (total program gain).

Built with three CTEs over `hp_tests` (youth, test_date in the training window):

| CTE | Picks |
|---|---|
| `latest_tests` (`curr`) | each athlete's **MAX(test_date)** |
| `previous_tests` (`prev`) | each athlete's **2nd-most-recent** test (MAX below the max) |
| `first_tests` (`first`) | each athlete's **MIN(test_date)** = baseline |

Then `curr LEFT JOIN prev LEFT JOIN first ON athlete_name`, selecting
`curr.metric - prev.metric AS *_diff_from_previous` and
`curr.metric - first.metric AS *_diff_from_baseline` for **6 metrics**:
CMJ power, SJ power, IMTP force, pitch speed, bat speed, bodyweight.

`gainers_final.R` runs this query, merges the Notion roster, fixes Jeremy's team
label (`16/18u → 16u`), drops anyone not on a WA coach's roster
(`!is.na(coach)`), and writes **`biggest_gainers.csv`** — which carries all 6
metrics × {previous, baseline} = 12 delta columns plus the raw current values
(see the `biggest_gainers (1).csv` header).

**Then it hands off to ChatGPT.** The script literally ends with a paste-ready
prompt: *"Rank the top 3 athletes per age group (11U…18U) for the 6 diff-from-previous
columns. Missing → 0. Rank by highest positive improvement. 11U/12U only have CMJ.
13U–15U lack IMTP. 16U/18U have all six. Tie for 3rd → list 4. Exclude Kaito Garrett."*
The data pipeline produces the ranked dataset; the LLM does the per-age-group
top-3 ranking + formatting. (See [[lightgbm-baseball-modeling]] for the contrast —
that's the *model-driven* side of Zac's analytics; this is deliberately
lightweight, an LLM-as-ranker.)

### B. R-side rolling join (biggest_gainers.R) — the swing-data merge variant
A second, more experimental script that merges **two different DBs** so gains can
be looked at against actual exit velo / bat speed from the lab:

1. Pull the flattened **POI/trials/sessions/users** swing data from
   `theia_hitting_db` (per-swing `blast_bat_speed_mph` + `exit_velo_mph`).
2. Pull youth **`hp_tests`** force-plate data (post-2024-08-10, `%Youth%`).
3. Merge Notion roster.
4. Reduce each swing source to **max exit velo per (name, date)**.
5. **Rolling join** (`data.table` `roll = "nearest"`): for each force-plate test
   row, attach the swing-DB row with the *nearest date* for that athlete —
   `statcastdb[youth_data, roll = "nearest"]`. This is the key trick: the two DBs
   don't share session IDs, so they're aligned by **athlete + nearest calendar
   date**. Also dumps `test_gainers.csv` as a practice dataset "for GPT analysis."

> The "gainers" idea is general enough to deserve its own concept note —
> see [[gainers-analysis]].

---

## The OBP/HP app — Shiny "metric vs metric" explorer

Three R scripts are variants of the **same Shiny scatter-plot app**, themed
"Open Biomechanics Project" (a nod to Driveline's public viewer):

| Script | Data source | Notes |
|---|---|---|
| `obp_hp_app (1).R` | `hp_obp.csv` (589 KB, the big OBP+HP join) | The canonical app. Exports to a static site via `shinylive::export` + `httpuv::runStaticServer` so it can be hosted without a live R server. |
| `LINEAR GRAPH.R` | `boddy_twt.csv` (from `ALL_DATA_SQL.R`) | "Launchpad x HP App" variant — adds an in-title linear-model fit, R coefficient. |
| `ALL_DATA_SQL.R` | merges StatcastDB (max bat speed per athlete) + `hp_tests` → `boddy_twt.csv`, then defines the same app | The ETL+app in one file; full-outer-merges swing data to HP data on athlete name, back-fills `level` from `playing_level`. |

**What the app does:** dropdowns pick an **X metric** and **Y metric** from any
column; checkbox filters **playing level** (Pro / College / High School); renders a
`ggplot` scatter colored by level with an `lm` smoother and the **Pearson r** in
the title. It's a fast "is metric A related to metric B, and does it differ by
level" tool — e.g. `peak_power_mean_cmj` vs `pitch_speed_mph`, or
`exit_velo_mph` vs `IMTP`. Pure exploratory correlation, no inference rigor
(commented-out MSE/MAE/R²/predict blocks show that was considered and dropped).

This is the **same shape** as the Astros affiliate-tracker "pick two metrics,
scatter them" instinct, and the same EV-vs-strength question that drives
[[biomech-scores]] and the force-plate work.

---

## The SQL, summarized

| File | Returns |
|---|---|
| `poi_trials_sessions_users.sql` / the query in `ALL_DATA_SQL.R` & `biggest_gainers.R` | The flattened 4-table swing chain: every POI swing row decorated with trial/session/user info. **One row per swing.** |
| `gainers_query_OG.sql` (also inline in `gainers_final.R`) | One row per youth athlete with current values + 12 delta columns (6 metrics × {from-previous, from-baseline}) via the 3-CTE self-join. **One row per athlete.** |
| inline youth pulls in `hp_trios.R` / `biggest_gainers.R` | `hp_tests WHERE athlete LIKE '%Youth%'` (+ a date floor) — the youth cohort slice of the wide force-plate table. |

Cohort filter everywhere = **`athlete LIKE '%Youth%'`** (the raw `athlete` label
carries a `Youth` tag). Date windows (`> 2024-08-10`, `>= 2024-09-01`,
`<= 2025-01-25`) scope to the active training block and are flagged "CHANGE FOR
FUTURE DATES" — this was a recurring monthly run, not a one-off.

---

## How this connects to the Astros work

- **Force-plate / jump tests** here (CMJ/SJ/IMTP) are the youth-program version of
  the strength inputs in the Astros [[biomech-scores]] / [[hitting-biomechanics]]
  pipeline — and the *unmeasurable* "Force Deck / twitch / eccentric" goals in
  PD Goals (`rules/pd-goals-unmeasurable`) are exactly these metrics, just not
  yet wired to a DB on the Astros side.
- **Gainer diffs** (current − baseline / current − previous) are the same
  "improvement over time" question as the Astros **PD Flag / drift tracker**
  (`rules/pd-goals-flag-tracker`) — flag who moved, good or bad — and the
  amateur→pro development deltas in the draft work (`rules/draft-projects`).
- **The Shiny scatter app** is the spiritual ancestor of the affiliate-tracker
  "metric vs metric" exploration and the EV-vs-strength correlation studies.
- **Bat speed + exit velo** tie straight into [[swing-path-bat-tracking]] and
  [[big-3-hitting]].

---

## Open / fragile bits (if revived)

- **Hardcoded DB creds** in every script (read-only users, but plaintext).
- **Hardcoded date windows** + manual coach/level patches — re-edit each run.
- **`make.names()` on the `[w]`/`[n]` columns** is mandatory or R chokes on the
  special chars; the app variants differ on whether they pre-sanitize.
- The **rolling-join** (`roll="nearest"`) in `biggest_gainers.R` can mis-pair a
  force-plate test to a far-away swing date if an athlete has sparse swing data —
  no max-gap guard.
- Ranking is **outsourced to an LLM prompt**, so it's reproducible only if the
  prompt + dataset are kept together (they are, at the bottom of `gainers_final.R`).

## Links
- [[MOC-baseball-analytics]]
- [[hp-trios]] · [[gainers-analysis]] — the two method notes spun out of this
- [[swing-path-bat-tracking]] · [[big-3-hitting]] · [[hitting-biomechanics]]
- [[biomech-scores]] · [[statcast-pipeline]]
- Astros tie-ins: `rules/pd-goals-unmeasurable` (force-deck goals),
  `rules/pd-goals-flag-tracker` (drift = gainers), `rules/draft-projects`
  (amateur dev deltas)
