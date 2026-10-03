---
type: project
created: 2026-08-03
tags:
  - astroworld
  - astrosedu
  - quizzes
  - media-upload
status: shipped-pending-live-verification
---
# AstrosEDU: the media pipeline fight, and the quiz system

Companion to [[astro-world]], [[astro-world-storage]], [[astro-world-azure-migration-2026-07-14]].
Repo: `Baseball-Operations/astroworld-dev` (canonical, auto-deploys from `main`).
Local clone `C:\Users\Owner\astroworld`, remote `prod`.

Two things happened on 2026-08-01 through 08-03. Getting video to work at all,
which took four PRs and felt like pulling teeth. Then building quizzes, which
was the actual feature.

---

## Part 1: why uploading a video took four PRs

Zac's words: *"we cannot download a video for the life of us"*. He was right,
and the reason kept moving. Three independent bugs sat in a row on the same
path, so fixing each one only revealed the next.

### Bug 1: the platform truncates request bodies at 10 MiB, silently

Not a rejection. The platform delivers the first 10,485,760 bytes and ends the
stream, so the multipart parser dies with "Unexpected end of form" and the real
cause is invisible. Measured directly: a 5 MB body arrives whole; 15 MB and
24 MB bodies both arrive as exactly 10,485,760 bytes.

- **PR #12** made the failure say why instead of "check the server log".
- **PR #13** fixed it, by sending the file in 4 MB chunks that are appended to a
  temp file and streamed into the storage adapter on the last piece. Works for
  any size and any storage driver, and does not depend on knowing where the cap
  comes from.

**Still outstanding:** the chunked uploader is wired ONLY to the course builder
(`CourseBuilder.tsx` to `/api/admin/courses/lesson-media/chunk`). The
content-page uploader `/api/upload` still hard-refuses anything over 10 MB with
a 413 telling you to paste a SharePoint link. **The fix exists in the repo, on
the wrong path.** Porting it is the next known piece of work.

### Bug 2: a link is a page, not a media file

The workaround the 413 suggests is pasting a SharePoint or Stream link. The
course player then handed that URL to a `<video>` element, which cannot render a
web page, so you get a black player that loads nothing.

The content pages already had this right: `VideoPlayer` frames embed-backed
items and uses `<video>` only for bytes we serve. The course player did not make
the distinction.

**PR #14** made `lessonMediaSrc` report whether a source is an embed or a file we
stream, framed embeds in an `<iframe>`, and put an "Open it directly" link
underneath, because some SharePoint links refuse to display inside another site
via `X-Frame-Options` or CSP.

### Bug 3: Save deleted the upload

The one that actually looked like magic. Upload a video, watch it succeed, see
"A file is attached", press **Save lesson**, and the lesson goes back to
"no media yet".

The editor sends the link field on every save of a media lesson, empty string
included. `updateLesson` read an empty link as "clear the media" and nulled
`driver` and `storageKey`. So Save wiped the pointer to the file that had just
uploaded. The file stayed on disk, orphaned, and **nothing reported an error,
because from the server's side nothing failed.**

That branch exists so you can clear a pasted link. It could not tell "clear the
link" apart from "I never typed one, I uploaded a file."

**PR #15**: an empty link box clears a pasted link and only a pasted link, acting
only when the lesson is currently `externalEmbed`. Save is disabled while an
upload is in flight. The file input now says outright that choosing a file
uploads it immediately, because the Save button sitting underneath implied the
file was queued waiting to be saved.

Present since PR #10. Not caused by #14, though it surfaced right after it.

### The generalisable lesson

**A form that sends a field on every save will clear whatever that field
controls, for state the field does not represent.** Title and body were safe
because they round-trip through visible inputs. Uploaded media was not
represented in any field the form posted, so an empty link looked like an
instruction to erase it.

Worth checking on any similar editor. On this repo the content-page PATCH
(`api/content/[id]`) is clean: it only writes title and description and never
touches `driver` or `storageKey`. `updateLesson` was the only site.

### The other lesson, about this project specifically

None of this was testable before deploying. No database and no Entra on the
personal laptop means every fix ships to find out whether it worked, and each
round trip costs a merge plus a three minute deploy. **One test was run against
a build that had not finished deploying yet**, which produced a video of the old
bug and a minute of confusion. The tell that saved it: a UI string added in the
new build was absent from the recording.

If AstrosEDU keeps moving, a local dev database is worth the setup cost.

---

## Part 2: the quiz system (PR #16)

Before this, `kind: "quiz"` was a valid lesson type and nothing else. Both the
editor and the player rendered a hardcoded "coming soon". No questions, no
scores, no reporting.

