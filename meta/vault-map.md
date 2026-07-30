# Vault Map

Top-level structure of the BSB Brain vault. See `CLAUDE.md` for the retrieval
rules and `README-dual-run.md` for the safety contract.

```
bsb-brain/
├── CLAUDE.md            → vault operating instructions (slim, retrieval-first)
├── 00-inbox/            → unprocessed captures + attachments
├── rules/               → SNAPSHOT of .claude/rules (70 files) — READ-ONLY
│   └── blocking-rules.md   ← the 17 non-negotiables (read first for code work)
├── memory/              → SNAPSHOT of agent memory (124 files) — READ-ONLY
│   └── MEMORY.md           ← the memory index
├── chatgpt-imports/     → exported ChatGPT history (see README there)
├── sql/                 → saved queries, schema notes, discovery SQL
├── projects/            → active project notes (one subfolder each)
├── personal/            → reflection, learning, non-work
├── meta/                → vault system docs (this file, dual-run, mcp-setup)
└── templates/           → note templates
```

## Two zones, two rules

- **READ-ONLY zone** (`rules/`, `memory/`): retrieved on demand, never rewritten
  here. Canonical writer is the live `.claude/` workflow.
- **WRITE zone** (everything else): yours to capture, organize, and link freely.

## Counts at build time

- 70 rule notes
- 124 memory notes
- = 194-note starting graph (before personal/ChatGPT content)

- [[claude-session-skill-sequence]] — cheatsheet: what each session skill does (/brief /wrap /research /document /ingest /deep-research /explain + GSD /spec /plan /implement /reviewloop /orchestrate) and the canonical order they run in. (added 2026-07-06)
