---
type: moc
domain: training-knowledge
created: 2026-09-04
updated: 2026-09-04
---
# MOC - Training Knowledge

The hub for **how players get better**: throwing, hitting, strength, anatomy
and movement, and the research behind them. Built from the public output of
coaching organizations and kept current by the nightly pipeline in
`_pipeline/`. Owned personally (BridgerBSB), mirrored to the Astros account.
Design: [[projects/training-knowledge/design]].

## Domains
- [[MOC-pitching]] - throwing mechanics, velocity, pitch design, command, arm care
- [[MOC-hitting]] - swing, bat speed, approach, bat path
- [[MOC-strength]] - weight room, plyos, mobility, periodization
- [[MOC-anatomy]] - anatomy, physiology, motor learning, injury mechanism

## Layers
- `sources/<source>/` - one note per video or post, tagged by domain / kind / value
- `cues/` - one note per coaching cue (what the coach SAYS), linked from every source that uses it
- `drills/` - one note per drill (setup, what it builds, who for), linked from every source that shows it
- `concepts/` - the topic layer (definitions), enriched by sources
- `sources/_raw/` - immutable transcripts and articles, cited by timestamp

## Sources watched
- Driveline Baseball - YouTube + blog
- Tread Athletics - YouTube + blog
- Baseball Performance Center - YouTube (pitching only)

## Review
Pending notes sit in `_review/`. Edit the frontmatter or the cue list, set
`status: approved | edited | rejected`, and the next run files the note and
records the correction in `_pipeline/taxonomy.md`. Contradictions between
sources land in `_review/contradictions.md`; candidate channels to add in
`_review/candidates.md`.

## Related
[[MOC-baseball-analytics]] · [[MOC-astros-engineering]] · [[meta/skill-dev-principles]] · [[ltad]]
