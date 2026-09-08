"""Training-knowledge pipeline CLI.

  python kb.py discover  [--source X]            find new items on every feed
  python kb.py backfill  --source X [--limit N] [--from newest|oldest]
  python kb.py fetch     [--source X] [--limit N] [--whisper]
  python kb.py summarize [--source X] [--limit N]
  python kb.py promote   [--no-git]
  python kb.py lint
  python kb.py run       [--no-git]              the nightly sequence
  python kb.py rescue    --id=ID                  re-summarize an auto-filed low item as a FULL note into _review
  python kb.py retry     --id=ID                  failed item -> fetched (raw exists) or new. Use --id= : YouTube ids can start with "-"
  python kb.py status

All verbs are idempotent against _pipeline/state.json. Nothing is deleted.
"""
from __future__ import annotations

import argparse
import sys
import time
import traceback
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kb.paths import VaultPaths                       # noqa: E402
from kb.state import State                            # noqa: E402
from kb import discover as D                          # noqa: E402
from kb import fetch_video as FV                      # noqa: E402
from kb import fetch_blog as FB                       # noqa: E402
from kb import summarize as S                         # noqa: E402
from kb import promote as P                           # noqa: E402
from kb import lint as L                              # noqa: E402
from kb import faults as FA                           # noqa: E402

SLEEP = 2.5           # seconds between network calls
VIDEO_SLEEP = 12      # seconds between caption fetches; ~15 rapid pulls earned an IP block on 2026-09-04
WHISPER_BUDGET_S = 90 * 60   # per run: Whisper time before remaining videos wait for the next run
QUEUE_CAP = 40        # never leave more than this many pending for Zac
NIGHTLY_BATCH = 8     # backfill items per source per night


from kb.sources import load_sources, feeds_for, drop_paused  # noqa: E402


def log(paths: VaultPaths, line: str) -> None:
    P._log(paths, line)
    print(line)


# --- discover / backfill --------------------------------------------------------

def _found_for_feed(key: str, feed: dict, mode: str, state: State, limit: int | None, frm: str) -> list[dict]:
    kind = feed["kind"]
    if kind == "youtube":
        if mode == "new":
            return D.parse_ytdlp_lines(D.yt_dlp_flat(feed["url"], end=30))
        # backfill: walk the channel list. newest = playlist start 1..; oldest = from the end.
        total = state.cursor(f"{key}:total")
        if total is None:
            total = len(D.parse_ytdlp_lines(D.yt_dlp_flat(feed["url"])))
            state.set_cursor(f"{key}:total", total)
        pos = state.cursor(f"{key}:pos:{frm}", 0)
        n = limit or NIGHTLY_BATCH
        if frm == "newest":
            start, end = pos + 1, pos + n
        else:
            start, end = max(1, total - pos - n + 1), max(1, total - pos)
        items = D.parse_ytdlp_lines(D.yt_dlp_flat(feed["url"], start=start, end=end))
        state.set_cursor(f"{key}:pos:{frm}", pos + n)
        return items
    if kind == "blog-pages":
        if mode == "new":
            return D.parse_driveline_page(D.fetch_text(feed["url"] + "?page=1"))
        page = state.cursor(f"{key}:page:{frm}", 140 if frm == "oldest" else 1)
        html = D.fetch_text(f"{feed['url']}?page={page}")
        items = D.parse_driveline_page(html)
        if frm == "oldest":
            items = list(reversed(items))
        nxt = page - 1 if frm == "oldest" else page + 1
        state.set_cursor(f"{key}:page:{frm}", nxt)
        if not items:
            state.set_cursor(f"{key}:done:{frm}", True)
        return items
    if kind == "blog-rss":
        if mode == "new":
            return D.parse_tread_feed(D.fetch_text(feed["url"]))
        page = state.cursor(f"{key}:page:{frm}", 9 if frm == "oldest" else 1)
        # A transport error is NOT the end of the archive. Marking done on any
        # exception let one DNS blip (2026-09-06) retire Tread's backfill for
        # good, and "0 seen, 0 new" reads exactly like a finished walk. Let it
        # raise: cmd_discover logs the feed and retries next run. Only an
        # archive page that parses to nothing means we ran off the end.
        html = D.fetch_text(feed["archive_url"].format(n=page))
        items = D.parse_tread_archive_page(html)
        if not items:
            state.set_cursor(f"{key}:done:{frm}", True)
            return []
        if frm == "oldest":
            items = list(reversed(items))
        state.set_cursor(f"{key}:page:{frm}", page - 1 if frm == "oldest" else page + 1)
        return items
    raise ValueError(f"unknown feed kind {kind}")


