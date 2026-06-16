# PD Goals — Subjective & Unmeasurable Goals Reference

Goals fall into 3 categories:
1. **MEASURABLE** — metric exists in DB, wired in stats.py
2. **OBJECTIVE but UNMEASURABLE** — real metric but no DB source yet (could be added later)
3. **SUBJECTIVE** — no numeric metric possible

## RECENTLY PROMOTED TO MEASURABLE (Apr 7 2026)

These were subjective/unmeasurable but are now fully wired:

| Old Goal | New Goal | Metric Key | Notes |
|----------|----------|-----------|-------|
| Baseline Organizational Goals | Increase FPinZ% to 57% | `fpinz_pct` | Cristian direction |
| Maintain Velocity throughout outings | Increase FF Velo to 93mph | `ff_velo` | Cristian direction |
| Continue defensive progress | Increase Arm to 85mph in IF | `arm_strength` (P99) | Cristian direction |
| Usages (60% Hard / 40% Slider) | Increase FB Usage to 60% | `fb_usage` | Cristian direction |
| Develop FT 10 IVB x 15 HB | Avg FT IVB above 10 and HB above 15 | `ft_ivb` + `ft_hb` | Compound shape goal |
| Develop short spin weapon (FC 5,5) | Avg FC IVB above 5 and HB below -5 | `fc_ivb` + `fc_hb` | Compound shape, HB negative (cutter) |
| Reduce FF usage v RHH Pre2k (50%) | Decrease FF Usage to 50% in Pre2K vs RHH | `ff_usage` | Perez |

## SUBJECTIVE Goals (no metric, direction=DESCRIPTIVE)

These goals should parse as `direction=DESCRIPTIVE` with no target value.
The parser must recognize these and NOT attempt to compute a value.

| Keyword/Pattern | Example Goal | Notes |
|----------------|-------------|-------|
| `soft skills` | "Improve soft skills and game preparation" | |
| `game preparation` | same | |
| `Prioritize recovery` | "Prioritize recovery" | |
| `sleep quality` | "Improve sleep quality" | |
| `nutritional` / `fueling plan` | "Maintain nutritional routines at affiliate" | |
| `Maintain Velocity throughout` | "Maintain Velocity throughout outings" | |
| `Dominate attack plans` | "Dominate attack plans and support your pitchers on the mound" | |
| `Keep your body` / `body ready` | "Keep your body ready to play a full season" | |
| `Manage fatigue` | "Manage fatigue" | |
| `Improve mobility` | "Improve mobility" (Freuddy Bautista) | |
| `internal clock` | "Improve internal clock" | |
| `Release consistency` / `mirror FF/SL` | "Release consistency -- mirror FF/SL" | |
| `twitch` (any form) | "Improve twitchiness", "Increase and maintain twitchiness", "Maintain/improve eccentrics and twitch on force plates" | |
| `eccentric` (any form) | "Eccentric metrics -- monitor and improve ability to apply the brakes", "Improve eccentric braking metrics", "Improve eccentric strength" | |
| `Force Deck` / `Force Plate` / `force plates` | "Improve eccentrics on Force Decks", "Improve force and power on Force Decks", "Maintain/improve eccentrics and twitch on force plates" | |
| `explosiveness` | "Improve explosiveness" | |
| `shoulder scores` | "Improve shoulder scores" | |
| `shoulder strength` | "Improve shoulder strength" | |
| `groin adduction` / `adductor` | "Improve groin adduction strength" | Could be objective in future |
| `Maintain weight` | "Maintain weight" | |
| `hamstring` | "Address hamstring asymmetries" | |
| `hip rotation at release` | "Increase hip rotation at release" | Could be objective in future |
| `Isometric shoulder` | "Isometric shoulder strengthening" | |
| `Usage v RHH` (no target) | "Usage v RHH" | No specific target given |

## OBJECTIVE but UNMEASURABLE (no DB source yet)

These are real metrics with numeric targets but we have no data source in GroundControl2.
Tag as `direction=DESCRIPTIVE` for now. When a data source becomes available, promote to MEASURABLE.

| Goal Pattern | Metric Type | Notes |
|-------------|------------|-------|
| `lean mass` / `lbs of lean` | Body composition | "Add 5 lbs of lean mass", "Gain 5 lbs of lean mass" |
| `fat mass` / `lbs of fat` | Body composition | "Lose 5 lbs of fat mass", "Decrease fat mass by 2%" |
| `body weight` + lbs | Body composition | "Increase body weight by 5 lbs", "Decrease fat mass by 2%; body weight to 240-245" |
| `CI100` / `CI` / `Concentric Impulse` | Force plate metric | "Improve CI100 to 150", "Improve Concentric Force Production (goal of 285-290 Concentric Impulse)" |
| `CMP/BM` | Biomechanics metric | "Improve CMP/BM" |
| `IR/ER` / `shoulder IR/ER` | Internal/External rotation | "Improve IR/ER", "Improve shoulder IR/ER" — could be objective in future |
| `Force Plate jumps` / `P2 to P1` | Force plate ratio | "Improve your Force Plate jumps. P2 to P1 ratio to 0.6" |
| `Concentric Force` | Force plate metric | "Improve Concentric Force Production" |
| `hip internal rotation` | Mobility/S&C | "Hip internal rotation; improve functional adductor strength" |

## KEY RULES

1. **All subjective goals** → `direction=DESCRIPTIVE`, `target=None`, displayed but no progress bar
2. **All objective-but-unmeasurable** → same treatment as subjective for now
3. **"twitch" anywhere in text** → ALWAYS subjective
4. **"eccentric" anywhere in text** → ALWAYS subjective (unless specific DB metric added)
5. **"Force Deck" or "Force Plate"** → ALWAYS subjective/unmeasurable
6. **"CI" or "Concentric"** → objective but unmeasurable
7. When user provides a data source for any unmeasurable metric, move it to MEASURABLE
8. **Descriptive goals get NO grey text** — report skips at direction check, app shows "Subjective" label and `continue`s
9. **NO fallback grey text** — unrecognized metrics return `skip=True`, not "0 PA"
