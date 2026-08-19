# Claude Code Usage Audit — Jun 10 → Jul 2, 2026

**What this is:** Fable use case 02 ([[fable5-use-cases]]) run on 2026-07-02.
Four parallel sub-agents read distilled digests of **82 bsb-resources sessions**
(user-typed messages + tool errors + slash commands; 293MB JSONL → 1.1MB digests),
clustered friction, and proposed fixes. This file is the synthesis, ranked by
(frequency × pain). Evidence quotes live in the per-window agent reports (not
retained — the clusters below carry dates + sample quotes).

## Ranked friction clusters

### 1. End-of-session wrap + crash recovery ritual — THE #1 TAX
Every window, ~30+ sessions. Two faces of one problem:
- **Closing:** "document everything then I'll clear" / "/log + /sync + sync-rules
  so I can clear" typed manually at the end of nearly every session (9× Jun 10–14,
  ~9× Jun 15–19, 8× Jun 20–25).
- **Opening after a crash:** "computer crashed, where were we??" (4+ sessions
  Jun 26–Jul 2 alone; also Jun 16/18 restarts).

**Fix (one build, both faces):** a **`/wrap` skill** that chains: memory
graduation check → /log daily note (create from template when missing — the
`05-daily/2026-06-XX.md not found` error hit 3×) → vault /sync → /sync-rules →
write a rolling **`last-state.md`** (task, branch, exact next step) →
"safe to /clear." Pair with a SessionEnd/Stop hook writing `last-state.md`
automatically and make `/brief` read it FIRST. The Jul 2 session-digest hook is
halfway there — add the forward-looking "next step" field.