def cmd_discover(paths, state, args, mode="new"):
    sources = load_sources(paths)
    total = 0
    for key, feed in feeds_for(sources, args.source):
        if mode == "backfill" and state.cursor(f"{key}:done:{args.frm}"):
            continue
        try:
            found = _found_for_feed(key, feed, mode, state, getattr(args, "limit", None), getattr(args, "frm", "oldest"))
        except Exception as e:  # one dead feed must not stop the others
            log(paths, f"discover {key}: ERROR {e}")
            continue
        if mode == "backfill" and getattr(args, "limit", None):
            found = found[: args.limit]
        n = D.discover_items(state, feed, found)
        total += n
        log(paths, f"discover {key} ({mode}): {len(found)} seen, {n} new")
        time.sleep(SLEEP)
    state.save()
    return total


# --- fetch ----------------------------------------------------------------------------

def _fetch_one(paths, state, item, save_images: bool, run_ctx: dict):
    """run_ctx carries per-run facts: captions_blocked, whisper_s (time spent)."""
    iid = item["id"]
    raw_path = paths.raw_file(item["source"], iid)
    if item["medium"] == "video":
        meta = FV.fetch_video_meta(iid)
        t0 = time.time()
        segs, ctype, blocked = FV.get_transcript(iid, paths.raw / "_tmp",
                                                captions_blocked=run_ctx["captions_blocked"])
        if ctype.startswith("whisper"):
            run_ctx["whisper_s"] += time.time() - t0
        if blocked and not run_ctx["captions_blocked"]:
            run_ctx["captions_blocked"] = True
            log(paths, "fetch: YouTube throttled captions; Whisper for the rest of this run")
        md = FV.segments_to_markdown(segs, iid)
        if len(md) < FV.MIN_TRANSCRIPT_CHARS:
            raise RuntimeError("too-short transcript")
        FV.write_raw_video(raw_path, item, meta, md, ctype)
        title = meta.get("title") or item.get("title")
        published = meta.get("published") or item.get("published")
    else:
        html = D.fetch_text(item["url"])
        meta, md, images = FB.extract_article(html, item["url"])
        if len(md) < FB.MIN_CHARS:
            raise RuntimeError("too-short article")
        saved = {}
        if save_images and images:
            slug = iid.split("-blog-", 1)[-1]
            got = FB.save_images(images, paths.assets / item["source"] / slug)
            saved = {u: paths.rel(p) for u, p in got.items()}
        FB.write_raw_blog(raw_path, item, meta, md, saved)
        title = meta.get("title") or item.get("title")
        published = meta.get("published") or item.get("published")
    state.update(iid, raw=paths.rel(raw_path), title=title, published=published)
    state.set_status(iid, "fetched")


