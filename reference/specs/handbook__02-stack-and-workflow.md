# Stack & Workflow

Everything we ship is Python + SQL Server + Streamlit + Slack delivery.
This chapter covers the tech stack, the four-worktree branch strategy,
the dev cycle, and how a feature actually goes from your laptop to a
coach's phone.

::: tip
**What you'll learn:** the Python and database stack we use, why we
have four worktrees, the personal-laptop/work-laptop dance, how
Posit Connect deploys work, and how the PDF-to-Slack pipeline ships.
:::

## The Python stack

| Layer | Library | What we use it for |
|---|---|---|
| Web app | **Streamlit** | All four apps; multi-page sidebar pattern |
| Plotting (interactive) | **Plotly** | Live charts inside Streamlit pages |
| Plotting (static) | **matplotlib** + custom helpers | Every PDF chart (zone plots, density heatmaps, KDE, scatter) |
| PDF generation | **reportlab** + **matplotlib** PDF backend | Postgame, KPI weekly, advance, snapshot reports |
| PDF assembly | **pypdf** | Combined KPI stapler |
| Data | **pandas**, **numpy** | Everything |
| DB driver | **pyodbc** + **SQLAlchemy** | All DB access |
| Cache layer | **pins** (Posit Connect pins) + `lru_cache` + `@st.cache_data` | Tracker parquet pins, percentile pools, league environments |
| Slack delivery | `requests.post` to Azure Logic App HTTP trigger | All PDF delivery |

Python version: **3.11+** on personal laptop, **3.13** on work laptop,
**3.11** on Posit Connect (locked --- handbook + scheduled jobs target
this version).

::: blocking
**The four apps share NO Python code at the module level.** Each
worktree has its own `src/`, its own `pages/`, its own `database.py`.
Three copies of `deliver.py` exist (one per non-PD-Engine worktree)
and they're functionally identical. If you change a pattern in one
copy, change it in the others --- this is what `.claude/rules/` are
for, and what the cross-worktree sync skills enforce.
:::

## The database stack

| Property | Value |
|---|---|
| **Server** | `gcsql02.astros.com` |
| **Database** | `GroundControl2` |
| **Auth (work laptop)** | Windows Auth via ODBC Driver 17 (`BASEBALL\<username>`) |
| **Auth (Posit Connect)** | FreeTDS via `DB_USER` / `DB_PASS` env vars |
| **Schemas you'll touch** | `Astros.*` (org-wide), `MLBAM.*` (league-wide Statcast), `Guts.*` (linear weights), `MLB_eBis.*` (rosters), `groundcontroltracking.tracking.*` (HawkEye tracking) |

Full schema reference is in **Chapter 3**. The fact that the personal
laptop has no DB access and the work laptop has no Claude Code creates
the dev cycle described below.

## The four-worktree strategy

A Git worktree is a working directory that points at a different branch
of the same repository. Instead of `git checkout` (which switches the
active branch in one directory), worktrees give you four directories
each pinned to one branch:

```
C:\Users\<user>\
  ├─ bsb-resources\                              # main repo, feature/pd-goals
  ├─ bsb-wt-hitting\                              # feature/barrelsville
  ├─ bsb-wt-bullpen\                              # feature/bullpen-reports
  └─ bsb-wt-intangibles\astros-intangibles\       # feature/astros-intangibles
```

Why four? Three reasons:

1. **One branch per project.** Hitting changes don't touch fielding;
   pitching changes don't touch baserunning. Each project deploys
   independently to Posit Connect.
2. **Parallel work.** Multiple Claude agents can work in different
   worktrees concurrently without `git stash` dances or merge fights.
3. **Cross-app patterns share via `.claude/rules/`.** The four
   worktrees have IDENTICAL copies of `.claude/rules/`. When you change
   a rule, sync it to all four worktrees in lockstep
   (`document-pattern` skill handles this).

::: blocking
**You'll see "BLOCKING: this rule is mirrored across all four
worktrees" callouts often.** When you see one, the change MUST land
on all four branches in the same session. Otherwise the apps drift
silently.
:::

### Which worktree is which app?

