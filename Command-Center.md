---
type: MOC
created: '2026-07-01'
tags:
  - moc
  - dashboard
  - hub
---
# 🧠 Command Center: vault home dashboard

> [!example] Browser dashboard — the daily cockpit (Fable use case 03)
> **Double-click `Command-Center.cmd`** at the vault root: it regenerates the HTML and
> opens it. One action, run it each morning. The dashboard shows, top-down:
> - **Today** — where you left off + the exact next step (reads `last-state.md`; run /wrap to update).
> - **Needs attention** — live git triage across all 4 worktrees: branch drift, unpushed
>   commits, uncommitted modified files, inbox backlog, "no /log today". Untracked noise is filtered out.
> - **Recent activity** — merged commit feed across all worktrees (more current than last-state).
> - Ops tiles · sessions chart · notes-by-folder · deploy-chain table · click-to-copy command deck.
>
> Data is a snapshot at generate time — the `.cmd` is the refresh button (no plugins, so no
> live buttons inside Obsidian). Generator: `meta/generate_command_center.py`. Built Jul 2,
> rebuilt as a daily driver Jul 16 2026 — see [[fable5-use-cases]] · [[ig-cc-command-stack-obsidian-command-center]].

> [!tip] Live boards, powered by Bases
> Adopted kepano's official `obsidian-bases` skill (Jul 1 2026). These views are LIVE: they read note frontmatter, so new project and idea notes show up automatically. Open this note in the Obsidian app to see them render (Bases needs the desktop app).

## 🎯 Idea backlog (council foundations + 17-tool)
![[Idea-Backlog.base#Board]]

> [!todo] How the backlog board works (L3 governance)
> Each idea is its own note in `ideas/` carrying `status` / `tier` / `domain` / `effort` / `lens` frontmatter. Advance an idea by editing its `status` (backlog to scoping to building to shipped) and it moves on the board. The [[team-process-architecture|L3 backlog-governance loop]] runs off this view. Full detail: [[council-new-tools-ideation-2026-06-26]].

## 📁 Projects & process
![[Projects-and-Process.base#Projects]]

## 🧭 Maps of content
- [[MOC-baseball-analytics]] — the analytics hub (domains, methods, projects)
- [[advisory-council]] — the 10-member team roster
- [[team-process-architecture]] — teams (3) + loops (3) + build-now workstreams (2)
- [[ecosystem-map-and-process-architecture-2026-06-27]] — the full 4-app ecosystem map
- [[context-library]] — external resource library (vetted)

> [!info] Related
> [[council-knowledge-base]] (the curriculum) · [[team-training-loop]] (how the team improves) · [[loop-engineering]] (the methodology) · [[claude-code-toolkit-raycfu]] (tooling evals)


---

## How to use this hub (the daily loop)

> [!example] Two surfaces, one brain
> - **Obsidian (this vault) = the cockpit.** You *see, plan, and track* here. The boards are the operating surface.
> - **Claude Code = the crew.** The 10 agents *do the work* (run from `bsb-resources` for code, or `cd bsb-brain` for vault ops).
> - **The vault is the bridge.** Both you and the agents read AND write it, so context compounds each cycle instead of resetting.

**1. Start here.** Open this note. Glance at the **backlog board** (what's queued, grouped by status/domain) and the **projects board** (what's live and what moved recently). Thirty seconds of situational awareness.

**2. Pick the next thing.** On the backlog board, look at the `scoping` column and the top-tier `backlog` items. Open an idea note to read the pitch/gap/approach. Decide to move it, then edit its `status` frontmatter (`backlog` -> `scoping`) and it jumps columns on the board.

**3. Put the crew on it.** In Claude Code:
> - Stress-test the idea first -> run the **council** (`council-data-scientist` / `council-scout` / `council-skeptic` + the domain specialist).
> - Build it -> the **Build Squad**: a maker builds, the council checks the diff, the `verifier` proves it.
> - Flip the idea's `status` to `building`, then `shipped`, as it advances. The board is your progress tracker over weeks.

**4. Feed new inputs.** Paste a link / screenshot / idea -> `research-analyst` vets it against the ecosystem and files it itself (context-library + a note). A new idea becomes a new note in `ideas/` and shows up on the board automatically.

**5. Write player evals.** Drop a player's metrics or messy notes -> `player-evaluator` hands back a scouting report in your voice.

**6. Weekly (L3 governance).** Open the board, see what moved, promote the next one or two ideas, the `verifier` sweeps the verification backlog, and the `skeptic` adds any new failure to the golden set.

> [!info] The loop in one line
> The board shows the state, the agents change the state, the vault remembers it. That is the self-feeding brain.