def cmd_fetch(paths, state, args):
    sources = load_sources(paths)
    save_images = {f["source"]: bool(f.get("save_images")) for f in sources.values() if f["kind"] != "youtube"}
    todo, paused = drop_paused(state.by_status("new", args.source), sources)
    if paused:
        print(f"  fetch: {paused} item(s) left queued, their feed is paused")
    if args.limit:
        todo = todo[: args.limit]
    ok = bad = deferred = 0
    ctx = {"captions_blocked": False, "whisper_s": 0.0}
    for item in todo:
        if item["medium"] == "video" and ctx["whisper_s"] > WHISPER_BUDGET_S:
            deferred += 1                 # stays `new`; next run continues
            continue
        try:
            _fetch_one(paths, state, item, save_images.get(item["source"], False), ctx)
            ok += 1
        except FV.Unavailable as e:
            state.set_status(item["id"], "skipped")
            state.update(item["id"], error=f"unavailable: {str(e)[:120]}")
            print(f"  fetch {item['id']}: unavailable, skipped")
        except Exception as e:
            state.set_status(item["id"], "failed", error=f"{type(e).__name__}: {str(e)[:200]}")
            bad += 1
            print(f"  fetch {item['id']}: {type(e).__name__}: {str(e)[:120]}")
        state.save()
        if item["medium"] == "video" and not ctx["captions_blocked"]:
            time.sleep(VIDEO_SLEEP)
        else:
            time.sleep(SLEEP)
    log(paths, f"fetch: {ok} ok, {bad} failed, {deferred} deferred; whisper {ctx['whisper_s']/60:.0f} min"
              + (", captions throttled" if ctx["captions_blocked"] else ""))
    return ok


# --- summarize ------------------------------------------------------------------------

def cmd_summarize(paths, state, args):
    sources = load_sources(paths)
    excl = {}
    for f in sources.values():
        if f.get("scope", {}).get("exclude_domains"):
            excl[f["source"]] = f["scope"]["exclude_domains"]
    pending_now = L.lint_vault(paths, state)["pending"]
    room = max(0, QUEUE_CAP - pending_now)
    todo, paused = drop_paused(state.by_status("fetched", args.source), sources)
    if paused:
        print(f"  summarize: {paused} item(s) left fetched, their feed is paused")
    if args.id:
        todo = [r for r in todo if r["id"] in args.id.split(",")]
    elif args.limit:
        todo = todo[: args.limit]
    elif not args.ignore_cap:
        todo = todo[:room]
    ok = bad = 0
    for item in todo:
        try:
            out = S.summarize_item(paths, state, item, exclude_domains=excl.get(item["source"]))
            if out:
                ok += 1
                print(f"  {out.name}")
            else:
                bad += 1
        except Exception as e:
            state.set_status(item["id"], "failed", error=f"{type(e).__name__}: {str(e)[:200]}")
            bad += 1
            traceback.print_exc(limit=2)
        state.save()
    log(paths, f"summarize: {ok} ok, {bad} failed (queue had room for {room})")
    return ok


# --- promote / lint / run ---------------------------------------------------------

def cmd_promote(paths, state, args):
    res = P.promote_all(paths, state, git=not args.no_git)
    state.save()
    log(paths, f"promote: {res['promoted']} promoted, {res['rejected']} rejected, {res['examples']} corrections")
    return res


def cmd_lint(paths, state, args):
    rep = L.lint_vault(paths, state)
    print(L.format_report(rep))
    return rep


def cmd_run(paths, state, args):
    log(paths, "run: start")
    cmd_discover(paths, state, args, mode="new")
    cmd_fetch(paths, state, args)
    cmd_promote(paths, state, args)
    rep = L.lint_vault(paths, state)
    if rep["pending"] < QUEUE_CAP:
        args.frm = "oldest"
        args.limit = NIGHTLY_BATCH
        cmd_discover(paths, state, args, mode="backfill")
        cmd_fetch(paths, state, args)
    args.limit = None
    cmd_summarize(paths, state, args)
    rep = cmd_lint(paths, state, args)
    if not args.no_git:
        P.git_commit_and_push(paths.root, [paths.raw, paths.assets, paths.review, paths.state, paths.log, paths.failed],
                              f"kb: nightly run, {rep['pending']} pending for review")
    log(paths, "run: done")


def cmd_retry(paths, state, args):
    """A failed item goes back to `fetched` when its raw file exists (re-summarize),
    else to `new` (re-fetch)."""
    for iid in args.id.split(","):
        rec = state.get(iid)
        if not rec:
            sys.exit(f"no item {iid}")
        back = "fetched" if rec.get("raw") and (paths.root / rec["raw"]).exists() else "new"
        state.set_status(iid, back)
        rec["retries"] = 0
        print(f"{iid} -> {back}")
    state.save()


