# How To --- Recipes

Five concrete recipes you'll run repeatedly:

1. Write a one-off SQL query
2. Add a new metric to an existing report
3. Add a new report (or new report variant)
4. Debug a three-surface parity divergence
5. Propagate a fix across worktrees

Plus the daily / weekly operational recipes.

::: tip
**What you'll learn:** end-to-end workflows for the most common
tasks in this role. Each recipe links back to the chapters that
explain the underlying patterns.
:::

## Recipe 1: Write a one-off SQL query

A coach asks "show me the HOU MiLB pitchers with FF velo above 95
vs LHH this month." Here's how to answer it.

### Step 1 --- find the closest reference

`grep` `sql-queries/` for similar queries:

```bash
ls sql-queries/ | grep -i "velo\|ff\|fastball"
ls sql-queries/ | grep -i "by-ip\|monthly"
```

For this question: `sql-queries/astros-non-mlb-velo-by-ip.sql` is
close. Open it.

### Step 2 --- adapt the reference, don't reconstruct from memory

Copy the file to a new name describing the question:

```bash
cp sql-queries/astros-non-mlb-velo-by-ip.sql \
   sql-queries/hou-milb-pitchers-ff-vs-lhh-this-month.sql
```

Edit the new file:

- Change pitch type filter to `pv.pitch_type = 'FF'`
- Add handedness filter `pv.bat_side = 'L'`
- Change date filter to current month
- Restrict to HOU via `mt.org_abbrev = 'HOU'` on `MLBAM.Teams`
- Add velocity threshold `pv.release_speed > 95`

### Step 3 --- check your column references

Before running, verify columns:

- Is it `pv.release_speed` or `pv.velocity`? (`release_speed` --- see Ch 3)
- Is it `pv.bat_side` or `pv.batter_side`? (`bat_side`)
- Is it `pv.pitcher_throws` or `p.throws`? (`pitcher_throws` ON Pitches_View, `throws` ON Players)
- Bunt filter via `Events_View.hit_trajectory_id`, NOT `Hits.hit_trajectory_id`

Cross-check with `.claude/rules/db-columns.md`.

### Step 4 --- run on the work laptop

```powershell
# Work laptop — has DB access
git pull
sqlcmd -S gcsql02 -d GroundControl2 -E -i sql-queries\hou-milb-pitchers-ff-vs-lhh-this-month.sql -o output.csv -W -s,
```

Or just paste into SSMS or run via Python:

```python
import pandas as pd
from sqlalchemy import create_engine
engine = create_engine("mssql+pyodbc://@gcsql02/GroundControl2?driver=ODBC+Driver+17+for+SQL+Server&Trusted_Connection=yes")
df = pd.read_sql(open("sql-queries/hou-milb-pitchers-ff-vs-lhh-this-month.sql").read(), engine)
print(df.to_string())
```

### Step 5 --- send the answer

Reply to the coach in Slack with the relevant rows. Don't paste the
whole table if there are 100+ rows --- summarize with TOP 20 or top by
the most-relevant metric.

### Step 6 --- commit the SQL

```bash
git add sql-queries/hou-milb-pitchers-ff-vs-lhh-this-month.sql
git commit -m "sql(one-off): HOU MiLB FF velo > 95 vs LHH this month"
git push
```

The file becomes institutional memory for the next time this kind of
question arrives.

## Recipe 2: Add a new metric to an existing report

