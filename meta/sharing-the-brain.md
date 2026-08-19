---
type: meta
topic: sharing
status: in-progress
created: '2026-06-16'
---
# Sharing the BSB Brain — two tracks

Two recipients, two methods. **Private-archive is excluded from BOTH** (Sam: don't
publish it; Camden: it's `.gitignore`d). The vault is at `C:\Users\Owner\bsb-brain`.

## 🟢 Track 1 — Sam Niedorf (non-technical) → Obsidian Publish (a link)
Sam just opens a URL in a browser. No app, no git. **Publish is a paid add-on (~$8/mo)** —
the cost of zero-tech. All done by Zac in the Obsidian app:

1. **Settings → General → Account → Sign up / Log in** to an Obsidian account. ← **YOU ARE HERE** (screenshot 2026-06-16: "You're not logged in").
2. **Settings → Obsidian Publish → purchase a Publish site.**
3. Enable the **Publish** core plugin (Settings → Core plugins) if not on.
4. Click **Publish changes** (ribbon/command palette) → in the file picker, **tick only what to share** (`concepts/`, `MOC-*`, `sql/`, `people/`, `org/`, `rules/`, `05-daily` if wanted) and **LEAVE `projects/private-archive/` UNTICKED**. Publish.
5. In the site settings turn on **password protection** → get the URL (`publish.obsidian.md/<site>`).
6. **Send Sam the link + password.** Re-click **Publish changes** after any `/ingest` to update.

## 🔴 Track 2 — Camden Quick (technical) → private git repo
Repo already staged locally: `git init` done, commit `7549646`, 310 notes,
**0 private-archive files** (excluded). No remote yet.

1. **Zac:** create a **PRIVATE** repo (GitHub or Baseball-Ops org — never public; it holds Astros rules). Then:
   ```
   cd C:\Users\Owner\bsb-brain
   git remote add origin <private-repo-url>
   git push -u origin main
   ```
2. **Camden:** `git clone` → open folder as vault in Obsidian → install **Obsidian Git** plugin (auto pull/push).
3. **Camden (optional AI side):** `npx @bitbonsai/mcpvault@latest <his-clone-path>` + copy the global commands → his agents read/grow the shared brain.
4. Workflow: Camden branches → PRs to `main`. Private-archive never reaches him.

## Key facts
- Obsidian = a **free app** (notes are plain `.md`). The **repo/Publish are just delivery methods**, not Obsidian itself.
- Markdown is required + ideal — portable, future-proof, and exactly what the agent reads/writes.
- `.gitignore` already excludes `projects/private-archive/` + per-user `.obsidian/workspace`.
