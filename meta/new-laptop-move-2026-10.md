# New laptop move - plan + carry-over kit (built 2026-10-02)

Three layers. Nothing important should depend on the transfer service copying
everything on C: - it usually moves user folders (Desktop, Documents, Pictures),
often skips hidden folders (`.claude`, `.ssh`, `.recall`, AppData), and never
reinstalls programs.

| Layer | What | How it gets to the new laptop |
|---|---|---|
| 1. GitHub | every repo's committed work | `git clone` on the new laptop |
| 2. This folder | everything NOT in GitHub (list below) | carry this folder (transfer service, USB, or OneDrive) |
| 3. Reinstall | programs + logins + SSH keys | install fresh, sign in fresh |

**As of 2026-10-02: every repo had 0 unpushed commits.** Other Claude sessions
were committing "backup before laptop swap" work at the same time; anything
they did not commit is still covered by `uncommitted-repo-files/` below.

---

## THE ONE THING: keep the Windows user name `Owner`

Claude Code keys project memory by FOLDER PATH (`.claude\projects\C--Users-Owner-bsb-resources\memory`),
and the hooks, CLAUDE.md files, rules and worktree map all say `C:\Users\Owner\...`.
Same user name = everything lines up with zero edits.
If the new laptop's user folder has a different name, rename the folders under
`.claude\projects\` to match (e.g. `C--Users-Zac-bsb-resources`) and
find/replace `C:/Users/Owner` in `.claude\settings.json` (8 hook paths).

---

## What is in this folder

| Folder | What it is | Where it goes on the new laptop |
|---|---|---|
| `claude-user-config/` | Claude Code: global CLAUDE.md, settings, hooks, 490 files of skills / agents / commands / GSD | `C:\Users\Owner\.claude\` |
| `claude-project-memory/` | Claude's memory: 230 files for bsb-resources, plus astroworld / coordinator-app / bullpen | `C:\Users\Owner\.claude\projects\` (copy each `C--Users-Owner-*` folder in) |
| `recall/` | the recall MCP brain (12.6 MB) | `C:\Users\Owner\.recall\` |
| `mcp/mcpServers.json` | MCP server definitions (recall, obsidian), no secrets | merge into `C:\Users\Owner\.claude.json` under `mcpServers`, or re-add with `claude mcp add` |
| `git/gitconfig`, `git/ssh-config` | git identity + the two GitHub host aliases (no keys) | `C:\Users\Owner\.gitconfig`, `C:\Users\Owner\.ssh\config` |
| `git-stashes/` | 5 bsb-resources stashes + the vault's leftover rebase autostash, as patches | only if wanted: `git apply <file>` in the matching repo |
| `never-committed/` | `pm-tool` + `pm-tool-1` (repos with ZERO commits; these files exist nowhere else) | copy back to `C:\Users\Owner\pm-tool*` |
| `outside-any-repo/` | `bsb-wt-intangibles\.claude\` + `CLAUDE.md` (they sit above the worktree, in no repo) | `C:\Users\Owner\bsb-wt-intangibles\` |
| `uncommitted-repo-files/` | 965 files / 263 MB of modified + untracked files from 10 repos (scratch SQL, renders, decks, mocks) | drop each folder back over its fresh clone (same relative paths) |

**Deliberately NOT in this folder (secrets):** the SSH private keys and any login
tokens. Make new ones (below). Claude transcripts (`.claude\projects\*\*.jsonl`,
1.2 GB) are also not here; they only power `/resume` of old chats.

---

## New-laptop setup, in order

1. **Windows user `Owner`.** Install: Git, Python 3.12 (this laptop: 3.12.4), Node (v24; the Claude hooks are .js),
   VS Code, Claude Code, Obsidian, Anaconda if still wanted.
2. **SSH keys (new, not copied).** Two accounts, two keys:
   ```
   ssh-keygen -t ed25519 -f $HOME\.ssh\id_ed25519            # Astros GitHub (zbridger_astros)
   ssh-keygen -t ed25519 -f $HOME\.ssh\id_ed25519_personal   # personal GitHub (BridgerBSB)
   ```
   Add each `.pub` to its GitHub account (Settings -> SSH keys). For the
   Baseball-Operations org repos, click **Configure SSO -> Authorize** on the new key.
   Copy `git\ssh-config` to `.ssh\config` and `git\gitconfig` to `.gitconfig`.
   Then remove the old laptop's keys from both GitHub accounts.
3. **Clone** into `C:\Users\Owner\` (same folder names):
   ```
   git clone git@github.com:zbridger_astros/bsb-resources.git
   git clone git@github-personal:BridgerBSB/bsb-brain.git
   git clone git@github-personal:BridgerBSB/hiring.git
   git clone git@github-personal:BridgerBSB/astroworld.git     # then: git remote add prod git@github.com:Baseball-Operations/astroworld-dev.git ; bare `git push` tracks prod
   git clone git@github-personal:BridgerBSB/coordinator-app.git
   git clone git@github-personal:BridgerBSB/pitch-grips.git
   git clone git@github-personal:BridgerBSB/11labs-llm.git
   git clone git@github.com:Baseball-Operations/player-development.git
   git clone https://github.com/zbridger_astros/indyball-tracker.git indy-ball-scraper
   git clone https://github.com/Quackman21/IQ_Baseball_Performance.git
   git clone https://github.com/SideQuest-io/SideQuest.git
   ```
   `cage-sandbox` (standalone, no remote) is NOT needed: its commits live in `hiring\cage-sandbox`.
4. **Worktrees** (share the bsb-resources clone; run inside `C:\Users\Owner\bsb-resources`):
   ```
   git worktree add ..\bsb-wt-bullpen feature/bullpen-reports
   git worktree add ..\bsb-wt-hitting feature/barrelsville
   git worktree add ..\bsb-wt-intangibles\astros-intangibles feature/astros-intangibles
   git worktree add ..\bsb-wt-modeling feature/promotion-models
   git worktree add ..\bsb-wt-project-hub feature/project-hub
   ```
   Optional, only if still in use: `bsb-wt-eoyfix` (`zb/eoy-league-row-pin-guards`),
   `bsb-wt-eoyfix-pd` (`zb/eoy-port-pin-guards`). Hiring: `git worktree add ..\hiring-wt-deck director-deck-philosophy`.
   Astro World grips worktrees: `fix/pitch-grips-review`, `feat/pitch-grips-page`, `parked/pitch-grips` (parked; skip unless needed).
   `bsb-wt-intangibles` also has a `.claude\` + `CLAUDE.md` one level ABOVE the worktree, in no repo:
   copy `outside-any-repo\bsb-wt-intangibles\*` into `C:\Users\Owner\bsb-wt-intangibles\`.
5. **Claude Code:** copy `claude-user-config\*` into `.claude\`, `claude-project-memory\*` into `.claude\projects\`,
   `recall\` to `.recall\`, merge `mcp\mcpServers.json` into `.claude.json`. Sign in to Claude Code.
   Re-install plugins from `claude-user-config\plugins\*.json` if they do not come back on their own.
6. **Put the uncommitted files back:** copy `uncommitted-repo-files\<repo>\` over each clone.
7. **Check it worked:** open Claude Code in `C:\Users\Owner\bsb-resources` and ask it what it remembers about
   the pin map. It should cite memory; if it starts cold, the memory folder name does not match the path.
   Run `/brief` - it should show the last-state "Today" block. Run
   `python bsb-wt-bullpen\bullpen-report\scripts\test_similarity_rank_vectorized.py` -> `ALL MATCH` (Python works).

## Not affected
The **work laptop** (`C:\Users\zbridger\`), Posit Connect, the pins, and the DB.
Nothing on Connect points at this laptop.

## Open items from the old laptop
- Vault (`bsb-brain`) sits in a stale "rebasing" state (only an autostash left; exported to
  `git-stashes\bsb-brain-rebase-autostash.patch`). A fresh clone does not carry that state.
- Stashes worth a look before deleting the old laptop: `stash0` (WIP on pd-goals, visual-standards
  rv_gain rule) and `stash2` (WIP swing-shape loft card). The other three are notes / duplicates.
