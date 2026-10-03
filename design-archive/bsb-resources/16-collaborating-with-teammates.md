# Collaborating with Teammates

You are joining a codebase that one PD analyst (Zac Bridger) built solo,
then opened up. The branching pattern, deploy auth, and rule-sync rituals
were originally built for one author — this chapter explains how your
day-to-day plugs in cleanly. By week two you should be running reports,
re-pinning data, and editing live config the same way he does. There's
no gatekeeping; there's a Day-One handoff so you have the same keys he
does.

::: tip
**What you'll learn:** the branch model you'll use, your Day-One setup
(GitHub access + Connect API key + DB access), the daily git flow,
which files require coordination before editing, what running reports
day-to-day looks like, and the PR conventions for getting your work
merged.
:::

## The mental model

| Layer | Owner |
|---|---|
| `main` | Milestone-only. Nobody works directly here. |
| `feature/<project>` (long-lived) | Zac's primary working branch per app (`feature/pd-goals`, `feature/barrelsville`, `feature/bullpen-reports`, `feature/astros-intangibles`). Already live on Posit Connect. |
| `feature/<project>/intern/<your-task>` (yours, short-lived) | You branch off the live feature branch, push your work here, open a PR back into the feature branch. |
| Posit Connect deploys | Both of you have keys after Day-One setup. |
| GroundControl2 (`gcsql02`) | Both of you have access — granted via R&D request in GC2 (checkmark icon, upper right). |

This is intentional. It means:

- Your branch can be broken, half-finished, or experimental — Connect doesn't see it.
- Zac reviews your PR before it touches anything coaches see.
- Both of you can work simultaneously without merge-conflict hell on shared files.
- You can re-pin and re-deploy without waiting on Zac.

## Day-One setup checklist

::: blocking
**Do not skip these.** A missing key or permission is the single biggest
source of "I can't push my work" or "the app doesn't see my edit"
frustration in week one.
:::

1. **Get added as a Collaborator** on the GitHub repo
   (`github.com/zbridger_astros/bsb-resources`). Zac does this from
   GitHub → Settings → Collaborators. You need **push** access.

2. **Set up SSH** to GitHub on your machine (`ssh-keygen` → upload
   public key to your GitHub account). HTTPS auth with username/password
   stopped working years ago.

3. **Receive the Connect API key from Zac.** This document is internal,
   so the actual keys are listed here. Two keys exist:

   | Key | Purpose | Value |
   |---|---|---|
   | `CONNECT_API_KEY` | Pin reads/writes from Python (`pins` library) | `H9MB6feNB2ccKfmoX9Q3DS7AykVhvNNb` |
   | `rsconnect` deploy key | `rsconnect deploy manifest …` CLI auth | `lbMcrPhsgeyCZnIjcXjBoIQZRWZKWMzO` |

   Set the pin key in your shell:

   ```powershell
   # Per session — for testing
   $env:CONNECT_API_KEY = "H9MB6feNB2ccKfmoX9Q3DS7AykVhvNNb"
   ```

   For persistence across shells, add it to your PowerShell profile:

   ```powershell
   notepad $PROFILE
   # Add the line:
   $env:CONNECT_API_KEY = "H9MB6feNB2ccKfmoX9Q3DS7AykVhvNNb"
   # Save, restart PowerShell, verify with: echo $env:CONNECT_API_KEY
   ```

   You'll need this for `python pd-goals/scripts/pin_goals.py` (re-pin
   goals), the four `pin_*_tracker_seasons.py` tracker re-pins, and the
   `connect_pins/deploy.ps1` scheduled-job deploys.

   For app deploys, pass the rsconnect key inline on the command:

   ```powershell
   C:\Users\<you>\AppData\Roaming\Python\Python314\Scripts\rsconnect.exe `
     deploy manifest . `
     --server https://connect2.astros.com `
     --api-key lbMcrPhsgeyCZnIjcXjBoIQZRWZKWMzO `
     --app-id <app-guid> `
     --title "<App Title>"
   ```

   App GUIDs are listed in `CLAUDE.md` per app (PD Engine
   `79f52369-…`, Arm Farm `13482bcb-…`, Intangibles `295a5205-…`,
   Barrelsville `bbb53548-…`).

4. **Confirm `gcsql02` DB access.** This is granted via the **R&D
   access request form inside GroundControl2** — open GC2 in your
   browser, click the **checkmark icon in the upper right**, fill
   out the request for `gcsql02.astros.com` read access, submit.
   R&D processes it. Most of these requests at the org are verbal
   follow-ups — if it's taking longer than a day, ping the R&D
   contact in Slack and remind them.

   You'll also need ODBC Driver 17 installed locally and a
   `BASEBALL\<username>` AD account (your standard Astros employee
   credentials). Test with:

   ```powershell
   python -c "from pd_goals.src.database import get_engine; print(get_engine().connect())"
   ```

   If that returns a connection object instead of an error, DB access is
   good. From here on, you can run any query in `sql-queries/` or any
   script under `scripts/` directly — no hand-off needed.

5. **Clone fresh** to a parent directory of your choice:

   ```
   git clone git@github.com:zbridger_astros/bsb-resources.git
   cd bsb-resources
   ```

6. **Set up the four worktrees** alongside the main clone. The sibling
   layout is documented in Chapter 2 — match Zac's exactly:

   - `bsb-resources/` → `feature/pd-goals` (PD Engine + main repo)
   - `bsb-wt-hitting/` → `feature/barrelsville` (Barrelsville)
   - `bsb-wt-bullpen/` → `feature/bullpen-reports` (Arm Farm)
   - `bsb-wt-intangibles/astros-intangibles/` → `feature/astros-intangibles` (Intangibles)

   The path names matter — the cross-worktree KPI stapler in
   `pd-goals/scripts/generate_combined_kpi.py` resolves these by relative
   path. Renaming any of them breaks the Monday cascade.

7. **Install Python 3.11** and the per-app `requirements.txt` for any
   app you'll touch. Chapter 2 covers this in detail.

## The daily git flow

When you start a task — anything from a one-line typo to a new report —
work in this exact order:

```bash
# 1) Move to the app's main feature branch and sync.
git checkout feature/barrelsville
git pull

