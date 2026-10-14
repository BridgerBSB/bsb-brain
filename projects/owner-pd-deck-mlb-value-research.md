---
status: research captured 2026-10-09; slide design pending discussion with Zac
tags:
  - owner-deck
  - player-development
  - mlb-value
  - spence
  - ullola
created: 2026-10-09
---
# Owner PD deck: MLB value added by PD (Spence + Ullola)

**What it is:** Research for 1-2 slides in the owner-facing deck "What Player Development Means to the Astros Organization" (artifact https://claude.ai/artifact/UVm5wbrjeuh7nbwArw2Lyd). Zac's ask, 2026-10-09: show the Major League value added by two 2026 call-ups, Lucas Spence and Miguel Ullola, with WAR (or "ARV", meaning unconfirmed), photos, graphs and numbers.

Related: [[promotion-models-STATUS]] · [[prp-player-review-process]] · [[owner-pd-deck-needs-research]] (Needs + Staff slides, 2026-10-10)

## Bottom line (all figures final regular season 2026, fetched 2026-10-09)

| | Lucas Spence (OF) | Miguel Ullola (RHP) |
|---|---|---|
| Acquired | Undrafted FA, 2024 (SIU Edwardsville) | Intl FA, Jan 15 2021, Dominican Republic, $75,000 bonus |
| Path | 2024 A (Fayetteville) -> 2025 A / A+ / AA -> 2026 AAA -> MLB | 2021 DSL/FCL -> 2022 A -> 2023 A+ (+AFL) -> 2024 AA/AAA -> 2025 AAA -> 2026 MLB |
| MLB debut | Jul 17 2026 (age 23) | Jun 29 2026 (age 24) |
| 2026 MLB line | 19 G, 63 PA, .218/.317/.509, 4 HR, 12 RBI, 130 wRC+, 130 OPS+ | 11 G (2 GS), 16.2 IP, 2-0, 2.16 ERA, 194 ERA+, 0.72 WHIP, 16 K / 5 BB |
| bWAR | **0.4** | **0.4** |
| fWAR | **0.4** | **0.1** (FIP 4.00 vs 2.16 ERA drives the gap) |

- Combined: **0.8 bWAR** / 0.5 fWAR.
- Market value of that WAR, at FanGraphs' 2026 price for 0-1 WAR players (**$6.74M per WAR**): about $2.7M each by bWAR, about **$5.4M combined**. At the overall rate ($11.23M per WAR) it is about $9.0M combined. Use the tier rate. It is the honest match for 0.4-WAR players.
- Cost side: 2026 MLB minimum salary $780,000 (2022 CBA), prorated for MLB service days. Exact days were not computed.
- Headline moment: **Sep 24 2026, Spence hit his first three MLB home runs in one game** (7-5 win at the Athletics, West Sacramento), with Houston tied with Texas for the AL West lead and 3 games left. Third player ever whose first three career HRs came in one game. Houston won the AL West at 81-81, one game ahead of Texas (80-82). Do NOT say the game won the division (Houston held the tiebreaker on the final day).
- Ullola: debuted Jun 29 vs MIN, 4 K in 2 scoreless IP; used as an opener vs TB on Sep 10.

## Sources

### Baseball-Reference: Lucas Spence player page
- URL: https://www.baseball-reference.com/players/s/spenclu01.shtml
- Fetched via: WebFetch direct (200). Note `spencl01` 404s; the id is `spenclu01`.
- Substance: 2026 HOU 19 G, 63 PA, 4 HR, .218/.317/.509, OPS+ 130, **bWAR 0.4** (oWAR 0.4, dWAR 0.1, Rbat 2, Rbaser -1, Rfield 0). Born Jan 27 2003, Chicago Heights IL.
- Takeaways for us: Use bWAR for both players so the source is consistent.

### FanGraphs: Lucas Spence stats
- URL: https://www.fangraphs.com/players/lucas-spence/35126/stats
- Fetched via: WebFetch direct.
- Substance: 2026 MLB 19 G, 63 PA, wOBA .355, **wRC+ 130**, BsR -0.7, Off 1.5, Def -0.3, **fWAR 0.4**. 2026 AAA: 214 PA, .213/.332/.416, 8 HR, 97 wRC+.
- Takeaways: Search snippets showed a stale mid-season line (-0.3 WAR over 41 PA). Always fetch the page, not the snippet.

### Baseball-Reference: Miguel Ullola player page
- URL: https://www.baseball-reference.com/players/u/ullolmi01.shtml
- Fetched via: WebFetch direct.
- Substance: 2026 HOU 11 G, 2 GS, 16.2 IP, 2-0, 2.16 ERA, **194 ERA+**, FIP 4.00, 0.720 WHIP, 16 SO, 5 BB, **bWAR 0.4**.

### FanGraphs: Miguel Ullola stats
- URL: https://www.fangraphs.com/players/miguel-ullola/sa3016504/stats
- Fetched via: WebFetch direct.
- Substance: 2026 MLB FIP 4.00, xFIP 4.61, K% 25.8, BB% 8.1, **fWAR 0.1**. 2026 AAA: 39 G (10 GS), 66.1 IP, 4.21 ERA, 31.8 K%, **14.8 BB%**.
- Takeaways: fWAR is FIP-based and rates him lower than his results. If the deck shows only bWAR, say "bWAR" on the slide. Walk rate is the known development thread; there is an internal walk analysis script (`pd-goals/scripts/generate_ullola_walk_analysis.py`, AGM one-off).

### MLB Stats API (statsapi.mlb.com)
- URLs: https://statsapi.mlb.com/api/v1/people/828599/stats?stats=season,yearByYear&group=hitting&season=2026&sportId=1 · https://statsapi.mlb.com/api/v1/people/699044/stats?stats=season&group=pitching&season=2026&sportId=1 · https://statsapi.mlb.com/api/v1/people/search?names=Miguel%20Ullola
- Fetched via: WebFetch direct (public JSON).
- Substance: confirms both lines above. MLBAM ids: Spence **828599**, Ullola **699044**. Ullola mlbDebutDate 2026-06-29.

### MLB.com: "Work ethic puts UDFA Lucas Spence on fast track to Astros" (MLB.com staff, Sep 14 2026)
- URL: https://www.mlb.com/astros/news/work-ethic-puts-astros-lucas-spence-on-fast-track
- Fetched via: WebFetch direct.
- Substance: UDFA from the 2024 Draft class. Astros No. 12 prospect, one of three NDFAs on the Top 30. 60-grade arm and run, projects as a big-league CF. Optioned Aug 3 after 14 games. Quotes from the director of player development ("He's one of our best defenders, really throughout the system").
- Takeaways: The UDFA-to-MLB-in-two-years story is the PD headline for the owner. Skip the quotes on the slide; the quoted director is likely the presenter.

### Wikipedia: Lucas Spence; Miguel Ullola
- URLs: https://en.wikipedia.org/wiki/Lucas_Spence · https://en.wikipedia.org/wiki/Miguel_Ullola
- Fetched via: WebFetch direct.
- Substance: level-by-year paths (table above). Ullola added to the 40-man Nov 18 2025, optioned Mar 5 2026, recalled Jun 28 2026. Wikipedia's 2026 Astros season page conflicts with the AP on final standings. Treat Wikipedia as path-only.

### AP / ABC News: "Spence hits first 3 homers of career, helps Astros survive Athletics 7-5"
- URL: https://abcnews.com/Sports/wireStory/spence-hits-3-homers-career-helps-astros-survive-136744042
- Fetched via: WebSearch excerpts.
- Substance: Sep 24 2026, 3-run HR (2nd), solo (7th, 387 ft), solo (9th). Joined Joshua Baez (Aug 15 2026) and Seby Zavala (Jul 31 2021). Houston 79-80, tied with Texas, 3 games left. Had 40 MLB AB before the game.

### AP / TSN: "Astros win AL West with 81-81 record"
- URL: https://www.tsn.ca/mlb/article/astros-win-al-west-with-81-81-record-worst-for-first-place-team-beat-athletics/
- Fetched via: WebSearch excerpts.
- Substance: 81-81, AL West title by one game over Texas (80-82). Swept by CWS in the Wild Card Series.

### NBC Sports / Houston Chronicle: Ullola call-up + usage
- URLs: https://www.houstonchronicle.com/sports/astros/article/miguel-ullola-call-up-houston-22323669.php · https://www.nbcsports.com/fantasy/baseball/player-news/2026-07-02/astros-option-miguel-ullola-back-to-triple-a · https://www.nbcsports.com/fantasy/baseball/player-news/2026-09-10/miguel-ullola-to-serve-as-opener-against-rays
- Fetched via: WebSearch excerpts.
- Substance: debut vs MIN, 4 K over 2 scoreless IP, then 2 perfect innings. Optioned after that series and recalled later. Opener vs TB Sep 10.

### Signing bonus + prospect standing (Ullola)
- URLs: https://www.crawfishboxes.com/2025/2/26/24372873/astros-top-three-prospects-right-handers · https://www.mlb.com/astros/player/miguel-ullola-699044 · https://www.si.com/mlb/astros/news/meet-astros-pitching-prospect-real-chance-getting-called-up-in-2025
- Fetched via: WebSearch excerpts.
- Substance: **$75,000** bonus (Crawfish Boxes). BA No. 6 org prospect / top pitcher entering 2025. Best FB in system (BA). Led MiLB in opp AVG .161 in 2024 (min 100 IP). Current MLB Pipeline rank NOT confirmed.

### FanGraphs (Ben Clemens, Feb 24 2026): "What Are Teams Paying For A Win In Free Agency? 2026 Edition"
- URL: https://blogs.fangraphs.com/what-are-teams-paying-for-a-win-in-free-agency-2026-edition/
- Fetched via: WebFetch direct (verified, after the figure first surfaced in a forum post).
- Substance: 2025-26 offseason **$11.23M per projected WAR overall**. Tiers: **0-1 WAR $6.74M**, 1-2 WAR $8.51M, 2+ WAR $12.84M. 2020-26 avg overall $10.62M. Relievers excluded. No position-player/pitcher split.
- Takeaways: This is the conversion for any "market value" slide. Use the 0-1 WAR tier for these two players.

### 2022 CBA minimum salary schedule
- URL: https://www.truebluela.com/2022/3/10/22971463/mlb-collective-bargaining-agreement-details-2022-2026
- Fetched via: WebSearch excerpts.
- Substance: 2026 MLB minimum **$780,000**. The CBA expires Dec 1 2026.

### MLB headshots (images)
- URLs: https://img.mlbstatic.com/mlb-photos/image/upload/d_people:generic:headshot:67:current.png/w_640,q_auto:best/v1/people/828599/headshot/67/current · same pattern with 699044
- Fetched via: curl, 640x962 JPEG each.

## Open questions for Zac
1. "ARV" = ? Options: WAR market value ($/WAR), AAV, or an internal metric. No `ARV` exists in the codebase.
2. bWAR only, or show both bWAR and fWAR (Ullola differs 0.4 vs 0.1)?
3. One slide (both players) or two (one each)?
4. Internal data to add (work-laptop query): level-by-level path dates from GC2, Ullola BB% trend by level, Spence defense/arm.


## 2026-10-09 update: acquisition cost + GC2 Asset Value (AV)

- Zac: "ARV" was a typo for **AV = Asset Value** (GC2 internal). Bonuses per Zac: **Ullola $75K (intl 2021), Spence $150K (UDFA 2024)**. The slide emphasis is acquired low, then developed into value.
- AV source: `Player_Val.Asset_Value` (groundcontrol_id, season, pos, mkt_sv, salary, date_generated). AV = SUM(mkt_sv) at the latest snapshot. Verified for hitters (Kevin Alvarez $3.79M = GC2 $3.8M). **Pitcher rollup NOT verified** (Mayer: ours 38.2M vs GC2 21.3M). Ullola's GC2 page value decides which formula to use.
- Bonus sources: `MLB_eBis.MN_CONTRACT.SIGNINGBONUSTOTAL` (both players), `MLB_eBis.Intl_Query.signing_bonus` + `class_bonus_rank` (Ullola), `R4_Draft_Query` (expect none for Spence).
- Query: `sql-queries/owner-deck-av-spence-ullola.sql` (commit 385c1b67b, feature/pd-goals). Sections: S0 table size/index, S1 identity, S2 bonuses, S3 AV + every rollup, S4 AV by month, S5 Spence rank in the 2024 UDFA class (all orgs), S6 Ullola AV + bonus rank in his intl signing class, S7 rank inside HOU, S8 Contract_Data RAR + prospect-list ranks.
- Related prior work: [[promotion-models-STATUS]]. Promotion-velocity AV code is in `pd-goals/src/promotion_velocity_data.py`; the prospect-value deck is on branch `cq/pv-deck`.


## 2026-10-10 query results (sql-queries/owner-deck-av-spence-ullola.sql, run by Zac)

- `Player_Val.Asset_Value` = **95,747 rows**, clustered PK (groundcontrol_id, season, pos). **Current snapshot only. There is no AV history in GC2**, so an "AV over time" chart is not possible.
- Bonuses confirmed (MN_CONTRACT): Ullola **$75,000**, signed 2021-01-15, contract 31012990. Spence **$150,000**, signed 2024-07-19, contract 31025013. Spence has no R4 draft rows.
- Ullola Intl_Query: signing_class **2020** (2020-21 period), class_bonus_rank 320 (eBIS). Our RANK on bonus is 340 of 849, with ties. In 2026: actual_rar 5.3, projected_rar 12.5, c_war 1.79.
- AV, our rollups at the latest snapshot:
  - Spence: **$14,293,702** (one role; every rollup equal), seasons 2027-2032.
  - Ullola: all rows $65.3M · max per season **$56.0M** (= SP only) · RP only $9.3M, seasons 2027-2033. **Pitcher formula still unverified against GC2.**
- Class ranks, all 30 orgs:
  - Spence: **#12 of 220** in the 2024 undrafted domestic class (144 have an AV); **#3 of 84 hitters**.
  - Ullola: **#6 of 849** in the 2020-21 international class (206 have an AV); **#5 of 459 pitchers**. Bonus rank 340.
- 2024 undrafted class, current org HOU: Jagger Beck #3 (P), Max Holy #11, Spence #12, Arturo Flores #17. Among hitters, HOU holds **#2-#4** behind Parks Harber (SF). Org = PP_MASTER current org.
- HOU org AV rank (278 players): Ullola #3, Spence #35, which is the 13th-highest hitter. Pitchers dominate the top because the season-max rollup inflates them.
- Contract_Data 2026: both at AAVAMT $780,000. Actual RAR this year: Ullola **5.315**, Spence **2.410**. First callup: Ullola 2026-06-28, Spence 2026-07-17.
- ProspectLists: Ullola ranked #6 in two sources entering 2025 (source_ids 2 and 3, undecoded). Spence has no rows.
- Deck: added slide `acquired` ("Acquired at Low Cost", with headshots). The value slide is pending GC2's displayed AV for both players.
