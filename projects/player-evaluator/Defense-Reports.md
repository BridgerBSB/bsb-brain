---
type: reference
created: '2026-06-29'
tags:
  - player-evaluation
  - defense
  - catcher
  - scouting
---
# Defense Reports

Part of [[Player-Evaluator-Agent]].

## Philosophy
For all defenders, start with reaction and first move. How quickly does the player read contact,
and how accurate is the first step relative to ball flight or direction. Pair that with pre-pitch
routine, communication, motor, field IQ, backup responsibilities, and body positioning.

Defense matters less than hitting overall, but it carries more weight at premium positions:
catcher, shortstop, and center field.

## Catcher, three areas
**Receiving**: glove speed, beating the ball to the spot, called strikes outside the zone in the
shadow, balls called on pitches in the zone in the shadow.
**Game management**: staff trust, tempo, blocking, corralling wild pitches, handling pitchers.
**Throwing**: arm strength, exchange, pop time, accuracy, ability to throw from awkward pitch
locations.

Arm strength in mph is the anchor throwing metric, because it strongly connects to exchange
time, carry, and the ability to get the ball to second on the fly.

## How to write it
Lead with reaction and first move, then pre-pitch routine and IQ, then the position-specific
actions. For a catcher, walk the three areas in order (receiving, game management, throwing) and
anchor the throwing read on arm strength in mph. Tie everything to a development path and a way
to confirm progress, the same five questions as every other report (see [[Player-Evaluator-Agent]]).

Defensive tracking metric names that match our DB (use these so the report lines up with our
surfaces): see `.claude/rules/reference-impl-index.md` (fielding tier-1, OAA, PAA/EO, arm P99,
catcher framing/NetK) and `.claude/rules/fielding.md`.
