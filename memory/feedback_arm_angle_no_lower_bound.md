---
name: arm angle has NO global lower bound
description: Submarine RHPs (Tyler Rogers, Josh Hejka, Adam Cimber) legitimately throw with negative arm angles — never add a global lower bound to arm-angle cleaning
type: feedback
originSessionId: 0506d4f2-0a41-4377-8757-ea1a547d55b5
---
NEVER write a global lower bound on arm angle (e.g. `>= 0`, `>= -20`, etc.).

**Why:** Submarine pitchers are real and produce negative arm-angle values. Tyler Rogers, Josh Hejka, Adam Cimber. Lefties also produce negative values regardless of slot. Any global lower-bound rule will silently delete real submariner pitches.

**How to apply:** The only safe global cap on arm angle is the upper limit at 90° (physically impossible to release with elbow above shoulder). All within-pitcher cleanup must be **relative to each pitcher's own mean** — that handles slot diversity automatically. A submariner's -3° pitch is inside HIS window because his mean is ~0°. A 3/4 pitcher's -3° pitch (with mean ~45°) sits 48° below HIS window and gets trimmed correctly.

The hard physical-limit lower bound that LOOKS reasonable for "normal" pitchers becomes a per-pitcher-archetype rule — which is exactly what the 2.5σ trim already implements. Don't double-impose.

Discovered when I claimed "no RHP throws below sidearm" while explaining Murrieta's -6.54° as a glitch. User corrected: Hejka and Rogers are real, throw negative routinely. The Murrieta-specific suspicion was correct (he's 3/4 with mean 45°, so -6° IS a glitch for HIM), but the global generalization was wrong.