### Decisions Zac locked, 2026-08-03

| Decision | Choice |
|---|---|
| Question types | Multiple choice, true/false, AND multi-select. No short answer. |
| Gating | Must pass to continue. |
| Retakes | Unlimited, every attempt kept, **best** score counts. |
| Reporting first | Who has completed what (roster), not item analysis. |
| Multi-select credit | All-or-nothing (my call, stated not asked). |

### What it does

**Authoring.** A quiz lesson grows a question builder: prompt, one-answer or
pick-all-that-apply, answers, tick the correct ones, reorder, delete, plus a
pass mark per quiz defaulting to 80%. A one-click true/false shortcut exists.

**Taking.** The player grades on submit and marks questions right or wrong
*without revealing the correct answer*, so a retake is not a copy of the first
attempt.

**Gating.** Passing completes the lesson; everything after an unpassed quiz is
locked in the rail. Only quizzes gate. Admins bypass the lock so they can author
and preview.

### Design calls worth remembering

- **True/false is not a type.** It is a single-answer question with two choices.
  No extra model, no extra grading branch, no extra UI.
- **Single and multi grade identically**: the set of choices picked must equal
  the set marked correct. One rule, no per-type branch to get wrong.
- **The answer key never reaches the browser.** `isCorrect` is stripped in
  `getQuizForPlayer`. Grading is server-side, so it cannot be read out of the
  page source or edited into a pass on the way in.
- **`/api/courses/complete` refuses to tick an unpassed quiz.** Otherwise the
  gate is decoration that a direct POST steps around.
- **A question is saved whole, with its choices**, so a half-written question is
  not a reachable state and the server can enforce its rules on every write.
  Choices match by id on edit, so revising a question does not invalidate choice
  ids in past attempts.

### The two traps that were designed out

Both are in `scripts/test-quiz-grading.ts` rather than waiting to be found by
someone getting a wrong mark.

1. **An empty quiz does not gate.** Quizzes are created blank and filled in
   later. Gating on an empty one would silently lock everyone out of the rest of
   the course the moment an author added the lesson, **and the author would not
   see it, because admins bypass locks.**
2. **A question with no correct answer marked scores wrong**, not
   correct-for-everyone. A naive set comparison hands out a free mark when both
   the picked set and the correct set are empty.

### Files

| Piece | Where |
|---|---|
| Grading and gating, pure and DB-free | `src/lib/quiz.ts` |
| Tests, no DB, no sign-in | `scripts/test-quiz-grading.ts` (33) |
| Authoring API | `src/app/api/admin/courses/route.ts`, ops `saveQuestion` / `deleteQuestion` / `moveQuestion` |
| Submit and grade | `src/app/api/courses/quiz/submit/route.ts` |
| Player | `src/components/QuizPlayer.tsx` |
| Author UI | `src/components/CourseBuilder.tsx`, `QuizEditor` + `QuestionForm` |
| Results | `src/app/(site)/admin/courses/[id]/results/page.tsx`, data in `getCourseResults` |
| Schema | `prisma/schema.prisma` (`Question`, `Choice`, `QuizAttempt`, `Lesson.passThreshold`) |

### Reporting

**Admin > course > Results**: everyone who has touched the course, lessons
completed, best score per quiz with pass state and try count, last activity.
Editors can read it, not just admins.

There is no enrolment model, so the roster is people with real activity rather
than an invented list. Names come from `AppUser` when that table exists and fall
back to email when it does not, so the page works on a database where the
`AppUser` migration was never run. **Which is still the case in prod.**

### Not built, deliberately

- **Item analysis** ("which question does everyone miss"). Attempts store the
  answers given in a JSONB column, so this can be added with no schema change.
  Nothing reads that column yet.
- **Partial credit** on multi-select. Needs a weighting decision that is easier
  to make once real quizzes exist.

---

## Migrations now apply from inside the app

Worth knowing beyond quizzes. PR #11 added `Admin > Database`, which applies
declared schema migrations using the connection the app already has, so a new
table no longer needs someone with the connection string. It is narrow on
purpose: admin only, not arbitrary SQL, additive only, idempotent, and a test
asserts the guard refuses destructive DDL.

The quiz migration needed one new allowed statement shape, `ADD COLUMN IF NOT
EXISTS`. It is written as a **full regex pattern, not a bare `ALTER TABLE`
prefix**, because a prefix would also have admitted `DROP COLUMN` and `RENAME`.
The safety test now asserts those three are still refused.

**This supersedes half of issue #7**, which is still open asking Peter to run
`psql` and `npm run db:seed` by hand. PR #8 replaced the seed ask and PR #11
replaced the psql ask. The issue should be closed.

