# GitHub Workflow — Quick Reference

A short, practical guide to working in this repo. Read this once on Day 1,
then bookmark it for daily reference. The deep-dive version is in
[Chapter 16 — Collaborating with Teammates](16-collaborating-with-teammates.md).

---

## How the branches are set up

```
main                          ← archive, rarely touched
  ↑
feature/<app>                 ← LIVE production. 4 of these:
  ↑                             feature/pd-goals
  |                             feature/barrelsville
  |                             feature/bullpen-reports
  |                             feature/astros-intangibles
  |
<your-name>/<task>            ← your scratch branch — edit freely here
```

You never push directly to `feature/*`. GitHub blocks it. You propose
changes by opening a Pull Request (PR) into the feature branch.

---

## One-time setup

1. **Accept the GitHub collaborator invite.** Check your email.

2. **Add an SSH key to GitHub** (one-time, on your work laptop):
   ```powershell
   ssh-keygen -t ed25519 -C "you@astros.com"
   cat ~/.ssh/id_ed25519.pub
   ```
   Copy the output, then add at github.com → Settings → SSH and GPG keys
   → New SSH key.

3. **Clone the repo:**
   ```powershell
   git clone git@github.com:<your-org>/bsb-resources.git
   cd bsb-resources
   git config user.name "Your Name"
   git config user.email "you@astros.com"
   ```

4. **Set environment variables** in PowerShell (Zac will DM the values).
   Session-only — drop into your `$PROFILE` to persist across shells:
   ```powershell
   $env:DB_USER = "rs_connect_ro"
   $env:DB_PASS = "<from Zac>"
   $env:CONNECT_API_KEY = "<from Zac>"
   $env:LOGIC_APP_URL = "<from Zac>"
   ```

5. **Install Python 3.13** and the requirements for whichever app
   you're working in:
   ```powershell
   pip install -r pd-goals/requirements.txt
   # or barrelsville/, bullpen-report/, intangibles/
   ```

---

## Daily workflow

### Starting a new task

```powershell
git checkout feature/<the-project>     # the LIVE branch for the app
git pull                                # always pull first
git checkout -b <your-name>/<short-task>
```

Example:
```powershell
git checkout feature/pd-goals
git pull
git checkout -b apprentice/pd-goals-fix-percentile
```

### While you work

```powershell
git status                              # see what changed
git add path/to/specific/file.py        # stage files by name
git commit -m "short description of what changed"
git push -u origin <your-name>/<short-task>
```

The `-u origin <branch>` part is only needed on the **first push** of a
new branch. After that, plain `git push` works.

Push as often as you want — your scratch branch is yours, nothing goes
live until you open a PR.

### Testing

Run Streamlit / scripts on your work laptop against the real DB before
opening a PR:

```powershell
python -m streamlit run pd-goals/PD_Engine.py
```

### Opening a PR

1. Go to github.com → the repo
2. A yellow banner appears: "your branch had recent pushes" → click
   **Compare & pull request**
3. **CRITICAL:** Change the **base** dropdown from `main` to the
   feature branch you branched from (e.g. `feature/pd-goals`).
   It defaults to `main` — switch it.
4. Title: short description of what you did
5. Description: a sentence or two on what + why + how you tested
6. Click **Create pull request**
7. Ping Zac in Slack so he knows to review

### After Zac reviews

- He'll either **leave comments** asking for changes, or **Approve**
- If he asks for changes → fix locally, commit, push again to the
  same branch. The PR updates automatically.
- Once he approves, **YOU click the green "Merge pull request" button**
  on the PR page. The button is greyed out until he approves — that's
  the safety net.
- Zac handles the Posit redeploy from there.

### Starting the next task

After your PR merges, clean up and pull the latest before branching
again:

```powershell
git checkout feature/<the-project>
git pull                                 # gets the merged state
git branch -d <your-name>/<old-task>     # delete old scratch locally
git checkout -b <your-name>/<new-task>   # fresh branch
```

The `git pull` is important — if you skip it, your new scratch branch
will be behind and you'll hit merge conflicts later.

---

## Hard rules

- **Never push directly to `feature/*`.** GitHub will reject you. The
  rule exists for a reason.
- **Never `git push --force`** on a shared branch. On your own scratch
  branch in emergencies, ask Zac first.
- **`git add path/to/file` — never `git add .`** That stages everything
  including junk files (`__pycache__/`, output PDFs, parquet pins,
  `.env`). Stage by name.
- **Always `git pull`** on the feature branch BEFORE creating your
  scratch branch.
- **`git status` before every commit** to see what's being staged.
- **One logical change per commit.** Easier to revert.
- **Feature branches are LIVE.** When Zac merges your PR + redeploys,
  coordinators see it. There's no staging environment. If in doubt
  about a change, ask before you open the PR.
- **Unsure about anything? DM Zac.** Cheaper than a bug shipping live.

---

## Topic branches (for bigger projects)

Sometimes Zac will assign a multi-day project — new dashboard card,
new metric family, new app section. For these, instead of PR-ing every
commit into the live feature branch, he'll set up an intermediate
**topic branch**:

```
feature/pd-goals                                ← LIVE
  ↑ (one clean ship PR when whole subfeature is done)
  └─ feature/pd-goals-coordinator-notes         ← topic branch
       ↑
       └─ <your-name>/coord-notes-data-layer    ← your scratch
```

When that's the setup, your scratch branches PR into the **topic
branch** (e.g. `feature/pd-goals-coordinator-notes`), not the main
feature branch. Same flow otherwise. Zac will point you at it when it
applies.

---

## What to do if something errors

| Error | What it means | Fix |
|---|---|---|
| `protected branch hook declined` | You tried to push directly to a `feature/*` branch | Create a scratch branch, push that, open a PR |
| `! [rejected] ... non-fast-forward` | Remote has commits you don't | `git pull` first, then push again |
| `merge conflict` | Your branch diverged from the feature branch | Ask Zac before resolving — easy to make worse |
| PR merge button greyed out | Zac hasn't approved yet | Wait + ping him in Slack |
| `git status` shows files you don't recognize | Junk files (caches, outputs) | DON'T `git add .` — only stage real changes |

When in doubt → DM Zac. Always cheaper than fighting git alone.

---

## Required reading

Before you write any real code:

1. [`CLAUDE.md`](../../CLAUDE.md) — architecture + the 16 BLOCKING rules
2. [`.claude/rules/blocking-rules.md`](../../.claude/rules/blocking-rules.md) — those rules in detail
3. The rule file for your app (e.g.
   [`.claude/rules/pd-goals.md`](../../.claude/rules/pd-goals.md))
4. [`.claude/rules/db-columns.md`](../../.claude/rules/db-columns.md) —
   saves you from guessing SQL columns

Skim them; come back as needed. The rules exist because every one of
them is a bug that shipped once and shouldn't ship again.

---

## First task (Day 1)

Before any real work, do one trivial PR end-to-end to shake out any
setup issues:

1. Branch off `feature/pd-goals`
2. Add your name to `CONTRIBUTORS.md` (create the file if it doesn't
   exist)
3. Push the branch, open the PR into `feature/pd-goals`
4. Zac reviews + approves
5. You click Merge

That covers SSH, env vars, branch protection, and PR mechanics in one
safe pass. Once it's clean, Zac will hand you your first real task.
