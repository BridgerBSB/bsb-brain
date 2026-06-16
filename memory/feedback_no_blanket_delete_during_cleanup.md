---
name: feedback-no-blanket-delete-during-cleanup
description: Never blanket-delete files or DB rows during test cleanup — destroys real user data on shared dev stores
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 196af78a-1076-4240-9b6f-14e06621ab6a
---

While testing the astroworld app (2026-06-04), I ran `rm -f` over the whole
`uploads/` folder to clean up MY smoke-test files. That folder also held the
user's real uploaded video + PDF — both were deleted and unrecoverable. The
catalog DB rows survived but pointed at missing files → blank/500 playback.

**Why:** Smoke tests run against the user's REAL dev database + storage folder.
Blanket cleanup (`rm` a whole uploads dir, `deleteMany` on a broad filter)
destroys real user content, not just test artifacts.

**How to apply:** When cleaning up test artifacts, capture the exact ids / keys /
filenames I created this run and delete ONLY those. NEVER `rm` an entire
content/uploads directory or `deleteMany` on a broad/`startsWith` filter against
a store the user also uses. Prefer a throwaway scratch page + unique test IDs, or
skip destructive cleanup entirely and leave a note. When unsure, don't delete.
