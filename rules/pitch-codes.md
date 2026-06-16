---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# LK_Pitch_Results — Complete Reference

| ID | gumbo_description | pitch_result | did_swing | gumbo_code | Code Group |
|----|-------------------|--------------|-----------|------------|------------|
| 1 | NULL | (empty) | 0 | NULL | BALL |
| 2 | Ball - Automatic | automatic_ball | 0 | V | BALL |
| 3 | Strike - Automatic | automatic_strike | 0 | A | CALLED_STRIKE |
| 4 | Ball - Called | ball | 0 | B | BALL |
| 5 | Ball - Ball In Dirt | blocked_ball | 0 | *B | BALL |
| 6 | Strike - Called | called_strike | 0 | C | CALLED_STRIKE |
| 7 | Strike - Foul | foul | 1 | F | FOUL |
| 8 | Strike - Foul Bunt | foul_bunt | 1 | L | FOUL |
| 9 | Strike - Foul on Pitchout | foul_pitchout | 1 | R | FOUL |
| 10 | Strike - Foul Tip | foul_tip | 1 | T | WHIFF |
| 11 | Ball - Hit by Pitch | hit_by_pitch | 0 | H | BALL |
| 12 | Hit Into Play - Out(s) | hit_into_play | 1 | X | BIP |
| 13 | Hit Into Play - No Out(s) | hit_into_play_no_out | 1 | D | BIP |
| 14 | Hit Into Play - Run(s) | hit_into_play_score | 1 | E | BIP |
| 15 | Ball - Intentional | intent_ball | 0 | I | BALL |
| 16 | Strike - Missed Bunt | missed_bunt | 1 | M | WHIFF |
| 17 | Ball - Pitchout | pitchout | 0 | P | BALL |
| 18 | Pitchout HIP - Out(s) | pitchout_hit_into_play | 1 | Y | BIP |
| 19 | Pitchout HIP - No Out(s) | pitchout_hit_into_play_no_out | 1 | J | BIP |
| 20 | Pitchout HIP - Run(s) | pitchout_hit_into_play_score | 1 | Z | BIP |
| 21 | Strike - Swinging on Pitchout | swinging_pitchout | 1 | Q | WHIFF |
| 22 | Strike - Swinging | swinging_strike | 1 | S | WHIFF |
| 23 | Strike - Swinging Blocked | swinging_strike_blocked | 1 | W | WHIFF |
| 24 | Strike - Unknown | unknown_strike | 0 | K | CALLED_STRIKE |
| 25 | Strike - Bunt Foul Tip | bunt_foul_tip | 1 | O | WHIFF |
| 26 | Ball - Automatic (IBB) | automatic_ball | 0 | VB | BALL |
| 27 | Ball - Auto (Timer - Catcher) | automatic_ball | 0 | VC | BALL |
| 28 | Ball - Auto (Timer - Pitcher) | automatic_ball | 0 | VP | BALL |
| 29 | Ball - Auto (Shift Violation) | automatic_ball | 0 | VS | BALL |
| 30 | Strike - Auto (Pitch Timer) | automatic_strike | 0 | AC | CALLED_STRIKE |
| 31 | Strike - Auto (Batter Timeout) | automatic_strike | 0 | AB | CALLED_STRIKE |

## Code Group Constants
```python
BALL_CODES = (1, 2, 4, 5, 11, 15, 17, 26, 27, 28, 29)        # 11 codes
WHIFF_CODES = (10, 16, 21, 22, 23, 25)                         # 6 codes — all swinging strikes
CALLED_STRIKE_CODES = (6, 3, 24, 30, 31)                       # 5 codes
FOUL_CODES = (7, 8, 9)                                          # 3 codes (NOT 16, NOT 25)
BIP_CODES = (12, 13, 14, 18, 19, 20)                           # 6 codes (includes pitchout BIPs)
```

## Important Notes
- **pitch_result_id=16** = "Strike - Missed Bunt" (NOT "Foul Tip"). CAN be a strikeout (strikes_before=2)
- **pitch_result_id=10** = "Strike - Foul Tip" (the ACTUAL foul tip). In WHIFF_CODES
- **pitch_result_id=25** = "Strike - Bunt Foul Tip" (did_swing=1). Extremely rare
- **18/19/20** = Pitchout BIPs (extremely rare but properly grouped)
- All 31 pitch_result_ids are classified
- **Pitch type classification:** FF/FT/SI=Fastball, SL/CU/FC=Breaking, CH/FS/SC/KN=Offspeed
