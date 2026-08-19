# Context-Bloat Fix — spec seed (captured 2026-07-09)

**Next session: `/brief` → `/spec` this.** The goal is to stop fresh Claude Code
sessions from burning ~50% of context before any real work. Everything below is
measured, not guessed — don't re-derive.

## The problem (diagnosed 2026-07-08/09)
A fresh session on `bsb-resources` pays a huge fixed injection tax:
- **`.claude/rules/` = 1.1 MB across 84 files** (~275K tokens if all loaded).
- Reading just **2 files in `pd-goals/`** auto-loaded **~42 rule files (~140K tokens)** — the path→rule matcher is far too broad.
- Biggest rules: `tracker-parquet-pins.md` 44KB · `arm-farm.md` 41KB · `pd-goals.md` 41KB · `intangibles.md` 40KB · `multi-level-rollup.md` 37KB.
- **`.claude/settings.local.json` = ~27K tokens** — 414 individual permission entries (e.g. 30+ distinct `git commit -m "…"` strings) that loads every session.
- Plus CLAUDE.md (18KB) + the always-on blocking-rules set (~30–40K tokens).
- Net: ~200K tokens of pure INJECTION before work + `/brief` + skills.

**The irony:** the rules system was built to FIGHT context rot but became the #1
context consumer. It does eager INJECTION; it should do retrieval (like the vault:
one note per question, loaded on demand).

## The fix — 4 levers, by impact/effort
1. **Tighten the auto-load scope (biggest win).** A `pd-goals` read should pull ~5 relevant rules (db-columns, pd-goals, pitfalls, the domain one) — NOT 42. Rule files now carry frontmatter `paths:` globs (e.g. pd-goals.md has `paths: [pd-goals/**/*]`); AUDIT every rule's `paths:` — the universal ones (db-columns, pitfalls, visual-standards, etc.) are matching everything. Scope them tighter or make them pointer-first.
2. **Pointer-first big rules.** The 40KB files load a ~30-line index by default; grep the full section only when the task needs it. Retrieval, not injection.
3. **Collapse `settings.local.json` (free ~25K tokens/session, zero risk).** 414 entries → wildcards: `Bash(git commit:*)`, `Bash(cp:*)`, `Bash(git -C:*)`, `Bash(sed:*)`, `Bash(find:*)`, etc. Most of the file is redundant specific commands.
4. **Trim always-on set.** `blocking-rules.md` inlines 18 rules in full → make it pointers.

**Highest leverage = #1 + #3** (both low-risk config, not code; together ~halve the fresh-session baseline).

## Spec decisions to resolve (the forks)
- For #1: retune each rule's `paths:` frontmatter, OR switch to a "load index, grep detail" model, OR a hard cap on # rules auto-loaded per turn? (which mechanism)
- Which rules are truly "universal" (must always load) vs "load only in domain"? — db-columns/pitfalls feel universal; visual-standards/tracking-schema/arm-farm do NOT.
- For #3: confirm wildcard consolidation won't over-broaden permissions in a way the user dislikes.
- Do the fix in bsb-resources then `/sync-rules` to the 3 worktrees (settings.local.json + rule frontmatter both need syncing).

## Verify
Fresh session, read 2 `pd-goals` files, count `Loaded .claude/rules/*` lines — target ≤ ~6, not 42. Check session context % after `/brief` + those reads.

Cross-ref: [[loop-engineering]] · [[claude-usage-audit-2026-07-02]] · [[skills-cheatsheet]].
