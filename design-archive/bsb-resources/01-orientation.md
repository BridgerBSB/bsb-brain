# Orientation

Welcome to Houston Astros Player Development analytics. This chapter
covers what the role is, who you're working with, and how to get the
keys you need before any code makes sense.

::: tip
**What you'll learn:** the team you're joining, the four apps in
production, the two laptops you'll switch between, the cadence of a
typical week, and the people to ask when you're stuck.
:::

## What the role is

You're joining the Player Development analytics team. Zac Bridger
(PD analyst) builds and maintains four live Streamlit apps that ship
daily PDF reports to coaches and players via Slack. You'll work
directly with him. Your job is to:

1. Help build new reports, metrics, and visualizations.
2. Run one-off SQL queries when a coach, scout, or front-office staffer
   asks a specific question.
3. Maintain the three-surface parity that keeps every metric matching
   across the trackers, the KPI weekly reports, and PD Goals (more on
   this in Chapter 11).
4. Keep the canonical rules in `.claude/rules/` accurate as the codebase
   evolves.

The role is **code-heavy**: SQL, Python, baseball domain knowledge. You
will write more SQL than Python. The handbook assumes you're fluent in
both; if you hit something unfamiliar, ask Claude or codex --- both
have full access to this codebase.

## The four apps you'll work with

| App | Domain | Branch | Worktree |
|---|---|---|---|
| **PD Engine** (Goals + Org Board + Transition) | Player development goals, org roster, transition reports | `feature/pd-goals` | `bsb-resources/` (this repo) |
| **Barrelsville** | Hitting analytics --- postgame, advance scouting, KPI weekly, hitter analysis | `feature/barrelsville` | `bsb-wt-hitting/` |
| **Arm Farm** | Pitching analytics --- bullpens, postgame, advance scouting, KPI weekly | `feature/bullpen-reports` | `bsb-wt-bullpen/` |
| **Intangibles** | Baserunning + Outfield + Infield + Catcher analytics | `feature/astros-intangibles` | `bsb-wt-intangibles/astros-intangibles/` |

Each app has its own subdirectory, its own Streamlit deploy on Posit
Connect, and its own per-domain Slack channels. They all read from the
same database (`GroundControl2` on `gcsql02`), share `.claude/rules/`
canonical documentation, and follow the same SQL/PDF/Logic-App patterns.

The four apps live on **separate Git branches** for parallel work; each
branch has its own working directory (a Git "worktree"). This lets one
engineer (or multiple Claude agents) work on Barrelsville changes while
another works on Intangibles without merge conflicts.

::: blocking
**Never push to `main` for testing.** Everything goes to the feature
branch first. Merges to `main` happen at milestones --- never as a
shortcut to deploy. See Chapter 2 for the full ship cycle.
:::

## Hardware and accounts

You'll work across **two laptops** for one specific reason: the work
laptop has DB access, the personal laptop has Claude Code installed.

### Personal laptop (Windows 11, primary dev machine)

- Path: `C:\Users\<username>\bsb-resources\` (and worktree siblings)
- **Claude Code** installed and configured
- **GitHub SSH key** for `git push` / `git pull`
- **No DB access** --- can't run live queries here
- Pandoc + xelatex via TinyTeX for handbook builds

### Work laptop (Windows, behind Astros VPN)

- DB access via ODBC Driver 17 (Windows Auth, `BASEBALL\<username>`)
- Python 3.13
- **Claude Code BLOCKED** (IT policy) --- you can't run agents here
- Posit Connect deploys land via `rsconnect`
- Slack delivery via the Logic App (URL in env var, see Ch 13)

### The handoff cycle

```
1. Personal laptop: write code with Claude Code
2. git commit + git push (feature branch)
3. Work laptop: git pull, run against live DB to verify
4. Fix on personal laptop, push, pull on work laptop, repeat
```

You can't shortcut this. IT has explicitly blocked Claude on the work
laptop and DB access on the personal laptop --- both decisions are
permanent. The cycle is the workflow.

## Accounts and credentials

Day 1 setup --- ask Zac or Chris Josefy (Supervisor of Data) for:

- **GitHub access** to the `bsb-resources` repo (private)
- **Astros VPN credentials**
- **Posit Connect login** at `https://connect2.astros.com`
- **Slack** workspace access + the player-development workspace
- **GroundControl2 DB access** request through IT
- **Connect API key** (for parquet pin reads) --- already set in each
  Connect app's Vars tab; you only need it for CLI pin writes

::: note
Don't try to install Claude Code on the work laptop. It's been
attempted multiple times. IT policy blocks it. Develop on the personal
laptop and verify on the work laptop --- that's the workflow.
:::

## Weekly cadence

A typical week looks like this:

