---
name: connect-offload-migration
description: NOW (not future) — move heavy pin/aggregation compute off Posit Connect into the DB; new official repo Baseball-Operations/player-development; driven by Catherine Fields/IT server-load pressure.
metadata: 
  node_type: memory
  type: project
  originSessionId: cdcf4026-70bc-429c-bb18-bcb9b7478efd
---

## ⚠️ GUARDRAIL — org repo = PD-only, from Zac, ZERO oversharing (BLOCKING)
`Baseball-Operations/player-development` is INTERNAL-visible to the whole
Baseball Ops org. User directive (Jun 13, emphatic): the repo is **"directed to
PD, from Zac, no one else."** **Mention NO names but Zac, NO other teams (esp.
R&D), NO infra brands (Databricks/DBX-ELT), NO IT-pressure/politics
(Catherine/"100% CPU"/"hounding"), NO Slack quotes.** Frame the DB-offload as
neutral engineering ("heavy aggregation belongs in the database, not a Connect
app — for performance + scalability"). Naming a teammate/team = oversharing.
- Jun 13 round 1: leaked Catherine/IT-pressure → scrubbed + history-rewrote.
- Jun 13 round 2: leaked R&D + Databricks/DBX-ELT into README/CONTRIBUTING/
  pipelines/onboarding; ALSO the migrated pd-goals app carried colleague names
  in its OWN docs+code comments (PRD "Brodie/Arrivo", README "Josefy"+email,
  `src/woba_weights.py` "Brodie", `src/pins_config.py` "Arrivo"). Scrubbed ALL
  + renamed PD Hub→**Astros PD Engine** + **history-rewrote to single commit
  `688e580`, force-pushed**. Verified `git grep` = zero R&D/Databricks/known
  names across ALL tracked files.
- ⚠️ **RESIDUAL RISK:** the migrated app = months of code/docs; I scrubbed only
  the names I knew to grep (Catherine/Brodie/Arrivo/Josefy/R&D/Databricks).
  OTHER colleague refs ("per <name>", "<name> said") likely still hide in
  src/*.py + scripts/*.py comments. Before broadly publicizing the repo, run a
  dedicated full name-sweep (ask Zac for the list of names to grep).

**ACTIVE / NOW (not future).** IT (via Catherine Fields, 2026-06-12) flagged PD
processes hitting 100% CPU/RAM on RConnect (Posit Connect), specifically the
**pin tracker jobs running during the day** despite off-hours scheduling.
RConnect is for visualization, NOT large-scale data processing. R&D will help
with the Python.

## ►► CURRENT STATE / RESUME HERE (Jun 13 2026) ◄◄
- **PUSHED ✓** — `C:\Users\Owner\player-development\` is LIVE on the org remote
  `git@github.com:Baseball-Operations/player-development.git` (`main`, commit
  `f05fa1f`, 146 files). Verified clean: `apps/` = only `pd-engine` + README, NO
  personal/junk-drawer/secret files tracked. Remote root tree confirmed (apps/,
  libs/, docs/, pipelines/ + README/CONTRIBUTING/CODEOWNERS/.gitignore).
- Contains: monorepo skeleton (apps/, libs/pd_common/, pipelines/, docs/) +
  **`apps/pd-engine/` = full copy of `bsb-resources/pd-goals`** (the first app) +
  onboarding docs (`docs/onboarding/01-getting-into-github.md`,
  `02-deploy-your-app.md`) + README/CONTRIBUTING/CODEOWNERS/.gitignore.
- **►► NEXT (work laptop ONLY — DB/Connect access):** `git clone`/pull the new
  repo, then deploy `apps/pd-engine` to the EXISTING Connect content GUID
  `79f52369-…` (NOT a new one) so the live app just updates from the new folder.
  Coaches see no change. Verify it comes up identical, then move on.
- First deploy keeps existing `database.py` (NO gcpy swap yet) — pure relocation,
  same env vars (Connect Vars tab), same `zbridger/*` pins. gcpy + Databricks
  offload are LATER.
- After pd-engine verified: repeat copy-in for arm-farm / barrelsville /
  intangibles (one at a time, from their worktrees). DO NOT copy the
  bsb-resources junk drawer — see [[feedback_never_push_personal_files_to_org]].
- Layout/branch model: apps = FOLDERS on `main` (not branches); branch only for
  changes → PR → merge. Mother-app (one tabbed shell = the mockup) is the LATER
  end-state built on the shared code.

**Plan doc:** `pd-goals/docs/plans/2026-06-12-connect-offload-and-repo-migration-preface.md`.
**New official repo:** https://github.com/Baseball-Operations/player-development
(under Baseball Ops umbrella; R&D-visible; target home for the migrated
DB-backed data layer + the future unified hub).

## The agreed fix (Zac already said it in-thread; rules already documented it)
Move league-wide aggregation + percentile pooling (30 orgs × all levels) OFF
Connect and INTO the DB — SQL Server Agent jobs → materialized tables /
`_view` / stored procs. **Apps become pure readers.** This is literally
`tracker-parquet-pins.md §11.2 Step 3` ("DB-side materialized table = 5-year-
horizon architecture"). Catherine's nudge: GC2 already serves org pages
(`/orgs/HIT`) backed by `_view`/procs — have R&D add columns there instead of
recomputing on Connect (watch parity: `three-surface-parity.md`, `org-codes.md`).

## "Running during the day" smoking gun (confirm w/ IT)
Pins refresh **every 6h** → ~4×/day, two of which land ~noon + ~6pm (peak).
Plus manual daily report runs 8:30–9am (3 .py, gated on video/IZ ingest) +
Monday weekly cascade + TCP-retry churn on VPN drops.
**Immediate reversible relief:** reschedule the 6h tracker refreshes to true
off-peak (do this before the R&D meeting). Heaviest single job = fielding combo
precompute (~132 min, Connect content 909; see fielding-tracker-perf-session.md)
→ move DB-side FIRST.

## Sequencing
NOW = Connect offload (data layer → DB) → THEN future = unified PD Hub built on
the stable DB-backed read layer, in the new repo. Migrate the shared DATA LAYER
first (database.py / pins_config / roster / aggregation SQL), UI follows.

## Open before moving code
- Monorepo (all 4 apps + hub) vs hub-only in the new repo? (leans monorepo)
- Branch/PR model (R&D norms) vs current per-app-worktree + "merge to main at
  milestones" habit.
- Inspect the new repo's current state (empty? README/structure R&D expects?).
- Secrets/deploy story (CONNECT_API_KEY, DB creds, Logic App URL).

## Next actions (no code yet)
1. Pull Connect schedule + per-content job-duration table → bring to IT/R&D mtg.
2. Reschedule 6h→off-peak (quick win). 3. Prioritize DB-side moves by wall-clock.
4. Inspect new repo; decide layout. 5. Prep R&D ask + GC2 reuse + parity guards.

## New repo = `Baseball-Operations/player-development` (inspected Jun 12 2026)
BLANK (created Jun 13Z, `main`, INTERNAL visibility = whole Baseball-Ops org,
Zac=admin). It's the **PD department monorepo** — everyone in the dept deploys
there. **Layout doc:** `pd-goals/docs/plans/2026-06-12-player-development-repo-layout.md`.

Org conventions found (gh inspected):
- One-repo-per-project is the org norm; `player-development` is the deliberate
  department-monorepo exception. Mixed R + Python stacks. `main` everywhere.
- **`gcpy`** = org-canonical DB access (`pip install git+ssh://…/gcpy`;
  `gcpy.grab_query(sql, params)`; prod/dev engines; env `CON_STR_PROD/DEV`
  override; keytab/domain auth; helpers get_player_name/hand). **Replaces our
  bespoke `database.py`** — direct answer to Catherine's "align with DB
  architecture." ⚠ MUST verify gcpy authenticates from a Connect (Linux)
  deployment before adopting app-wide (laptops are domain-Windows; Connect isn't).
- **`DBX-ELT` (Databricks ELT) + `MLOps` + `DBX-Monitoring`** = R&D uses
  **Databricks** for data processing → that's where the heavy tracker
  aggregation moves (Databricks ELT → materialized tables; apps READ via gcpy).

**Recommended layout = MONOREPO-by-app** (hub = `apps/pd-engine`, NOT hub-only):
`apps/{pd-engine,arm-farm,barrelsville,intangibles,<teammates>}/` each a
self-contained Connect deployable (own requirements/manifest/deploy, existing
GUID preserved) + `libs/pd_common` + thin `pipelines/` (heavy ELT lives in
DBX-ELT) + single `.claude/` + `docs/plans/`.
**Big win:** monorepo collapses the 4-worktree `.claude/rules/` + 5 copies of
`slack_channels.csv` → ONE copy (kills the cross-worktree drift bug class).
**Migration order:** scaffold → adopt gcpy (thin shim) → move `pd-engine` first
(history via git-subtree/filter-repo) → repoint DB → offload aggregation to
Databricks → retire worktrees → main+PR+CODEOWNERS (replaces "merge at milestones").

Related: [[unified-pd-hub-vision]] (the future hub this prefaces).
