---
name: player-development-dual-track
description: Dual-track process — bsb-resources stays the live deploy mid-season; player-development is the parallel encompassing-app build. NO cutover pressure.
metadata: 
  node_type: memory
  type: project
  originSessionId: e63a00af-37e0-47fb-a8c8-46ade1251425
---

Two SEPARATE efforts, do not conflate them (Zac direction, Jun 13 2026):

1. **OPERATE — `bsb-resources` (+ the 3 sibling worktrees).** This is the LIVE deploy
   chain mid-season: the 4 apps, the daily/Monday cascades, all Slack delivery.
   **New fixes/features continue to ship here** through the season. It is NOT frozen.
   An earlier session wrote "freeze bsb-resources, new work → player-development" —
   that was WRONG. Zac overruled: mid-season you do not disrupt a working pipeline.

2. **ASSEMBLE — `player-development` / `apps/pd-engine/Astros_PD_Engine.py`.** The
   parallel, no-deadline build of the ONE all-encompassing Astros PD Engine (all four
   apps as top-tabs/sub-tabs over a shared player/level/season context). This is a
   genuinely hard feat — merging four apps' sidebars/state/filters into one shell.
   It progresses on its own clock and only becomes source-of-truth once FULLY proven.

**Why this isn't the copy-drift trap:** we are NOT porting the same *change* into both
repos. bsb-resources = the running operation; player-development = the build. A domain's
bsb-resources copy retires ONLY when its tab is genuinely done in the hub — one at a
time, end of season or later. No big-bang cutover.

**Where to build a given request:** if it's "fix/ship X for the live apps" → bsb-resources.
If it's "wire/assemble the encompassing app" → player-development. When unsure, ask which
track. Related: [[connect-offload-migration]], [[unified-pd-hub-vision]].

## player-development branch map (Jun 13 2026 — cleaned up)

- **`main`** = clean stable base teammates fork from. Holds: scaffold + the migrated
  `apps/pd-engine/` app (original `PD_Engine.py`) + `libs/` + `docs/` + `CONTRIBUTING.md`
  + `CODEOWNERS` + `.claude/rules/`. Does NOT carry the unfinished hub. (HEAD `bf9cdbd`.)
- **`feature/encompassing-app`** = the hub WIP — `apps/pd-engine/Astros_PD_Engine.py`
  (top-tab/sub-tab shell) + `apps/pd-engine/domains/{arm_farm,barrelsville,intangibles}/`
  (185 files copied verbatim) + the extra requirements. ALL hub dev happens here; PR into
  main only when a domain's tab is genuinely proven. (HEAD `85586de`.)
- History note: the hub had been committed straight to main last session (violated
  "keep main stable"). Jun 13 cleanup: rebased main to drop the 2 hub commits (`7f17c8c`
  shell, `95165cd` domains), preserved the full work on the feature branch. Recovery SHA
  for the pre-clean main = `85586de` (== feature/encompassing-app HEAD).
- **Branch protection: DEFERRED.** Not enabled yet — PR-required would block the solo
  maintainer. Turn it on (require PR + CODEOWNERS review on main) the day the first
  teammate is onboarded. `gh` is installed + authed as zbridger_astros.
- **Test path = DEPLOY TO POSIT CONNECT, view in browser. NOT local streamlit.** Streamlit
  is NOT allowed on the work laptop, and personal laptop has no DB — Connect is the only
  place any of these apps actually run (true for all 4 apps). Do NOT tell Zac to
  `streamlit run` anything (repeated mistake — corrected Jun 13 2026).
- **Connect content name for the combined app: `Astros PD Engine (BETA)`** — distinct from
  the LIVE `PD Engine` content (don't collide). Drop "(BETA)" + retire old PD Engine when proven.
- **Deploy recipe (work laptop, `apps/pd-engine/` on `feature/encompassing-app`):** manifest
  already regenerated → entrypoint `Astros_PD_Engine.py`, python 3.11.0, 298 files inc. all
  `domains/`. Command:
  `C:\Users\zbridger\AppData\Roaming\Python\Python314\Scripts\rsconnect.exe deploy manifest . --server https://connect2.astros.com --api-key <KEY> --title "Astros PD Engine (BETA)" --new`
  Then set Vars on the new content (DB_USER, DB_PASS, CONNECT_API_KEY, LOGIC_APP_URL) or pages go blank.
- **First-deploy risk:** the `_mount` `src`-swap (4 apps sharing one process). If a domain tab
  errors, read the Connect log — fix = namespace that domain's `src/` imports. Expected; deploying is the test.
- **UI pass shipped Jun 13 2026** (feature/encompassing-app): nav buttons now navy-bg/orange-text
  with hover-invert (orange-bg/navy-text) + orange active — readable on Org Board's dark bg
  (were white-on-white). Scoped via `st.container(key="pde_topnav"/"pde_subnav")` →
  `.st-key-pde_topnav button` CSS so mounted-page buttons are untouched. Forced full-width on
  every page (`[data-testid=stMainBlockContainer]/.block-container max-width:100%`) to match
  Org Board. Hid auto sidebar page-list (`[data-testid=stSidebarNav]{display:none}`) — that was
  the "Pitch Arsenal / View 4 more" clutter (experimental pages 8–13). Org sub-tabs now:
  Org Board · Team View · Goals · Transitions · Transitions View · Win Prob · **Defense Matrix**
  (rightmost, per user). All Barrelsville + Arm Farm sub-tabs already wired to real pages.
- **ALL sub-tabs now wired (Jun 13 2026).** Intangibles BR/IF/OF/Catching each route internally on
  `?view=<v>` (discovered by reading the pages) — the hub drives it via `_mount(path, view=...)` which
  sets `st.query_params["view"]` before runpy, reusing each page's OWN routing with ZERO source edits.
  Maps: tracker→Affiliate Tracker, postgame→Gamelog, kpi→KPI, advance→Advance, weekly→Individual,
  review→PAA Review Log. Only **Catcher Dash BETA** left as a placeholder (page's `?view=dashboard` —
  unfinished, ~7-8 open design Qs are the user's). Org/Barrelsville/Arm Farm already on real pages.
  So every requested sub-tab is wired except the one the user themselves marked unfinished.
- Shared player/level/season context bar is still a static placeholder ("wiring pending").
  Experimental pd-engine pages 8–13 (Player Card/Pitch Arsenal/Compare/etc.) not in any tab.
- **Pre-deploy static audit done (Jun 13 2026) + fixes shipped:** (1) `blast_report.py` was NOT
  copied (domains copy excluded scripts/) but Barrelsville→Blast Motion does
  `sys.path.insert(.../"scripts"); from blast_report import ...` → copied just that one module to
  `domains/barrelsville/scripts/` (self-contained: matplotlib/reportlab/seaborn only; name-clean).
  (2) Added `requests`, `urllib3` (every `pins_config.py` imports them, app-wide) + `PyPDF2`
  (Org→Win Prob) to requirements — were missing. (3) Manifest regenerated (299 files). All 208
  mounted pages + src modules ast.parse clean; manifest valid JSON; all `src.*` imports resolve
  within each domain. `db_connection`/`pptx`/slide-deck imports are scripts-only (never mounted) — ignored.
- **CAN'T verify UI from personal laptop** (no Connect). Each change = push → user redeploys BETA
  content + reloads to see it. CSS `st-key-*` scoping assumes Streamlit ≥1.39 container-key support
  (they pin ≥1.49 — fine).
