---
type: project
created: 2026-07-09
tags: [promotion-release-models, release, backtest, transactions]
---

# HOU Spring-2026 Release List (release-model backtest input)

Pulled by Zac from `MLB_eBis.TR_HISTORY` on the work laptop (2026-07-09) for the
release-model backtest: "where did the guys we cut in spring 2026 rank in the
release model at the moment we cut them?" Scored on each player's end-2025 line
(no 2026 games at spring; the sparkline carries prior-year stats). Content saved
here so it survives even if the CSVs are deleted.

Files: `bsb-wt-modeling/pd-goals/modeling/research/discovery/2026-07-09-hou-spring-2026-releases.csv`
and `...-departure-codes.csv`. Query grounded in `modeling/sql/03_label_released.sql`
(codes: cut = URREL/RELES; FA = FAOTH/FAXAD/FAXAC/FAXIA/ELFA; PRE_ORG_LK='HOU').

Related: [[promotion-release-models]] · [[artifacts-register]] · [[advisory-council]]

## Releases (22 RELES + 2 RETIR)

| player | gcid | ebis | mlbam | date | code | move_type | resigned_30d |
|---|---|---|---|---|---|---|---|
| Angel Aybar | 197733 | 816851 | 806723 | 2026-02-12 | RELES | Release | 0 |
| Isaac Palacio | 1262273 | 10008940 | 829453 | 2026-02-12 | RELES | Release | 0 |
| Frankelys Mendoza | 1258824 | 10005797 | 831045 | 2026-02-28 | RELES | Release | 0 |
| Alejandro Castellano | 265930 | 1004408 | 823489 | 2026-03-04 | RELES | Release | 0 |
| Andrews Sosa | 196447 | 827352 | 806237 | 2026-03-13 | RELES | Release | 0 |
| Ben Petschke | 216752 | 5027171 | 814386 | 2026-03-13 | RELES | Release | 0 |
| Dawil Almonte | 196079 | 823556 | 805044 | 2026-03-13 | RELES | Release | 0 |
| Franklin Gil | 196522 | 812833 | 805046 | 2026-03-13 | RELES | Release | 0 |
| Jorge Geraldo | 171631 | 830326 | 702876 | 2026-03-13 | RELES | Release | 0 |
| Juan Soto (minors) | 155743 | 813044 | 699041 | 2026-03-13 | RELES | Release | 0 |
| Luis Angel Rodriguez | 80598 | 767006 | 678296 | 2026-03-13 | RELES | Release | 0 |
| Norbis Diaz | 212951 | 999220 | 808588 | 2026-03-13 | RELES | Release | 0 |
| Rhett Kouba | 104277 | 5007875 | 688763 | 2026-03-13 | RELES | Release | 0 |
| Ryan Smith | 219805 | 5033520 | 823193 | 2026-03-13 | RELES | Release | 0 |
| Tyler Guilfoil | 117176 | 5017935 | 805965 | 2026-03-13 | RELES | Release | 0 |
| Anthony Sherwin | 216650 | 5028571 | 815448 | 2026-03-18 | RELES | Release | 0 |
| Darwin De Leon | 197463 | 816452 | 805816 | 2026-03-18 | RELES | Release | 0 |
| David Landeta | 197039 | 812549 | 805399 | 2026-03-18 | RELES | Release | 0 |
| Justin Trimble | 145359 | 5019095 | 702293 | 2026-03-18 | RELES | Release | 0 |
| Manuel Urias | 81971 | 782779 | 679893 | 2026-03-18 | RELES | Release | 0 |
| **Peter Lambert** | 71841 | 408540 | 663567 | 2026-03-24 | RELES | Release | **1 (re-signed HOU)** |
| Parker Chavers | 95753 | 5010894 | 685091 | 2026-04-20 | RELES | Release | 0 |
| Karniel Pratt | 177606 | 830527 | 805043 | 2026-04-29 | RELES | Release | 0 |
| Wes Clarke | 171629 | 799947 | 682265 | 2026-02-06 | RETIR | Retired | 0 |
| Drew Vogel | 211942 | 5026873 | 826164 | 2026-02-09 | RETIR | Retired | 0 |

Notes: Peter Lambert's `resigned_within_30d=1` = HOU re-signed him, so the query
correctly excludes him from the true-cut set (the 30-day re-sign guard worked).
Wes Clarke / Drew Vogel retired (not model-scored as org releases). "Juan Soto"
here is the minor-leaguer (mlbam 699041), NOT the star.

## Departure-code diagnostic (all HOU PRE_ORG_LK moves in window)

RELES=23, RETIR=2 are the roster-removal cuts/retirements. The rest are IL
placements (DL*/PL*/RSTIL), options (OPTAS/OUTRT), transfers (TRANS=117),
waivers (WVCLM=2), etc. No distinct "trade" departure surfaced in the window
(trades would show as a move to another org; none in the roster-removal set).
Full counts in `...-departure-codes.csv`.