| Cadence | Who runs it | What ships |
|---|---|---|
| **Daily (game days)** | Postgame CLIs on work laptop | Per-pitcher pitcher postgame PDFs (Arm Farm), per-batter hitter postgame PDFs (Barrelsville), per-runner BR postgame PDFs (Intangibles), per-fielder OF/IF postgame PDFs (Intangibles), per-catcher postgame PDFs (Intangibles) |
| **Weekly (Sunday)** | Six KPI weekly CLIs in sequence + the combined-KPI stapler | Six per-domain PDFs to per-domain Slack channels + ONE combined KPI PDF per affiliate level to the affiliate Slack channel |
| **On series** | Advance scouting batch CLIs | Hitter advance PDFs (Barrelsville), pitching advance PDFs (Arm Farm), hitter advance PDFs (Intangibles --- defensive positioning) |
| **Continuous** | Live Streamlit apps on Posit Connect | Coaches and coordinators interact directly --- no batch step |
| **Every 6 hours** | Connect-scheduled pin refresh jobs | Tracker parquet pins refresh for current season; historical years stay frozen |

## Slack channels you'll see traffic in

Channel naming follows a strict convention:

- `zzz_<player_name>` --- coach-facing channel for that player
  (postgame reports, KPI metrics, advance scouting)
- `z_<player_name>` --- player-facing athlete channel
  (PD Goals, transition reports, development feedback)
- `sugarland_<domain>`, `corpus_<domain>`, `asheville_<domain>`,
  `fayetteville_<domain>`, `fcl_<domain>`, `dsl_<domain>` ---
  per-affiliate per-domain channels (one per app per level)
- `z1_sugar_land`, `z2_corpus_christi`, `z3_asheville`,
  `z4_fayetteville`, `wpb_complex` (FCL), `z8_dominican_academy` (DSL)
  --- general affiliate channels (combined KPI stapler delivers here)
- `pd-automation-test` (`C0ABHSF6SCA`) --- overflow / test channel for
  any delivery without a real channel mapping
- `weekly-player-updates` (`C0AVBKPEG8H`) --- single channel for
  org-wide analysis + KPI snapshot PDFs

The full mapping lives in `pd-goals/data/slack_channels.csv`. This
file is the **single source of truth** for channel routing across
ALL four apps. See Chapter 13 for the routing details and the
five-copy sync rule.

## Who's who

| Person | Role | When to ping |
|---|---|---|
| **Zac Bridger** | PD analyst (you'll work directly with him) | Anything code, anything pattern --- he wrote most of the canon |
| **Chris Josefy** (`cjosefy@astros.com`) | Supervisor of Data | DB access requests, IT issues, anything VPN |
| **Adam Brodie** | R&D | DB schema questions, metric formulas (he wrote a lot of GC2) |
| **Sam Niedorf** | Farm Director | Org-level rollup requests, age-vs-league questions |
| **Cristian** | Pitching directional input on goals (FPinZ%, FB velo targets, IF arm goals) | Pitching metric direction --- ask Zac for current title |
| **Perez** | Pitching directional input (FF usage vs RHH in pre-2K counts) | Same area as Cristian; may or may not be the same person --- ask Zac |
| **Kyle Brennan** | Set the advance scouting page-1 layout (May 2026) based on coach feedback | Advance report layout questions --- ask Zac for current title |
| **Mazzo** | Drove the OF positioning project requirements (May 2026) | OF positioning + spray chart questions --- ask Zac for current title |
| **Nick Arrivo** | Wrote the UDFA detection pattern for PP_MASTER queries | UDFA roster patterns, PP_MASTER details --- ask Zac for current title |

When something looks wrong on a report, the diagnostic order is:

1. Check `.claude/rules/` for a known BLOCKING rule on that metric
2. Run the diagnostic SQL (some live in `sql-queries/`, more in
   per-app `scripts/`)
3. Compare against another surface (tracker vs KPI weekly vs PD
   Goals --- see Chapter 11 on three-surface parity)
4. Ask Zac

## Reading the rest of this handbook

If you have one full day before your first task, read in this order:

1. **Chapter 2** (Stack & Workflow) --- ~1 hr
2. **Chapter 3** (Database Tour) --- ~2 hr, mark it up heavily
3. **Chapter 4** (GC2 & Deviations) --- ~1 hr
4. Skim **Chapter 5** (Metric Catalog) --- ~30 min, keep handy
5. **Chapter 6** (Data Cleaning Canon) --- ~1 hr, read closely
6. Pick ONE app chapter (7-10) most relevant to your first task --- ~1 hr
7. Skim **Chapters 11-15** --- ~30 min, bookmark for later

About 7 hours of focused reading. The rest is reference.

## Where to look next

- **Chapter 2** for the actual dev workflow.
- `.claude/rules/` is the canonical knowledge base. Each rule has a
  YAML frontmatter telling you which file paths it auto-applies to
  when Claude is editing.
- `CLAUDE.md` at the repo root is the master orientation document for
  Claude agents --- it links to everything.
