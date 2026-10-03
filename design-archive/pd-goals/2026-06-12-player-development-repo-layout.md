# `Baseball-Operations/player-development` — Repo Layout & Migration Strategy

**Date:** 2026-06-12
**Repo:** https://github.com/Baseball-Operations/player-development
  (blank, created 2026-06-13Z, default `main`, **internal** visibility, Zac = admin)
**Purpose:** Official **PD department home** — "everyone in the department deploys
their code here." Target for the migrated, DB-backed app layer (now) + the
future unified PD Hub.
**Prefaces:** `2026-06-12-connect-offload-and-repo-migration-preface.md`
**Builds toward:** `2026-06-12-unified-pd-hub-design.md`

---

## 1. Org landscape (what we're aligning to)

Inspected the `Baseball-Operations` org. Conventions observed:

- **One-repo-per-project is the org norm** (`swing_smoother`, `sp-prob-model`,
  `player_valuation_app`, `trade_display_app`, `daily-reports`, …). Mixed
  stacks — some R (`app.R`/`.Rproj`), some Python. Each repo organizes itself
  loosely; no rigid enforced structure. Default branch `main` everywhere.
- **`player-development` is the deliberate exception** = a department monorepo
  where multiple people deploy. So we DO want internal structure + ownership.
- **`gcpy` = org-canonical DB access** (`pip install
  "git+ssh://git@github.com/Baseball-Operations/gcpy.git"`; `gcpy.grab_query(
  sql, params={...})`; `gc.engine_prod`/`engine_dev`; override via env
  `CON_STR_PROD`/`CON_STR_DEV`; keytab/domain auth via `get_keytab.py`; helpers
  `get_player_name`/`get_player_hand`/`get_research_url`). **This replaces our
  bespoke `database.py` + `run_query`** and is the direct answer to Catherine's
  "align with our database architecture."
- **`DBX-ELT` (Databricks ELT) + `MLOps` + `DBX-Monitoring`** = R&D's data-
  processing platform is **Databricks**. The heavy tracker aggregation that
  must leave Connect goes HERE (Databricks ELT → materialized tables), not into
  this app repo.

---

## 2. Decision: MONOREPO-by-app (hub is one app inside it)

Not "hub-only." The repo is the PD department's deploy home, so it holds every
PD app, each a self-contained Connect deployable, plus shared tooling. The hub
is just `apps/pd-engine` among them.

### Proposed top-level layout
```
player-development/
  README.md                 # what this is; app index; deploy how-to
  CONTRIBUTING.md           # branch/PR flow, deploy conventions, gcpy usage
  CODEOWNERS                # per-app ownership (multi-person dept)
  .github/workflows/        # CI: lint + import-graph/deploy audit
  .claude/                  # rules + skills — ONE copy now (see §4 win)
  apps/
    pd-engine/              # HUB + PD Goals / Transition / WPA / Org Board  (Zac)
    arm-farm/               # pitcher                                        (Zac)
    barrelsville/           # hitter                                         (Zac)
    intangibles/            # OF / IF / BR / catcher                         (Zac)
    <teammate-app>/         # other department members' apps
  libs/
    pd_common/              # shared PD helpers NOT in gcpy (pins, slack, viz)
  pipelines/                # ⚠ thin — heavy ELT lives in DBX-ELT, not here
  docs/
    plans/                  # design docs (these files migrate here)
```

### Per-app subdir (each = one Connect content, GUID preserved)
```
apps/barrelsville/
  app.py / pages/ / src/
  requirements.txt          # app-specific; depends on gcpy + pd_common
  manifest.json             # Connect deploy manifest (per app)
  deploy.ps1                # deploys THIS subdir to its existing Connect GUID
  README.md
```

Each app deploys independently from its own subdir to its **existing** Connect
content (App GUIDs unchanged — no re-provision). Monorepo ≠ one deployment;
it's one repo, many deploy targets.

---

## 3. Where the heavy compute goes (the Catherine offload)

- **NOT in this repo as Connect jobs.** The 30-org × all-level aggregation +
  percentile pooling (the tracker pins, fielding combo precompute, defense
  matrix, compliance) moves to **Databricks ELT (`DBX-ELT`) / SQL materialized
  tables**, owned/co-built with R&D.
- **Apps here become readers:** `gcpy.grab_query("SELECT … FROM <materialized
  table>")`. The pin layer either disappears or becomes a trivial cache of a
  SELECT (cheap), not a compute job.