---

## State as of 2026-08-03

| PR | What | State |
|---|---|---|
| #12 | Honest upload errors | Merged |
| #13 | Chunked upload, 10 MiB cap | Merged |
| #14 | Links render in an iframe | Merged |
| #15 | Save stops deleting the upload | Merged, **confirmed working by Zac** |
| #16 | Quizzes | **Open, not yet merged** |

**Verified live:** chunked upload, progress meter, attach, save, playback.

**Not verified:** everything in #16. 72 tests pass with no database, which is
the only check possible before a deploy. After merging, **run Admin > Database >
AstrosEDU quizzes before writing any questions.**

## Open items

- Port the chunked uploader to `/api/upload` so content pages accept files over
  10 MB. The code exists; it is wired only to courses.
- Close issue #7 (both asks superseded by PRs #8 and #11).
- Run the `AppUser` migration in prod, now doable from Admin > Database.
- Issue #4, dependency advisories (next/postcss, sharp), untouched.
- A local dev database, so this stops being deploy-to-test.

---

# VERIFIED LIVE, 2026-08-03

Everything above shipped and works on the live site. Zac's results page:
2/2 lessons complete, Chapter 1 Quiz **100% passed on the 2nd try**, name
resolved from `AppUser`. That single screen proves the whole chain: authoring,
taking, retaking, best-of scoring, gating, and reporting.

PRs #12 through #17 all merged.

## The last bug, and the lesson that generalises

PR #16 merged and every course page immediately threw
`Application error: a server-side exception has occurred`.

**Cause:** the deploy ships code, the migration ships tables, and there is
always a window between the two. The question count was an `include` on the
course query, so every course page ran a query against a `Question` table that
did not exist yet and went down with it.

**PR #17** moved question counts and attempts into separate, tolerant queries
that degrade to "no questions, no attempts" — which reads as *no quiz gates
anything yet*, exactly what a database with no quizzes means.

> **The rule worth keeping: in an app that applies its own migrations, an
> unapplied migration must never be able to take a page down. You have to be
> able to reach the app in order to run the migration that fixes it.**

Second-order lesson: **#16's PR body claimed the pages degrade rather than
crash. That was asserted, not checked.** It was true of the two pages with a
catch around the course load and false of the rest.

(The 404 Zac saw before that was the *correct* degraded behaviour of the player
page, which has a catch. Then he realised he had never pressed the Database
setup button, which was the whole thing.)

## What happens in the database when you delete or edit

Every relation in the course graph is `onDelete: Cascade`:

```
Course -> Module -> Lesson -> LessonCompletion
                           -> Question -> Choice
                           -> QuizAttempt
```

| Action | What goes |
|---|---|
| Delete a **course** | Its sections, lessons, **everyone's completions**, all questions, choices and **every quiz attempt**. |
| Delete a **section** | Its lessons and everything under them. |
| Delete a **lesson** | Its completions; if a quiz, its questions, choices and all attempts. |
| Delete a **question** | Its choices. Past attempts keep their score; their `answers` JSON references a now-dead question id. |

**No soft delete, no undo, no audit trail.** The delete button asks you to type
the course title for exactly this reason.

**Uploaded files are NEVER removed by any delete path.** Only database rows go.
Media orphans in storage, and replacing a lesson's file orphans the old one too.
Harmless today (nothing serves an unreferenced key) but it accumulates, and a
cleanup job is the obvious future want.

**Editing an answer key does not rescore past attempts.** Scores are frozen at
grading time. Fix a wrong answer key and everyone who already took the quiz
keeps the mark they got. Deliberate — silently changing someone's recorded
result would be worse — but it means a genuinely wrong key needs the affected
people asked to retake.

**Prefer Unpublish to Delete.** Status `draft` hides a course from everyone but
admins and keeps every row intact.

## Working rules for this repo, learned the hard way

1. **Repo is `Baseball-Operations/astroworld-dev`, remote `prod`.** Branch off
   `prod/main`. `git checkout main` tracks `bizops` (the ARCHIVE) and gives you
   a tree where half the app looks deleted.
2. **Deploy takes ~3 minutes after the workflow goes green.** Do not test before
   it lands, and hard refresh. This cost a full round trip.
3. **Merging code that needs a table does not create the table.** `Admin >
   Database` applies migrations. Run it immediately after merging.
4. **Nothing here is testable before deploying.** Which is why the quiz grading
   was built as a pure DB-free module with 33 tests. That is a workaround for a
   missing dev environment, not a substitute for one. **A local dev Postgres is
   the single highest-value thing left to do on this project.**
5. **No AI/Claude co-author trailer on commits.** Shared with the Director of IT.
