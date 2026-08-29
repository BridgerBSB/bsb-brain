# Last session state - 2026-08-28 22:02 (the magnet board's 11-item spec, shipped)

- **Project / cwd:** `C:/Users/Owner/hiring` - branch `main`. Also
  `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals` (the query).
- **Recall checkpoint (SOURCE OF TRUTH):** session `133c` - two domains:
  `hiring/main` (id `20e0f662b669f9ab`) and `bsb-resources/feature/pd-goals`
  (id `b2dcf31348d4cecf`). Read those before this file.
- **Read first on resume:** `cage-sandbox/docs/magnet-board-spec-2026-08-28.md`
  and the `2026-08-28` entry in `hiring/LINEAGE.md`.

- **What we were doing:** Verified the magnet board's CSV import and 40-man
  gold border against Zac's real roster, put the MLB level back, then built all
  11 items of his 2026-08-28 spec: three IL rows, the MiLB 165, the Current vs
  Project board split, a coordinator access level, and the "Astros
  Multipurpose" rebrand. Then fixed what he found testing it.

- **Shipped this session:**
  - `hiring/main`: `f96122c` (MLB + DH), `3c3daef` (DSL uncapped, out of the
    grid), `9ed9f5a` (Tue-Sun), `7f50864` (import removal + sharing picker),
    `ea581f6` (3 ILs, MiLB 165, week inside Starters, 40-man override, query in
    the Import dialog), `044d6fd` (coordinator level, rebrand, access boxes),
    `51e634c` (Current/Project boards + history), `461fa25` (arrows to
    field-view only, full names, import Current-only), `9ad3b74` (level squares
    rebuilt), plus a lineage commit.
  - `bsb-resources/feature/pd-goals`: `0fe81622` ('ml' back in the whitelist),
    `53ed4ad3` (il_label -> 7DIL/60DIL/FSIL, rehab becomes active), plus a
    lineage commit.
  - 503 pytest / 7 skipped, up from 449. ~40 injections proven red.

- **EXACT next step:** Zac opens **Railway > Deployments** and says whether
  `9ad3b74` built. The fix IS in `origin/main` (verified: 3 matches for
  `lvlgrid`/`level_choices`, 0 for the broken `access_box`/`level_options`) and
  `/admin/access` serves `Cache-Control: no-store`, so the server - not a
  browser cache - is still sending the old User Management page 13+ minutes
  after the push. If the build failed, get the log. If it never triggered, a
  manual redeploy unblocks it. THEN import `mag board (2).csv` on the **Current**
  board so the three IL rows fill from eBIS rather than the legacy bridge.

- **Then, the next feature (Zac's words):** "expand upon what the compare looks
  like when we compare... and see how the feature differs from the person we
  allow to share with - on the depth chart and grid - idk how we show it."
  A COMPARE view between your project board and somebody else's shared one.
  He does not know how to show it yet, so this starts as a DESIGN conversation,
  not a build. Pieces that already exist: sharing points only at project boards;
  `/api/magnets/board?owner=` returns an unlocked board; every placement is
  `{id, level, row, status, slot, ord}` so a diff is a set comparison per
  player; `/api/magnets/history` lists every save of either board.

- **Blockers / waiting on:** (1) the `9ad3b74` deploy - only Zac can see
  Railway. (2) Does "All IL -> FCL" include the big leagues? It does today;
  asked three times, never answered. (3) `60R` mapped to 60DIL not REHAB -
  unconfirmed. (4) Zac was mid-sentence about "a couple buttons to the right of
  Find" on the project board and never finished it.

- **Uncommitted work:** `hiring` clean. `bsb-resources` 77 paths, ALL
  pre-existing untracked clutter from other threads - nothing from this session.

- **Live state, verified not assumed:** `https://hirehou.up.railway.app`,
  healthy, backend postgres. Production `magnet_doc` holds `board:current` v84,
  `board:zbridger@astros.com` v76, `board:saniedorf@astros.com` v66, `roster`
  v73. `admins.role` is text so `coordinator` needs NO migration; production has
  2 owners, 1 admin, 2 viewers, and no coordinator yet.

- **The MiLB 165 is 161, not 165.** The pre-split export could not tell a
  full-season IL from a 7-day one, so four FSIL players were being counted
  against the domestic limit.

- **What I got wrong, all one shape:** I asserted three times about output I had
  not looked at. User Management shipped printing raw HTML as text with an empty
  level picker (Set level could not work); I built chips per row instead of the
  squares Zac asked for; a coordinator could not be CREATED at all. My tests
  checked the function that built the HTML, not the rendered page, and I skipped
  render-and-look on an HTML page. I also told Zac a deploy had landed when I
  had only confirmed that EARLIER commits were live.