### 2. Pin / deploy "what do I run now?" — biggest single-window cluster
Jun 20–25 dominant (asked 3× in one session, ~10 sessions total); also Jun 18–19
("oh i have to repin huh... thats retarded") and Jul 2 ("run skip combos then
build combos after?").

**Fix:** **`pin-deploy-runbook.md` rule + `/whats-next` behavior**: after any
tracker/app commit, Claude proactively prints the exact ordered work-laptop
commands (git pull → pin script + flags → connect_pins deploy.ps1 → rsconnect
manifest --app-id GUID) including the "pin before app redeploy?" ordering
answer and expected runtimes. Zero new infra — it's a discipline + one rule file.

### 3. Recall failure — canonicals/prior queries not consulted before SQL
The most expensive *correctness* cluster: SwDec direction inverted (Jun 10–11,
full deck refactor), PoC sign flipped vs tracker canonical (Jun 29 — rule
existed, wasn't read), wrong PA source on first-rounder query (Jul 1 — shipped
wrong data to a coach), `gs_2026` guessed column (Jun 20), "we have queried
this before, come on man" (Jul 2).

**Fix:** **Step 0 in the `baseball-sql` skill**: (a) grep `sql-queries/` +
`reference-impl-index.md` + memory for the ask-shape BEFORE drafting; (b) echo
back ONE scope line (years, roster gate, level, per-player vs pool grain) for
confirmation before writing SQL. Optional hard gate: PreToolUse hook blocking
`sql-queries/*.sql` writes until a recall grep ran. The sql-vault-index scripts
(Jun 29) were built for exactly this — wire them in.

### 4. Work-laptop round-trip loop
Every window: pull → set env → run → paste output/error back. Recurring
environment potholes: GitHub DNS flake, untracked files blocking pull, py3.13
vs 3.14 launcher, ExecutionPolicy, 15-min diff runs with no ETA ("how long do
u estimate this taking?!"), temp-table rerun errors on pasted SQL.

**Fix:** (a) **`wl_run.ps1` per worktree** — env setup + retry-pull +
stash-untracked + command + ETA print + tee log, so the ritual is one line;
(b) expected-runtime table in `tracker-parquet-pins.md`; (c) rule: shareable
T-SQL always starts `IF OBJECT_ID('tempdb..#x') IS NOT NULL DROP TABLE #x`;
(d) the user's own idea (Jun 23): a **csv-fixture-test** path — hand Claude a
CSV sample so DB-dependent scripts get tested locally before the laptop trip.

### 5. Visuals shipped unrendered / restructured beyond the ask
Spawned rule #18 (Jun 17 stray-"P") yet continued: grey text off-PDF (Jun 28),
"PLACEHOLDERS on every one" (Jun 28), camera-angle thrash with no images in
chat (Jun 21), "put it back where it was, you fucked everything up" (Jun 20),
false "can't read PDFs" claim (Jul 1 — fitz works).

**Fix:** (a) always paste the rendered PNG **into chat** before committing any
layout/angle change (not just self-inspect); (b) add a **minimal-diff clause**
to `render-and-look.md`: never move elements the user didn't name; (c) note in
that rule: local PDF reading = pymupdf/fitz, never pdftoppm (missing on this box).

### 6. Context bloat / MEMORY.md auto-load
"Why is context so used up after a simple request" (Jun 19); 309.8k tokens of
memory files (Jun 16); MEMORY.md now 254 lines / 75.4KB and truncating.

**Fix:** run `/memory-cleanup`: collapse shipped-project entries (amateur-vs-pro,
injury dashboard, etc.) to one-liners, move detail to topic files, enforce the
one-line-index rule. This is overdue and mechanical.

### 7. Recurring tool/environment errors (hook/config candidates)
- **Wrong-worktree relative paths** (7+ sessions) — Claude cwd is bsb-resources
  but edits sibling worktrees → always absolute paths; re-read worktree map.
- **SendUserFile validation error** (3×) — files must be a JSON array.
- **pdftoppm / powershell.exe not found in Bash** (4 sessions) — use full
  `System32\WindowsPowerShell\v1.0\powershell.exe` path or the PowerShell tool;
  fitz for PDFs. Candidate rule: `windows-toolchain.md`.
- **"File has not been read yet"** edit rejections (9+ sessions) — habit-level.
- **git SSH kex / DNS flakes** (4 sessions) — retry once, then hand to user.

### 8. Smaller durable wins
- **add-slack-channels skill** — the 5-CSV × 4-worktree paste ritual ran 3× in
  2 days (Jun 15–16) and again Jul 1.
- **new-posit-app rule** — manifest/requirements/py3.11/DB Vars checklist;
  deploy amnesia burned Jun 18–19 + Jun 23 (DB_USER/DB_PASS memory now exists).
- **goal-hook-hygiene rule** — a /goal whose verification needs the work laptop
  looped a Stop hook ~28× (Jun 14), burning a whole context window.
- **"in the chat, not a file"** — 3× "why did you make a py file, draw it in
  chat" → CLAUDE.md line: one-off queries/mockups render inline by default.
- **pin-freshness audit** — stale OF pins + PRP pin data loss (Jun 29, Jul 2)
  → `/pin-health` script listing pin versions + last-modified per tracker.
- **player-development repo hygiene** — no IT/R&D narrative, no teammate
  names in that shared repo (Jun 13–14).

## Slash/skill usage (observed across 82 sessions)
/clear ~60 · /goal ~22 · /sync ~13 · /sync-rules 6 · /log 7 · baseball-sql
auto-fired 25 · brainstorming 16 · tracker-new-metric 4 · document-pattern 5 ·
new-visual 4. Notably ~zero usage of /brief /today /drift /sunday — the daily
loop exists but isn't habit; the Command-Center deck (use case 03) surfaces them.

## Highest-friction sessions (for the record)
06-14 e63a00af (goal-hook loop) · 06-24 b26cb787 (swing-decision scope misread)
· 06-18 606ce92e (PPTX env fight) · 06-29 0bfc755b (PoC sign) · 06-27 f4878503
(EV-P95 laptop loop) · 07-01 a9369f21 (PDF-reading false claim).

## Suggested build order — status Jul 3 2026
1. ✅ **SHIPPED** `/wrap` command (`~/.claude/commands/wrap.md`) + crash
   breadcrumb hook (`~/.claude/hooks/last-state-breadcrumb.js`, PostToolUse,
   5-min throttle, live-fire verified) + cleanup in `autocapture-session.js` +
   `/brief` Step 0 reads `last-state.md` / breadcrumb + reports MCP status.
   Also fixed: obsidian MCP repointed from `npx @latest` to pinned global
   install (node + server.js direct) — takes effect next session.
2. ✅ **SHIPPED** baseball-sql Step 0 recall-first + scope echo — synced to all
   4 worktrees + committed (bsb-resources `9b490c01`).
3. ✅ **SHIPPED** `pin-deploy-runbook.md` BLOCKING rule — proactive runbook
   print after every tracker/app commit; synced + committed all 4 worktrees.
4. ✅ **SHIPPED Jul 3** — /memory-cleanup index collapse: MEMORY.md 78KB→46.5KB
   (Most Recent Session → one-line index; zero files deleted; backup
   `.bak-20260703`; graduation log entry).
5. ✅ **SHIPPED Jul 3** — `wl_run.ps1` at every worktree root (pull-retry + env
   check + timed tee'd log; UNTESTED on work laptop — first run is the test) +
   `windows-toolchain.md` rule (fitz not pdftoppm, PowerShell paths, no jq,
   SendUserFile array, absolute worktree paths).
6. ✅ **SHIPPED Jul 3** — `add-slack-channels` skill (5 CSVs, checksum verify),
   `new-posit-app.md`, `goal-hook-hygiene.md`, render-and-look v2 (show render
   in chat + minimal-diff clause + fitz note). Commit `402173a5` + 3 sync
   commits, all pushed. Remaining nice-to-have: "in the chat not a file" line
   is covered by /explain's contract; CLAUDE.md line optional.
7. Also born from this audit (Jul 3): /explain command + the 5 agentic.james
   aliases (/spec /plan /implement /reviewloop /orchestrate → GSD).

Related: [[fable5-use-cases]] · [[loop-engineering]] · [[Command-Center]] ·
`.claude/rules/render-and-look.md` · `.claude/skills/baseball-sql`
