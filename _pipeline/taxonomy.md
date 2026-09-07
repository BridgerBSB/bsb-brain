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
