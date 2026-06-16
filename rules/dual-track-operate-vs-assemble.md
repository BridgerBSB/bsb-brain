# Dual-Track — Operate (bsb-resources) vs Assemble (player-development)

Two SEPARATE efforts run in parallel. Do not conflate them, and do not
"migrate" one into the other under time pressure. (Zac direction, Jun 13 2026.)

| Track | Repo | Role | Status |
|---|---|---|---|
| **OPERATE** | `bsb-resources` + 3 sibling worktrees (`bsb-wt-hitting`, `bsb-wt-bullpen`, `bsb-wt-intangibles`) | The LIVE deploy chain mid-season — 4 apps, daily/Monday cascades, all Slack delivery | NOT frozen. New fixes/features ship here through the season. |
| **ASSEMBLE** | `Baseball-Operations/player-development` (`apps/pd-engine/Astros_PD_Engine.py`) | The parallel build of the ONE all-encompassing Astros PD Engine (4 apps → top-tabs/sub-tabs over a shared player/level/season context) | No deadline. Becomes source-of-truth only when FULLY proven. |

## Which track does a request belong to?

- "Fix / ship / deliver X for the live apps" → **OPERATE** (bsb-resources or the matching sibling worktree).
- "Wire / assemble / merge into the one app" → **ASSEMBLE** (player-development).
- **When ambiguous, ASK which track.** Never assume.

## Why this is not the copy-drift trap

We are NOT porting the same *change* into both repos. bsb-resources = the running
operation; player-development = the build. A domain's bsb-resources copy retires
ONLY when its hub tab is genuinely done and proven — one domain at a time, end of
season or later. No big-bang cutover. An earlier note said "freeze bsb-resources,
new work → player-development" — that was WRONG and is overruled. Mid-season you do
not disrupt a working pipeline.

## player-development is a SHARED repo — teammates branch off it

- Conventions for contributors live in `CONTRIBUTING.md` + `docs/onboarding/` on
  `main` (not in memory, not in a personal file) so every branch/fork inherits them.
- **Apps are folders, not branches.** All apps live on `main` together under `apps/`.
- Build the encompassing app on a **feature branch**, PR into `main`. Keep `main`
  clean so teammates branching off it get a stable base.
- Don't touch another person's `apps/<their-app>/` folder. `CODEOWNERS` routes review.
- Heavy league-wide aggregation belongs in the database (scheduled job → table the
  app READS), not inside a Connect app.

## What NOT to do

- **Don't** rely on a memory file to carry a cross-repo/cross-branch rule — memory is
  local + per-path. Durable rules go in `.claude/rules/` committed to git.
- **Don't** freeze bsb-resources or stop shipping live fixes there mid-season.
- **Don't** dual-maintain the same change in both repos.
- **Don't** force a cutover. Retire a live app only when its hub tab is proven.
- **Don't** put contributor conventions only in `.claude/rules/` — teammates read
  `CONTRIBUTING.md`; keep both in sync.
