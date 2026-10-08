---
type: raw
source: driveline
medium: blog
id: dl-blog-advanced-baseball-injury-database-release-point-corrections-implemented
title: "Advanced Baseball Injury Database: Release Point Corrections Implemented"
url: "https://drivelinebaseball.com/blogs/blog/advanced-baseball-injury-database-release-point-corrections-implemented"
published: '2011-03-13'
author: Admin
tags: []
figures: []
---
# Advanced Baseball Injury Database: Release Point Corrections Implemented

The [Advanced Baseball Injury Database](https://injurydb.drivelinebaseball.com/) has had a major problem since it's debuted - the release point PITCHf/x metrics were **uncorrected**. They needed to be corrected because the PITCHf/x cameras were not properly synchronized between each team's home park, and even game-to-game adjustments were necessary to get relatively accurate data. This has been a project I mostly gave up on until I started up work on it last month, and my fellow writer at [The Hardball Times](https://www.thehardballtimes.com), Max Marchi, has graciously provided me with a set of release point corrections based on his methodology [partially outlined in this article](https://www.hardballtimes.com/main/article/fine-tuning-pitchf-x-location-data/).

He sent them to me last night, and I implemented them in our database as of this evening. You can check out the [Advanced Injury Baseball Database](https://injurydb.drivelinebaseball.com/) and search for a player you're interested in - for example, [Tim Lincecum](https://injurydb.drivelinebaseball.com/index.php/injurydb/playerresult/NDUzMzEx) - and see the new results.

![Advanced Baseball Injury Database Advanced Baseball Injury Database](https://cdn.shopify.com/s/files/1/0952/2295/6313/files/baseballinjurydb.jpg?v=1779554091)

I hope to perform some statistics-based work on the corrected data and see if we can find a meaningful link between PITCHf/x values, injuries, and data about a player's anthropometry (height, weight, age).

## Leave a comment
