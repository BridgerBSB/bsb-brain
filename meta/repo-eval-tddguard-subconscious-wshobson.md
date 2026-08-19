---
type: meta
created: '2026-06-30'
tags:
  - meta
  - ai
  - claude-code
  - tooling
  - eval
  - teams
---
# Repo Eval — TDD Guard · Claude Subconscious · wshobson/agents (Jun 30 2026)

Vetted three repos from the @raycfu carousel ([[claude-code-toolkit-raycfu]]) against our
stack (Claude Code on Windows; 4 Streamlit apps on Posit Connect; DB is work-laptop-only; no
in-session DB). Two were pitched as off-the-shelf fixes for our loop-engineering gaps
([[loop-engineering]]). Neither is, but both hand us a pattern worth lifting. Done by the
`research-analyst` member (its first real assignment).

## TDD Guard (nizos/tdd-guard) — SKIP tool / ADOPT pattern
- **Reality check:** NOT "blocks a commit." It is a `PreToolUse` hook matching
  `Write|Edit|MultiEdit|TodoWrite` that blocks the *edit* if it violates test-first TDD,
  judged by a validation LLM against a live test reporter. Node 22+, MIT. Windows unaddressed
  (Unix-only docs).
- **Gap 2 (hooks-as-law):** the PATTERN nails it; the TOOL does not. It enforces test-first,
  which is not our law. Ours are metric-audit (cross-surface parity) + render-and-look (PNG
  inspection). We have no pytest suite for it to read anyway.
- **Action:** lift the settings.json `PreToolUse` shape into a `.claude/hooks/` Python script
  (reads tool JSON from stdin, exits non-zero to block) that gates metric-file / visual-draw
  edits. Makes `render-and-look` #18 fire as LAW, not prompt.

## Claude Subconscious (letta-ai/claude-subconscious) — SKIP
- 4-hook (SessionStart / UserPromptSubmit / PreToolUse / Stop) background agent; the Stop hook
  ships FULL transcripts to Letta CLOUD, memory injected back. Node, MIT, requires
  `LETTA_API_KEY`. Windows unaddressed.
- **Gap 1 (write-back):** conceptually yes, but (1) it exfiltrates org-internal transcripts
  (player names, GC2 schema) to a third party by default, and (2) we ALREADY run this loop
  transparently via `/log` + SessionEnd capture + vault + memory-cleanup. An opaque cloud brain
  is the opposite of our inspectable design.
- **Action:** steal only the Stop-hook async-summarizer idea, run LOCALLY: a background
  summarizer that proposes golden-set cases into the vault, automating the capture step in
  [[team-training-loop]]. Pair with affaan-m/ecc memory-optimizer (already on the study list).
  Do not adopt the tool.

## wshobson/agents — ADAPT (mine, do not bulk-install)
- 194 agents / 88 plugins, Markdown-only, MIT, Windows-fine, no runtime. Lowest risk. Selective
  install via `/plugin`.
- **Roster:** our 10 council + voltagent agents are DB-grounded and better than the generic
  analogs. Bulk-installing 194 would bloat the roster, and roster bloat already breaks subagent
  spawning from bsb-resources.
- **Action:** install ONLY the security plugin (we have zero security coverage; relevant to
  Connect deploys / DB creds / env-var footguns). Skim data/ML prompt wording to sharpen our
  agents; port wording, do not add agents.

## Recommended next action
Hand-roll gap 2 ourselves: build one `.claude/hooks/` PreToolUse gate (TDD Guard's pattern, our
checks) for render-and-look + metric-audit. Skip both memory tools; extend our existing vault
write-back with a local Stop-hook summarizer instead of adopting Subconscious. Install
wshobson's security plugin only.

Related: [[loop-engineering]] · [[team-training-loop]] · [[claude-code-toolkit-raycfu]]
