# Storage + backup policy (this laptop, set 2026-10-16)

One home per kind of thing, one backup, and nothing big on C: that has a copy
somewhere else. Written during the Oct 16 C: cleanup (30 GB free of 445 GB).
Sibling of [[new-laptop-move-2026-10]].

## Where each kind of thing lives

| Kind | Home (the one real copy) | Backup | Takes C: space? |
|---|---|---|---|
| Code | GitHub. `BridgerBSB` = personal, `zbridger_astros` = Astros work | GitHub itself | Only the working clone at `C:\Users\Owner\<repo>` |
| Documents (PDF, Word, applications, certificates, reports) | `OneDrive\Documents` | OneDrive cloud (+ 30-day recycle bin) | No, online-only until you open it |
| Screenshots, photos | `OneDrive\Pictures` | OneDrive cloud | No, once freed |
| Knowledge / notes (shareable) | this vault | GitHub (`bsb-brain`) | Yes, but text is tiny |
| Personal / private notes | `projects/private-archive/` in this vault (gitignored) | **GAP: laptop only** (see open items) | Tiny |
| Big data, videos, model weights | per project (see cleanup log) | rebuildable or GitHub LFS / Drive | **Yes, this is the real C: risk** |

## Rules

1. **Never keep a git repo inside OneDrive.** OneDrive syncs every file in
   `.git` (the old `Documents\github` copies were 41,671 files), it can corrupt a
   repo mid-sync, and a second copy silently drifts from the real one. Code's
   backup is GitHub. Work in `C:\Users\Owner\<repo>`.
2. **One primary copy. Notes point at files, they never copy them.** A vault note
   links the OneDrive path; the PDF stays in OneDrive.
3. **Read the OneDrive status icon before deleting for space.**
   - cloud icon = online-only, **0 bytes on C:**. Deleting it frees OneDrive
     quota, not C:.
   - green outline check = downloaded, can be freed (right-click > Free up space).
   - solid green check = "Always keep on this device", really on C:.
   To reclaim C: from OneDrive, right-click the folder > **Free up space**.
   Deleting is not required and loses the cloud copy.
4. **Caches regenerate, projects do not.** pip / conda pkgs / npm / HuggingFace
   / browser cache / Temp / app caches are safe to clear. A folder with your own
   edits in it (CapCut drafts, notebooks, repos) is not a cache.
5. **One Windows account.** `C:\Users\zbrid` is a junction to `C:\Users\Owner`
   (same folder, two names, from the Oct 6 rename). Do not count it twice when
   measuring, and do not delete it: OneDrive still registers its root through it.
6. **This vault pushes to a PUBLIC repo** (`BridgerBSB/bsb-brain`). Anything
   personal (applications, career, money, family) goes in
   `projects/private-archive/`, which is gitignored. Never `personal/`: that
   folder IS pushed.
7. **Measure what's actually on the disk, not the size Explorer shows.**
   Explorer reports online-only files at their full size. A scan that skips the
   cloud-only attribute (0x400000) gives the real number.
8. **Don't run `git status` inside OneDrive on a full disk.** It reads every
   file, which downloads every online-only file.

## Cleanup log

- **2026-10-16** - C: at 30.1 GB free of 445.7 GB.
  - `OneDrive\Documents\IQ_Baseball_Performance-main`: all 27 files match
    `Quackman21/IQ_Baseball_Performance` (private, reachable from the personal
    account). Safe to delete; frees ~0 on C: (online-only).
  - `OneDrive\Documents\github`: 11.5 GB cloud / 0.34 GB on disk. Pre-move
    copies. bsb-resources x3 + catcher-depth match `BridgerBSB` on GitHub.
    11labs-llm has an uncommitted README edit + untracked `app.py`.
    `nyy_twt` is a local-only repo (no remote): the ONLY copy.
  - Real on-disk measurement (cloud-only skipped), candidates:
    `C:\0291-261003-30945` Geek Squad staging ~127 GB (Chrome profile 29,
    old VS Code + Python installs 19, CapCut 18, Packages 10, ProgramData 8,
    Descript 5.5, pip + npm caches 9) / `bsb-resources` 62 GB (repo is ~1 GB;
    rest is data/outputs, breakdown pending) / `anaconda3` 9.3 / `rtools45`
    5.9 / `Downloads` 4.4 / `eSupport` (ASUS driver backup) 3.6 /
    `AppData\Local\Temp` 3.1 / `Owner.leftover` 2.4.
  - **Unique user content inside the staging folder** (not anywhere else on
    this laptop; CapCut is not installed here):
    `...\AppData\Local\CapCut\User Data\VideoRecord` = 62 mp4 screen
    recordings, 10 GB, Apr 2025 - Aug 2026; `...\CapCut\Videos` = 2 mp4,
    2.2 GB; `...\CapCut\User Data\Projects` = drafts (open only in CapCut).
    Zac reviewing these himself before any staging delete.
  - **DELETED `C:\0291-261003-30945` (incl. the CapCut recordings), Zac's
    call: "we have everything we need, worst comes to worst we still have my
    old computer."** The old Surface is still around as the fallback.
    Free space 28.4 GB -> **159.1 GB (+130.7 GB)**, 330 s.
  - `bsb-resources` 62 GB = **`command-cv` 59.6 GB** (its own repo, nested
    in the folder): `data/clips` 34.7 GB (game video, the season job adds to
    it), old YOLO datasets `yolo_milb3`..`yolo_milb9s` + `yolo_milb4_staging`
    (8.6) etc. Rest of bsb-resources ~2 GB. Retire old datasets ONLY through
    command-cv's own process (`docs/retired_datasets/README.md`: grep
    scripts/src/tools first, keep the file listing + weights).
  - `anaconda3` 9.3 GB: not on PATH, no venv built on it (both venvs use
    Python312), untouched since the Oct 5 copy. **Zac keeps it** (handy for
    Python envs). `rtools45` stays (R 4.5.3 is installed). `Owner.leftover`
    kept for now. `C:\eSupport` = ASUS factory driver copy (`eDriver`), no
    workflow uses it; Claude's delete was blocked, Zac deletes it by hand if
    he wants the 3.6 GB. `AppData\Local\Temp` is mostly live app scratch
    (only 0.5 GB older than 7 days) - leave it to Windows Storage Sense.
  - Stopped here at **159 GB free** (Zac: "we can breathe").

## Where C: pressure comes from next

`command-cv/data/clips` is the only thing on this laptop that grows on its
own. Watch it; if it passes ~100 GB, move clips to an external SSD (or keep
them on the GPU box) and point the code at that path.

## Open items

- `projects/private-archive/` is on this laptop only (gitignored, and the vault
  is not in OneDrive). If the SSD dies, those notes are gone. The raw files they
  index are safe in OneDrive.
