---
type: meta
created: 2026-08-31
tags:
  - meta
  - ai
  - claude-code
  - tooling
  - context-library
  - security
source: "@raycfu Google Doc — '6 Open Source Repos That Make Claude 10x Better'"
---
# Repo Eval — "6 Open Source Repos That Make Claude 10x Better" (@raycfu, Aug 2026)

Source doc (Google Docs, sign-in walled — content was pasted by Zac, not fetched):
<https://docs.google.com/document/d/1D0sOJ4V9ZUylhUOB2iU0KhHM0soGo9HHC1dASbjdq2c/edit>

**Provenance matters here.** Same author as [[claude-code-toolkit-raycfu]] (the 10-repo
Instagram carousel, Jun 29 2026), and the doc ends in a paid-community CTA
(skool.com/raycfu). It is a funnel, not a neutral eval. Two of the six were already
triaged in the June note (`ecc` = #6 here). Treat star counts and "10x" as marketing;
every claim below was checked against the actual repos.

Related: [[claude-code-toolkit-raycfu]] · [[repo-eval-tddguard-subconscious-wshobson]] ·
[[loop-engineering]] · [[context-bloat-fix-plan]] · [[hooks-setup]] · [[skills-cheatsheet]]

---

## Part 1 — What we actually have (measured 2026-08-31)

This is the baseline any of these six would be layered onto. Numbers are from a live
scan of `bsb-resources/.claude/` and `~/.claude/`, not from memory.

| Layer | What we run | Size |
|---|---|---|
| **Rules** | `.claude/rules/*.md`, path-routed via `paths:` frontmatter | **119 files / 1518K**; 106 scoped, **13 always-on (75K)** |
| **Blocking law** | `blocking-rules.md` — 23 numbered non-negotiables, always-on | 12K |
| **Project skills** | amateur, baseball-sql, document-pattern, explainer-artifact, load-rules, memory-cleanup, metric-audit, new-report, new-visual, slack-channels-csv, tracker-new-metric, ui-ux-pro-max | 12 |
| **Global skills** | codex, percentile | 2 |
| **Agents (global)** | 6 council (hitting/pitching/fielding/data-scientist/ml-engineer/scout) + verifier + player-evaluator + research-analyst + 15 gsd-* | 27 |
| **Plugins** | superpowers 4.1.0, document-skills, planning-with-files, voltagent ×3, frontend-design | 7 |
| **Framework** | GSD (get-shit-done) — ~60 slash commands: spec/plan/execute/verify/ship/debug/audit | installed |
| **Hooks** | 8 node hooks: `bsb-law-gate`, `gsd-prompt-guard`, `gsd-context-monitor`, `last-state-breadcrumb`, `autocapture-session`, `gsd-check-update`, `gsd-statusline`, `gsd-workflow-guard` + a project `sync-rules.sh` PostToolUse | 8 + 1 |
| **MCP** | `recall` (session memory / soft locks), `obsidian` (this vault), `claude-in-chrome` (browser) | 3 |
| **Guards (repo-side)** | `test_rule_routing.py`, `test_weekly_layout.py`, `sync-rules.sh` (114 rule files byte-identical across 4 worktrees) | — |
| **Permissions** | `defaultMode: auto`, **155 allow / 0 deny / 0 ask**, `skipDangerousModePermissionPrompt: true`, `skipAutoPermissionPrompt: true` | — |
| **Second brain** | this vault, `/wrap` `/brief` `/log` `/sunday` `/drift`, `last-state.md` | — |

**The honest read:** we are not a bare Claude Code install. We are one of the more
built-out configs a solo operator can have. The marginal value of a "give Claude a
process" repo is therefore much lower for us than for the doc's intended reader, and
the marginal *risk* of layering one on is much higher.

---

## Part 2 — The six, checked

### 1. gstack (`garrytan/gstack`) — virtual engineering team
**Verified.** Real, MIT, v1.57.x, ~108K stars (doc said 89K — it grew), 81 contributors,
CI on Linux + Windows. It is **~53 skills**, not 23 (the doc quotes an older count).

Actual skill families: product framing (`/office-hours`, `/spec`, `/plan-ceo-review`,
`/autoplan`), review (`/plan-eng-review`, `/review`, `/investigate`), design
(`/design-consultation`, `/design-review`, `/design-shotgun`, `/design-html`), QA
(`/qa`, `/browse`, `/benchmark`, `/canary`), release (`/ship`, `/land-and-deploy`,
`/setup-deploy`), security (`/cso` — OWASP + STRIDE), docs (`/document-generate`,
`/make-pdf`, `/diagram`), memory (`/learn`, `/context-save`, `/context-restore`,
gbrain), safety (`/careful`, `/freeze`, `/guard`, `/unfreeze`), plus a whole iOS
device-QA suite (`/ios-qa`, `/ios-fix`, `/ios-design-review`).

**Overlap with us — high.** Mapping:

| gstack | We already have |
|---|---|
| `/office-hours` `/spec` `/autoplan` | `superpowers:brainstorming`, `/gsd:new-project`, `/gsd:discuss-phase`, `/spec` |
| `/plan-eng-review` `/plan-design-review` | `/gsd:plan-phase` + `gsd-plan-checker`, `/gsd:ui-phase` + `gsd-ui-checker` |
| `/review` | built-in `/code-review` (+ `ultra`), `superpowers:code-reviewer` |
| `/investigate` | `superpowers:systematic-debugging`, `/gsd:debug` |
| `/qa` `/qa-only` | `verifier` agent, `superpowers:verification-before-completion` |
| `/cso` | built-in `/security-review` |
| `/ship` `/land-and-deploy` | `/gsd:ship`, `pin-deploy-runbook.md` (our deploy is Posit Connect + rsconnect, not a web platform — `/setup-deploy` will not detect it) |
| `/learn` `/context-save` `/context-restore` + gbrain | `recall` MCP, this vault, `/wrap` `/brief`, `last-state.md` |
| `/document-generate` | `document-pattern` skill, `/lineage`, `/document` |
| `/browse` | `claude-in-chrome` MCP |
| `/codex` | our `codex` skill |

**Genuinely new to us — four things:**
1. **`/careful` `/freeze` `/guard`** — an edit-lock that restricts writes to one
   directory. This is a real gap. Our worktree discipline ("only touch your project's
   subfolder") is prose in CLAUDE.md, enforced by nothing. `/freeze` is that rule as a
   mechanism. **Highest-value single item in all six repos for us.**
2. **`/design-shotgun`** — generates 3 visual variants side by side. Fits the
   render-and-look loop (blocking #18) where Zac's eye is the only thing that catches
   *wrong* as opposed to *broken*.
3. **`/diagram`** — English → mermaid + excalidraw + SVG/PNG. We hand-roll matplotlib
   or HTML artifacts for every explainer.
4. **`/retro`** — commit-history velocity analysis. Adjacent to `/sunday`.

**Costs / frictions:** browser-dependent skills need its own Chromium ("GStack
Browser") which duplicates `claude-in-chrome`. The iOS suite (~6 skills) is dead weight.
It wants its own `CLAUDE.md` conventions, `DESIGN.md`, `~/.gstack/config.yaml` — and our
CLAUDE.md is already a heavily-tuned 23-rule instrument. gbrain would be a **fourth**
memory system alongside recall MCP, this vault, and `~/.claude/projects/.../memory/`.

**Verdict: CHERRY-PICK, do not install whole.** Vendor 3-4 skills, leave the rest.

---

### 2. OpenMontage (`calesthio/OpenMontage`) — video production
**Verified.** Real, AGPL-3.0, 12 pipelines, 700+ skill files, free local path via Piper
TTS + Remotion + FFmpeg.

**Blocker for us, and it is a hard one:** the local path is FFmpeg-based. Per
`windows-toolchain.md`, ffmpeg is **not on PATH** on the personal laptop (we use `cv2`
or `imageio_ffmpeg.get_ffmpeg_exe()`), and per CLAUDE.md's IT constraints the bundled
`imageio_ffmpeg` binary is **blocked by application whitelisting on the work laptop**.
So this runs personal-laptop-only, and even there needs a real toolchain install.

**License caveat is real.** AGPL-3.0 reaches network-deployed software. Anything we
build on it that gets served from Posit Connect would inherit obligations. Fine for
making a video; not fine as a component of an Astros app.

**Relevance:** zero to the baseball repos. Non-zero to [[astroworld-status]] content and
the hitting-coach deck work — and that is it.

**Verdict: PARK.** Note it exists; revisit only if a video deliverable is actually asked for.

---

### 3. AgentShield (`affaan-m/agentshield`, `npx ecc-agentshield scan`)
**Verified.** Real. 102 static rules, 1,282 tests. Scans `CLAUDE.md`,
`.claude/settings.json`, `mcp.json`, `hooks/`, `agents/*.md` for hardcoded secrets,
prompt-injection patterns, over-permissive allowlists, missing deny lists, **dangerous
bypass flags**, risky MCP endpoints, command interpolation, silent error suppression.
Output: terminal / JSON / Markdown / HTML.

**The doc does not disclose that #3 and #6 are the same author.** `ecc-` is the
Everything Claude Code prefix. So "install AgentShield, then run it after every other
install" is one vendor recommending its own scanner as the neutral safety check on its
own ecosystem. That does not make it bad — it makes the framing not independent.

**Why it lands hardest on us specifically.** Our config is exactly what its rules
target:
- `permissions: 155 allow / 0 deny / 0 ask` — no deny list at all
- `defaultMode: "auto"`
- `skipDangerousModePermissionPrompt: true`, `skipAutoPermissionPrompt: true`
- 8 node hooks running on every Write/Edit/Bash
- 3 MCP servers, one of which (obsidian) has vault write access
- 119 rule files + a 400-line CLAUDE.md that agents follow as law
- DB credentials, domain auth, and **player medical/performance data** in scope

We have never audited any of that. `soft_deny` in `autoMode` carries two DB/main-branch
entries; the real `permissions.deny` is empty.

**Cost: near zero.** `npx`, read-only, no install, no config change. `--fix` exists but
should NOT be used blind on our settings.

**Verdict: ADOPT FIRST. This is the one to run today.** Read-only scan, then triage the
report by hand. Do not run `--fix`.

---

### 4. DeerFlow (`bytedance/deer-flow`) — SuperAgent harness
**Verified.** Real, MIT, LangGraph/LangChain, v2 is a ground-up rewrite (the doc's
warning about pre-v2 tutorials is correct). Install is Docker: `make config` →
`make docker-init` → `make docker-start`, UI on :2026.

**This is not a Claude Code upgrade.** It is a separate self-hosted agent product with
its own model providers, API keys, and sandbox. The doc says as much at the bottom.

**Fit for us: poor.** We already have subagents (27), orchestration (Workflow, GSD
autonomous, forks), and long-horizon work handled by scheduled Connect jobs and pin
scripts. The one thing it adds — an isolated sandbox for code execution — is a problem
we solve with worktrees and the personal/work laptop split. Adding a Docker service
with its own LLM keys expands the credential surface for no named job.

**Verdict: SKIP** unless a specific job appears that our stack cannot do.

---

### 5. Graphify (`Graphify-Labs/graphify`) — code knowledge graph
**Verified.** Real. tree-sitter AST, local + deterministic, 25 languages, no vector
store, edges tagged EXTRACTED vs INFERRED. Claimed ~71x token reduction on their corpus.
`graphify install --platform claude` writes a CLAUDE.md directive **and a PreToolUse
hook** so the graph is consulted before every file-search tool call.

**Two things to weigh, and they cut opposite ways.**

*For:* we do sweep 4 worktrees with grep constantly — parity audits, reference-impl
lookups, the "is this metric implemented in all 3 surfaces" question. `three-surface-parity`
and `metric-audit` are literally graph queries done by hand. And SQL schemas + configs
are in its stated scope.

*Against — and this is the important one:* **our measured context problem was never
code re-reading. It was rule injection.** [[context-bloat-fix-plan]] measured 903K / ~220K
tokens of *rules* on a single Streamlit edit; the Aug 20 retargeting cut always-on from
34 files/293K to 13/75K (verified again today). Graphify does not touch that. It fixes a
cost we did not measure and may not have.

**And strict mode conflicts with our blocking law.** `--strict` blocks the first raw
source read of a session and redirects to the graph. Core Rule #1 is *"always read
existing sibling/reference implementations before writing new code"*; blocking rule #1
is *"NEVER guess DB column names — grep, or verify with INFORMATION_SCHEMA."* A graph
edge labelled INFERRED is exactly the kind of plausible-but-underived answer that rule
exists to prevent. Half our incident history ([[tautological-display]], the `next_level`
case; the Aug 28 "trusted a NAME over a COUNT" case) is *this failure mode*.

**Verdict: PILOT WITHOUT STRICT MODE, on one worktree.** Default mode is zero-token AST
parsing — cheap to try. Measure whether it actually shortens a real parity audit. Never
enable `--strict`. Note the doc's own catch: re-run `graphify hook install` after any
upgrade, because the hook embeds the interpreter path — and our interpreter paths differ
between laptops.

---

### 6. Everything Claude Code (`affaan-m/everything-claude-code`)
**Verified, and already triaged once** — it is #4 in [[claude-code-toolkit-raycfu]]
(Jun 29 2026), verdict "📚 Study" for its memory-optimizer subagent. It has grown:
**38 agents, 156 skills, 72 command shims, 28 hooks across 7 events.**

The doc's stated selling point is the hooks-and-rules layer (tests before claiming
success, no hardcoded secrets, no committing broken code, coverage gates) — "these run
as actual hooks, which is why they work when a line in a prompt would not."

**That principle is correct and it is our gap 2 from [[loop-engineering]], still open
since June.** But we do not need 38 agents and 156 skills to get it. We already run
`bsb-law-gate.js` as a PreToolUse hook; the move is to *extend that file*, not to import
someone else's 28 hooks on top of our 9.

**Collision risk is the highest of any repo here.** 156 skills would land beside our 14
+ superpowers + GSD + voltagent. 38 agents beside our 27. Its rules must be hand-copied
to `~/.claude/rules/` (the doc is right that plugins can't ship rules) — into the same
directory our `sync-rules.sh` treats as authoritative and byte-copies to 4 worktrees.
And the fork problem the doc names is real: search returns at least three forks
(`chchwa/`, `WorldFlowAI/`, `usernametron/`, `faisalalqarni/`) under different names.

**Verdict: MINE THE HOOKS, INSTALL NOTHING.** Read `hooks/hooks.json`, take the 2-3
patterns worth having, write them into `bsb-law-gate.js` ourselves.

---

## Part 3 — What integration would actually look like

Ordered by value-to-risk. Nothing here is a full install.

**Step 1 — audit before adding anything (today, ~10 min, zero risk)**
```
npx ecc-agentshield scan .
```
Run it in `bsb-resources`. Read the report. Do **not** pass `--fix`. Expect it to flag:
empty deny list, `skipDangerousModePermissionPrompt`, auto mode, hook command
interpolation, the obsidian MCP write scope. Triage by hand; a flag is a question, not a
defect — several will be deliberate choices we keep.

**Step 2 — close the edit-lock gap (highest real value)**
Vendor gstack's `/freeze` `/careful` `/guard` pattern, or implement the same idea in
`bsb-law-gate.js`: a PreToolUse hook that refuses a Write/Edit outside the active
worktree's project subfolder. This makes CLAUDE.md Core Rule #2 ("confirm WHICH worktree,
never assume") mechanical. It is the one thing in these six repos that solves a named,
recurring, expensive failure for us.

**Step 3 — hooks-as-law, take two**
Re-open [[loop-engineering]] gap 2. Read ECC's `hooks/hooks.json` and gstack's guard
skills for patterns, then extend `bsb-law-gate.js` so `metric-audit` (on a metric change)
and `render-and-look` (on a visual change) fire deterministically rather than "if the
agent remembers." June's note flagged TDD Guard for exactly this and it never got done.

**Step 4 — pilot Graphify on ONE worktree, default mode only**
`graphify install --platform claude` in `bsb-wt-intangibles` (smallest, most
cross-referenced). Run a real parity audit through it. Keep it only if it measurably
shortens one. Never `--strict`. Never on all four at once.

**Step 5 — optional, low stakes**
`/diagram` and `/design-shotgun` from gstack, if the explainer/render workflow keeps
costing round-trips.

**Not doing:** DeerFlow, OpenMontage, full gstack, full ECC.

---

## Part 4 — Risks specific to OUR config

The doc's safety section is right in general and understates the case for us.

1. **We are in `auto` permission mode with 155 allows, 0 denies, and both dangerous-mode
   prompts skipped.** Anything that writes hooks or MCP servers into this config executes
   with very little friction. The doc's "read hooks.json before you install" is not
   optional here.
2. **`sync-rules.sh` is a PostToolUse hook that byte-copies `.claude/rules/` and
   `.claude/scripts/` to 3 sibling worktrees on every Write/Edit.** Anything dropped into
   those directories propagates automatically and immediately. `sync-rules.sh` has already
   nearly deleted a rule once (blocking #18b, Aug 30). Do not let a third-party installer
   write there.
3. **Scope creep in the memory layer.** We run three memory systems already (recall MCP,
   this vault, `~/.claude/projects/.../memory/`). gbrain would be four, ECC's
   memory-optimizer five. More stores = more places for a stale fact to survive.
4. **Skill-name collisions.** ECC has a `/spec`, gstack has a `/spec`, GSD has a `/spec`,
   and we have a `/spec` alias. Three more `/review`s. Whichever resolves first wins, and
   the failure is silent.
5. **Same-vendor recommendation loop (#3 recommending scanning after installing #6).**
   Fine to use the scanner; do not treat it as an independent audit of its own ecosystem.
6. **Fork/typosquat.** `everything-claude-code` has 4+ mirrors under different owners.
   If we ever install, it is `affaan-m/` and nothing else.

---

## Part 5 — The finding underneath the list

**Three** of the six sell **process** — planning, review, QA, release discipline, memory:
gstack (#1), everything-claude-code (#6), and AgentShield (#3) as config hygiene. That is
precisely the layer we have spent since April building by hand, and ours is tuned to a
domain none of them know: T-SQL grain traps, percentile pool gates, three-surface parity,
the personal/work laptop split, Posit Connect deploys, and 23 blocking rules that each
exist because something shipped wrong. A generic `/review` does not know that
`next_level >= level_to` compares a value against itself.

The other three are not process and not comparable to anything we run: Graphify (#5) is
retrieval, DeerFlow (#4) is a separate agent runtime, OpenMontage (#2) is a video product.
An earlier draft of this note said "five of six" — that overstated the redundancy and
contradicted Parts 2.4 and 2.2 above. Corrected 2026-08-31.

So the answer is not "which of these do we install." It is: **the only items worth taking
are the ones that turn a prose rule of ours into a mechanism.** That is exactly two
things — the security scan (#3) and the edit-lock/hooks-as-law pattern (#1 and #6). The
rest is either redundant with what we run, or a different product entirely.

June's list produced a "next move" that was never executed. If this one produces the same,
it was entertainment.

---

## DECISION (Zac, 2026-09-01)

**Graphify is the implement.** Not for the Python — **for documentation.** DeerFlow and
OpenMontage are **SHELVED for the future** (not rejected — revisit when a job appears).
AgentShield scan + the edit-lock/hooks-as-law work stand as previously written.

### Why Graphify earns it on the DOCS corpus specifically

Its own numbers: 71.5x token reduction on 52 **mixed** files, ~1x on a 6-file codebase.
The win is on mixed corpora, and ours is large: 119 rule files (1518K), the whole vault,
`sql-queries/schema/`, R&D PDFs, diagrams. It ingests code via tree-sitter AST, markdown
via LLM concept extraction, PDFs via citation mining, images/diagrams via vision.

The specific documentation job nothing else we own can do: **our rules already CLAIM a
link structure** — every rule file ends in "Cross-references", `blocking-rules.md` names
every rule by path, `reference-impl-index.md` is a hand-maintained metric→file:line map,
and `MEMORY.md` is ~200 `[[wikilinks]]`. Nothing verifies any of it. A graph surfaces
orphan rules nothing points at, rules that should cross-reference and don't, and
`[[wikilink]]` targets that were never written. `GRAPH_REPORT.md` (god nodes + surprising
connections) is a documentation audit we have never been able to run.

### Verified install facts (2026-09-01)

- PyPI package is **`graphifyy`** (double-y); the CLI is `graphify`. Confirm this before
  installing — a single-y `graphify` on PyPI would be a textbook typosquat.
- `uv tool install graphifyy` (recommended) / `pipx` / `pip`.
- `graphify install --platform claude` writes **three** things: the `/graphify` skill, a
  **CLAUDE.md registration**, and a **PreToolUse hook that fires on every Glob and Grep**.
- **Docs/PDF/image extraction inside Claude Code uses the existing session's model — no
  separate API key.** Only headless `graphify extract` needs `ANTHROPIC_API_KEY`.
- **Windows:** use `graphify .`, NOT `/graphify .` — the leading slash is a path separator
  in PowerShell. Developer Mode needed for symlinks; LongPathsEnabled for long paths.
- Strict mode is runtime-toggleable: `GRAPHIFY_HOOK_STRICT=0`. Keep it 0. See the
  blocking-rule-#1 conflict in Part 2.5.
- `graphify uninstall` (`--purge` also deletes `graphify-out/`) — fully reversible.
- Re-run `graphify hook install` after any upgrade; the hook embeds the interpreter path,
  and ours differs between the personal and work laptops.

### Pilot plan (staged, bounded)

0. Install via `uv`, then inspect exactly what it wrote to CLAUDE.md and settings before
   running anything. Set `GRAPHIFY_HOOK_STRICT=0` first.
1. Graph **`.claude/rules/` + CLAUDE.md only** — one bounded corpus, highest doc value.
2. Read `GRAPH_REPORT.md`. Judge on one real question: an orphan-rule / broken-crosslink
   audit, and a `path` query between a metric and its reference impl.
3. Only if step 2 pays: extend to the vault, then `--update`/`--watch`.

**Guardrails:** never `--strict`; do not let the installer's CLAUDE.md edit ship
unreviewed (CLAUDE.md is a tuned instrument and a tracked file); do not install into the
sibling worktrees until proven here. Note `sync-rules.sh` copies `.claude/rules/` and
`.claude/scripts/` to 3 worktrees on every Write/Edit — it does NOT copy settings or
skills, so a Graphify install should not auto-propagate, but verify that holds.

### Salvage from the shelved two

Neither product is coming in, but each contains one mechanism we have only as prose:

- **OpenMontage's budget governance** — estimate → reserve → reconcile → `cap` (hard
  limit) + per-action approval threshold + a decision log of every provider chosen *and
  the alternatives considered*. That is blocking rule **18b** ("estimate a query's COST
  before handing it to the user") as a mechanism. Ours is a paragraph that exists because
  a probe ran 2+ hours before being killed.
- **OpenMontage's pre-compose validation** — refuses to render when the delivery promise
  is violated (their example: a "motion-led" video that is 80% stills), then post-render
  self-review runs ffprobe validation and frame sampling before showing the file.
  "Approval gates are enforced, not suggested." That is blocking rule **#18**
  (render-and-look) plus rule **4b** (a guard must run at the grain that can break),
  implemented in code. We enforce both by remembering.

**The convergence is the finding:** gstack's `/freeze`, ECC's 28 hooks, and OpenMontage's
approval gates are three independent projects landing on the same idea — *put the guard in
a hook that can refuse, not in a prompt that can be forgotten.* We have 23 blocking rules
and exactly one hook enforcing any of them (`bsb-law-gate.js`). Open since Jun 29.

### DeerFlow — the reason it is shelved, not skipped

Self-hosted LangGraph runtime; sandbox in local/Docker/K8s; built-in skills for research,
reports, slides, web pages, and `/data-analysis analyze file.csv` → dashboards. The one
genuine fit was its **message gateway: Telegram, Slack, Feishu, WeChat, DingTalk,
auto-starting with no public IP**. That is precisely what IT has denied (CLAUDE.md: Slack
Incoming Webhooks denied, Slack Bot/App install denied), and workarounds are on the
do-not-suggest list. Cost of entry is 16 vCPU / 32 GB recommended plus a second set of LLM
keys. Revisit only if the Slack posture changes or a long-horizon job appears that our
worktrees + Connect jobs cannot do.

---

## PILOT RESULT (2026-09-01) — built, and here is the honest verdict

Built the graph over `.claude/rules` + reference PDFs. **123/123 files, 727 nodes, 752
edges, 74 communities.** Extraction ran as 6 parallel general-purpose subagents writing
JSON to disk, ~1.6M input tokens total — spent in the subagents, NOT in the main session
context. Health check clean: **0 dangling, 0 missing endpoints**, so the node-ID
convention held across all six chunks. Outputs in `bsb-resources/graphify-out/`
(gitignored): `graph.html`, `graph.json`, `GRAPH_REPORT.md`.

Install was non-invasive: all four config checksums unchanged, no hooks, `--strict` is
opt-in and requires `--project`. One new 231-byte global `~/.claude/CLAUDE.md` registering
the skill.

### THE HEADLINE FINDING (verified by grep, not by the graph)

`rule-loading-architecture.md:65` states the safety guarantee for the entire Aug 20
rules-retargeting:

> "`blocking-rules.md` stays always-on and **names every rule file by path**. So a
> narrowed rule does not become unfindable — it becomes on-demand, reachable via that
> pointer or `/load-rules`."

**It names 18 of 119.** The 18: barrelsville, blank-must-not-overwrite,
central-time-not-utc, db-columns, dual-query-path, fielding, intangibles, level-codes,
monkeypatch-idempotency, org-attribution-per-pa, org-codes, pdf-last-in-script, pd-goals,
pitfalls, pooled-percentile-pattern, query-cost-before-handoff, render-and-look,
tautological-display.

So **101 rule files are neither always-on nor named in the always-on index.** They load
only when a `paths:` glob happens to match. The justification for narrowing 106 rules off
always-on was that the index would keep them reachable; the index does not do that. This
is the same defect class as `tautological-display.md` — a stated guarantee that nothing
verifies, which reads as true because it is written down.

### The graph UNDER-REPORTS edges — do not trust its orphan list

The graph called 5 files fully isolated. Grep says **4 of the 5 are cited by other rules**:

| graph says isolated | actually cited by |
|---|---|
| `windows-toolchain.md` | blank-must-not-overwrite, br-advance-3rd-out-wash, posit-card-status-hygiene, rasterizer-fidelity, render-and-look, rule-loading-architecture (**6**) |
| `never-defer-to-tomorrow.md` | movement-cleaning-canonical, query-cost-before-handoff, rule-loading-architecture |
| `windows`/`external-resource-capture.md` | rule-loading-architecture |
| `weekly-report-no-activity-gate.md` | amateur-data-guardrails |
| `weights-sum-to-100.md` | **nothing — genuinely orphaned** |

A 4-in-5 false-positive rate on that one query. The semantic extractor only emits an edge
when a subagent notices and encodes it; a passing mention in prose does not become an
edge. **Treat graph output as a hypothesis generator and confirm with grep** — which is
exactly blocking rule #1, and exactly why `--strict` stays off. Strict mode would have
substituted the wrong answer for the grep that produced the right one.

### Other real defects surfaced

1. **`org-codes.md` contradicts itself.** Rule 2 mandates the CHI/LA/NY remap on
   PP_MASTER↔MLBAM joins (and its May 12 2026 bug history records fixing exactly that);
   its "What NOT to do" says do NOT add chi/la/ny remapping to PP_MASTER↔MLBAM joins
   because they are "R4-shorthand-specific." Org-code canon is **blocking rule #14** —
   getting it wrong silently drops the Cubs, Dodgers, Mets and Athletics. Needs Zac's
   call on which side matches the shipped queries.
2. **Four Streamlit rule files share one root cause** (top-to-bottom rerun) —
   `streamlit-module-scope-cost`, `-conditional-widget-state`, `-keep-subpage-on-rerun`,
   `-inline-images` — but only **2 of the 6 pairings** cross-reference each other.
3. **`weights-sum-to-100.md` is orphaned AND always-on** despite being domain-specific —
   it was already on the Open-items list as a `paths:` candidate; now confirmed nothing
   points at it either.
4. **`.graduation-log.md` was truncated** at line 849 of 1011 by the subagent read cap;
   ~160 lines of older May 2026 entries went unextracted. Re-queue at `offset=850`.
5. **29 rule files are never cited by any other rule** (they point out, nothing points
   back) — subject to the same false-positive caveat as above, so verify before acting.

### Verdict

**Keep it, scoped.** It earned its place as a *hypothesis generator over documentation* —
the community clustering and the never-cited list pointed straight at questions worth
asking, and one of those questions found a broken load-bearing guarantee. It did not
earn trust as an *authority*: its edge recall is well below grep's. Use
`GRAPH_REPORT.md` + `god-nodes` + the never-cited list to decide WHERE to look, then
grep to decide WHAT IS TRUE.

Not extending to the vault or the code worktrees until the above is acted on.

---

## Open items
- [ ] Run `npx ecc-agentshield scan .` in bsb-resources; triage the report by hand
- [ ] Decide: vendor gstack `/freeze` vs implement edit-lock in `bsb-law-gate.js`
- [ ] Shelved for future: DeerFlow, OpenMontage (salvage patterns noted in DECISION above)
- [ ] Re-open [[loop-engineering]] gap 2 (hooks-as-law) — still open since Jun 29
- [x] ~~Graphify pilot stage 0-2~~ — DONE 2026-09-01, see PILOT RESULT above.
- [ ] **FIX: `blocking-rules.md` indexes 18 of 119 rules** while
      `rule-loading-architecture.md:65` claims it names every one. Either complete the
      index or correct the claim — right now the retargeting's safety story is false.
- [ ] **DECIDE: `org-codes.md` self-contradiction** on the CHI/LA/NY remap (blocking #14).
- [ ] Add the 4 missing Streamlit cross-references (2 of 6 pairings present).
- [ ] Re-extract `.graduation-log.md` at offset 850 (truncated at 849/1011).
- [ ] Give `weights-sum-to-100.md` + `pitch-grade-variants.md` real `paths:` frontmatter.
- [ ] Rotate the `GOOGLE_API_KEY` that was echoed into the 2026-09-01 session transcript.
- [ ] `pitch-grade-variants.md` (8K) and `weights-sum-to-100.md` (2K) are always-on but
      domain-scoped — candidates for `paths:` frontmatter (see [[context-bloat-fix-plan]])


---

## Re-surfaced 2026-10-02 - Ray Fu newsletter "How to Replace Your Dev Team With 68 AI Agents"

Source: https://raycfu.beehiiv.com/p/how-to-replace-your-dev-team-with-68-ai-agents (Oct 1 2026, pasted by Zac).
Same repo (`affaan-m/ECC`), now pitched as 68 agents / 292 skills / 94 commands (counts from the post, not re-verified).
Workflow it sells: `/ecc:plan` -> tdd-workflow skill -> `/code-review` -> `/security-scan` (AgentShield) -> `/test-coverage` (80%) -> `/build-fix`, plus `/save-session` `/resume-session` `/learn-eval` `/instinct-status` for memory.

**Verdict unchanged: do not install full ECC.** Every stage already has an equivalent here
(superpowers brainstorming/writing-plans + GSD plan = plan; superpowers TDD; /code-review; /security-review;
/wrap + /brief + recall MCP = save/resume). Its install step copies `rules/common` into `~/.claude/rules/ecc`,
which loads on EVERY project and would push us back over the 150k instruction limit we hit Sep 24
(see `rule-loading-architecture.md`). Also adds more slash-name collisions (risk #4 above).

**Still undone from the Aug 31 plan (checked 2026-10-02):**
- Step 1, `npx ecc-agentshield scan .` in bsb-resources: never run (no results anywhere in the vault).
- Step 3, make `metric-audit` + `render-and-look` fire from `.claude/hooks/bsb-law-gate.js`: hook exists, neither is wired.
These two are the actionable pieces.

Only genuinely new idea in this post: `/learn-eval` / `/instinct-status`, i.e. MEASURING whether the agent
stops repeating mistakes. Our analog would be counting rule "Bug history" recurrences per month. Not started.
