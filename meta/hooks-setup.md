---
type: meta
topic: hooks
status: active
created: '2026-06-17'
---
# Claude Code Hooks — current setup (2026-06-17)

Record of what's wired + the 2026-06-17 fixes. Hooks = **law** (deterministic,
fire every time) vs CLAUDE.md = taste. See [[loop-engineering]].

## Active hooks

| Event | Command | Scope | Purpose |
|---|---|---|---|
| SessionStart | `gsd-check-update.js` | user | GSD update check |
| PostToolUse (`Bash\|Edit\|Write\|Agent\|Task`) | `gsd-context-monitor.js` | user | GSD context monitor |
| PreToolUse (`Write\|Edit`) | `gsd-prompt-guard.js` | user | GSD guard |
| **SessionEnd** | `autocapture-session.js` | user | **NEW — auto-capture** |
| PostToolUse (`Write\|Edit`) | `sync-rules.sh` | bsb-resources local | sync rules → 3 worktrees |
| statusLine | `gsd-statusline.js` | user | status line |

Note: `CLAUDE_CODE_AUTO_COMPACT_ENABLED=false` in user settings → you `/clear`
manually, so **SessionEnd** (not PreCompact) is the capture trigger.

## Fixes applied 2026-06-17

1. **SessionEnd auto-capture (NEW)** — `C:/Users/Owner/.claude/hooks/autocapture-session.js`.
   On every clear/exit it copies the session transcript into
   `bsb-brain/00-inbox/transcripts/<date>_<sid>.jsonl` and appends a pointer to
   `bsb-brain/00-inbox/_autocapture-<date>.md`. **Cheap + lossless, no LLM.**
   Curate later with `/log`; clear the file after. This is the "state file"
   principle — multi-agent days no longer lose context on `/clear`. Verified
   working (test payload → wrote correctly). Wired in user `settings.json`.

2. **sync-rules hook path fix** — the command was the relative
   `bash .claude/scripts/sync-rules.sh`, which errored (`No such file or
   directory`) whenever cwd ≠ bsb-resources (e.g. editing from bsb-brain).
   Changed to the absolute path. The script already self-guards (only syncs when
   a `.claude/rules/` file was edited), so this was purely the path bug.

## Known open item — the rules-bloat (separate fix)

bsb-resources auto-loads **~310k tokens of `.claude/rules/`** every session and
every subagent → subagents spawned from there die with "prompt too long"
(confirmed 2026-06-17: 3/3 research agents failed identically). `.claudecodeignore`
already excludes graduation logs (~35k); the bulk still loads. **Next
optimization:** split rarely-needed reference rules out of the always-load path
(deliberate — many rules are load-bearing for coding; can't blind-ignore).
Tracked in [[loop-engineering]] open TODOs.