# 2) Create a sub-branch named for what you're doing.
git checkout -b feature/barrelsville/intern/<short-task-name>

# 3) Do your work. Commit often.
git add <files>
git commit -m "feat(barrelsville): add Hard% column to AAA weekly hitter card"

# 4) Push your branch to GitHub.
git push -u origin feature/barrelsville/intern/<short-task-name>

# 5) Open a PR on GitHub that targets `feature/barrelsville`
#    (NOT main).
```

### Naming convention

`feature/<project>/intern/<task-slug>` — pick a slug under ~30 chars
that describes the work, not the file. Good examples from across the
apps:

- `feature/barrelsville/intern/blast-motion-srv-by-pt`
- `feature/bullpen-reports/intern/fpinz-handedness-split`
- `feature/astros-intangibles/intern/of-arm-floor-audit`
- `feature/pd-goals/intern/fcl-augpop-pool-gate`

Bad:

- `intern-branch` (no app context)
- `fix-stuff` (no signal)
- `feature/barrelsville/intern/jan` (just the date)

### Commit message format

Match the existing convention you'll see in `git log`:

```
<type>(<app>): <short description>

<optional longer body explaining WHY, not WHAT>
```

Types: `feat`, `fix`, `refine`, `docs`, `chore`, `perf`.
Apps: `pd-goals`, `barrelsville`, `arm-farm`, `intangibles`, `cross`.

Examples from real history across the apps:

- `feat(barrelsville): wire VBA at contact into postgame zone grid`
- `fix(arm-farm): IP/S NULL when ha_filter='all' (proportional split)`
- `feat(intangibles): catcher framing hexbin PDF, level-calibrated`
- `feat(pd-goals): wire AugPop in stats.py + percentiles.py`
- `docs(rules): graduate three-surface-parity Apr 25 fix`

Tiny commits, push often. Sitting on three days of work in a local
branch is how merge conflicts grow teeth.

## Pull-request conventions

When you open a PR back into `feature/<project>`:

1. **Title:** same shape as the commit message — `feat(<app>): ...`.
2. **Body:** one paragraph of context, plus a "Files touched" mini-table
   if it's more than three files. If the PR fixes a bug, link to
   what triggered it (a Slack screenshot, a coach question, a stack
   trace).
3. **Always include a test plan.** Now that you have DB access, this
   usually means actual verification: "Tested locally against AAA 2026
   data — Sacco wOBA matches GC2 (.330)." Synthetic-data fallbacks are
   fine when DB isn't relevant.
4. **Tag Zac as reviewer.** Don't merge your own PRs.

Zac merges via "Squash and merge" — your branch history compresses to
one commit on the feature branch. This keeps the long-term log clean
without taking away your ability to push WIP commits.

## What you'll own day-to-day

Once Day-One setup is complete, the dividing line between "you" and "Zac"
shifts dramatically. Here's the realistic split:

| Task | You | Zac |
|---|---|---|
| Write SQL queries in `sql-queries/` | Yes | — |
| Run any query against `gcsql02` | Yes | — |
| Write report / Streamlit / data-module code | Yes | — |
| Edit any `.claude/rules/*.md` (canonical copy) | Yes | Syncs to all 4 worktrees |
| Run the Monday weekly-reports cascade | Yes | — |
| Run an affiliate-tracker re-pin (`pin_*_tracker_seasons.py`) | Yes | — |
| Re-pin `goals.csv` after a CSV edit | Yes | — |
| Edit `pd-goals/data/slack_channels.csv` when new player picked up | Yes | — |
| Deploy a Streamlit app to Posit Connect | Yes | — |
| Trigger a `connect_pins/deploy.ps1` for a scheduled job | Yes | — |
| Open a PR | Yes | — |
| Merge a PR | — | Yes |
| Architectural decisions (new app, new metric system, schema change) | Discuss first | Reviews / decides |

The general rule: **once Day-One handoff is done, you and Zac have
symmetric capabilities.** PR merge is the only thing intentionally
funnelled through him — that's the review checkpoint, not a permissions
wall.

## Running reports (this is going to be a big part of your job)

You'll be responsible for running the daily / weekly / monthly report
cascades and shipping their PDFs to Slack. The full delivery
infrastructure is in Chapter 13 — this section is the operational
"what to actually run" pointer.

### Daily / postgame reports

After a game, the per-app postgame Streamlit pages (`pages/1_Postgame.py`
in Barrelsville and Arm Farm, `pages/4_Catching.py` in Intangibles, etc.)
let you select players, generate a cumulative PDF, and ship it via the
"Save Report" / "Deliver" buttons in-app. The on-screen view IS the
deliverable — no separate CLI run.

### Weekly KPI cascade (Mondays)

There's a slash-command for this: **`/monday`**. It runs the full
cascade across all 4 worktrees:

1. Per-app weekly KPI scripts (`barrelsville/scripts/generate_hitter_kpi_report.py`,
   `bullpen-report/scripts/generate_pitcher_kpi_report.py`,
   `intangibles/scripts/generate_{of,if,br,c}_kpi_report.py` — six total).
2. **Then** the combined KPI stapler
   (`pd-goals/scripts/generate_combined_kpi.py`) — this collates the
   six per-domain PDFs into one combined PDF per level and delivers to
   the affiliate channels. **NEVER re-add `AFFILIATE_CHANNEL_IDS` to
   the six individual scripts** — that delivery is owned exclusively
   by the stapler. See `.claude/rules/combined-kpi-stapler.md`.

Each individual KPI script delivers to its per-domain channel
(`sugarland_barrelsville`, `sugarland_armfarm`, etc.). The stapler
delivers to affiliate channels (`z1_sugar_land`, `z2_corpus_christi`, etc.).

### Tracker pin daily refresh

The five affiliate trackers (Barrelsville hitter, Arm Farm pitcher,
Intangibles BR / Fielding / Catcher) are pre-aggregated into parquet
pins on Posit Connect via Connect-scheduled jobs that fire every 6
hours. You don't run these manually unless something's gone sparse —
see `.claude/rules/tracker-parquet-pins.md` §10 "Sparse-pin recovery"
for the `repair_tracker_pin.py` workflow when a year shows incomplete
data.

### PD Goals re-pin

Whenever `pd-goals/data/goals.csv` changes (new player added,
end_date rolled, goal swapped), you re-pin so the deployed PD Engine
app reads the new data:

```powershell
cd C:\Users\<you>\bsb-resources
git pull
python pd-goals/scripts/pin_goals.py
```

~5-10 seconds. Connect picks up the new pin on next page load — no
redeploy needed.

### One-off / boss-ask reports

When the GM, Farm Director, or a coach asks for a specific cut
("PoC depth for all 2024 first-rounders" / "FB velo YoY by affiliate"
/ "Schiavone's contact rate by pitch type"), the workflow is:

1. Open `sql-queries/` and find a similar existing query as a template.
2. Adapt it. Save the new query in `sql-queries/<descriptive-slug>.sql`.
3. Run it locally, sanity-check against a known player or known org.
4. If it's a one-off CSV / quick table → ship the result directly.
5. If it deserves a recurring PDF / app surface → discuss with Zac
   before building.

Chapter 12 (SQL Query Playbook) covers this in detail.

## Shared-file landmines

Some files carry cross-worktree coordination rules. Editing them
without following the protocol breaks delivery for the whole org.
You can still own these edits — just follow the protocol.

### `pd-goals/data/slack_channels.csv` — 5 copies must stay in sync

This file maps players to their Slack channels (a `zzz_*` athlete
channel and a `z_*` coach channel per player). When a new player
gets picked up, you'll be the one adding their row — this is part
of the running-reports workflow.

The file exists in **5 places** across **4 worktrees** because each
app reads it from a different relative path. Full rule in
`.claude/rules/slack-channels-sync.md`. **Workflow when adding a player:**

1. **Ping in Slack** to confirm nobody else is mid-edit. Parallel
   edits on this file are a guaranteed merge-conflict on 5 files at
   once.
2. **Use the canonical 5-place sync block** (the rule shows the
   `for f in <5 paths>; do printf ... >> "$f"; done` pattern).
3. **Preserve CRLF line endings.** The file is Windows-CRLF; mixed
   endings break downstream CSV parsers in subtle ways.
4. **Push to all 4 worktrees' branches.** All 4 must carry the same
   file content or apps diverge.

Zac will walk you through your first new-player addition (which
channel name format, where to find the gc_id, etc.) — after that
it's straightforward.

::: blocking
**Never rename a `zzz_*` row to `z_*` or vice-versa.** Per
`feedback_slack_channels_zzz_z.md` the answer is almost always to
ADD a new row, not rename. Renaming breaks delivery for code paths
that key on the old channel name. See also
`feedback_slack_channels_zzz_z.md` for the Sandro Pereira
"channel-name-suffix-≠-gc_id" caveat — some channel names have
frozen Slack labels from old gc_ids.
:::

### `.claude/rules/*.md` — synced across 4 worktrees

The rules directory is the authoritative knowledge base. Each rule
file lives in 4 places (one per worktree). When you edit a rule:

1. Edit the canonical copy in `bsb-resources/.claude/rules/`.
2. Use the `sync-rules` slash-command (Claude Code) OR manually
   byte-copy to the 3 sibling worktrees. The script lives at
   `.claude/scripts/sync-rules.sh`.
3. Commit the change on each worktree's feature branch.

Verify with `md5sum` across all 4 — the file should be byte-identical
in every worktree.

### `pd-goals/data/goals.csv` — coordinate concurrent edits

Only one person edits this at a time. If you and Zac both edit player
goal rows in parallel, the merge conflict is a guaranteed pain.
Coordinate in Slack before opening the file.

Your CSV edits become live after you (or anyone) re-pins:

```powershell
python pd-goals/scripts/pin_goals.py
```

### `manifest.json` per worktree — Connect allow-list

Every new file you add under an app's `src/`, `pages/`, `scripts/`,
`data/`, or `assets/` directory MUST be added to that app's
`manifest.json`. Connect uses it as an allow-list — files not listed
are silently excluded at deploy. Symptom of forgetting: `ModuleNotFoundError`
in the Connect app log after deploy.

Each worktree has its own `manifest.json` at the worktree root.

## Claude Code & AI tooling

Per repo setup, **Claude Code is licensed only on Zac's personal
laptop today.** If you want AI help on yours, you have three options:

1. **Run Claude through claude.ai** in a browser — paste code in,
   discuss, paste back. Works but loses the codebase context that
   makes Claude Code valuable.
2. **Buy your own Claude Code subscription** and authenticate on your
   machine. The `.claude/` directory + rules + skills all carry over;
   Claude will read them automatically.
3. **Read the rules yourself.** Every `.claude/rules/*.md` file is
   plain markdown — you can open them in VS Code regardless of
   tooling. This is honestly the fastest way to ramp up.

Whichever path you take, the rules + handbook ARE the source of truth.
Claude Code just enforces them; the knowledge isn't AI-only.

## When to ask vs forge ahead

Use this matrix. When in doubt, ask — interrupting Zac for 30 seconds
beats shipping a bug coaches see.

| Situation | Action |
|---|---|
| You don't know which DB column to use | Grep first. If still unclear, ask. |
| You don't know the SQL syntax (T-SQL vs Postgres) | This is T-SQL. See `.claude/rules/pitfalls.md`. |
| You think you've found a bug in production | Slack first, then PR. Don't push a "fix" without confirming the bug exists. |
| You want to refactor something tangential to your task | Don't. Open a separate PR or `gsd:add-todo` for later. |
| You want to add a new rule to `.claude/rules/` | Discuss the topic first; rules are blocking guidance for future agents. |
| You want to rename a file or module | Ask. Imports + manifest.json + Connect deploy + rules cross-references all break. |
| Your local app crashes on startup | Read the Connect deploy log too — it often has clearer errors. Ask if stuck after 15 minutes. |
| A coach DMs you a one-off question | Decide whether it's a quick `sql-queries/` lookup or warrants a recurring report. Ping Zac if it's bigger than a Slack reply. |
| You think a coach's request is unreasonable / out of scope | Slack Zac. We have a "no" budget; spend it deliberately. |
| A scheduled Connect job (tracker re-pin, etc.) fails | Check Connect logs first. Most failures are TCP drops covered by the auto-retry rule (`.claude/rules/database-tcp-retry.md`); some need `repair_tracker_pin.py`. |

## A worked example — your first PR

Suppose Zac asks: *"Schiavone's Hard% on his weekly hitter card looks
wrong vs the postgame — they should match. Take a look?"*

Here's the loop (with DB access on Day 1, no DB-less dance needed):

```
# 1. Branch off live work
git checkout feature/barrelsville
git pull
git checkout -b feature/barrelsville/intern/schiavone-hard-pct-parity

# 2. Investigate — find every Hard% computation across surfaces.
grep -rn "hard_pct\|Hard%" barrelsville/src/ | head -20
# Read the relevant files in postgame_data.py vs weekly_hitter_data.py
# Run a diagnostic query locally to confirm the divergence.

# 3. Check three-surface parity rule.
# Open .claude/rules/three-surface-parity.md — it lists which surfaces
# must match for each metric.

# 4. Make the change in the diverging file (probably weekly_hitter_data.py
#    if postgame is canonical per the rule).

# 5. Verify against live DB.
python -c "from src.weekly_hitter_data import get_weekly_hitter_data; \
           df = get_weekly_hitter_data(...); print(df[df['name'].str.contains('Schiavone')])"

# 6. Commit + push
git add barrelsville/src/weekly_hitter_data.py
git commit -m "fix(barrelsville): align Hard% bunt filter with postgame (three-surface parity)"
git push -u origin feature/barrelsville/intern/schiavone-hard-pct-parity

# 7. Open a PR on GitHub
#    Title: same as commit
#    Body: "Schiavone's Hard% diverged between postgame (45.2%) and
#           weekly hitter (47.1%). Postgame was using bunt-excluded
#           BIPs (canonical per rules/three-surface-parity.md); weekly
#           was including bunts. Aligned filter. Now Schiavone matches
#           at 45.2% both surfaces."
#    Test plan: "Verified locally against AAA 2026: Schiavone 45.2%
#                both surfaces; spot-checked Biggers + Spence — all match."

# 8. Ping Zac for review.

# 9. He reviews, merges via Squash. You pull on your next branch.
```

That loop should take an hour or two for a small fix, half a day for
a new metric, two-to-three days for a new report. If a task starts
sliding past those estimates, it's probably scoped wrong — ping Zac
and re-scope.

## Closing thought

The codebase rewards reading before writing. Every rule in
`.claude/rules/` was written because someone (usually Zac or a Claude
agent) burned hours hitting that exact trap. The handbook chapters
you're reading right now distill those traps into a few hundred pages.

The single highest-leverage habit you can build in week one: **before
touching any new metric, query, or app, open the relevant chapter and
rule files first.** Twenty minutes of reading saves four hours of
debugging. Every time.

Welcome to the team.
