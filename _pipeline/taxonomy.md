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
- 2026-09-09 [[2018-05-28-reverse-throw-our-favorite-cues]]: cues ['cue-drive-front-foot-into-ground-to-drive-knee-out', 'cue-start-a-lawnmower', 'cue-reach-scap-elbow-hand'] -> ['cue-drive-that-front-foot-into-the-ground-to-try-to-drive', 'cue-think-about-starting-a-lawnmower', 'cue-reach-scap-elbow-hand']
- 2026-09-09 [[2019-01-13-upgrading-your-j-band-routine-part-2a-patterning-front-leg]]: cues ['cue-cheat-the-front-foot-open', 'cue-step-into-it-like-a-steep-slope', 'cue-step-plant-finish'] -> ['cue-cheat-the-front-foot-open', 'cue-step-into-the-movement-like-you-re-stepping-down-a', 'cue-step-plant-finish']; drills ['drill-jband-hip-rotation-patterning-1', 'drill-jband-hip-rotation-patterning-2', 'drill-jband-hip-rotation-patterning-3', 'drill-jband-hip-rotation-patterning-4-dynamic'] -> ['drill-j-band-hip-rotation-patterning-1', 'drill-j-band-hip-rotation-patterning-2', 'drill-j-band-hip-rotation-patterning-3', 'drill-j-band-hip-rotation-patterning-4-dynamic-step-in']
- 2026-09-09 [[2019-01-13-upgrading-your-j-band-routine-part-2b-patterning-fixing-a]]: cues ['cue-pull-dont-push-to-release'] -> ['cue-pull-the-elbow-into-release-with-the-pec-and-lat-don-t']; drills ['drill-jband-ron-wolf-4th-pulling-pattern'] -> ['drill-j-band-ron-wolf-4th-drill-pulling-pattern']
- 2026-09-09 [[2026-05-28-drills-to-fix-your-timing-and-hinge-swing-design]]: cues ['cue-keep-your-front-foot-down', 'cue-keep-your-pelvis-down-as-you-turn', 'cue-hold-the-ground-with-your-back-foot', 'cue-pull-your-back-hip-away-from-home-plate-when-you-stride', 'cue-catch-it-deep-and-pull-a-homer', 'cue-hold-hold-hold-then-let-go'] -> ['cue-keep-your-front-foot-down', 'cue-keep-it-the-pelvis-down-as-you-turn', 'cue-try-to-hold-the-ground-with-that-back-foot', 'cue-pull-your-back-hip-away-from-home-plate-when-you-stride', 'cue-catch-it-deep-and-pull-a-homer', 'cue-hold-hold-hold-and-then-just-let-go']; drills ['drill-step-back-offset-open', 'drill-step-behind', 'drill-longer-bat-timing', 'drill-kershaw', 'drill-big-poppy', 'drill-redbat-handle-load-pull-back-release'] -> ['drill-step-back-offset-open', 'drill-step-behind', 'drill-longer-bat-timing-walk-through', 'drill-kershaw', 'drill-big-poppy', 'drill-redbat-handle-loaded-bat-pull-back-and-release']
- 2026-09-09 [[2026-06-09-throw-harder-by-fixing-your-pushy-arm-action]]: cues ['cue-burn-the-ball-through-the-net', 'cue-ring-finger-pressure-at-release', 'cue-add-a-glove-tap-to-stay-on-time'] -> ['cue-burn-that-ball-through-that-net', 'cue-hold-the-ball-and-put-a-ton-of-pressure-on-this-ring']; drills ['drill-lasso-arm-action', 'drill-pendulum-arm-action', 'drill-plyo-wall-added-space'] -> ['drill-lasso-drill', 'drill-pendulum-drill', 'drill-plyo-wall-with-added-space']
- 2026-09-09 [[2026-06-14-sidearmer-going-for-99-mph]]: cues ['cue-scoop-underneath-it', 'cue-add-intent-half-a-beat-later', 'cue-rotate-right-shoulder-under-left-shoulder'] -> ['cue-scooping-underneath-it', 'cue-rotate-your-right-shoulder-under-your-left-shoulder']
- 2026-09-09 [[2026-06-15-the-royals-just-recalled-this-28-year-old-slugger-john-rave]]: cues ['cue-catch-it-as-deep-as-you-can-and-pull-it', 'cue-stay-in-the-spot', 'cue-keep-the-back-shoulder-lower-than-the-front-one'] -> ['cue-catch-it-as-deep-as-you-can-and-pull-it', 'cue-stay-in-the-spot', 'cue-keep-the-back-shoulder-lower-than-this-front-one']; drills ['drill-darts', 'drill-handle-load-barrel-load-open-closed', 'drill-pivot-pick', 'drill-underload-light-bat-vs-lh-curveball', 'drill-rh-cutter-lh-curveball-live-bp', 'drill-opposite-side-short-round'] -> ['drill-darts', 'drill-handle-load-barrel-load-open-and-closed', 'drill-pivot-pick', 'drill-underload-light-bat-vs-left-handed-curveball', 'drill-rh-cutter-lh-curveball-live-bp', 'drill-opposite-side-short-round']
- 2026-09-09 [[2026-06-18-6-8-hs-vanderbilt-commit-goes-for-96mph-in-pre-draft]]: cues ['cue-feel-the-chest-over', 'cue-keep-that-same-hand-speed', 'cue-split-the-seam-offset-it', 'cue-drop-drive-through-the-baseball'] -> ['cue-feel-the-chest-over-and-then-get-compact-coming-up', 'cue-keep-that-same-hand-speed', 'cue-split-that-seam-offset-it', 'cue-drop-drive-through-the-baseball']
- 2026-09-09 [[2026-06-23-the-plane-of-rotation-how-elite-throwers-use-it-to-throw]]: cues ['cue-get-over-the-top', 'cue-get-behind-the-ball', 'cue-unravel-out', 'cue-let-the-pelvis-do-the-work'] -> ['cue-unravel-out', 'cue-let-the-pelvis-just-do-the-work-imagine-your-arm-is']
- 2026-09-09 [[2026-06-27-from-juco-to-d1-how-garrett-west-made-it-as-a-two-way-player]]: cues ['cue-tongue-between-teeth', 'cue-get-more-tilt', 'cue-rotate-chest-to-target-and-stop'] -> ['cue-put-the-tongue-in-between-the-teeth', 'cue-the-tilt', 'cue-rotate-the-chest-to-the-traject-sic-and-stop-it-there']
- 2026-09-09 [[2026-06-30-how-to-fix-your-pushy-arm-action-pushy-arm-action-part-two]]: drills ['drill-l-screen-constraint', 'drill-10-toes', 'drill-abbreviated-arm-action', 'drill-underload-ball-open-hand'] -> ['drill-l-screen-constraint', 'drill-10-toes-drill', 'drill-abbreviated-arm-action', 'drill-underload-ball-open-hand-tennis-racket']
- 2026-09-09 [[2026-07-16-36-year-old-pitching-coach-starts-a-pro-game]]: cues ['cue-delay-front-leg-get-it-up', 'cue-let-it-float-pull-through', 'cue-arms-along-for-the-ride'] -> ['cue-let-it-float-into-place-and-then-just-pull-it-through', 'cue-delay-your-front-leg-get-it-up-give-this-time-to-get', 'cue-arms-just-along-for-the-ride']
- 2026-09-09 [[2026-07-19-which-plyos-should-you-use-with-drills]]: drills ['drill-tentos', 'drill-pivot-pick', 'drill-half-layback-feel', 'drill-figure-eight', 'drill-one-leg-off-ground-throw', 'drill-drop-step-quick-pick'] -> ['drill-tentoe-s-split-stance-heavy-plyo', 'drill-pivot-pick', 'drill-half-layback-feel-drills-self-toss-dangle-dead-man', 'drill-figure-eight', 'drill-one-leg-off-ground-throw', 'drill-drop-step-quick-pick-throws']
- 2026-09-09 [[2026-07-21-day-in-the-life-of-a-baylor-pitcher-at-tread]]: drills ['drill-nerve-release-scalenes', 'drill-pre-throw-band-internal-rotation', 'drill-two-knee-glove-behind-back-throws', 'drill-med-ball-rotational-throws'] -> ['drill-nerve-release-on-scalenes', 'drill-pre-throw-internal-rotation-band-work', 'drill-two-knee-glove-behind-back-throws', 'drill-med-ball-rotational-throws']
- 2026-09-09 [[2026-07-26-from-88-to-96-mph-in-10-weeks-the-luis-patino-story]]: cues ['cue-go-back-to-what-you-used-to-do', 'cue-feel-like-a-shortstop-feel-like-an-infielder', 'cue-feel-yourself-in-front-of-the-ball'] -> ['cue-feel-like-a-shortstop-feel-like-an-infielder']
- 2026-09-09 [[2026-07-29-these-6-lifts-are-non-negotiable-for-pitchers]]: cues ['cue-big-toe', 'cue-hold-flexion', 'cue-extend-elbows-let-the-trunk-move'] -> ['cue-big-toe', 'cue-hold-flexion', 'cue-extend-the-elbows-let-the-trunk-move']; drills ['drill-safety-bar-reverse-lunge', 'drill-sled-push', 'drill-sled-lateral-drag', 'drill-sled-reverse-backpedal', 'drill-single-leg-db-rdl', 'drill-nordic-iso-hamstring-hold', 'drill-reverse-crunch', 'drill-trunk-rotation'] -> ['drill-safety-bar-reverse-lunge', 'drill-sled-push', 'drill-sled-lateral-drag', 'drill-sled-reverse-backpedal', 'drill-single-leg-db-rdl', 'drill-nordic-iso-ghr-hamstring-hold', 'drill-reverse-crunch', 'drill-trunk-rotation-cable-or-straight-bar']
- 2026-09-09 [[2026-08-02-he-just-skipped-college-to-become-a-pro-keaton-maiorana]]: cues ['cue-stay-tall-as-you-work-that-direction', 'cue-dont-let-yourself-die', 'cue-pick-your-starting-point-throw-through-it', 'cue-horseshoe-in-not-horseshoe-out'] -> ['cue-stay-tall-as-you-work-that-direction', 'cue-don-t-let-yourself-die', 'cue-pick-your-starting-point-throw-through-it', 'cue-you-go-horseshoe-in-not-horseshoe-out']
- 2026-09-09 [[2026-08-18-d3-shortstop-became-a-d1-pitcher-after-this-showcase]]: cues ['cue-dont-control-it-so-much', 'cue-take-big-bites', 'cue-hang-out-over-the-backside'] -> ['cue-don-t-control-it-so-much', 'cue-take-big-bites', 'cue-hang-out-over-the-backside-hold-things-back']
- 2026-09-09 [[2026-08-23-how-to-throw-hard-as-a-short-pitcher]]: drills ['drill-long-toss', 'drill-pull-downs', 'drill-rotational-med-ball-cable-work'] -> ['drill-long-toss', 'drill-pull-downs', 'drill-rotational-med-ball-cable-kaiser-work']
- 2026-09-09 [[2026-08-30-6-upper-body-lifts-for-pitchers]]: domain ['pitching', 'strength'] -> ['strength']; cues ['cue-help-yourself-up-slow-down', 'cue-accumulate-a-minute', 'cue-dont-ego-lift-this'] -> ['cue-help-yourself-on-the-way-up-and-then-slow-on-the-way', 'cue-accumulate-a-minute', 'cue-don-t-ego-lift-this']
- 2026-09-09 [[2026-09-06-complete-guide-to-mastering-the-changeup-grips-cues]]: cues ['cue-turn-the-ball-over-and-pronate-through', 'cue-throw-it-like-a-fastball', 'cue-get-away-from-the-midline', 'cue-palm-facing-the-catcher-at-release'] -> ['cue-throw-it-like-a-fastball', 'cue-get-that-middle-finger-away-from-the-midline', 'cue-feel-like-the-palm-of-your-hand-is-facing-directly-at']
