---
type: meta
domain: training-knowledge
---
# How to review this queue

Every `.md` here is a PROPOSAL the pipeline wrote from one video or blog
post. Nothing leaves this folder until you say so. Reviewing one note takes
under a minute:

1. Read the TL;DR and skim the Claims. Open the timestamp link if you doubt one.
2. Fix what is wrong, directly in the file:
   - `domain:` add or remove (pitching, hitting, strength, anatomy-movement, mental, business)
   - `kind:` instruction | philosophy | research | interview | athlete-story | marketing
   - `value:` high | med | low | skip
   - the **Cues** bullets: delete a fake one, fix the wording, add one I missed
     (keep the shape `- **"phrase"** - fixes X; for Y`)
   - the **Drills** bullets, same idea (shape `- **Name** - setup; builds X; for Y`)
   - anything else in the body; it is your note now
3. Write a line under `## Zac` if you want the tagger to learn WHY.
4. Set `status:` to one of
   - `approved` - file it as is
   - `edited` - file it, and record what you changed as a training example
   - `rejected` - file it under `_rejected/`, no cues, no links
   - `duplicate` - same as rejected, for a second copy of a note you already graded
   Leave `pending` to come back later.

The next nightly run (or `python _pipeline\kb.py promote`) moves the note to
`sources/<source>/`, creates one note per cue in `cues/`, links the concepts
and the domain MOC, and appends your correction to `_pipeline/taxonomy.md`
under Worked examples. After ~30 reviews per source, the summarizer is
reading your corrections on every run.

Do not move files out of here by hand and do not edit `sources/_raw/`.
Definitions live in `_pipeline/taxonomy.md`; change them there when a
pattern keeps repeating.
