# LINEAGE - bsb-brain

> Newest on top. What superseded what in the vault's own tooling.

---

## 2026-10-15 - Command Center v1 superseded by v2 (Houston World / Command / Library)

**Superseded:** the neon-green v1 dashboard (`meta/generate_command_center.py` writing
`Command-Center.html`). Replaced by `meta/generate_command_center_v2.py`: a Houston isometric
world (EaDo project yard, downtown library skyline, Daikin Park jobs, Port of Galveston research,
Idea Bank) plus Command and Library tabs. Design: `projects/command-center-library/design.md`.

- **New data layer:** `bank/projects/*.md` (project cards: lane / owner / stage / `## Steps` /
  git hook / `share`) and `bank/processes/*.md` (jobs: scheduled task, log, or manual entry).
- **STILL-WIRED (deliberate):** v1 module stays as v2's helper library (`git_info`,
  `attention_items`, `parse_last_state`, `run_git`); its `__main__` now forwards to v2.
- **Why the forward exists:** `/wrap` step 6 still ran v1 and reverted the page at 16:50 on Oct 15.
  `~/.claude/commands/wrap.md` now runs v2 `--publish`; anything else still calling v1 builds v2.
- **Scheduled task "BSB Command Center":** was `powershell refresh_and_open.ps1` daily; now
  `pyw.exe v2 --open-once-daily --publish` every 15 min. `meta/refresh_and_open.ps1` is no
  longer the task action (kept for running by hand).
- **New outward copy:** `--publish` pushes a filtered page (no hiring, no last-state) to
  `zbridger_astros/pd-command-center` for Cael. Hiring gate: `publish()` refuses on any match.