| App | Worktree | Branch | Subdirectory inside worktree |
|---|---|---|---|
| PD Engine | `bsb-resources` | `feature/pd-goals` | `pd-goals/` |
| Barrelsville | `bsb-wt-hitting` | `feature/barrelsville` | `barrelsville/` |
| Arm Farm | `bsb-wt-bullpen` | `feature/bullpen-reports` | `bullpen-report/` |
| Intangibles | `bsb-wt-intangibles/astros-intangibles` | `feature/astros-intangibles` | `intangibles/` |

The shared root contains `sql-queries/`, `astros-docs/`, `docs/`, and
`.claude/` --- those are the same across all four worktrees because
worktrees share the same `.git/` directory.

## The dev cycle

A feature ships in this loop. Most features take 5-15 cycles before
they're production-ready:

```
┌─────────────────────────────────────────────────────────────┐
│  Personal laptop (Windows, Claude Code, no DB)              │
│                                                              │
│  1. cd bsb-wt-hitting/  (or whichever worktree)             │
│  2. git pull                                                 │
│  3. Edit code with Claude                                    │
│  4. git add + git commit                                     │
│  5. git push   (always to feature branch — never to main)   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼  (work laptop pulls)
┌─────────────────────────────────────────────────────────────┐
│  Work laptop (Windows, DB access, no Claude Code)           │
│                                                              │
│  6. cd <worktree>                                            │
│  7. git pull                                                 │
│  8. python scripts/<cli>.py --date 2026-05-08  (test live)  │
│  9. (Optional) python -m streamlit run <App>.py             │
│  10. Verify: numbers right? PDF correct? Slack delivery?    │
│  11. If broken, jump back to step 3 on personal laptop      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼  (when verified)
┌─────────────────────────────────────────────────────────────┐
│  Deploy to Posit Connect (work laptop)                      │
│                                                              │
│  12. rsconnect deploy streamlit <app-dir>/                  │
│  13. Verify the deployed app pulls the new code             │
│  14. Stop. Don't merge to main yet.                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼  (only at milestones)
┌─────────────────────────────────────────────────────────────┐
│  Merge feature → main                                       │
│  (rare; only at logical project milestones)                 │
└─────────────────────────────────────────────────────────────┘
```

::: blocking
**Step 5 is the BLOCKING rule.** Push to feature branch, never to
main. Pull from feature branch on the work laptop. Merge to main only
when a milestone is genuinely complete. This rule exists because main
has historically been the deploy target and pushing un-tested commits
there has caused production breaks.
:::

## Posit Connect

`https://connect2.astros.com` --- the Posit Connect server that hosts
all four apps + the scheduled pin-refresh jobs.

### What's deployed there

| Content type | Examples |
|---|---|
| **Streamlit apps** | All four (PD Engine, Barrelsville, Arm Farm, Intangibles) |
| **Scheduled jobs** (Jupyter notebook + Python script bundles) | Goals pin refresh, tracker pin refresh (one per tracker), drift alerts |
| **Pins (parquet/joblib)** | `zbridger/pd_goals_data` (canonical goals roster), `zbridger/<app>_tracker_<year>` (six historical years across all five trackers), `zbridger/transition_reports`, `zbridger/transition_drafts` |

### Deploy via `rsconnect-python`

The work laptop has `rsconnect.exe` at
`C:\Users\zbridger\AppData\Roaming\Python\Python314\Scripts\`. Standard
deploy command for a Streamlit app:

```powershell
cd <worktree>/<app-dir>
rsconnect deploy streamlit . --server https://connect2.astros.com `
    --api-key $env:CONNECT_API_KEY --title "<App Name>"