A coach asks for a new column ("can we add the 1stPZ% to the postgame
report?"). Three-surface parity (Ch 11) drives the workflow.

### Step 1 --- identify the surface(s)

Where does the metric currently exist? Use the reference index in
`.claude/rules/reference-impl-index.md` or grep:

```bash
grep -rn "1stPZ\|first_pitch_inzone" \
    barrelsville/src bullpen-report/src intangibles/src pd-goals/src
```

If the metric exists in any one of {tracker, KPI weekly, PD Goals
org KPI}, the rule of three-surface parity applies --- you'll add it
to all three.

### Step 2 --- open the canonical reference impl

For 1stPZ%, the reference is in `bullpen-report/src/tracker_data.py`
(pitcher) or `barrelsville/src/tracker_data.py` (hitter view).

```sql
-- Standard pattern: AVG(csc) on first-pitch pitches
AVG(CASE WHEN balls_before = 0 AND strikes_before = 0
         THEN called_strike_chance_mlb
         ELSE NULL END) AS first_pitch_inzone_pct
```

### Step 3 --- add to the data module

Paste the same SELECT clause into the right data function:

- `barrelsville/src/postgame_data.py` if it's the postgame report
- `barrelsville/src/hitter_kpi_data.py` if it's KPI weekly
- `pd-goals/src/org_kpi_data.py` if it's the org KPI

For postgame specifically, you'll add it to BOTH `get_game_pitches()`
(CLI path) AND `get_game_pitches_for_app()` (app path) per the dual
query path rule (Ch 11 §3).

### Step 4 --- add to the report module

```python
# barrelsville/src/postgame_report.py
TABLE_COLS = [
    ...,
    {"key": "first_pitch_inzone_pct", "label": "1stPZ%", "fmt": "pct1"},
    ...
]
```

### Step 5 --- add to the app

`pages/1_Postgame.py` --- the column toggle UI typically reads from
`TABLE_COLS` directly so this auto-propagates. Check.

### Step 6 --- update parity in the OTHER two surfaces

Repeat steps 3-5 in the matching files for the other two surfaces.
Same SQL fragment, same column key, same display format.

### Step 7 --- run all three

On the work laptop:

```bash
# Tracker (live in Streamlit)
streamlit run barrelsville/Barrelsville.py
# Verify the column appears in the Affiliate Tracker

# KPI weekly (CLI)
python barrelsville/scripts/generate_hitter_kpi_report.py --end 2026-05-08 --weeks 2 --level aaa
# Verify the column appears in the PDF

# PD Goals org KPI (CLI)
python pd-goals/scripts/generate_org_kpi.py --end 2026-05-08 --level aaa
# Verify the column appears in the org KPI PDF
```

For a known player, **all three should produce identical values**.
That's the parity check.

### Step 8 --- commit on the right branch

If your change touched only Barrelsville:

```bash
cd bsb-wt-hitting
git add -p && git commit -m "feat(hitter-kpi): add 1stPZ% column" && git push
```

If it touched all three (likely):

```bash
# Barrelsville
cd bsb-wt-hitting && git add -p && git commit -m "..." && git push

# Arm Farm (only if pitcher-side change)
cd ../bsb-wt-bullpen && git add -p && git commit -m "..." && git push

# PD Goals
cd ../bsb-resources && git add -p && git commit -m "..." && git push
```

Three commits on three branches for one logical feature. Normal
overhead for the role.

## Recipe 3: Add a new report (or report variant)

A coach asks for a brand-new report ("can we ship a per-pitcher
splits report comparing vs LHH and vs RHH side-by-side?").

### Step 1 --- find the closest existing report

```bash
ls bullpen-report/src/*report*.py
ls bullpen-report/scripts/generate_*.py
```

For pitch splits, `advance_pitching_report.py` is structurally
similar (per-pitcher, multi-page, shows specific matchup). Or
`postgame_report.py` for general per-pitcher layout.

### Step 2 --- copy + rename + simplify

```bash
cp bullpen-report/src/advance_pitching_report.py \
   bullpen-report/src/splits_report.py
cp bullpen-report/src/advance_pitching_data.py \
   bullpen-report/src/splits_data.py
cp bullpen-report/scripts/generate_advance_pitching.py \
   bullpen-report/scripts/generate_splits.py
```

Strip out everything specific to the source report. Keep the
boilerplate (PDF header, page setup, channel routing).

### Step 3 --- add to manifest.json

```json
"src/splits_report.py": {"checksum": ""},
"src/splits_data.py": {"checksum": ""},
"scripts/generate_splits.py": {"checksum": ""},
```

Critical (Ch 2 §Posit Connect). New `src/*.py` files MUST be in
`manifest.json` or they're silently excluded from the deploy.

### Step 4 --- write the data layer

In `splits_data.py`, define the queries you need. Use the standard
pitching skeleton (Ch 12). Apply the BIP filter chain + bunt
exclusion + EV misread + Tier 1 gate as relevant (Ch 6).

### Step 5 --- write the PDF generator

In `splits_report.py`, define `generate_splits_report(...)`. Use
plottable + matplotlib for tables, follow `pdf-patterns.md`
conventions:

- Always call `_fix_null_bbox()` after creating a percentile-colored
  plottable table
- Never use `fontdict` and `fontsize` together in matplotlib
- Match header layout from a closest sibling (postgame style)

### Step 6 --- write the CLI

In `generate_splits.py`, set up argparse and call the data + report
functions. Follow the standard arg shape:

```python
parser.add_argument("--date", required=True)        # or --end
parser.add_argument("--pitcher", help="GC ID")
parser.add_argument("--level", default="aaa")
parser.add_argument("--deliver", action="store_true")
parser.add_argument("--logic-app-url",
                    default=os.environ.get("LOGIC_APP_URL"))
```

For delivery, copy `_deliver_pdf` from a working sibling --- never
write from scratch (Ch 13 §payload shape).

### Step 7 --- run, verify, deploy

```bash
# Test locally
python bullpen-report/scripts/generate_splits.py --date 2026-05-08 --pitcher 244959

# Deploy to Connect
cd bullpen-report
rsconnect deploy streamlit . --server https://connect2.astros.com \
    --api-key $env:CONNECT_API_KEY --title "Arm Farm"
```

### Step 8 --- document the new report

Add a row to the relevant `.claude/rules/<app>.md` file under
"Scripts" so the next agent knows it exists. Add a row to
`docs/handbook/08-app-arm-farm.md` (if you're updating the
handbook). Commit.

## Recipe 4: Debug a three-surface parity divergence

A coach reports "Pena's contact rate is 5% in the tracker but 7% on
the postgame report." Drift across surfaces is a real bug.

### Step 1 --- isolate

Reproduce both numbers on the work laptop:

```bash
# Tracker
streamlit run barrelsville/Barrelsville.py
# Navigate to Affiliate Tracker, find Pena, note Ctct%

# Postgame
python barrelsville/scripts/generate_postgame.py --date 2026-05-08 --batter <pena_gc_id>
# Open the PDF, find Ctct%
```

### Step 2 --- find the metric formula in each surface

```bash
grep -rn "ctct_pct\|contact_pct" barrelsville/src/
```

Tracker: `barrelsville/src/tracker_data.py` SELECT clause.
Postgame: `barrelsville/src/postgame_data.py::compute_game_stats`.

### Step 3 --- compare the formulas line-by-line

| Field | Tracker | Postgame | Same? |
|---|---|---|---|
| Numerator | `SUM(swings - whiffs)` | `n_contact` | Yes if same WHIFF_CODES |
| Denominator | `SUM(swings)` | `n_swings` | Yes if same swing detection |
| WHIFF_CODES | `(10, 16, 21, 22, 23, 25)` | `(10, 16, 21, 22, 23, 25)` | Same |
| `did_swing` gate | required | required | Same |
| Date filter | season-to-date | game-only | DIFFERENT WINDOW (expected) |
| Junk level filter | yes | yes | Same |
| Bunt exclusion | not relevant for Ctct% | not relevant | --- |

In this example: the date window differs (tracker shows season, postgame
shows the single game). That's not a bug --- the coach is comparing
season vs game. Educate the coach.

### Step 4 --- if formulas truly differ, find the bug

If the formulas above don't match (e.g. WHIFF_CODES differ between
surfaces, or one applies a filter the other doesn't):

1. Identify which surface is correct (usually the one matching GC2
   production). Reference `.claude/rules/gc2-metrics.md` for the
   canonical formulas.
2. Fix the divergent surface.
3. Verify the fix doesn't break the OTHER surface(s).
4. Run all three: tracker, KPI weekly, org KPI. All should produce
   the same value for this player on the same window.

### Step 5 --- common parity bugs (skim before going deep)

Most parity bugs match one of these patterns:

- **wOBA denom uses PA count instead of `AB+BB-IBB+HBP+SF`** (Ch 11 §7)
- **Multi-level rollup weights by `n_pitches` instead of per-metric `n_obs`** (Ch 11 §2)
- **Cross-level percentile pooling** (weighted-avg of P99s ≠ pooled P99) (Ch 11 §2)
- **Damage% rounded in decimal space instead of percentage space** (Ch 6)
- **CSC column mismatch (level-adjusted vs MLB-model)** (Ch 4 §2)
- **Junk level codes leak through with `sched_type='R'` only** (Ch 3)

Check these first.

### Step 6 --- run the parity diagnostic if one exists

Some metrics have a dedicated diagnostic SQL:

- xwOBA: `sql-queries/xwoba-parity-diag.sql`
- gcOBA: `python scripts/gcoba_diagnostic.py --batter <gc_id> --start <date> --end <date>`
- Bat speed: `.claude/rules/bat-speed-canonical.md` Implementation Playbook

These produce side-by-side comparisons of the surfaces.

### Step 7 --- propagate the fix across worktrees

If the bug is in a `.claude/rules/` referenced pattern, update the
rule file across all four worktrees (Recipe 5).

## Recipe 5: Propagate a fix across worktrees

You fixed a metric formula in Barrelsville. The same pattern exists
in three other apps. Time to propagate.

### Step 1 --- identify the affected files in each worktree

```bash
# In each worktree:
grep -rn "<metric_name>\|<column_name>" \
    bsb-wt-hitting/barrelsville/src/ \
    bsb-wt-bullpen/bullpen-report/src/ \
    bsb-wt-intangibles/astros-intangibles/intangibles/src/ \
    bsb-resources/pd-goals/src/
```

### Step 2 --- apply the same fix in each worktree

Each worktree is its own Git branch. Make the change, commit, push
PER worktree:

```bash
cd bsb-wt-bullpen
# edit src/...
git add -p && git commit -m "fix(<metric>): match canonical formula" && git push

cd ../bsb-wt-intangibles/astros-intangibles
# edit src/...
git add -p && git commit -m "fix(<metric>): match canonical formula" && git push

cd ../../bsb-resources
# edit pd-goals/src/...
git add -p && git commit -m "fix(<metric>): match canonical formula" && git push
```

### Step 3 --- update the rule

If the fix changed a canonical pattern, update the relevant `.claude/rules/<topic>.md`
file. Then sync the updated rule to all four worktrees:

```bash
# Use the document-pattern skill or copy manually:
for wt in bsb-wt-hitting bsb-wt-bullpen bsb-wt-intangibles/astros-intangibles bsb-resources; do
  cp bsb-resources/.claude/rules/<topic>.md ${wt}/.claude/rules/<topic>.md
  cd ${wt} && git add .claude/rules/<topic>.md \
     && git commit -m "docs(rules): sync <topic>.md" && git push && cd -
done
```

### Step 4 --- log the graduation

If the fix codified a NEW pattern, add an entry to
`.claude/rules/.graduation-log.md`. Future agents will read this.

## Daily / weekly operational recipes

### Daily (game days) on the work laptop

```powershell
# 1. Pull all four worktrees
cd C:\Users\zbridger\bsb-resources && git pull
cd C:\Users\zbridger\bsb-wt-hitting && git pull
cd C:\Users\zbridger\bsb-wt-bullpen && git pull
cd C:\Users\zbridger\bsb-wt-intangibles\astros-intangibles && git pull

# 2. Set environment variables (once per session)
$env:LOGIC_APP_URL = "https://prod-23..."
# (LOGIC_APP_URL already in $PROFILE if set up)

# 3. Run the postgame batch for yesterday's date
$DATE = "2026-05-07"

# Hitter postgame (Barrelsville)
cd C:\Users\zbridger\bsb-wt-hitting\barrelsville
python scripts\generate_postgame.py --date $DATE --milb --deliver

# Pitcher postgame (Arm Farm)
cd C:\Users\zbridger\bsb-wt-bullpen\bullpen-report
python scripts\generate_postgame.py --date $DATE --milb --deliver

# Fielding + BR + Catcher postgame (Intangibles)
cd C:\Users\zbridger\bsb-wt-intangibles\astros-intangibles\intangibles
python scripts\generate_br_report.py --date $DATE --deliver
python scripts\generate_of_report.py --date $DATE --deliver
python scripts\generate_if_report.py --date $DATE --deliver
python scripts\generate_catcher_report.py --date $DATE --deliver
```

### Weekly (Sunday) on the work laptop

```powershell
$END = "2026-05-08"

# 1. Six per-domain KPI weeklies (each delivers to per-domain channels)
cd C:\Users\zbridger\bsb-wt-hitting\barrelsville
python scripts\generate_hitter_kpi_report.py --end $END --weeks 2 --deliver

cd C:\Users\zbridger\bsb-wt-bullpen\bullpen-report
python scripts\generate_pitcher_kpi_report.py --end $END --weeks 2 --deliver

cd C:\Users\zbridger\bsb-wt-intangibles\astros-intangibles\intangibles
python scripts\generate_of_kpi_report.py --end $END --weeks 2 --deliver
python scripts\generate_if_kpi_report.py --end $END --weeks 2 --deliver
python scripts\generate_br_kpi_report.py --end $END --weeks 2 --deliver
python scripts\generate_c_kpi_report.py  --end $END --weeks 2 --deliver

# 2. Combined KPI stapler — affiliate channels
cd C:\Users\zbridger\bsb-resources\pd-goals
python scripts\generate_combined_kpi.py --end $END --deliver
```

### Series-day on the work laptop

```powershell
# Hitter advance (Barrelsville)
cd C:\Users\zbridger\bsb-wt-hitting\barrelsville
python scripts\generate_advance_batch.py --level aaa --deliver

# Pitcher advance (Arm Farm)
cd C:\Users\zbridger\bsb-wt-bullpen\bullpen-report
python scripts\generate_advance_pitching_batch.py --level aaa --deliver

# Hitter advance for opposing pitching staff (Intangibles defensive positioning)
cd C:\Users\zbridger\bsb-wt-intangibles\astros-intangibles\intangibles
python scripts\generate_hitter_advance.py --level aaa --series 2026-05-09 --deliver
```

### Connect-scheduled jobs (no manual run needed)

These run automatically every 6 hours on Posit Connect:

- `pin_goals.py` (PD Engine) → refreshes `zbridger/pd_goals_data`
- `pin_tracker_2026.ipynb` (Barrelsville) → refreshes
  `zbridger/barrelsville_tracker_2026`
- (same for Arm Farm, BR, Fielding, Catcher trackers)

If a Connect-scheduled job fails, you'll get an email
notification (if Email tab is enabled). To investigate, log into
Connect → Content → <job> → Logs.

## Where to look next

- **Chapters 11-13** for the underlying patterns each recipe relies on.
- `.claude/rules/` --- canonical rules for every topic.
- The `sql-queries/` directory --- look at recent commits to see what
  one-offs other engineers have written.
