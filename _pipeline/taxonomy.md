---
type: schema
domain: training-knowledge
created: 2026-09-04
updated: 2026-09-04
---
# Taxonomy - how a source gets tagged

This file is read by the summarizer on every run. Zac's audits reshape it:
`promote` appends his corrections under **Worked examples**, and any
definition below can be edited by hand. Definitions win over examples; the
examples show how the definitions apply in edge cases.

## domain (one or more)

| value | means |
|---|---|
| `pitching` | throwing mechanics, velocity, pitch design, command, arm care, workload |
| `hitting` | swing mechanics, bat speed, approach, bat path, hitting drills |
| `strength` | weight room, plyos, med ball, mobility work, periodization, nutrition |
| `anatomy-movement` | anatomy, physiology, motor learning, movement screens, injury mechanism |
| `mental` | mindset, routines, competitiveness, confidence |
| `business` | running a facility, recruiting, program sales, industry commentary |

A pitching video that spends five minutes on the weight room is
`[pitching, strength]`. Tag what the source teaches, not what it mentions.

## kind (exactly one)

| value | means | default value |
|---|---|---|
| `instruction` | teaches HOW: a drill, a progression, a fix, a cue, a program | high |
| `philosophy` | teaches WHY: what to believe about development, how to think | high |
| `research` | data, a study, a method, numbers with a method behind them | high |
| `interview` | a conversation; grade by what the guest actually teaches | med |
| `athlete-story` | one player's arc; usually promotional, sometimes carries numbers or shows drills | med; low only if no numbers AND no drills with a purpose |
| `marketing` | program sales, recruiting pitches, testimonials, announcements | low |

## value (exactly one)

| value | means | what the pipeline does |
|---|---|---|
| `high` | would change how we coach, evaluate, or program | full note, cues extracted, concepts linked |
| `med` | useful context, a data point, a good example | full note, cues if any |
| `low` | record that it exists | 3-line note, no cues |
| `skip` | out of scope for this source (BPC + hitting) or noise | raw kept, no note in the queue |

## cues (the payoff)

A cue is the phrase a coach would actually say, plus the fault it fixes and
who it is for. Extract only cues the source **gives**, verbatim where
possible. Never invent a cue from a description of mechanics. One cue that
two sources phrase differently is one cue note with both phrasings.

Good: `"Get the ball out of the glove early"` - fixes late arm, for youth arms
with long arm swings.
Not a cue: `"He improved his hip-shoulder separation"` - that is a claim.

## anti-cues (a cue the source ARGUES AGAINST)

Sources frequently name a cue in order to criticise it. "Get over the top" and
"get behind the ball" are both named by Tread as causes of shoulder climb and
dart/push arm action, linked to labrum and triceps problems.

**These must never appear under `## Cues`.** A cue note reads as something to
say to a player: it has a `fixes:` field and it is filed in `cues/` beside the
good ones. Polarity buried in prose ("meant to fix X; causes Y") is not enough,
because the reader meets the cue in `cues/`, out of its original context.

Put them under `## Anti-cues` instead, one per line:

`- **"phrase"** - taught to fix X; actually causes Y; per <source>`

The pipeline deliberately does NOT create notes from this section. The
knowledge stays on the source note, where the surrounding claims explain it.
Knowing which cues a source considers harmful is real knowledge, and often
higher-value than the good cue -- it just is not a coaching instruction.

The test: would a coach reading this phrase alone, in a folder of cues, say it
to a player? If no, it is an anti-cue.

## drills (the other payoff)

A drill is an exercise with a setup and a purpose: an implement (long bat,
underload bat, plyo ball), a constraint (step-behind, kneeling, pivot pick),
or a movement pattern, plus what it builds. Extract only drills the source
shows or names, with the purpose the source gives. One drill used by two
sources is one note with both usages. Drills are not cues: a cue is what
the coach SAYS during the drill.

Good: `**Step-behind long bat** - step-behind into contact with a long bat;
builds holding space in the load; for hitters who drift`.

## claims

Every claim in a note carries a `[mm:ss]` link (video) or a section name
(blog), and the number the source gives if it gives one. A claim that
contradicts an approved note on the same concept is written down under
**Open questions**, not resolved.

## Worked examples

<!-- promote appends one block per Zac correction, newest last -->
- 2026-09-06 [[2026-08-16-long-vs-short-arm-action-whats-the-difference]]: cues ['cue-hold-flexion-longer', 'cue-get-it-go-get-it-go', 'cue-be-smooth'] -> ['cue-hold-flexion-longer', 'cue-get-it-go-get-it-go', 'cue-stay-stacked-over-the-pelvis']
- 2026-09-06 [[tread-CxObu-w6cJw]]: cues ['cue-hold-flexion-longer', 'cue-get-it-go-get-it-go', 'cue-be-smooth'] -> ['cue-hold-flexion-longer', 'cue-get-it-go-get-it-go', 'cue-be-smooth', 'cue-stay-stacked-over-the-pelvis']
- 2026-09-08 [[2025-12-02-luis-patino-was-dealing-mic-d-up-live-abs]]: kind athlete-story -> None
