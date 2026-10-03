
# Astro World — Storage Architecture (RESOLVED 2026-06-22)

Final, working storage design for [[astroworld-status]]. Built for 60+ users with heavy
video/image load. **This is the source of truth — supersedes earlier "cloudflareStream"
and "keep video on Railway" notes below.**

## The architecture (live + verified)
- **App + Postgres database → Railway.** Runs the Next.js app; DB is Supabase Postgres
  (catalog/structure: pages, domains, sections, video rows with `driver`+`storageKey`).
- **Video + images + thumbnails → Supabase Storage** (private bucket `content-videos`,
  CDN-served via signed URLs). Object storage + CDN = the right tool for many concurrent
  viewers; keeps the app server out of byte-delivery.
- **PDFs → Railway persistent volume** (`/data/uploads`, `LOCAL_STORAGE_DIR`). Small, fine.

### Why this split (the principle)
Never serve heavy media *through* the app server at scale — every view would burn the
app's CPU/RAM/bandwidth and bottleneck all 60 users. Object storage + CDN is built for it.
Railway 1TB was never the issue; **delivery** was. (Storage size ≠ delivery capacity.)

## How it works (code map)
- `src/lib/storage/` — swappable adapters: `local` (volume), `supabaseStorage`,
  `cloudflareStream`, `sharepoint`, `externalEmbed`. Each `Video` row pins its `driver`.
- `src/lib/storage/constants.ts` — `SUPABASE_VIDEO_BUCKET = "content-videos"`.
- **Upload (video+image):** browser uploads **direct to Supabase** via `@supabase/supabase-js`
  browser client (`UploadForm.tsx`) → POST `/api/storage/finalize` records the row. Bytes
  never touch Railway → no request-size limit. PDFs still POST to `/api/upload` (volume,
  streamed to disk via busboy — `2a43889`).
- **Playback:** `/api/video/[id]/stream` — for `supabaseStorage` driver, mints a 1h **signed
  URL** and 302-redirects (private; only signed-in users can sign). For `local`, streams bytes
  abort-safely (custom Node→Web stream — fixes the `ERR_INVALID_STATE` uncaught crash `7bf6006`).
- **Thumbnails:** `/api/content/[id]/thumb` — uploads to Supabase, GET redirects to signed URL.
- **RLS (storage.objects):** admin (active profile) INSERT/DELETE on `content-videos`;
  authenticated SELECT (so signed URLs work for the 60 logged-in users). Bucket is private.

## Key gotchas (hard-won)
- **Supabase has TWO size limits.** Per-bucket `file_size_limit` (set to 5GB via SQL) AND a
  **project-wide "Upload file size limit"** (Dashboard → Storage → **Settings** tab) that
  defaults to **50MB and OVERRIDES the bucket.** A 358MB upload failed with "object exceeded
  the maximum allowed size" until the global limit was raised to 5GB. Raise BOTH for big video.
- **Railway volume = ephemeral without a volume.** `/data` volume + `LOCAL_STORAGE_DIR=/data/uploads`
  are set (verified). Files uploaded before that (≤6-19) were wiped — only catalog rows survived.
- **Per-row `driver` makes migration seamless** — old `local` rows + new `supabaseStorage` rows
  coexist; the app serves each by its own driver. Migration = move bytes + repoint the row.
- **Migrating volume files must run ON Railway** (only the app can read the volume). Done via
  admin-only one-click buttons: `/api/admin/migrate-thumbnails` + `/api/admin/migrate-videos`
  (`/admin` → Maintenance, allowlist-gated). Smallest-first, per-file try/catch.

## Final verified state (2026-06-22)
- **7 videos → Supabase** (405.8MB incl. the 358MB Steal Breaks, verified in bucket). 0 on Railway.
- **15 thumbnails → Supabase.** 0 on Railway.
- **9 PDFs → Railway volume.** App + DB on Railway.

## Cost
- Supabase **Pro** $25/mo: 100GB storage, 250GB egress + 250GB cached (CDN) egress, big-file
  uploads, daily backups, no DB auto-pause. Cheaper/more predictable than Railway egress for
  video + offloads the app. (Railway Pro 1TB could *store* it but would bill egress per view
  through the app — worse.)

## Open / pending
1. **Thumbnail load speed** — each thumb does app→sign→302→CDN, uncached, per image (slow with
   many cards). Fix options: (A) render-time signed URLs + cache [keeps private]; (B) public
   thumbnail bucket [fastest, but thumbnails publicly reachable by UUID URL; video stays private].
   DECISION PENDING (Zac choosing A vs B).
2. **Branded error/loading pages** — still on Railway's raw fail page when the app errors.
3. **Prose/body content type** — pages only have media cards + `blurb`; philosophy/policy text
   currently lives in `blurb`. A rich-text block is a worthwhile feature.

## Links
[[astroworld-status]] · [[coordinator-notes-app]]

---
*(Below: superseded historical notes from the decision process — kept for context.)*
