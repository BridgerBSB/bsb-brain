---
name: feedback_fence_never_flat
description: NEVER use flat uniform 330ft fence — CF is always deeper (330-400-330 cosine for MiLB, Minute Maid polynomial for MLB)
type: feedback
originSessionId: bd88ed0b-ee4f-4dd9-a5ff-f6a220b085e0
---
Use `_minute_maid_fence()` (Daikin Park) for ALL levels, ALL spray charts. No exceptions. DELETE `_milb_fence` and `_generic_milb_fence` — they should not exist in the codebase.

**Why:** User explicitly said Minute Maid fence for everything. MiLB cosine and flat fences were wrong every time. Future: affiliate-specific fences from DB data.

**How to apply:**
- ALWAYS use `_minute_maid_fence()` — the piecewise polar equation
- DELETE `_milb_fence` and `_generic_milb_fence` from any file — they are NOT fallbacks, they are WRONG
- If `_draw_baseball_field(fence_fn=None)` defaults to anything other than `_minute_maid_fence`, change the default
- **NEGATE fence x-coordinate** for catcher's view: `fence_x.append(-r * np.sin(bearing_rad))` (fixed Apr 15, 2026 — was mirrored in all 6 files)
- See `.claude/rules/visual-standards.md` "Outfield Fence Standards" section
