---
name: hub-ux-revamp-next
description: Astros PD Engine (BETA) encompassing-app UX revamp — src-collision + chrome DONE 2026-06-14 (pushed, not deployed); transitions-browse/gray-flash/Team-View-drilldown/codex still open
metadata:
  node_type: memory
  type: project
  originSessionId: e63a00af-37e0-47fb-a8c8-46ade1251425
---

**Astros PD Engine (BETA)** = all-encompassing hub merging the 4 PD apps into top-tabs +
sub-tabs. Repo `Baseball-Operations/player-development`, branch `feature/encompassing-app`,
entrypoint `apps/pd-engine/Astros_PD_Engine.py`. "Assemble" track of
[[player-development-dual-track]] (bsb-resources stays the live mid-season deploy).
Full spec + progress: `player-development/docs/plans/2026-06-14-hub-ux-revamp.md` — READ IT.

## DONE 2026-06-14 (committed + pushed to feature/encompassing-app, NOT yet deployed)
- `b95fa8c` **Critical ImportError fixed (Option A — robust).** Each domain shipped its own
  top-level `src` pkg; mount juggled process-global sys.path/sys.modules → racy → Team View
  got barrelsville's `src.roster` (lacks `load_il_sus_roster`) on Connect. Renamed
  `domains/<d>/src` → `domains/<d>/<d>_src` (barrelsville_src/arm_farm_src/intangibles_src),
  rewrote 167 imports; pd-engine keeps `src`. Re-keyed 141 manifest paths. Verified locally
  (AST + collision-resolution test + manifest-existence). Chose A over "harden mount" because
  sys.path juggling is racy across concurrent sessions — wrong for an org-wide app.
- `7ef0936` **Chrome:** header transparent + top padding (no ⋮ over wordmark); ALL "Back to
  PD Engine" links hidden via `a[href="./"]/"../"` CSS (intra-domain links kept); "wiring
  pending" context bar deleted; Team View + Transitions View removed as Org sub-tabs (now
  Org Board · Goals · Transitions · Win Prob · Defense Matrix); sidebar hidden on no-sidebar
  views (`NO_SIDEBAR`={Org Board, Win Prob, Transitions}; Defense Matrix kept — uses
  st.sidebar L99); Transitions width 820px→100%.
- `8af9ca1` plan-doc progress update.
- `d39bb12` **Round 2 fixes:** Blast Motion `No module named database` (blast_report.py
  bare `from database`→`from barrelsville_src.database`); ALL back buttons gone (added
  `a.back-link`+`a.ac-back-link` hide — intangibles Fielding/KPI/cPAA/Catcher use those
  classes, not root hrefs); Transitions Browse leaving shell → in-shell radio toggle
  (Submit | Browse) mounting 2_Transition/3_Transitions_View in place + hid the
  `href=Transitions_View` link; Catcher Dash BETA wired to `4_Catching.py ?view=dashboard`;
  Org Board wordmark hidden under top bar → `[data-testid=stHeader]{display:none}` (Org
  Board reset .block-container padding, won specificity, so a padding fix lost). Codex
  CLI+skill installed but OpenAI account QUOTA EXCEEDED (user billing) — review couldn't run.

- `6001e3b` **Round 3:** Browse Past Reports width 1280px→100% (matches Submit). **Page-switch
  slowdown ROOT CAUSE FIXED** — 28 page scripts each `sys.path.insert(0,...)` every run; `_mount`
  only removed its own root → sys.path grew unbounded → imports/switches slower the longer app
  open (postgame blank, KPI/baserunning/batter-lookup slow). Rewrote `_mount` to snapshot+restore
  sys.path each mount; removed `_evict_src` (unique packages = no collision, keep cache). NOTE:
  postgame-blank may also be page-internal (session_state fingerprint) — confirm live after deploy.

## DEPLOY (user, work laptop — NO `-New`)
`cd C:\Users\zbridger\player-development\apps\pd-engine; git pull; .\deploy_beta.ps1 -ApiKey <KEY>`
then Ctrl+Shift+R. First check: Team View no longer throws the ImportError.

## STILL OPEN (need live behavior — do next, NOT blind)
- Gray load-flash on sub-tab switches — investigate (Org Board dark CSS bleed? `?view` double-rerun?).
- Team View drill-down from Org Board card `?team=` won't mount in hub (not a NAV tab) — hub must
  handle `?team=` to mount `6_Team_View.py`. No longer CRASHES, just routing.
- Codex review: CLI+skill+key all installed/registered; blocked on OpenAI **quota/billing** (user).
  Rerun once fixed: `printf '%s' "$OPENAI_API_KEY" | codex login --with-api-key` then
  `codex exec --sandbox read-only --skip-git-repo-check "review apps/pd-engine/Astros_PD_Engine.py"`.

## Repo team-readiness (DONE Jun 15 2026 — merged to player-development `main`)
Added the missing front door + pre-merge gate so teammates branch off `main` cleanly:
`docs/onboarding/00-start-here.md` (ordered reading path, apps=folders/branch=change rules,
two-laptop model, what-not-to-touch, first-hour checklist, CODEOWNERS), CONTRIBUTING.md "Before
you open a PR" checklist + quick-ref table, README "Read these" leads with 00-start-here. Committed
on `docs/team-readiness`, ff-merged to `main` (`04523c0`). Repo checkout left on `main`.
Optional later polish (not done, not urgent): consolidated env-vars reference doc; render
01-getting-into-github.md to PDF for the shared drive. BETA hub + data-layer migration stay parked.

## PROCESS NOTE (do not repeat)
Do NOT set a `/goal` whose success condition needs a live deploy — last session it looped the
Stop hook 27 min because the personal laptop can't deploy/verify. Execute + verify LOCALLY,
commit in deployable chunks, hand deploy to user.
