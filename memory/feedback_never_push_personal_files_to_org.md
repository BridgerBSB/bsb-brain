---
name: feedback_never_push_personal_files_to_org
description: BLOCKING — bsb-resources root contains personal/pre-Astros material that must NEVER be copied or pushed to any Baseball-Operations org repo. Only move named Astros app dirs.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cdcf4026-70bc-429c-bb18-bcb9b7478efd
---

**BLOCKING guardrail.** `C:\Users\Owner\bsb-resources\` is a personal working
junk-drawer that mixes (a) Zac's live Astros work with (b) personal /
pre-Astros / former-employer material he may keep PRIVATELY but is NOT
permitted to expose to others.

**Why:** several top-level folders predate his Astros tenure (former-company
work). He can retain them personally; nobody else (incl. the Baseball-Ops org)
may see them. They are NOT documented in CLAUDE.md and must not be enumerated
in any file that could be pushed.

**How to apply:**
- When migrating to `Baseball-Operations/player-development` (or ANY org repo),
  ONLY ever COPY specific, named Astros app directories (e.g. `pd-goals/`, the
  Arm Farm / Barrelsville / Intangibles app dirs). NEVER `git add` / copy the
  whole `bsb-resources` tree.
- NEVER name the personal/former-company folders in any committed/pushed file
  (.gitignore, README, etc.) — naming them in a shared repo defeats the privacy.
  Discretion lives in process + this memory, not in a pushed file.
- `bsb-resources` stays put on the personal laptop — nothing deleted, nothing
  exposed. Only the clean Astros app dirs leave for the org repo.
- If unsure whether a folder is Astros-work vs personal, ASK before copying.

Related: [[connect-offload-migration]] (the migration this guards),
[[unified-pd-hub-vision]].