```

The `manifest.json` in each app dir is the **allow-list** Connect uses
to bundle the deploy. **New `src/*.py` files MUST be added to
`manifest.json` or they're silently excluded** from the deployed bundle
and the app errors at runtime with `ModuleNotFoundError`.

::: blocking
This is the #1 cause of "deploy succeeded but the new feature doesn't
work" --- the new module didn't make it into the bundle. Always update
`manifest.json` in the same commit that adds a new `src/*.py` file.
:::

### Connect-scheduled jobs

Some jobs (tracker pin refreshes, goals pin refresh, drift alerts) run
on Connect's scheduler --- typically every 6 hours during the season.
They're deployed as Jupyter notebooks (`appmode: jupyter-static`)
wrapping the underlying Python script. See Chapter 13 for the full
setup playbook --- there are 8 known gotchas around manifest BOM
encoding, Python version pinning, and DB credential injection.

## The PDF + Slack delivery pipeline

```
Python CLI / Streamlit submit handler
         │
         │ generates PDF on disk
         ▼
   base64-encode PDF
         │
         │ POST {"channel": cid, "filename": fn, "pdf": b64}
         ▼
Azure Logic App HTTP trigger
         │
         │ pd-report-delivery → astros-file-uploader
         ▼
       Slack channel
```

The Logic App is a **dumb pipe** --- routing and channel resolution
happens in Python. The Logic App URL lives in the
`LOGIC_APP_URL` environment variable. On the work laptop, set it once
in your PowerShell `$PROFILE` and forget it.

::: blocking
**The payload field names are exactly `channel`, `filename`, `pdf`.**
Get any of them wrong and the Logic App returns HTTP 200 but nothing
shows up in Slack. This silent-failure mode has burned us before.
Never write a delivery wrapper from scratch --- always copy from a
working `_deliver_pdf` function in a sibling script. Full details in
Chapter 13.
:::

## Where the apps actually run

| App | URL | Refresh |
|---|---|---|
| PD Engine | `connect2.astros.com/pd-engine/` | Live (no pin --- direct DB) |
| Barrelsville | `connect2.astros.com/barrelsville/` | Live --- tracker pages backed by parquet pins (frozen historical, 6h current-year refresh) |
| Arm Farm | `connect2.astros.com/arm-farm/` | Live --- tracker pages backed by parquet pins |
| Intangibles | `connect2.astros.com/intangibles/` | Live --- four trackers (BR / Catcher / OF+IF / KPI) backed by parquet pins |

The Connect server lives behind the Astros VPN. Coaches and
coordinators reach it from their laptops on the corporate network or
through the VPN.

## Standard scripts every app has

Each app has a `scripts/` directory with command-line entry points.
You'll be running these on the work laptop daily:

| Script type | Examples | Cadence |
|---|---|---|
| Daily postgame | `generate_postgame.py` (Barrelsville hitter, Arm Farm pitcher), `generate_br_report.py`, `generate_of_report.py`, `generate_if_report.py`, `generate_catcher_report.py` | Game days |
| Weekly KPI | `generate_hitter_kpi_report.py`, `generate_pitcher_kpi_report.py`, `generate_of/if/br/c_kpi_report.py` | Sundays |
| KPI stapler | `pd-goals/scripts/generate_combined_kpi.py` | Sundays after the 6 weekly KPIs |
| Advance scouting | `generate_advance.py`, `generate_advance_batch.py`, `generate_hitter_advance.py` | On series |
| Org-wide analysis | `hitter_analysis.py`, `pitcher_analysis.py`, `kpi_snapshot_3.py`, `pitcher_kpi_snapshot.py` | Periodic |

Each script has a consistent CLI:

- `--date YYYY-MM-DD` for daily reports
- `--end YYYY-MM-DD --weeks N` for weekly reports
- `--level mlb|aaa|aax|afa|afx|rok|dsl` to scope to a level
- `--deliver` to push to Slack via the Logic App
- `--logic-app-url <url>` to override the env var if needed

You'll learn each script as you encounter it. Chapter 14 has the
"add a new script" recipe.

## A typical first task

Your first non-trivial task will probably be one of:

1. **Run a one-off SQL query** for a coach question
   ("show me HOU MiLB pitchers with FF velo above 95 vs LHH this
   month"). This involves: identifying which level/sched_type to
   filter, finding the right reference query in `sql-queries/`,
   adapting it, and running it on the work laptop.
2. **Add a new metric column** to an existing report. This involves
   the three-surface parity check (Ch 11), updating the data module +
   report module + app page, and re-running the report on the work
   laptop to verify.
3. **Fix a divergence** between two surfaces (someone says
   "Pena's contact rate is 5% in the tracker but 7% on the postgame").
   This is the bread and butter of the role. Chapter 11 has the
   recipe.

In all three cases, the first move is **read the relevant rule files
and reference implementation** (Ch 6, 11, 14) before touching code.

## Where to look next

- **Chapter 3** for the database itself --- which tables hold what,
  how to join them, and what the IDs map to.
- `CLAUDE.md` at the repo root for the master orientation Claude
  uses --- a quick refresher on which rule files load when.
- The actual files: pick a worktree (`barrelsville/` for hitting), run
  `tree -L 2` and look at `pages/`, `src/`, `scripts/`. Pattern is
  identical across all four apps.
