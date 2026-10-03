---
type: reference
created: '2026-06-29'
tags:
  - player-evaluation
  - biomechanics
  - mechanics
  - scouting
---
# Biomechanics

Part of [[Player-Evaluator-Agent]]. Always connect movement patterns to baseball outputs. Never
describe mechanics for their own sake; tie each observation to a baseball result and a path.

## Pitcher delivery checkpoints
- Athleticism: how fast can he move through ranges of motion while staying controlled.
- Layback.
- At least roughly 40 degrees of scap retraction at front-foot strike.
- Elbow flexion around 105 degrees or less at foot plant, without getting extreme.
- Shoulder and elbow in line with torso at foot plant.
- Center-of-gravity movement down the mound, smooth and progressive.
- Whether there is room to add speed.
- Pelvis rotation into a braced front leg.
- How open or closed the pelvis and torso are at foot plant.
- Hip-shoulder separation.
- Whether the delivery is adaptable and repeatable.

Pitcher language:
- "Drifts extremely well but does not fully capture the drop into rotation."
- "Leaves more on the table from lower-half rotation and deceleration."
- "Could create better hip-shoulder separation."
- "Sequences well despite the lower-half limitation."
- "Delays rotation well with the upper half."
- "Release height and extension variability create a development opportunity."
- "Improving release consistency should help command and pitch-shape stability."
- "He is athletic and shows the ability to get into good positions, but the early directional flaw limits his ability to create a clean linear drift and causes him to hit max hip-shoulder separation too early."

## Hitter movement checkpoints
- Back-leg hinge.
- Pelvic coil.
- Holding posture.
- Side bend.
- Hip-shoulder separation.
- Space to rotate, and direction.
- Point of contact.
- Attack angle.
- Swing tilt.
- Barrel direction.
- Ball-flight outcome.
- Ability to cover the upper and lower zones; pull-side direction and lift.

Hitter language:
- "Creates initial separation but loses it because he lands with a closed pelvis."
- "Does not create enough space to rotate."
- "Needs to hold the coil longer into rotation."
- "Pre-extends the hips, creating variable posture."
- "The swing gets reachy."
- "Needs swing variability to steepen the bat path on lower pitches."
- "There is a clear path to more pull-side power if he opens the pelvis sooner and holds the move into rotation."
- "With better back-leg hinge, pelvic coil, and later, more sequenced rotation, he would have more space to turn the barrel and match plane, which would unlock higher contact quality and damage potential."

Our bat-tracking and swing-path data sources (so mechanics tie to real metrics):
`.claude/rules/tracking-schema.md` (Biomechanics_Tracking, Swing_Contact_Values, Swing_Shapes)
and the Swing Path 3D work in Barrelsville.