- `pipelines/` in this repo stays thin (orchestration shims / scheduled
  triggers at most). The real ELT is a Databricks asset.

---

## 4. Migration wins this unlocks (call these out)

- **`.claude/rules/` + `slack_channels.csv` collapse to ONE copy.** Today they're
  duplicated across 4 worktrees (5 copies of `slack_channels.csv`, byte-identical
  rule files — see `slack-channels-sync.md`). In a monorepo that's **one** copy.
  An entire class of cross-worktree drift bugs disappears.
- **One `gcpy` instead of 4 `database.py`.** Single DB-access surface, org-aligned.
- **Shared `pd_common`** for the pin/slack/viz helpers currently copy-pasted.
- **One CI** (lint, the `audit_pin_deploy.py` import-graph check) across all apps.

---

## 5. Migration strategy (incremental, low-risk, history-preserving)

**Order matters — data layer first, UI later (per the offload preface).**

1. **Scaffold skeleton** on `main`: README, CONTRIBUTING, CODEOWNERS, `apps/`,
   `.github/`, `.claude/` (single rules copy), `docs/plans/`.
2. **Adopt `gcpy`** — add as a dependency; write a thin `pd_common.db` shim that
   forwards to `gcpy.grab_query` with our `run_query` signature, so apps migrate
   with minimal churn (keeps the TCP-retry behavior wrapped).
3. **Move apps one at a time**, `pd-engine` first (hub home). Preserve git
   history via `git subtree add` / `git-filter-repo` from each worktree, or a
   clean import if history isn't worth the friction. Each app keeps deploying to
   its current Connect GUID from its new subdir.
4. **Repoint DB access** per app from `database.py` → `gcpy`/`pd_common.db`.
5. **Offload heavy aggregation to Databricks/SQL** with R&D (`DBX-ELT`); repoint
   apps to read materialized tables.
6. **Retire the 4 worktrees / 5 CSV copies** once an app is fully moved.
7. **Branch/PR model** = org norm (`main` + PR). Replaces "merge to main only at
   milestones." Add branch protection + CODEOWNERS review.

---

## 6. Open questions to resolve before/at the R&D meeting
1. **Auth on Connect:** apps currently use FreeTDS + `DB_USER`/`DB_PASS`. `gcpy`
   uses keytab/domain auth + `CON_STR_PROD`/`CON_STR_DEV` env override. Confirm
   how Connect (Linux) authenticates via gcpy — likely set `CON_STR_PROD` in the
   content's Vars tab. **Verify gcpy works from a Connect deployment**, not just
   a domain Windows laptop, before committing every app to it.
2. **History preservation** worth the `git-filter-repo` effort, or clean import?
3. **Does the dept want apps under `apps/` or top-level per-owner dirs?** (Plan
   assumes `apps/<app>`; adjust if the dept prefers `<owner>/<app>`.)
4. **CI scope** — lint + deploy-audit now, tests later?
5. **Where do the 3 sibling worktrees' deploy bundles (`connect_pins*/`) live** —
   per-app subdir, presumably; but most of that compute is leaving for Databricks.

---

## 7. What NOT to do
- Don't put the heavy aggregation in this repo as Connect-scheduled jobs — it
  goes to Databricks/SQL (the whole point of the offload).
- Don't keep 4 bespoke `database.py` — standardize on `gcpy`.
- Don't re-provision Connect content — each app keeps its existing GUID, deployed
  from its subdir.
- Don't migrate all 4 apps at once — move `pd-engine` first, validate the
  gcpy-on-Connect + subdir-deploy pattern, then the rest.
- Don't lose the `.claude/rules/` content in the move — collapse 4 copies → 1,
  don't drop it.
- Don't adopt gcpy app-wide before confirming it authenticates from a Connect
  (Linux) deployment (§6.1).

---

## 8. Cross-references
- `2026-06-12-connect-offload-and-repo-migration-preface.md` — the why/now.
- `2026-06-12-unified-pd-hub-design.md` — the hub that lands in `apps/pd-engine`.
- `rules/slack-channels-sync.md` — the 5-copy problem the monorepo collapses.
- `rules/tracker-parquet-pins.md` §11.2 Step 3 — DB-side materialized tables.
- `gcpy` repo README — org DB-access standard.