def cmd_rescue(paths, state, args):
    sources = load_sources(paths)
    excl = {f["source"]: f["scope"]["exclude_domains"] for f in sources.values() if f.get("scope", {}).get("exclude_domains")}
    for iid in args.id.split(","):
        rec = state.get(iid)
        if not rec or not rec.get("raw"):
            sys.exit(f"no fetched item {iid}")
        out = S.summarize_item(paths, state, rec, exclude_domains=excl.get(rec["source"]), force_full=True)
        print(f"{iid} -> {out}")
    state.save()


def cmd_faults(paths, state, args):
    """Propose a fault taxonomy per domain. READ-ONLY except one proposal file
    per domain in _review/. Nothing is filed; that step does not exist yet."""
    groups = FA.collect(paths)
    if not groups:
        log(paths, "faults: no cue/drill fault strings found")
        return 0
    wanted = [d.strip() for d in args.domain.split(",")] if args.domain else sorted(groups)
    written = 0
    for domain in wanted:
        items = groups.get(domain) or []
        if not items:
            print(f"  faults {domain}: nothing to group")
            continue
        if domain not in FA.KNOWN_DOMAINS:
            print(f"  faults {domain!r}: not a taxonomy domain, skipped")
            continue
        # ONE domain's strings, one call. A cross-domain merge is not possible
        # here because the model never sees two domains at once (Zac, Sep 8 2026).
        body = S.run_claude(S._prompt(paths, "faults"), FA.render_input(items), args.model)
        out = FA.write_proposal(paths, domain, body, len(items))
        written += 1
        log(paths, f"faults {domain}: {len(items)} strings -> {paths.rel(out)}")
    return written


def cmd_status(paths, state, args):
    from collections import Counter
    c = Counter((r["source"], r["status"]) for r in state.data["items"].values())
    for (src, stt), n in sorted(c.items()):
        print(f"{src:10} {stt:11} {n}")
    print(L.format_report(L.lint_vault(paths, state)))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("verb", choices=["discover", "backfill", "fetch", "summarize", "promote", "lint", "run", "retry", "rescue", "status", "faults"])
    ap.add_argument("--source", help="driveline | tread | bpc")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--from", dest="frm", choices=["newest", "oldest"], default="oldest")
    ap.add_argument("--whisper", action="store_true", help="(kept for compatibility; Whisper is automatic now)")
    ap.add_argument("--no-git", action="store_true")
    ap.add_argument("--ignore-cap", action="store_true", help="summarize past the review-queue cap")
    ap.add_argument("--id", help="retry: one id; summarize: comma-separated ids to (re)summarize")
    ap.add_argument("--vault", help="vault root (default: parent of _pipeline)")
    ap.add_argument("--domain", help="faults: comma-separated domains (default: all found). "
                                     "One model call PER domain, never mixed.")
    ap.add_argument("--model", default="sonnet", help="faults: model for the grouping pass")
    args = ap.parse_args(argv)

    paths = VaultPaths(args.vault)
    state = State.load(paths.state)
    if args.verb == "discover":
        cmd_discover(paths, state, args, mode="new")
    elif args.verb == "backfill":
        if not args.source:
            sys.exit("backfill needs --source")
        cmd_discover(paths, state, args, mode="backfill")
    elif args.verb == "fetch":
        cmd_fetch(paths, state, args)
    elif args.verb == "summarize":
        cmd_summarize(paths, state, args)
    elif args.verb == "promote":
        cmd_promote(paths, state, args)
    elif args.verb == "lint":
        cmd_lint(paths, state, args)
    elif args.verb == "run":
        cmd_run(paths, state, args)
    elif args.verb == "retry":
        cmd_retry(paths, state, args)
    elif args.verb == "rescue":
        cmd_rescue(paths, state, args)
    elif args.verb == "status":
        cmd_status(paths, state, args)
    elif args.verb == "faults":
        cmd_faults(paths, state, args)


if __name__ == "__main__":
    main()
