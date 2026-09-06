# Pipeline log (append-only)

One line per run and per promoted note. Written by `_pipeline/kb.py`; never edited by hand.

- 2026-09-04 17:34 discover tread-yt (backfill): 10 seen, 10 new
- 2026-09-04 17:34 discover tread-blog (backfill): 6 seen, 6 new
- 2026-09-04 17:34 discover driveline-yt (backfill): 10 seen, 10 new
- 2026-09-04 17:34 discover driveline-blog (backfill): 6 seen, 6 new
- 2026-09-04 17:34 discover bpc-yt (backfill): 10 seen, 10 new
- 2026-09-04 17:41 fetch: 27 ok, 15 failed
- 2026-09-04 17:44 fetch: YouTube throttled captions (IpBlocked); skipping remaining videos this run
- 2026-09-04 17:44 fetch: 2 ok, 0 failed, videos throttled
- 2026-09-04 18:17 summarize: 25 ok, 2 failed (queue had room for 40)
- 2026-09-05 13:22 summarize: 2 ok, 0 failed (queue had room for 13)
- 2026-09-05 13:37 run: start
- 2026-09-05 13:37 discover driveline-yt (new): 30 seen, 20 new
- 2026-09-05 13:37 discover tread-yt (new): 30 seen, 20 new
- 2026-09-05 13:37 discover bpc-yt (new): 30 seen, 20 new
- 2026-09-05 13:37 discover driveline-blog (new): 6 seen, 0 new
- 2026-09-05 13:37 discover tread-blog (new): 10 seen, 4 new
- 2026-09-05 13:37 fetch: YouTube throttled captions (IpBlocked); skipping remaining videos this run
- 2026-09-05 13:38 fetch: 4 ok, 0 failed, videos throttled
- 2026-09-05 13:38 promote: 0 promoted, 0 rejected, 0 corrections
- 2026-09-05 13:39 discover driveline-yt (backfill): 8 seen, 8 new
- 2026-09-05 13:39 discover tread-yt (backfill): 8 seen, 8 new
- 2026-09-05 13:39 discover bpc-yt (backfill): 8 seen, 8 new
- 2026-09-05 13:39 discover driveline-blog (backfill): 1 seen, 1 new
- 2026-09-05 13:39 discover tread-blog (backfill): 5 seen, 5 new
- 2026-09-05 13:40 fetch: YouTube throttled captions (IpBlocked); skipping remaining videos this run
- 2026-09-05 13:40 fetch: 0 ok, 1 failed, videos throttled
- 2026-09-05 13:41 summarize: 4 ok, 0 failed (queue had room for 11)
- 2026-09-05 13:41 run: done
- 2026-09-05 13:46 fetch: YouTube throttled captions; Whisper for the rest of this run
- 2026-09-05 13:49 fetch: YouTube throttled captions; Whisper for the rest of this run
- 2026-09-05 15:25 fetch: 49 ok, 19 failed, 36 deferred; whisper 90 min, captions throttled
- 2026-09-05 15:33 summarize: 7 ok, 0 failed (queue had room for 7)
- 2026-09-06 06:57 run: start
- 2026-09-06 06:58 discover driveline-yt (new): 30 seen, 0 new
- 2026-09-06 06:58 discover tread-yt (new): 30 seen, 0 new
- 2026-09-06 06:58 discover bpc-yt (new): 30 seen, 1 new
- 2026-09-06 06:58 discover driveline-blog (new): 6 seen, 0 new
- 2026-09-06 06:58 discover tread-blog (new): 10 seen, 0 new
- 2026-09-06 08:14 fetch: 29 ok, 8 failed, 0 deferred; whisper 0 min
- 2026-09-06 08:14 rejected 2009-10-12-welcome-to-driveline-baseball
- 2026-09-06 08:14 promote: 0 promoted, 1 rejected, 0 corrections
- 2026-09-06 08:15 discover driveline-yt: ERROR yt-dlp failed: ERROR: [youtube:tab] @drivelinebaseball/videos: Unable to download API page: <urllib3.connection.HTTPSConnection object at 0x0000019DBA16C920>: Failed to resolve 'www.youtube.com' ([Errno 11001] getaddrinfo failed) (caused by TransportError("<urllib3.connection.HTTPSConnection object at 0x0000019DBA16C920>: Failed to resolve 'www.youtube.com' ([Errno 11001] getaddrinfo failed)"))

- 2026-09-06 08:15 discover tread-yt: ERROR yt-dlp failed: ERROR: [youtube:tab] treadathletics/videos: Unable to download API page: <urllib3.connection.HTTPSConnection object at 0x000001616DB9CDD0>: Failed to resolve 'www.youtube.com' ([Errno 11001] getaddrinfo failed) (caused by TransportError("<urllib3.connection.HTTPSConnection object at 0x000001616DB9CDD0>: Failed to resolve 'www.youtube.com' ([Errno 11001] getaddrinfo failed)"))

- 2026-09-06 08:15 discover bpc-yt: ERROR yt-dlp failed: ERROR: [youtube:tab] @baseballperformancecenter/videos: Unable to download API page: <urllib3.connection.HTTPSConnection object at 0x00000156F58DCB30>: Failed to resolve 'www.youtube.com' ([Errno 11001] getaddrinfo failed) (caused by TransportError("<urllib3.connection.HTTPSConnection object at 0x00000156F58DCB30>: Failed to resolve 'www.youtube.com' ([Errno 11001] getaddrinfo failed)"))

- 2026-09-06 08:15 discover driveline-blog: ERROR HTTPSConnectionPool(host='drivelinebaseball.com', port=443): Max retries exceeded with url: /blogs/blog?page=139 (Caused by NameResolutionError("<urllib3.connection.HTTPSConnection object at 0x0000019E8724A840>: Failed to resolve 'drivelinebaseball.com' ([Errno 11001] getaddrinfo failed)"))
- 2026-09-06 08:15 discover tread-blog (backfill): 0 seen, 0 new
- 2026-09-06 08:15 fetch: 0 ok, 0 failed, 0 deferred; whisper 0 min
- 2026-09-06 08:19 summarize: 0 ok, 1 failed (queue had room for 1)
