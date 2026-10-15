"""Baseball Command Center v2 - project bank, processes, idea bank, library.

Zac, Oct 14 2026: "a baseball command center that I actually use and actually
updates as things happen" - a project bank with progress bars (mine and Cael's),
an idea bank, the automated processes (did AFL send, did the nightly run), and
the second brain shown as a library. Design: projects/command-center-library/design.md

Data (all plain notes, edit them in Obsidian or tell Claude in chat):
  bank/projects/*.md   type: project   - lane, owner, stage, steps checklist, git hook
  bank/processes/*.md  type: process   - a scheduled task, a log, or a manual entry
  ideas/*.md           type: idea      - the idea bank (unchanged format)
  concepts/ drills/ cues/ sources/ MOC-*.md - the library shelves

Live reads: Windows Task Scheduler (one PowerShell call), git log per project,
the Command CV ledger, process logs, last-state.md. Writes ONE file:
Command-Center.html. Reuses the v1 helpers (worktree triage, last-state).

Run:  py C:\\Users\\Owner\\bsb-brain\\meta\\generate_command_center_v2.py [--open-once-daily]
Scheduled: the "BSB Command Center" task runs it with pyw.exe (no console window) every
15 min; --open-once-daily opens the page in the browser on the first run of each day only.
Headless check: open Command-Center.html?selftest=1 and read the SELFTEST console line.
"""
import csv
import datetime
import fnmatch
import glob
import hashlib
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_command_center as v1  # noqa: E402  (reuse triage + last-state helpers)

try:
    from zoneinfo import ZoneInfo
    CT = ZoneInfo("America/Chicago")
except Exception:  # no tzdata: the laptop clock is Central anyway
    CT = None

VAULT = v1.VAULT
BANK = os.path.join(VAULT, "bank")
OUT = os.path.join(VAULT, "Command-Center.html")
VAULT_NAME = os.path.basename(VAULT)
PUBLISH_REPO = r"C:\Users\Owner\pd-command-center"  # clone of zbridger_astros/pd-command-center (shared copy)
NOWIN = getattr(subprocess, "CREATE_NO_WINDOW", 0)
REFRESH_MIN = 15  # the scheduled task's repeat interval; the page reloads on this beat

STAGES = ["idea", "scoping", "building", "review", "shipped"]
LANES = [("now", "Now"), ("next", "Next"), ("later", "Later"), ("done", "Done")]

# Library shelves: note domain value -> shelf. Unlisted domains land on "Other".
SHELVES = [
    ("pitching", "Pitching", ["pitching", "pitching/philosophy"]),
    ("hitting", "Hitting", ["hitting"]),
    ("strength", "Strength", ["strength"]),
    ("body", "Body & Movement", ["anatomy-movement"]),
    ("defense", "Fielding & Baserunning", ["defense", "fielding", "baserunning", "catching"]),
    ("mental", "Mental", ["mental"]),
    ("pd", "Player Development", ["player-development", "business"]),
    ("analytics", "Analytics & Engineering",
     ["modeling", "viz", "data", "infra-scraping", "ai-tools", "ai-engineering"]),
]
LIBRARY_DIRS = [("concepts", "concept"), ("drills", "drill"), ("cues", "cue"), ("sources", "source")]
HIDDEN_SOURCE_STATUS = {"rejected", "duplicate"}


# ---------------------------------------------------------------- helpers

def now_ct():
    return datetime.datetime.now(CT) if CT else datetime.datetime.now()


def to_ct(dt):
    if dt is None:
        return None
    if CT is None:
        return dt.replace(tzinfo=None) if dt.tzinfo else dt
    if dt.tzinfo is None:
        return dt.replace(tzinfo=CT)  # naive times on this box are local = Central
    return dt.astimezone(CT)


def fmt_ct(dt):
    if dt is None:
        return ""
    dt = to_ct(dt)
    return dt.strftime("%b %d, %I:%M %p").replace(" 0", " ") + " CT"


def age_text(dt):
    if dt is None:
        return ""
    secs = (now_ct() - to_ct(dt)).total_seconds()
    if secs < 90:
        return "just now"
    mins = secs / 60
    if mins < 60:
        return f"{int(mins)}m ago"
    hrs = mins / 60
    if hrs < 36:
        return f"{int(hrs)}h ago"
    return f"{int(hrs / 24)}d ago"


def parse_dt(val):
    """Frontmatter dates arrive as str, date or datetime."""
    if val is None or val == "":
        return None
    if isinstance(val, datetime.datetime):
        return val
    if isinstance(val, datetime.date):
        return datetime.datetime(val.year, val.month, val.day)
    s = str(val).strip()
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d"):
        try:
            return datetime.datetime.strptime(s[:len(fmt) + 2].strip(), fmt)
        except ValueError:
            continue
    return None


def read_note(path, head_only=False):
    """(frontmatter dict, body). Bad YAML returns ({}, text) rather than failing the page."""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            txt = fh.read(8000) if head_only else fh.read()
    except OSError:
        return {}, ""
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n?", txt, re.S)
    if not m:
        return {}, txt
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except Exception:
        fm = {}
    return (fm if isinstance(fm, dict) else {}), txt[m.end():]


def h1(body):
    m = re.search(r"^#\s+(.+)$", body, re.M)
    return m.group(1).strip() if m else ""


def as_list(v):
    if v is None or v == "":
        return []
    return v if isinstance(v, list) else [v]


def obsidian_uri(path):
    rel = os.path.relpath(path, VAULT).replace("\\", "/")
    if rel.endswith(".md"):
        rel = rel[:-3]
    return "obsidian://open?vault=%s&file=%s" % (urllib.parse.quote(VAULT_NAME), urllib.parse.quote(rel))


def section(body, name):
    """Text under '## <name>' up to the next '## '."""
    m = re.search(rf"^##\s+{re.escape(name)}\s*$(.*?)(?=^##\s|\Z)", body, re.M | re.S | re.I)
    return m.group(1) if m else ""


def tail_lines(path, nbytes=6000):
    try:
        with open(path, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            size = fh.tell()
            fh.seek(max(0, size - nbytes))
            return fh.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return []


# ---------------------------------------------------------------- live counters

def counter_cv_season():
    """Command CV season run: games graded of games in the season pull."""
    root = r"C:\Users\Owner\bsb-resources\command-cv"
    ledger = os.path.join(root, "docs", "miss_season_ledger.csv")
    pull = os.path.join(root, "output", "season_pull_2026.csv")
    try:
        with open(ledger, encoding="utf-8", newline="") as fh:
            rows = list(csv.DictReader(fh))
        with open(pull, encoding="utf-8", newline="") as fh:
            total = sum(1 for _ in csv.DictReader(fh))
    except OSError as e:
        return {"error": f"cannot read ledger ({e.__class__.__name__})"}
    last = {}
    for r in rows:
        last[r.get("game_pk")] = r  # keep the latest grade per game
    graded = len(last)
    passed = sum(1 for r in last.values() if r.get("verdict") == "PASS")
    finished = rows[-1].get("finished_ct", "") if rows else ""
    return {"done": graded, "total": total, "unit": "games graded",
            "detail": f"{passed} PASS / {graded - passed} FAIL - last finished {finished} CT"}


COUNTERS = {"cv_season": counter_cv_season}


# ---------------------------------------------------------------- scheduled tasks

def scheduled_tasks():
    """Every Task Scheduler task with state + last run + result, one PowerShell call."""
    ps = ("Get-ScheduledTask | ForEach-Object { $i = $_ | Get-ScheduledTaskInfo; "
          "[pscustomobject]@{n=$_.TaskName; s=[string]$_.State; "
          "l=if($i.LastRunTime){$i.LastRunTime.ToString('s')}else{''}; r=$i.LastTaskResult; "
          "x=if($i.NextRunTime){$i.NextRunTime.ToString('s')}else{''}} } | ConvertTo-Json -Compress")
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True,
                             text=True, timeout=90,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0)).stdout
        data = json.loads(out) if out.strip() else []
    except Exception:
        return None  # None = could not read, distinct from "no such task"
    if isinstance(data, dict):
        data = [data]
    return {d["n"]: d for d in data}


TASK_RUNNING = 267009      # SCHED_S_TASK_RUNNING
TASK_NEVER_RAN = 267011    # SCHED_S_TASK_HAS_NOT_RUN


# ---------------------------------------------------------------- git

def git_commits(fm, n=5):
    repo = fm.get("repo")
    if not repo or not os.path.isdir(repo):
        return []
    args = ["log", f"-n{n}", "--format=%at|%h|%an|%s"]
    if fm.get("grep"):
        args += ["-i", "-E", f"--grep={fm['grep']}"]
    if fm.get("author"):
        args += [f"--author={fm['author']}"]
    if fm.get("branch"):
        args.append(str(fm["branch"]))
    paths = as_list(fm.get("paths"))
    if paths:
        args += ["--"] + [str(p) for p in paths]
    out = v1.run_git(repo, *args)
    commits = []
    for line in out.splitlines():
        parts = line.split("|", 3)
        if len(parts) == 4 and parts[0].isdigit():
            ts = datetime.datetime.fromtimestamp(int(parts[0]), CT) if CT else \
                datetime.datetime.fromtimestamp(int(parts[0]))
            commits.append({"sha": parts[1], "author": parts[2], "subj": parts[3][:110],
                            "when": fmt_ct(ts), "age": age_text(ts), "ts": int(parts[0])})
    return commits


# ---------------------------------------------------------------- projects

def load_projects():
    projects = []
    for path in sorted(glob.glob(os.path.join(BANK, "projects", "*.md"))):
        fm, body = read_note(path)
        if fm.get("type") != "project":
            continue
        steps = [{"done": m.group(1).lower() == "x", "text": m.group(2).strip()}
                 for m in re.finditer(r"^\s*-\s*\[( |x|X)\]\s+(.+)$", section(body, "Steps"), re.M)]
        stage = str(fm.get("stage") or "idea").lower()
        p = {
            "id": os.path.splitext(os.path.basename(path))[0],
            "share": bool(fm.get("share")),  # opt-in: only these go to the shared work copy
            "title": fm.get("title") or h1(body) or os.path.basename(path)[:-3],
            "lane": str(fm.get("lane") or "next").lower(),
            "owner": [str(o).lower() for o in as_list(fm.get("owner")) or ["?"]],
            "source": str(fm.get("source") or ""),
            "tag": str(fm.get("tag") or ""),
            "stage": stage,
            "status": str(fm.get("status") or "").lower(),  # paused / blocked / waiting
            "waiting_on": str(fm.get("waiting_on") or "").lower(),
            "next": str(fm.get("next") or ""),
            "due": str(fm.get("due") or ""),
            "link": str(fm.get("link") or ""),
            "steps": steps,
            "uri": obsidian_uri(path),
            "updated": fmt_ct(parse_dt(fm.get("updated"))) if fm.get("updated") else "",
            "commits": git_commits(fm),
        }
        if fm.get("counter") in COUNTERS:
            p["counter"] = COUNTERS[fm["counter"]]()
        projects.append(p)
    return projects


# ---------------------------------------------------------------- processes

def summarize_log(fm):
    log = fm.get("log")
    if not log:
        return "", None
    log = os.path.expanduser(str(log))
    if not os.path.exists(log):
        return f"log not found: {log}", None
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(log))
    lines = [l.strip() for l in tail_lines(log) if l.strip()]
    pat = fm.get("summary")
    if pat:
        lines = [l for l in lines if re.search(pat, l)]
    keep = int(fm.get("summary_lines") or 2)
    text = " | ".join(re.sub(r"^-\s*", "", l)[:140] for l in lines[-keep:])
    return text, mtime


def judge_process(fm, tasks, now):
    """-> dict(state, label, when, result). state: ok / running / late / failed / manual / none / ended."""
    expect_h = float(fm.get("expect_every_h") or 24)
    grace_h = expect_h * 0.25 + 1.0  # a daily job is "late" ~7h after it should have run
    until = parse_dt(fm.get("active_until"))
    check = str(fm.get("check") or "manual").lower()
    summary, log_mtime = summarize_log(fm)

    if until and to_ct(until) + datetime.timedelta(days=1) < now:
        return {"state": "ended", "label": f"ended {until:%b %d}", "when": "", "result": summary}

    if check == "manual":
        entered = parse_dt(fm.get("entered"))
        result = str(fm.get("result") or "")
        last_run = parse_dt(fm.get("last_run"))
        if not entered:
            return {"state": "none", "label": "no entry yet", "when": "",
                    "result": str(fm.get("how") or "tell Claude after it runs")}
        age_h = (now - to_ct(entered)).total_seconds() / 3600
        state = "late" if age_h > expect_h + grace_h else "manual"
        label = "entry is old" if state == "late" else "entered by you"
        return {"state": state, "label": label, "when": fmt_ct(last_run or entered),
                "age": age_text(last_run or entered), "result": result}

    if check == "log":
        if log_mtime is None:
            return {"state": "failed", "label": "no log", "when": "", "result": summary}
        age_h = (now - to_ct(log_mtime)).total_seconds() / 3600
        state = "late" if age_h > expect_h + grace_h else "ok"
        return {"state": state, "label": "late" if state == "late" else "ok",
                "when": fmt_ct(log_mtime), "age": age_text(log_mtime), "result": summary}

    # check == task
    if tasks is None:
        return {"state": "none", "label": "Task Scheduler unreadable", "when": "", "result": summary}
    names = as_list(fm.get("task"))
    pat = fm.get("task_glob")
    matched = [tasks[n] for n in names if n in tasks]
    if pat:
        matched += [t for n, t in tasks.items() if fnmatch.fnmatch(n, pat) and n not in names]
    if not matched:
        return {"state": "failed", "label": "task missing", "when": "", "result": summary}
    running = [t for t in matched if t.get("s") == "Running" or t.get("r") == TASK_RUNNING]
    runs = [parse_dt(t.get("l")) for t in matched if t.get("l")]
    last = max(runs) if runs else None
    bad = [t for t in matched if t.get("r") not in (0, TASK_RUNNING, TASK_NEVER_RAN, None)
           and t.get("s") != "Running"]
    extra = ""
    if pat:
        extra = f"{len(running)} of {len(matched)} running"
        summary = extra + (" | " + summary if summary else "")
    if bad:
        codes = ", ".join(sorted({f"0x{int(t['r']) & 0xFFFFFFFF:X}" for t in bad}))
        return {"state": "failed", "label": f"failed ({codes})", "when": fmt_ct(last),
                "age": age_text(last), "result": summary}
    if running:
        return {"state": "running", "label": "running", "when": fmt_ct(last), "age": age_text(last),
                "result": summary}
    if pat and fm.get("require_running"):
        return {"state": "late", "label": "none running", "when": fmt_ct(last), "age": age_text(last),
                "result": summary}
    if last is None:
        return {"state": "none", "label": "never ran", "when": "", "result": summary}
    age_h = (now - to_ct(last)).total_seconds() / 3600
    if age_h > expect_h + grace_h:
        return {"state": "late", "label": "late", "when": fmt_ct(last), "age": age_text(last),
                "result": summary}
    return {"state": "ok", "label": "ok", "when": fmt_ct(last), "age": age_text(last), "result": summary}


def load_processes(tasks):
    now = now_ct()
    procs = []
    for path in sorted(glob.glob(os.path.join(BANK, "processes", "*.md"))):
        fm, body = read_note(path)
        if fm.get("type") != "process":
            continue
        j = judge_process(fm, tasks, now)
        j.update({"title": fm.get("title") or h1(body), "where": str(fm.get("where") or ""),
                  "group": str(fm.get("group") or "Laptop"), "order": int(fm.get("order") or 50),
                  "uri": obsidian_uri(path), "schedule": str(fm.get("schedule") or "")})
        procs.append(j)
    procs.sort(key=lambda p: (p["group"] != "Laptop", p["order"], p["title"]))
    return procs


# ---------------------------------------------------------------- ideas + research

def load_ideas():
    ideas = []
    for path in glob.glob(os.path.join(VAULT, "ideas", "*.md")):
        fm, body = read_note(path, head_only=True)
        if fm.get("type") != "idea":
            continue
        created = parse_dt(fm.get("created"))
        if not created:
            created = datetime.datetime.fromtimestamp(os.path.getmtime(path))
        ideas.append({
            "title": h1(body) or os.path.basename(path)[:-3],
            "status": str(fm.get("status") or "backlog"),
            "domain": str(fm.get("domain") or ""),
            "source": str(fm.get("source") or "unlabeled"),
            "owner": str(fm.get("owner") or ""),
            "effort": str(fm.get("effort") or ""),
            "link": str(fm.get("link") or ""),
            "created": created.strftime("%Y-%m-%d"),
            "uri": obsidian_uri(path),
        })
    ideas.sort(key=lambda i: i["created"], reverse=True)
    return ideas


def load_research(days=60):
    cutoff = datetime.datetime.now() - datetime.timedelta(days=days)
    out = []
    for folder in ("meta", "projects"):
        for path in glob.glob(os.path.join(VAULT, folder, "*.md")):
            fm, body = read_note(path, head_only=True)
            if str(fm.get("type", "")).lower() not in ("research", "meta"):
                continue
            created = parse_dt(fm.get("created") or fm.get("date"))
            if not created or created < cutoff:
                continue
            out.append({"title": h1(body) or os.path.basename(path)[:-3],
                        "created": created.strftime("%Y-%m-%d"), "folder": folder,
                        "topic": str(fm.get("topic") or fm.get("project") or ""),
                        "uri": obsidian_uri(path)})
    out.sort(key=lambda r: r["created"], reverse=True)
    return out[:14]


# ---------------------------------------------------------------- library

def shelf_of(domain):
    d = str(domain or "").lower()
    for key, _, members in SHELVES:
        if d in members:
            return key
    if d.startswith("engineering"):
        return "analytics"
    return "other"


def load_library():
    items = []
    for folder, kind in LIBRARY_DIRS:
        for path in glob.glob(os.path.join(VAULT, folder, "**", "*.md"), recursive=True):
            if os.sep + "_raw" in path or os.sep + "_assets" in path:
                continue
            fm, body = read_note(path, head_only=True)
            status = str(fm.get("status") or "").lower()
            if kind == "source" and status in HIDDEN_SOURCE_STATUS:
                continue
            title = fm.get("title") or fm.get("name") or fm.get("phrase") or h1(body) \
                or os.path.basename(path)[:-3].replace("-", " ").capitalize()
            created = parse_dt(fm.get("created") or fm.get("published"))
            added = datetime.datetime.fromtimestamp(os.path.getmtime(path))
            items.append({"t": str(title)[:120], "k": kind,
                          "s": sorted({shelf_of(d) for d in (as_list(fm.get("domain")) or [None])}),
                          "low": kind == "source" and status == "auto-low",
                          "pend": status == "pending",
                          "c": (created or added).strftime("%Y-%m-%d"),
                          "a": added.strftime("%Y-%m-%d %H:%M"),
                          "u": obsidian_uri(path)})
    for path in glob.glob(os.path.join(VAULT, "MOC-*.md")):
        fm, body = read_note(path, head_only=True)
        items.append({"t": h1(body) or os.path.basename(path)[:-3], "k": "moc",
                      "s": [shelf_of(fm.get("domain"))], "low": False, "pend": False,
                      "c": str(fm.get("created") or ""), "a": "", "u": obsidian_uri(path)})
    return items


# ---------------------------------------------------------------- build

def build():
    t0 = datetime.datetime.now()
    tasks = scheduled_tasks()
    projects = load_projects()
    processes = load_processes(tasks)
    ideas = load_ideas()
    research = load_research()
    library = load_library()

    wt_infos = [(name, v1.git_info(path, expect)) for name, path, expect in v1.WORKTREES]
    has_daily = os.path.exists(os.path.join(VAULT, "05-daily", f"{datetime.date.today():%Y-%m-%d}.md"))
    inbox = len(glob.glob(os.path.join(VAULT, "00-inbox", "*.md")))
    attn, chronic = v1.attention_items(wt_infos, inbox, has_daily)
    last = v1.parse_last_state() or {}

    week_ago = (datetime.date.today() - datetime.timedelta(days=7)).strftime("%Y-%m-%d")
    data = {
        "generated": fmt_ct(now_ct()),
        "refresh_min": REFRESH_MIN,
        "today": {"title": last.get("title", ""), "next": last.get("next", ""),
                  "age": f"{last.get('age_h', 0):.0f}h ago" if last else ""},
        "attention": [{"sev": s, "html": h} for s, h in attn],
        "chronic": chronic,
        "projects": projects,
        "processes": processes,
        "ideas": ideas,
        "ideas_new": sum(1 for i in ideas if i["created"] >= week_ago),
        "research": research,
        "library": library,
        "shelves": [{"key": k, "name": n} for k, n, _ in SHELVES] + [{"key": "other", "name": "Other"}],
        "stages": STAGES,
        "lanes": [{"key": k, "name": n} for k, n in LANES],
        "tasks_ok": tasks is not None,
    }
    write_page(data, OUT)
    secs = (datetime.datetime.now() - t0).total_seconds()
    states = {}
    for p in processes:
        states[p["state"]] = states.get(p["state"], 0) + 1
    print(f"wrote {OUT} in {secs:.1f}s: {len(projects)} projects, {len(processes)} processes {states}, "
          f"{len(ideas)} ideas, {len(library)} library notes, {len(attn)} attention items")
    return data


def write_page(data, out):
    blob = json.dumps(data, ensure_ascii=False, default=str).replace("</", "<\\/")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(TEMPLATE.replace("__DATA__", blob))


def shared_view(data):
    """The copy Cael sees (Zac, Oct 15): projects marked share: true + the idea bank. No library,
    processes, research, last-state or git triage, and no obsidian:// links (they only open here)."""
    d = dict(data)
    d["projects"] = [dict(p, uri="") for p in data["projects"] if p.get("share")]
    d["ideas"] = [dict(i, uri=i["link"] if i["link"].startswith("http") else "") for i in data["ideas"]]
    d.update(shared=True, today={}, attention=[], chronic=0, processes=[], research=[], library=[], tasks_ok=True)
    return d


def _fingerprint(d, with_counters):
    core = {"p": [[p["id"], p["title"], p["lane"], p["owner"], p["stage"], p["status"], p["waiting_on"], p["next"],
                   p["due"], p["tag"], [[s["done"], s["text"]] for s in p["steps"]], [c["sha"] for c in p["commits"]],
                   (p.get("counter") or {}).get("done") if with_counters else None] for p in d["projects"]],
            "i": [[i["title"], i["status"], i["source"], i["created"]] for i in d["ideas"]],
            "tpl": hashlib.sha1(TEMPLATE.encode("utf-8")).hexdigest()}  # a page-code change publishes too
    return hashlib.sha1(json.dumps(core, sort_keys=True, default=str).encode("utf-8")).hexdigest()


def publish(data, min_gap_min=60):
    """Write the shared page into the pd-command-center clone and push it when it changed.
    A structural change (steps, lanes, commits, ideas) pushes right away; a live counter alone
    (Command CV games graded) pushes at most once an hour, so the repo is not one commit per game."""
    if not os.path.isdir(os.path.join(PUBLISH_REPO, ".git")):
        print(f"publish: no clone at {PUBLISH_REPO}")
        return
    d = shared_view(data)
    state_p = os.path.join(PUBLISH_REPO, "publish_state.json")  # gitignored
    try:
        with open(state_p, encoding="utf-8") as fh:
            state = json.load(fh)
    except (OSError, ValueError):
        state = {}
    fp, full = _fingerprint(d, False), _fingerprint(d, True)
    age_min = (time.time() - state.get("at", 0)) / 60
    if fp == state.get("fp") and (full == state.get("full") or age_min < min_gap_min):
        print("publish: no change")
        return
    os.makedirs(os.path.join(PUBLISH_REPO, "site"), exist_ok=True)
    write_page(d, os.path.join(PUBLISH_REPO, "site", "index.html"))

    def g(*a):
        return subprocess.run(["git", "-C", PUBLISH_REPO] + list(a), capture_output=True, text=True,
                              timeout=120, creationflags=NOWIN)
    g("add", "site/index.html")
    r = g("commit", "-m", "publish: " + data["generated"])
    if r.returncode != 0:
        print("publish: nothing committed", (r.stdout + r.stderr)[-200:])
        return
    r = g("push", "-q", "origin", "HEAD")
    if r.returncode != 0:
        print("publish: PUSH FAILED", r.stderr[-300:])  # state not saved, so the next run retries
        return
    with open(state_p, "w", encoding="utf-8") as fh:
        json.dump({"fp": fp, "full": full, "at": time.time()}, fh)
    print(f"publish: pushed {len(d['projects'])} projects, {len(d['ideas'])} ideas")


TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Baseball Command Center</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Space+Grotesk:wght@500;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
:root{
  --bg:#050913; --bg2:#0a1428; --panel:rgba(16,28,54,.62); --panel2:rgba(22,38,72,.55);
  --line:rgba(130,170,230,.14); --line2:rgba(130,170,230,.26);
  --ink:#e6edf7; --ink2:#9fb0c8; --ink3:#66788f;
  --orange:#EB6E1F; --orange2:#ff9b52; --navy:#002D62; --navy2:#1d4f91;
  --ok:#3ddc97; --run:#4cc9f0; --late:#f2b84b; --bad:#ff5c6c; --muted:#6b7a90;
  --zac:#EB6E1F; --cael:#4cc9f0; --both:#a78bfa;
}
*{box-sizing:border-box}
html,body{margin:0}
html{background:#050913}
body{background:
  radial-gradient(1200px 700px at 85% -10%, rgba(29,79,145,.38), transparent 60%),
  radial-gradient(900px 600px at -10% 110%, rgba(235,110,31,.10), transparent 60%),
  linear-gradient(180deg,var(--bg2),var(--bg) 55%);
  background-attachment:fixed; color:var(--ink);
  font:14px/1.5 Inter,system-ui,-apple-system,"Segoe UI",sans-serif; min-height:100vh}
body:before{content:"";position:fixed;inset:0;pointer-events:none;
  background-image:linear-gradient(rgba(130,170,230,.035) 1px,transparent 1px),
  linear-gradient(90deg,rgba(130,170,230,.035) 1px,transparent 1px);background-size:44px 44px}
.wrap{max-width:1500px;margin:0 auto;padding:22px 28px 60px;position:relative}
.mono{font-family:"JetBrains Mono",ui-monospace,Consolas,monospace}
a{color:inherit}
/* header */
.top{display:flex;align-items:center;gap:18px;flex-wrap:wrap;margin-bottom:18px}
.brand{display:flex;align-items:center;gap:12px}
.mark{width:38px;height:38px;border-radius:11px;display:grid;place-items:center;
  background:linear-gradient(135deg,var(--navy2),var(--navy));border:1px solid var(--line2);
  box-shadow:0 0 24px rgba(235,110,31,.25) inset}
.mark span{width:12px;height:12px;border-radius:50%;background:var(--orange);box-shadow:0 0 14px var(--orange)}
.brand h1{font:600 18px "Space Grotesk",Inter,sans-serif;letter-spacing:.14em;margin:0;text-transform:uppercase}
.brand small{display:block;color:var(--ink3);font-size:11px;letter-spacing:.18em;text-transform:uppercase}
.tabs{display:flex;gap:4px;padding:4px;border-radius:12px;background:var(--panel);border:1px solid var(--line)}
.tab{border:0;background:none;color:var(--ink2);font:600 13px Inter,sans-serif;padding:7px 16px;border-radius:9px;cursor:pointer}
.tab.on{background:linear-gradient(135deg,rgba(235,110,31,.95),rgba(235,110,31,.75));color:#fff;box-shadow:0 4px 18px rgba(235,110,31,.35)}
.stamp{margin-left:auto;text-align:right;color:var(--ink3);font-size:12px}
.stamp b{color:var(--ink2);font-weight:600}
/* panels */
.panel{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:18px 20px;
  backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px);box-shadow:0 10px 40px rgba(0,0,0,.25)}
.ph{display:flex;align-items:baseline;gap:10px;margin:0 0 14px}
.ph h2{font:600 13px "Space Grotesk",Inter,sans-serif;letter-spacing:.16em;text-transform:uppercase;margin:0;color:var(--ink)}
.ph .sub{color:var(--ink3);font-size:12px}
.ph .right{margin-left:auto}
/* strip */
.strip{display:grid;grid-template-columns:minmax(0,2.2fr) repeat(4,minmax(0,1fr));gap:14px;margin-bottom:18px}
.next .lbl{font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--orange2);font-weight:600}
.next .txt{margin-top:6px;color:var(--ink);font-size:13.5px;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.next .meta{margin-top:6px;color:var(--ink3);font-size:11.5px}
.kpi .n{font:600 30px "Space Grotesk",Inter,sans-serif;line-height:1.1}
.kpi .l{color:var(--ink2);font-size:12px;margin-top:2px}
.kpi .s{color:var(--ink3);font-size:11.5px;margin-top:4px}
.kpi.warn .n{color:var(--late)} .kpi.bad .n{color:var(--bad)} .kpi.good .n{color:var(--ok)}
/* layout */
.grid{display:grid;grid-template-columns:minmax(0,2.15fr) minmax(320px,1fr);gap:18px;align-items:start}
.lane{margin-bottom:18px}
.lane:last-child{margin-bottom:0}
.lane h3{display:flex;align-items:center;gap:8px;font:600 12px Inter,sans-serif;letter-spacing:.14em;text-transform:uppercase;color:var(--ink2);margin:0 0 10px}
.lane h3 .c{color:var(--ink3);font-weight:500}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(300px,100%),1fr));gap:12px}
.card{min-width:0;background:var(--panel2);border:1px solid var(--line);border-radius:14px;padding:14px 15px;cursor:pointer;transition:border-color .15s,transform .15s}
.card:hover{border-color:var(--line2);transform:translateY(-1px)}
.card.open{border-color:rgba(235,110,31,.55);grid-column:1/-1}
.ct{display:flex;align-items:flex-start;gap:10px}
.ct .title{font-weight:600;font-size:14.5px;line-height:1.3;flex:1}
.av{display:flex}
.av span{width:24px;height:24px;border-radius:50%;display:grid;place-items:center;font:700 11px Inter,sans-serif;color:#05101f;margin-left:-6px;border:2px solid #0d1830}
.av span:first-child{margin-left:0}
.chips{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0 10px}
.chip{font-size:11px;padding:2px 8px;border-radius:999px;border:1px solid var(--line2);color:var(--ink2);background:rgba(255,255,255,.03)}
.chip.tag{border-color:rgba(235,110,31,.45);color:var(--orange2)}
.chip.st-paused,.chip.st-waiting{border-color:rgba(242,184,75,.5);color:var(--late)}
.chip.st-blocked{border-color:rgba(255,92,108,.5);color:var(--bad)}
.chip.due{border-color:rgba(255,92,108,.45);color:#ff9aa4}
.bar{height:8px;border-radius:99px;background:rgba(255,255,255,.07);overflow:hidden}
.bar i{display:block;height:100%;border-radius:99px;background:linear-gradient(90deg,var(--orange),var(--orange2));box-shadow:0 0 12px rgba(235,110,31,.55)}
.barl{display:flex;justify-content:space-between;color:var(--ink3);font-size:11.5px;margin-top:5px}
.barl b{color:var(--ink2);font-weight:600}
.stg{display:grid;grid-template-columns:repeat(5,1fr);gap:4px}
.stg i{height:8px;border-radius:99px;background:rgba(255,255,255,.07)}
.stg i.on{background:linear-gradient(90deg,var(--navy2),#4f86d1)}
.stg i.cur{background:linear-gradient(90deg,var(--orange),var(--orange2));box-shadow:0 0 10px rgba(235,110,31,.5)}
.nx{margin-top:9px;font-size:12.5px;color:var(--ink2)}
.nx b{color:var(--ink);font-weight:600}
.lt{margin-top:7px;font-size:11.5px;color:var(--ink3);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.drawer{display:none;margin-top:12px;padding-top:12px;border-top:1px solid var(--line)}
.card.open .drawer{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.drawer h4{margin:0 0 6px;font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--ink3)}
.steps{list-style:none;margin:0;padding:0}
.steps li{display:flex;gap:8px;padding:3px 0;font-size:12.5px;color:var(--ink2)}
.steps li .bx{flex:none;width:15px;height:15px;border-radius:4px;border:1.5px solid var(--line2);margin-top:2px}
.steps li.d{color:var(--ink3);text-decoration:line-through}
.steps li.d .bx{background:var(--orange);border-color:var(--orange)}
.cm{font-size:12px;color:var(--ink2);padding:3px 0;display:flex;gap:8px}
.cm .mono{color:var(--orange2);font-size:11.5px}
.cm .a{color:var(--ink3);white-space:nowrap}
.dl{margin-top:10px;font-size:12px;color:var(--ink3);word-break:break-all}
.dl a{color:var(--run)}
.compact .card{padding:10px 13px}
.compact .chips{margin:6px 0 0}
/* processes */
.pgrp{font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--ink3);margin:14px 0 6px}
.pgrp:first-of-type{margin-top:0}
.proc{display:grid;grid-template-columns:12px 1fr auto;gap:10px;align-items:start;padding:10px 0;border-top:1px solid var(--line)}
.proc:first-of-type{border-top:0}
.dot{width:10px;height:10px;border-radius:50%;margin-top:5px}
.s-ok .dot{background:var(--ok);box-shadow:0 0 10px var(--ok)}
.s-running .dot{background:var(--run);box-shadow:0 0 10px var(--run);animation:pulse 1.6s infinite}
.s-late .dot{background:var(--late);box-shadow:0 0 10px var(--late)}
.s-failed .dot{background:var(--bad);box-shadow:0 0 10px var(--bad)}
.s-manual .dot{background:#8fa3bf}
.s-none .dot,.s-ended .dot{background:transparent;border:1.5px solid var(--muted)}
@keyframes pulse{50%{opacity:.35}}
.proc .nm{font-weight:600;font-size:13px}
.proc .rs{font-size:12px;color:var(--ink2);margin-top:2px;word-break:break-word}
.proc .wh{font-size:11.5px;color:var(--ink3);margin-top:2px}
.proc .lb{font-size:11px;font-weight:600;padding:2px 8px;border-radius:99px;white-space:nowrap;border:1px solid var(--line2);color:var(--ink2)}
.s-ok .lb{color:var(--ok);border-color:rgba(61,220,151,.4)}
.s-running .lb{color:var(--run);border-color:rgba(76,201,240,.4)}
.s-late .lb{color:var(--late);border-color:rgba(242,184,75,.45)}
.s-failed .lb{color:var(--bad);border-color:rgba(255,92,108,.45)}
.attn{margin-top:18px}
.attn li{font-size:12.5px;color:var(--ink2);padding:4px 0;list-style:none}
.attn ul{margin:0;padding:0}
.attn .sev2{color:#ffb38a}
/* ideas */
.ideas{margin-top:18px}
.filters{display:flex;flex-wrap:wrap;gap:6px;align-items:center}
.fbtn{font:500 12px Inter,sans-serif;padding:4px 11px;border-radius:999px;border:1px solid var(--line2);background:rgba(255,255,255,.03);color:var(--ink2);cursor:pointer}
.fbtn.on{background:rgba(235,110,31,.18);border-color:rgba(235,110,31,.6);color:#ffd2b5}
.search{flex:1;min-width:200px;max-width:320px;margin-left:auto;background:rgba(0,0,0,.25);border:1px solid var(--line2);border-radius:10px;color:var(--ink);padding:7px 12px;font:13px Inter,sans-serif;outline:none}
.search:focus{border-color:rgba(235,110,31,.6)}
.igrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(250px,100%),1fr));gap:10px;margin-top:14px}
.idea{display:block;text-decoration:none;background:var(--panel2);border:1px solid var(--line);border-radius:12px;padding:11px 13px}
.idea:hover{border-color:var(--line2)}
.idea .t{font-weight:600;font-size:13px;line-height:1.35}
.idea .m{display:flex;flex-wrap:wrap;gap:6px;margin-top:7px}
.idea .new{color:var(--orange2);font-size:10.5px;font-weight:700;letter-spacing:.1em}
.empty{color:var(--ink3);font-size:12.5px;padding:8px 0}
/* library */
.lib{display:none}
.libtop{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:14px;align-items:center;margin-bottom:16px}
.libsearch{width:100%;background:rgba(0,0,0,.28);border:1px solid var(--line2);border-radius:14px;color:var(--ink);padding:14px 18px;font:15px Inter,sans-serif;outline:none}
.libsearch:focus{border-color:rgba(235,110,31,.6);box-shadow:0 0 0 4px rgba(235,110,31,.12)}
.libstat{color:var(--ink3);font-size:12px;text-align:right}
.libstat b{color:var(--ink);font:600 22px "Space Grotesk",Inter,sans-serif;display:block}
.shelves{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(230px,100%),1fr));gap:12px}
.shelf{background:var(--panel2);border:1px solid var(--line);border-radius:14px;padding:14px;cursor:pointer;position:relative;overflow:hidden}
.shelf:hover,.shelf.on{border-color:rgba(235,110,31,.55)}
.shelf:after{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:linear-gradient(var(--orange),transparent)}
.shelf .nm{font:600 15px "Space Grotesk",Inter,sans-serif}
.shelf .tot{font:600 26px "Space Grotesk",Inter,sans-serif;margin-top:4px}
.shelf .br{display:flex;flex-wrap:wrap;gap:6px;margin-top:6px}
.libgrid{display:grid;grid-template-columns:minmax(0,1.6fr) minmax(300px,1fr);gap:18px;margin-top:18px;align-items:start}
.row{display:flex;gap:10px;align-items:baseline;padding:7px 0;border-top:1px solid var(--line);text-decoration:none}
.row:first-child{border-top:0}
.row .k{flex:none;font-size:10.5px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;width:62px}
.k-concept{color:#a78bfa}.k-drill{color:var(--ok)}.k-cue{color:var(--run)}.k-source{color:var(--orange2)}.k-moc{color:#f472b6}
.row .t{flex:1;font-size:13px;color:var(--ink)}
.row .d{flex:none;color:var(--ink3);font-size:11.5px}
.row:hover .t{color:#ffd2b5}
/* world */
.worldsec{display:none;position:relative}
#world{position:relative;height:calc(100vh - 110px);min-height:560px;border-radius:20px;overflow:hidden;border:1px solid var(--line);background:#0a1630}
#world canvas{display:block;outline:none}
#wlabels{position:absolute;inset:0;pointer-events:none;overflow:hidden}
.wl{position:absolute;transform:translate(-50%,-100%);white-space:nowrap;pointer-events:auto;cursor:pointer;font:600 12px Inter,sans-serif;color:#fff;background:rgba(8,14,28,.84);border:1px solid rgba(255,255,255,.16);padding:4px 11px 4px 8px;border-radius:999px;display:flex;gap:7px;align-items:center;box-shadow:0 4px 14px rgba(0,0,0,.45)}
.wl i{width:8px;height:8px;border-radius:50%;background:var(--orange);box-shadow:0 0 8px var(--orange)}
.wl.big{font:600 13.5px "Space Grotesk",Inter,sans-serif;padding:6px 13px 6px 10px;letter-spacing:.02em}
.wl.small{font-size:11px;padding:2px 9px 2px 7px;background:rgba(8,14,28,.72)}
.wl.small i{width:6px;height:6px}
.wb{position:absolute;transform:translate(-50%,-100%);pointer-events:auto;cursor:pointer;background:#fff;color:#14203a;font:700 11.5px Inter,sans-serif;padding:3px 9px;border-radius:10px;white-space:nowrap;box-shadow:0 3px 10px rgba(0,0,0,.35)}
.wb:after{content:"";position:absolute;left:50%;bottom:-5px;margin-left:-5px;border:5px solid transparent;border-top-color:#fff;border-bottom:0}
.wb em{font-style:normal;color:var(--orange)}
.wtip{position:absolute;display:none;pointer-events:none;background:#fff;color:#14203a;border-radius:14px;padding:11px 14px;min-width:230px;max-width:320px;box-shadow:0 12px 34px rgba(0,0,0,.5);font-size:12.5px;z-index:5}
.wtip .h{font:700 15px "Space Grotesk",Inter,sans-serif;line-height:1.25}
.wtip .s{color:#4a5872;margin-top:3px}
.wtip .c{color:var(--orange);font-weight:700;margin-top:7px}
.wtip .pb{height:6px;border-radius:9px;background:#e6ebf3;margin-top:7px;overflow:hidden}
.wtip .pb i{display:block;height:100%;background:linear-gradient(90deg,var(--orange),var(--orange2))}
.wtoast{position:absolute;right:16px;top:64px;display:none;pointer-events:none;background:rgba(10,16,30,.93);border:1px solid rgba(255,255,255,.16);border-radius:12px;padding:10px 13px;color:#fff;min-width:240px;max-width:320px;box-shadow:0 10px 26px rgba(0,0,0,.5);z-index:4}
.wtoast .t{color:var(--orange2);font:700 14px "Space Grotesk",Inter,sans-serif}
.wtoast .sj{font-size:12px;color:var(--ink2);margin-top:3px}
.wtoast .r{display:flex;gap:18px;margin-top:7px;font-size:10px;letter-spacing:.12em;color:var(--ink3);text-transform:uppercase}
.wtoast .r b{display:block;color:#fff;font:600 12.5px "JetBrains Mono",monospace;letter-spacing:0;text-transform:none}
.whud{position:absolute;left:16px;bottom:16px;background:rgba(8,14,28,.72);border:1px solid var(--line2);border-radius:14px;padding:12px 14px;backdrop-filter:blur(8px);max-width:330px;pointer-events:none}
.whud .wt{font:600 13px "Space Grotesk",Inter,sans-serif;letter-spacing:.16em;text-transform:uppercase;margin-bottom:6px}
.whud .wk{display:flex;gap:8px;align-items:center;font-size:11.5px;color:var(--ink2);margin-top:3px}
.whud .wk i{flex:none;width:8px;height:8px;border-radius:2px}
.whud .wk.dim{color:var(--ink3);margin-top:7px}
.wbtn{font:600 12px Inter,sans-serif;color:var(--ink);background:rgba(8,14,28,.8);border:1px solid var(--line2);border-radius:10px;padding:7px 12px;cursor:pointer}
.wbtn:hover{border-color:rgba(235,110,31,.6)}
#wreset{position:absolute;right:16px;top:16px}
.wfallback{display:none;position:absolute;inset:0;place-items:center;text-align:center;padding:40px;color:var(--ink2)}
.wdrawer{position:fixed;top:0;right:0;height:100vh;width:min(600px,100vw);transform:translateX(105%);transition:transform .25s ease;background:rgba(9,16,32,.97);border-left:1px solid var(--line2);z-index:50;overflow:auto;padding:22px 22px 40px;box-shadow:-20px 0 50px rgba(0,0,0,.45)}
.wdrawer.on{transform:none}
.wclose{float:right}
.wdrawer h2{font:600 18px "Space Grotesk",Inter,sans-serif;margin:4px 0 4px}
.wdrawer .ds{color:var(--ink3);font-size:12.5px;margin-bottom:14px}
.wdrawer .card{cursor:default}
.wdrawer .card:hover{transform:none}
.wdrawer .card.open .drawer{grid-template-columns:1fr}
.wdrawer .cm{flex-wrap:wrap}
body.worldmode .wrap{padding:14px 16px}
body.worldmode #world{height:calc(100vh - 28px);min-height:600px}
body.worldmode .top{position:absolute;z-index:6;top:28px;left:30px;right:30px;margin:0;pointer-events:none}
body.worldmode .top > *{pointer-events:auto}
body.worldmode .brand{background:rgba(8,14,28,.72);border:1px solid var(--line2);border-radius:14px;padding:7px 15px 7px 8px;backdrop-filter:blur(8px)}
body.worldmode .stamp{background:rgba(8,14,28,.72);border:1px solid var(--line2);border-radius:12px;padding:6px 12px;backdrop-filter:blur(8px)}
body.worldmode .tabs{background:rgba(8,14,28,.72);backdrop-filter:blur(8px)}
body.worldmode #wreset{top:auto;bottom:16px}
body.worldmode .wtoast{top:96px}
.grid.solo{grid-template-columns:minmax(0,1fr)}
body.shared .local-only{display:none}
@media (max-width:1100px){.grid,.libgrid{grid-template-columns:minmax(0,1fr)}.strip{grid-template-columns:minmax(0,1fr) minmax(0,1fr)}.next{grid-column:1/-1}}
@media (max-width:640px){.wrap{padding:16px}.panel{padding:14px}.strip{grid-template-columns:minmax(0,1fr)}.card.open .drawer{grid-template-columns:1fr}.stamp{margin-left:0;text-align:left}}
</style></head>
<body><div class="wrap">
<div class="top">
  <div class="brand"><div class="mark"><span></span></div>
    <div><h1>Baseball Command Center</h1><small>Projects &middot; Processes &middot; Ideas &middot; Library</small></div></div>
  <div class="tabs"><button class="tab on" data-tab="world">World</button><button class="tab" data-tab="cmd">Command</button><button class="tab" data-tab="lib">Library</button></div>
  <div class="stamp">Updated <b id="gen"></b><br>refreshes every <span id="rf"></span> min</div>
</div>

<section id="sec-world" class="worldsec">
  <div id="world">
    <div id="wlabels"></div>
    <div id="wtoast" class="wtoast"></div>
    <div id="wtip" class="wtip"></div>
    <div class="whud">
      <div class="wt">PD Campus</div>
      <div class="wk"><i style="background:var(--orange)"></i>Project Yard: lit floors = progress, orange frame = still to build</div>
      <div class="wk local-only"><i style="background:#ffd38a"></i>Library towers: one per shelf, lit windows = notes</div>
      <div class="wk local-only"><i style="background:var(--ok)"></i>Scoreboard = automated jobs &middot; Port = research batches</div>
      <div class="wk dim">drag to pan &middot; scroll to zoom &middot; right-drag to turn &middot; click anything</div>
    </div>
    <button id="wreset" class="wbtn">Reset view</button>
    <div id="wfallback" class="wfallback">The 3D campus needs WebGL and an internet connection (three.js loads from cdnjs). The Command and Library tabs work offline.</div>
  </div>
  <aside id="wdrawer" class="wdrawer"><button id="wclose" class="wbtn wclose">Close</button><div id="wbody"></div></aside>
</section>

<section id="sec-cmd">
  <div class="strip" id="strip"></div>
  <div class="grid">
    <div class="panel"><div class="ph"><h2>Project Bank</h2><span class="sub" id="psub"></span></div><div id="lanes"></div></div>
    <div>
      <div class="panel"><div class="ph"><h2>Processes</h2><span class="sub" id="prsub"></span></div><div id="procs"></div></div>
      <div class="panel attn"><div class="ph"><h2>Needs Attention</h2><span class="sub" id="atsub"></span></div><ul id="attn"></ul></div>
    </div>
  </div>
  <div class="panel ideas">
    <div class="ph"><h2>Idea Bank</h2><span class="sub" id="isub"></span></div>
    <div class="filters" id="ifilters"></div>
    <div class="igrid" id="igrid"></div>
  </div>
</section>

<section id="sec-lib" class="lib">
  <div class="libtop">
    <input class="libsearch" id="lq" placeholder="Search the library: drills, cues, concepts, sources..." autocomplete="off">
    <div class="libstat"><b id="ltot"></b>notes on the shelves</div>
  </div>
  <div class="filters" id="lkinds" style="margin-bottom:14px"></div>
  <div class="shelves" id="shelves"></div>
  <div class="libgrid">
    <div class="panel"><div class="ph"><h2 id="lh">Recently Added</h2><span class="sub" id="lsub"></span></div><div id="lrows"></div></div>
    <div class="panel"><div class="ph"><h2>Research Inbox</h2><span class="sub">captured link batches + research notes</span></div><div id="rrows"></div></div>
  </div>
</section>
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script id="data" type="application/json">__DATA__</script>
<script>
const D = JSON.parse(document.getElementById('data').textContent);
const $ = s => document.querySelector(s);
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function ago(ts){ if (!ts) return ''; const s = Date.now() / 1000 - ts; if (s < 90) return 'just now'; const m = s / 60; if (m < 60) return Math.floor(m) + 'm ago';
  const h = m / 60; return h < 36 ? Math.floor(h) + 'h ago' : Math.floor(h / 24) + 'd ago'; }
const OWN = {zac:['Z','var(--zac)','Zac'], cael:['C','var(--cael)','Cael'], both:['B','var(--both)','Both']};
$('#gen').textContent = D.generated; $('#rf').textContent = D.refresh_min;

/* ---------- tabs (remembered in the URL hash so the auto-reload keeps your tab) */
const HASH = {world: '#campus', cmd: '#command', lib: '#library'};
function showTab(t){ document.querySelectorAll('.tab').forEach(b => b.classList.toggle('on', b.dataset.tab === t));
  $('#sec-world').style.display = t === 'world' ? 'block' : 'none'; document.body.classList.toggle('worldmode', t === 'world');
  $('#sec-cmd').style.display = t === 'cmd' ? '' : 'none'; $('#sec-lib').style.display = t === 'lib' ? 'block' : 'none';
  history.replaceState(null, '', HASH[t]); window.scrollTo(0, 0);
  if (t === 'world' && window.worldShown) window.worldShown(); }
document.querySelectorAll('.tab').forEach(b => b.onclick = () => showTab(b.dataset.tab));
const START_TAB = location.hash === '#library' ? 'lib' : location.hash === '#command' ? 'cmd' : 'world';
setTimeout(() => location.reload(), D.refresh_min * 60 * 1000);

/* ---------- strip */
const P = D.projects, PR = D.processes;
const active = P.filter(p => p.lane === 'now' || p.lane === 'next');
const waiting = P.filter(p => p.waiting_on === 'zac' && p.lane !== 'done');
const bad = PR.filter(p => p.state === 'failed').length, late = PR.filter(p => p.state === 'late').length;
const okish = PR.filter(p => ['ok','running','manual'].includes(p.state)).length;
const needs = waiting.length + bad + late + D.attention.filter(a => a.sev >= 1).length;
$('#strip').innerHTML = `
 <div class="panel next"><div class="lbl">Next up</div><div class="txt">${esc(D.today.next || 'No last-state yet - run /wrap at the end of a session')}</div>
   <div class="meta">${esc(D.today.title)}${D.today.age ? ' &middot; written ' + esc(D.today.age) : ''}</div></div>
 <div class="panel kpi"><div class="n">${P.filter(p => p.lane === 'now').length}</div><div class="l">Projects in Now</div><div class="s">${active.length} active incl. Next</div></div>
 <div class="panel kpi ${needs ? 'warn' : 'good'}"><div class="n">${needs}</div><div class="l">Need you</div><div class="s">${waiting.length} waiting on you &middot; ${bad + late} process alerts</div></div>
 <div class="panel kpi ${bad ? 'bad' : late ? 'warn' : 'good'}"><div class="n">${okish}<span style="font-size:16px;color:var(--ink3)"> / ${PR.length}</span></div><div class="l">Processes OK</div><div class="s">${bad} failed &middot; ${late} late${D.tasks_ok ? '' : ' &middot; Task Scheduler unreadable'}</div></div>
 <div class="panel kpi"><div class="n">${D.ideas.length}</div><div class="l">Ideas banked</div><div class="s">${D.ideas_new} new this week</div></div>`;

/* ---------- project bank */
function avatars(p){ return '<div class="av">' + p.owner.map(o => { const a = OWN[o] || ['?','var(--muted)', o];
  return `<span style="background:${a[1]}" title="${esc(a[2])}">${a[0]}</span>`; }).join('') + '</div>'; }
function progress(p){
  if (p.counter && !p.counter.error && p.counter.total){ const pct = 100 * p.counter.done / p.counter.total;
    return `<div class="bar"><i style="width:${pct}%"></i></div><div class="barl"><span><b>${p.counter.done}</b> of ${p.counter.total} ${esc(p.counter.unit)}</span><span>${pct.toFixed(0)}%</span></div>`; }
  if (p.steps.length){ const d = p.steps.filter(s => s.done).length, pct = 100 * d / p.steps.length;
    return `<div class="bar"><i style="width:${pct}%"></i></div><div class="barl"><span><b>${d}</b> of ${p.steps.length} steps</span><span>${esc(p.stage)}</span></div>`; }
  const k = D.stages.indexOf(p.stage);
  return `<div class="stg">${D.stages.map((s, i) => `<i class="${i < k ? 'on' : i === k ? 'cur' : ''}" title="${s}"></i>`).join('')}</div>
    <div class="barl"><span>stage: <b>${esc(p.stage)}</b></span><span>${k < 0 ? 'stage not set' : 'no steps defined yet'}</span></div>`;
}
function card(p, compact){
  const c = p.commits[0];
  const chips = [p.tag ? `<span class="chip tag">${esc(p.tag)}</span>` : '',
    p.source && p.source !== p.tag && !p.owner.includes(p.source.toLowerCase()) ? `<span class="chip">${esc(p.source)}</span>` : '',
    p.status ? `<span class="chip st-${esc(p.status)}">${esc(p.status)}</span>` : '',
    p.waiting_on ? `<span class="chip st-waiting">waiting on ${esc(p.waiting_on)}</span>` : '',
    p.due ? `<span class="chip due">due ${esc(p.due)}</span>` : ''].join('');
  const steps = p.steps.length ? '<ul class="steps">' + p.steps.map(s => `<li class="${s.done ? 'd' : ''}"><span class="bx"></span><span>${esc(s.text)}</span></li>`).join('') + '</ul>'
    : '<div class="empty">No steps yet. Tell Claude the steps and the bar starts counting.</div>';
  const cms = p.commits.length ? p.commits.map(c => `<div class="cm"><span class="mono">${esc(c.sha)}</span><span style="flex:1">${esc(c.subj)}</span><span class="a">${esc(c.author.split(' ')[0])} &middot; ${esc(ago(c.ts))}</span></div>`).join('')
    : '<div class="empty">No commit hook on this card.</div>';
  const link = p.link ? (/^https?:/.test(p.link) ? `<a href="${esc(p.link)}" target="_blank">${esc(p.link)}</a>` : esc(p.link)) : '';
  const extra = p.counter ? (p.counter.error ? `<div class="dl">counter: ${esc(p.counter.error)}</div>` : `<div class="dl">${esc(p.counter.detail || '')}</div>`) : '';
  return `<div class="card" data-id="${esc(p.id)}">
    <div class="ct"><div class="title">${esc(p.title)}</div>${avatars(p)}</div>
    <div class="chips">${chips}</div>
    ${compact ? '' : progress(p)}
    ${p.next && !compact ? `<div class="nx"><b>Next:</b> ${esc(p.next)}</div>` : ''}
    ${c && !compact ? `<div class="lt">last touched ${esc(ago(c.ts))} &middot; ${esc(c.subj)}</div>` : ''}
    <div class="drawer"><div><h4>Steps</h4>${steps}${extra}</div>
      <div><h4>Recent commits</h4>${cms}<div class="dl">${link ? 'Link: ' + link + '<br>' : ''}${p.uri ? `<a href="${esc(p.uri)}">Open the card note in Obsidian</a>` : ''}</div></div></div>
  </div>`;
}
$('#lanes').innerHTML = D.lanes.map(l => { const ps = P.filter(p => p.lane === l.key); if (!ps.length) return '';
  const compact = l.key === 'later' || l.key === 'done';
  return `<div class="lane ${compact ? 'compact' : ''}"><h3>${l.name} <span class="c">${ps.length}</span></h3><div class="cards">${ps.map(p => card(p, compact)).join('')}</div></div>`; }).join('')
  || '<div class="empty">No project cards yet (bank/projects/).</div>';
$('#psub').textContent = `${P.length} cards`;
document.querySelectorAll('.card').forEach(el => el.addEventListener('click', e => { if (e.target.closest('a')) return; el.classList.toggle('open'); }));

/* ---------- processes */
let lastGrp = null;
$('#procs').innerHTML = PR.map(p => { const g = p.group !== lastGrp ? `<div class="pgrp">${esc(p.group)}</div>` : ''; lastGrp = p.group;
  return g + `<div class="proc s-${p.state}"><span class="dot"></span><div><div class="nm">${esc(p.title)}</div>
    ${p.result ? `<div class="rs">${esc(p.result)}</div>` : ''}
    <div class="wh">${p.when ? 'last ' + esc(p.when) + (p.age ? ' (' + esc(p.age) + ')' : '') : ''}${p.schedule ? (p.when ? ' &middot; ' : '') + esc(p.schedule) : ''}</div></div>
    <span class="lb">${esc(p.label)}</span></div>`; }).join('') || '<div class="empty">No processes yet (bank/processes/).</div>';
$('#prsub').textContent = `${okish} of ${PR.length} OK`;

/* ---------- attention */
$('#attn').innerHTML = D.attention.length ? D.attention.map(a => `<li class="sev${a.sev}">${a.html}</li>`).join('') : '<li>All clear.</li>';
$('#atsub').textContent = D.chronic ? `${D.chronic} chronic drift hidden` : '';

/* ---------- shared copy (Cael): projects + ideas only */
if (D.shared){
  document.body.classList.add('shared');
  document.querySelector('.brand small').textContent = 'Projects \u00b7 Ideas';
  $('#strip').style.gridTemplateColumns = 'repeat(3,minmax(0,1fr))';
  $('#strip').innerHTML = `
   <div class="panel kpi"><div class="n">${P.filter(p => p.lane === 'now').length}</div><div class="l">Projects in Now</div><div class="s">${P.filter(p => p.lane === 'next').length} in Next &middot; ${P.filter(p => p.lane === 'later').length} not started</div></div>
   <div class="panel kpi"><div class="n">${P.filter(p => p.owner.includes('cael')).length}</div><div class="l">Cael&#39;s projects</div><div class="s">${P.filter(p => p.owner.includes('zac')).length} Zac&#39;s</div></div>
   <div class="panel kpi"><div class="n">${D.ideas.length}</div><div class="l">Ideas banked</div><div class="s">${D.ideas_new} new this week</div></div>`;
  const lt = document.querySelector('.tab[data-tab="lib"]'); if (lt) lt.remove();
  const rc = $('#procs').closest('.panel').parentElement; if (rc) rc.remove();
  document.querySelector('#sec-cmd .grid').classList.add('solo');
}

/* ---------- idea bank */
const week = new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10);
let iSrc = 'all', iQ = '';
const srcs = ['all', ...Array.from(new Set(D.ideas.map(i => i.source)))];
function drawIdeas(){
  $('#ifilters').innerHTML = srcs.map(s => `<button class="fbtn ${s === iSrc ? 'on' : ''}" data-s="${esc(s)}">${esc(s)} ${s === 'all' ? D.ideas.length : D.ideas.filter(i => i.source === s).length}</button>`).join('')
    + `<input class="search" id="iq" placeholder="Search ideas" value="${esc(iQ)}">`;
  document.querySelectorAll('#ifilters .fbtn').forEach(b => b.onclick = () => { iSrc = b.dataset.s; drawIdeas(); });
  const q = $('#iq'); q.oninput = () => { iQ = q.value; drawGrid(); };
  drawGrid();
}
function drawGrid(){
  const q = iQ.trim().toLowerCase();
  const xs = D.ideas.filter(i => (iSrc === 'all' || i.source === iSrc) && (!q || (i.title + ' ' + i.domain + ' ' + i.source).toLowerCase().includes(q)));
  $('#igrid').innerHTML = xs.map(i => `<a class="idea" href="${esc(i.uri || 'javascript:void(0)')}">
    ${i.created >= week ? '<div class="new">NEW</div>' : ''}<div class="t">${esc(i.title)}</div>
    <div class="m"><span class="chip">${esc(i.status)}</span>${i.domain ? `<span class="chip">${esc(i.domain)}</span>` : ''}${i.source !== 'unlabeled' ? `<span class="chip tag">${esc(i.source)}</span>` : ''}${i.effort ? `<span class="chip">effort ${esc(i.effort)}</span>` : ''}</div></a>`).join('')
    || '<div class="empty">No ideas match.</div>';
}
$('#isub').textContent = `${D.ideas.length} ideas, newest first`;
drawIdeas();

/* ---------- library */
const L = D.library, KINDS = [['all','All'],['concept','Concepts'],['drill','Drills'],['cue','Cues'],['source','Sources'],['moc','Maps']];
let lShelf = null, lKind = 'all';
$('#ltot').textContent = L.length.toLocaleString();
function inScope(x){ return (!lShelf || x.s.includes(lShelf)) && (lKind === 'all' || x.k === lKind); }
function drawShelves(){
  $('#shelves').innerHTML = D.shelves.map(s => { const xs = L.filter(x => x.s.includes(s.key)); if (!xs.length) return '';
    const by = k => xs.filter(x => x.k === k).length;
    return `<div class="shelf ${lShelf === s.key ? 'on' : ''}" data-k="${s.key}"><div class="nm">${esc(s.name)}</div><div class="tot">${xs.length}</div>
      <div class="br">${['concept','drill','cue','source'].filter(k => by(k)).map(k => `<span class="chip">${by(k)} ${k}${by(k) === 1 ? '' : 's'}</span>`).join('')}</div></div>`; }).join('');
  document.querySelectorAll('.shelf').forEach(el => el.onclick = () => { lShelf = lShelf === el.dataset.k ? null : el.dataset.k; drawShelves(); drawRows(); });
  $('#lkinds').innerHTML = KINDS.map(([k, n]) => `<button class="fbtn ${k === lKind ? 'on' : ''}" data-k="${k}">${n}</button>`).join('');
  document.querySelectorAll('#lkinds .fbtn').forEach(b => b.onclick = () => { lKind = b.dataset.k; drawShelves(); drawRows(); });
}
function drawRows(){
  const q = $('#lq').value.trim().toLowerCase();
  let xs = L.filter(inScope);
  const shelfName = lShelf ? D.shelves.find(s => s.key === lShelf).name : '';
  if (q){ xs = xs.filter(x => x.t.toLowerCase().includes(q)); $('#lh').textContent = 'Search results'; }
  else { xs = xs.slice().sort((a, b) => (b.c + b.a).localeCompare(a.c + a.a)); $('#lh').textContent = 'Recently added'; }
  $('#lsub').textContent = (shelfName ? shelfName + ' &middot; ' : '').replace('&middot;', '-') + `${xs.length} notes`;
  $('#lrows').innerHTML = xs.slice(0, 60).map(x => `<a class="row" href="${esc(x.u)}"><span class="k k-${x.k}">${x.k}</span><span class="t">${esc(x.t)}</span><span class="d">${esc(x.c)}</span></a>`).join('')
    || '<div class="empty">Nothing matches.</div>';
}
$('#lq').addEventListener('input', drawRows);
drawShelves(); drawRows();
$('#rrows').innerHTML = D.research.map(r => `<a class="row" href="${esc(r.uri)}"><span class="k k-source">${esc(r.folder)}</span><span class="t">${esc(r.title)}</span><span class="d">${esc(r.created)}</span></a>`).join('')
  || '<div class="empty">No research captured in the last 60 days.</div>';

/* ================= WORLD: the isometric PD campus (three.js r128) ================= */
function pctOf(p){
  if (p.counter && !p.counter.error && p.counter.total) return p.counter.done / p.counter.total;
  if (p.steps.length) return p.steps.filter(s => s.done).length / p.steps.length;
  const k = D.stages.indexOf(p.stage); return k < 0 ? .1 : Math.max(.1, k / (D.stages.length - 1));
}
function rng(seed){ let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a;
  t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
function hashStr(s){ let h = 2166136261; for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619); return h >>> 0; }
const ownerName = o => (OWN[o] || ['?', '', o || 'unassigned'])[2];

function buildWorld(){
  const host = $('#world');
  if (typeof THREE === 'undefined' || !THREE.OrbitControls){ $('#wfallback').style.display = 'grid'; return null; }
  const T = THREE, W = () => host.clientWidth, H = () => host.clientHeight;
  const renderer = new T.WebGLRenderer({antialias: true, preserveDrawingBuffer: true});
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setSize(W(), H());
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = T.PCFSoftShadowMap;
  renderer.outputEncoding = T.sRGBEncoding;
  host.insertBefore(renderer.domElement, host.firstChild);
  const scene = new T.Scene();
  scene.background = new T.Color(0x0a1630);
  scene.fog = new T.Fog(0x0a1630, 210, 380);
  const VIEW = 60;
  const cam = new T.OrthographicCamera(-VIEW * W() / H(), VIEW * W() / H(), VIEW, -VIEW, -600, 1200);
  const HOME = {pos: new T.Vector3(100, 92, 100), target: new T.Vector3(-4, 0, -2), zoom: 1};
  cam.position.copy(HOME.pos); cam.zoom = HOME.zoom;
  const ctl = new T.OrbitControls(cam, renderer.domElement);
  ctl.enableDamping = true; ctl.dampingFactor = .08; ctl.screenSpacePanning = true;
  ctl.minZoom = .6; ctl.maxZoom = 3.5; ctl.minPolarAngle = .5; ctl.maxPolarAngle = 1.12;
  ctl.mouseButtons = {LEFT: T.MOUSE.PAN, MIDDLE: T.MOUSE.DOLLY, RIGHT: T.MOUSE.ROTATE};
  ctl.target.copy(HOME.target); ctl.update();

  scene.add(new T.HemisphereLight(0x9bb8ff, 0x0d1424, .62));
  scene.add(new T.AmbientLight(0x2c4378, .45));
  const moon = new T.DirectionalLight(0xcfe0ff, .62);
  moon.position.set(-70, 110, 50); moon.castShadow = true; moon.shadow.mapSize.set(2048, 2048);
  Object.assign(moon.shadow.camera, {left: -95, right: 95, top: 95, bottom: -95, near: 1, far: 360});
  moon.shadow.bias = -.0006; scene.add(moon);

  const mat = (c, o) => new T.MeshStandardMaterial(Object.assign({color: c, roughness: .88, metalness: 0, flatShading: true}, o || {}));
  const add = (geo, m, x, y, z, shadow) => { const me = new T.Mesh(geo, m); me.position.set(x, y, z);
    if (shadow !== false){ me.castShadow = true; me.receiveShadow = true; } scene.add(me); return me; };
  const picks = [], labels = [];
  const pick = (obj, info) => { obj.userData.pick = info; picks.push(obj); return obj; };

  /* ---------- ground */
  const water = new T.Mesh(new T.PlaneGeometry(1400, 1400), mat(0x163565, {roughness: .3, metalness: .15, flatShading: false}));
  water.rotation.x = -Math.PI / 2; water.position.y = -1.6; water.receiveShadow = true; scene.add(water);
  function rrect(x0, z0, x1, z1, r){ const s = new T.Shape(); s.moveTo(x0 + r, z0); s.lineTo(x1 - r, z0);
    s.quadraticCurveTo(x1, z0, x1, z0 + r); s.lineTo(x1, z1 - r); s.quadraticCurveTo(x1, z1, x1 - r, z1);
    s.lineTo(x0 + r, z1); s.quadraticCurveTo(x0, z1, x0, z1 - r); s.lineTo(x0, z0 + r); s.quadraticCurveTo(x0, z0, x0 + r, z0); return s; }
  function slab(x0, z0, x1, z1, r, h, color, top){ const g = new T.ExtrudeGeometry(rrect(x0, z0, x1, z1, r), {depth: h, bevelEnabled: false});
    g.rotateX(Math.PI / 2); const m = new T.Mesh(g, mat(color)); m.position.y = top; m.receiveShadow = true; scene.add(m); return m; }
  slab(-66, -54, 58, 54, 13, 1.4, 0x27304a, -.7);           // shoreline
  slab(-64, -52, 56, 52, 12, 2.6, 0x3b4664, 0);              // island
  slab(-60, 7, -11, 48, 3, .3, 0x4b5675, .3);                // project yard pad
  if (D.library.length) slab(-60, -48, -11, -1, 3, .3, 0x434e6c, .3);   // library pad (absent on the shared copy)
  slab(-3, -46, 50, -12, 4, .2, 0x2d5236, .2);               // bank lawn
  slab(-2, -6, 52, 48, 5, .15, 0x2b4c33, .15);               // park grounds
  const roadM = mat(0x1f2638);
  add(new T.BoxGeometry(3.4, .12, 100), roadM, -7, .06, 0, false).receiveShadow = true;
  add(new T.BoxGeometry(118, .12, 3.4), roadM, -4, .07, 3, false).receiveShadow = true;
  for (let z = -46; z <= 46; z += 4) add(new T.BoxGeometry(.18, .14, 1.6), mat(0x8b93a8), -7, .08, z, false);
  for (let x = -60; x <= 52; x += 4) add(new T.BoxGeometry(1.6, .14, .18), mat(0x8b93a8), x, .09, 3, false);

  /* ---------- glow + lamps */
  const glowTex = (() => { const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d');
    const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(.25, 'rgba(255,255,255,.55)');
    gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); return new T.CanvasTexture(c); })();
  function glow(x, y, z, size, color, op){ const s = new T.Sprite(new T.SpriteMaterial({map: glowTex, color: color, transparent: true,
    opacity: op == null ? .85 : op, blending: T.AdditiveBlending, depthWrite: false})); s.position.set(x, y, z); s.scale.set(size, size, 1); scene.add(s); return s; }
  const poleM = mat(0x1b2131), bulbM = new T.MeshBasicMaterial({color: 0xffd9a0});
  function lamp(x, z){ add(new T.CylinderGeometry(.09, .12, 2.6, 6), poleM, x, 1.3, z); add(new T.SphereGeometry(.28, 8, 6), bulbM, x, 2.7, z, false);
    glow(x, 2.7, z, 3.6, 0xffc070, .7); glow(x, .2, z, 5, 0xffb35c, .22); }
  for (let z = -44; z <= 44; z += 8) lamp(z % 16 === 4 ? -9.3 : -4.7, z);
  for (let x = -56; x <= 50; x += 9) lamp(x, x % 18 === 0 ? 5.3 : .7);

  /* ---------- building kit */
  function winTex(cols, rows, lit, seed, base, glowC){
    const cw = 16, ch = 20, mk = () => { const c = document.createElement('canvas'); c.width = cols * cw; c.height = rows * ch; return c; };
    const a = mk(), e = mk(), ga = a.getContext('2d'), ge = e.getContext('2d'), r = rng(seed);
    ga.fillStyle = base; ga.fillRect(0, 0, a.width, a.height); ge.fillStyle = '#000'; ge.fillRect(0, 0, e.width, e.height);
    for (let i = 0; i < rows; i++) for (let j = 0; j < cols; j++){ const on = r() < lit;
      ga.fillStyle = on ? glowC : '#0c1424'; ga.fillRect(j * cw + 4, i * ch + 5, cw - 8, ch - 9);
      if (on){ ge.fillStyle = glowC; ge.fillRect(j * cw + 4, i * ch + 5, cw - 8, ch - 9); } }
    const ta = new T.CanvasTexture(a), te = new T.CanvasTexture(e); ta.encoding = te.encoding = T.sRGBEncoding; return [ta, te];
  }
  function tower(x, z, w, d, h, o){
    o = o || {}; const y0 = o.y || 0;
    const floors = Math.max(1, Math.round(h / 2.1)), cols = Math.max(2, Math.round(Math.max(w, d) / 1.5));
    const [ta, te] = winTex(cols, floors, o.lit == null ? .7 : o.lit, o.seed || 1, o.base || '#27324e', o.glow || '#ffd48c');
    const side = new T.MeshStandardMaterial({map: ta, emissive: 0xffffff, emissiveMap: te, emissiveIntensity: o.dim ? .25 : 1, roughness: .85});
    const roof = mat(o.roof || 0x323e5c);
    const m = add(new T.BoxGeometry(w, h, d), [side, side, roof, roof, side, side], x, y0 + h / 2, z);
    const cap = add(new T.BoxGeometry(w + .35, .4, d + .35), mat(o.cap || 0x46547a), x, y0 + h + .2, z);
    if (o.info){ pick(m, o.info); pick(cap, o.info); }
    return m;
  }
  function label(text, pos, cls, onClick, dot){
    const el = document.createElement('div'); el.className = 'wl ' + (cls || '');
    el.innerHTML = (dot === false ? '' : `<i style="${dot ? 'background:' + dot + ';box-shadow:0 0 8px ' + dot : ''}"></i>`) + esc(text);
    if (onClick) el.onclick = onClick; $('#wlabels').appendChild(el); labels.push({el, p: pos, big: /big/.test(cls || '')}); return el; }
  function bubble(html, pos, onClick){
    const el = document.createElement('div'); el.className = 'wb'; el.innerHTML = html; if (onClick) el.onclick = onClick;
    $('#wlabels').appendChild(el); labels.push({el, p: pos, big: true}); return el; }

  /* ---------- PROJECT YARD: a building per active project, floors = progress */
  const yard = D.projects.filter(p => p.lane === 'now' || p.lane === 'next'), later = D.projects.filter(p => p.lane === 'later');
  const COLS = [-54, -44, -34, -24, -15], ROWS = [42, 31, 20], FULL = 14, Y0 = .6;
  const projPos = {}, cranes = [];
  function crane(x, z, h, seed){
    const yel = mat(0xf2a33a); add(new T.BoxGeometry(.45, h, .45), yel, x, h / 2, z);
    const top = new T.Group(); top.position.set(x, h, z); scene.add(top);
    const part = (g, m, px, py, pz) => { const me = new T.Mesh(g, m); me.position.set(px, py, pz); me.castShadow = true; top.add(me); };
    part(new T.BoxGeometry(9, .38, .38), yel, -2.6, 0, 0); part(new T.BoxGeometry(1.5, .9, .9), mat(0x3a4256), 1.7, -.1, 0);
    part(new T.BoxGeometry(.85, .8, .85), yel, 0, -.6, 0); part(new T.BoxGeometry(.06, 3.2, .06), mat(0x1a1f2b), -6.2, -1.6, 0);
    part(new T.BoxGeometry(.7, .5, .7), mat(0xeb6e1f), -6.2, -3.3, 0);
    top.rotation.y = rng(seed)() * Math.PI * 2; cranes.push({g: top, s: .0012 + rng(seed + 7)() * .0016});
    const tip = glow(x, h + .6, z, 1.6, 0xff4444, .9); cranes[cranes.length - 1].tip = tip;
  }
  yard.slice(0, COLS.length * ROWS.length).forEach((p, i) => {
    const x = COLS[i % COLS.length] + (Math.floor(i / COLS.length) % 2) * 2.5, z = ROWS[Math.floor(i / COLS.length)], prog = pctOf(p);
    const paused = p.status === 'paused' || p.status === 'blocked', built = Math.max(2.1, prog * FULL), info = {kind: 'project', id: p.id};
    add(new T.BoxGeometry(8.2, .25, 8.2), mat(0x5a6687), x, Y0 - .12, z, false).receiveShadow = true;
    tower(x, z, 5.6, 5.6, built, {y: Y0, lit: paused ? .12 : .72, dim: paused, seed: hashStr(p.id), info,
      base: p.lane === 'next' ? '#2a3550' : '#2b3858', cap: p.owner.includes('cael') ? 0x2a6f8f : 0x7a4a2c});
    if (prog < .999){
      const rem = FULL - built, frame = new T.LineSegments(new T.EdgesGeometry(new T.BoxGeometry(5.6, rem, 5.6)),
        new T.LineBasicMaterial({color: 0xeb6e1f, transparent: true, opacity: .8}));
      frame.position.set(x, Y0 + built + rem / 2, z); scene.add(frame);
      for (let y = built + 2.1; y < FULL - .2; y += 2.1){ const s = new T.Mesh(new T.BoxGeometry(5.6, .1, 5.6),
        new T.MeshBasicMaterial({color: 0xeb6e1f, transparent: true, opacity: .09, depthWrite: false})); s.position.set(x, Y0 + y, z); scene.add(s); }
      if (!paused && p.lane === 'now' && p.stage !== 'idea') crane(x + 3.6, z - 3.6, FULL + 4, hashStr(p.id));
    }
    if (p.status === 'blocked') glow(x, Y0 + built + 1.4, z, 3, 0xff3344, 1);
    if (p.waiting_on === 'zac') glow(x, Y0 + built + 1.2, z, 2.4, 0xf2b84b, .9);
    projPos[p.id] = new T.Vector3(x, Y0 + FULL + 1.2, z);
    label(p.tag || p.title.slice(0, 22), new T.Vector3(x, Y0 + FULL + .8, z), 'small', () => openInfo(info),
      p.owner.includes('cael') ? 'var(--cael)' : p.owner.includes('zac') ? 'var(--zac)' : 'var(--muted)');
  });
  later.forEach((p, i) => {
    const x = -55 + i * 7.6, z = 11.5, info = {kind: 'project', id: p.id};
    const f = add(new T.BoxGeometry(5.2, .6, 4.4), mat(0x6a7593), x, .6, z); pick(f, info);
    const post = add(new T.BoxGeometry(.15, 2.4, .15), mat(0xdedede), x + 2.1, 1.8, z + 1.7); pick(post, info);
    const sign = add(new T.BoxGeometry(1.8, .9, .1), mat(0xeb6e1f), x + 1.4, 2.7, z + 1.7); pick(sign, info);
  });
  label('Project Yard', new T.Vector3(-35, .6, 48.5), 'big', () => showTab('cmd'));
  bubble(`${yard.filter(p => p.lane === 'now').length} now &middot; ${yard.filter(p => p.lane === 'next').length} next &middot; <em>${later.length} lots waiting</em>`,
    new T.Vector3(-35, 6, 48.5), () => showTab('cmd'));

  /* ---------- THE LIBRARY: one tower per shelf */
  const shelfData = D.shelves.map(s => ({...s, n: D.library.filter(x => x.s.includes(s.key)).length})).filter(s => s.n)
    .sort((a, b) => b.n - a.n);
  const back = [[-54, -40], [-44, -41], [-34, -41], [-24, -40], [-15, -39]], front = [[-51, -26], [-41, -25], [-31, -25], [-21, -24], [-14, -15]];
  const slots = back.concat(front), shelfPos = {};
  const tints = ['#2a3760', '#2d3560', '#28405a', '#30395c', '#2b3b52', '#33365a', '#283a55', '#2f3a58', '#2a3450', '#2c3a5a'];
  shelfData.slice(0, slots.length).forEach((s, i) => {
    const [x, z] = slots[i], h = 3 + 2.2 * Math.log2(1 + s.n), info = {kind: 'shelf', key: s.key};
    tower(x, z, 7, 7, h, {y: .6, lit: .82, seed: hashStr(s.key), base: tints[i % tints.length], glow: '#ffe3a8', cap: 0x51608a, info});
    shelfPos[s.key] = new T.Vector3(x, .6 + h + 1.2, z);
    label(`${s.name}  ${s.n}`, new T.Vector3(x, .6 + h + 1, z), 'small', () => openInfo(info), '#ffd38a');
  });
  if (D.library.length) label('The Library', new T.Vector3(-35, .6, -0.8), 'big', () => showTab('lib'), '#ffd38a');
  if (D.library.length) bubble(`${D.library.length.toLocaleString()} notes on the shelves`, new T.Vector3(-35, 5.5, -0.8), () => showTab('lib'));

  /* ---------- IDEA BANK */
  {
    const bx = 22, bz = -30, info = {kind: 'ideas'}, stone = mat(0xc9cfdb), dark = mat(0x5d6884);
    pick(add(new T.BoxGeometry(18, 1.2, 12.5), dark, bx, .6, bz), info);
    pick(add(new T.BoxGeometry(17, .6, 11.5), mat(0x7b86a3), bx, 1.5, bz), info);
    tower(bx, bz - 1.2, 14, 7.5, 7, {y: 1.8, lit: .6, seed: 77, base: '#3a4566', glow: '#ffe7b0', cap: 0x9aa4bc, info});
    for (let i = 0; i < 6; i++) pick(add(new T.CylinderGeometry(.42, .5, 6.6, 10), stone, bx - 6.2 + i * 2.48, 5.1, bz + 4), info);
    pick(add(new T.BoxGeometry(15.4, .8, 10.4), stone, bx, 9.2, bz), info);
    const tri = new T.Shape(); tri.moveTo(-7.7, 0); tri.lineTo(7.7, 0); tri.lineTo(0, 2.6); tri.lineTo(-7.7, 0);
    const pg = new T.ExtrudeGeometry(tri, {depth: 10.4, bevelEnabled: false}); pg.translate(0, 0, -5.2);
    pick(add(pg, stone, bx, 9.6, bz), info);
    glow(bx, 11, bz + 5, 9, 0xffd27a, .35);
    label('Idea Bank', new T.Vector3(bx, .6, bz + 8.6), 'big', () => openInfo(info), '#ffd27a');
    bubble(`${D.ideas.length} ideas &middot; <em>${D.ideas_new} new this week</em>`, new T.Vector3(bx, 13.6, bz), () => openInfo(info));
  }

  /* ---------- BALLPARK + SCOREBOARD (the processes) */
  const HP = new T.Vector3(40, 0, 36);
  {
    const g = new T.Group(); g.position.copy(HP); scene.add(g);
    const flat = (geo, color, y) => { const m = new T.Mesh(geo, mat(color, {flatShading: false})); m.rotation.x = -Math.PI / 2; m.position.y = y; m.receiveShadow = true; g.add(m); return m; };
    flat(new T.CircleGeometry(25, 40, Math.PI / 2, Math.PI / 2), 0x2f8a48, .32);
    flat(new T.CircleGeometry(10.5, 30, Math.PI / 2, Math.PI / 2), 0x9a6a3e, .36);
    const inf = flat(new T.PlaneGeometry(6.2, 6.2), 0x37944f, .4); inf.position.set(-3.6, .4, -3.6);
    const mound = new T.Mesh(new T.CylinderGeometry(.9, 1.1, .25, 16), mat(0x9a6a3e)); mound.position.set(-3.6, .5, -3.6); g.add(mound);
    [[0, -7.2], [-7.2, -7.2], [-7.2, 0], [0, 0]].forEach(([bx, bz]) => { const b = new T.Mesh(new T.BoxGeometry(.6, .12, .6), mat(0xffffff)); b.position.set(bx, .48, bz); g.add(b); });
    const wall = new T.Mesh(new T.CylinderGeometry(25, 25, 1.4, 40, 1, true, Math.PI, Math.PI / 2), mat(0x1c4a2e, {side: T.DoubleSide}));
    wall.position.y = 1; g.add(wall);
    const seat = mat(0x24427e), seat2 = mat(0x2f5aa6), conc = mat(0x59647f);
    for (let k = 0; k < 3; k++){
      const off = 1.6 + k * 1.7, hh = 1 + k * 1.15;
      const a = new T.Mesh(new T.BoxGeometry(1.7, hh, 22), k === 2 ? seat2 : seat); a.position.set(off, hh / 2, -11); a.castShadow = a.receiveShadow = true; g.add(a);
      const b = new T.Mesh(new T.BoxGeometry(22, hh, 1.7), k === 2 ? seat2 : seat); b.position.set(-11, hh / 2, off); b.castShadow = b.receiveShadow = true; g.add(b);
      const c = new T.Mesh(new T.BoxGeometry(1.7, hh, 1.7 + off), conc); c.position.set(off, hh / 2, (1.7 + off) / 2 - .85); c.castShadow = true; g.add(c);
    }
    [[6.5, 6.5], [7, -24], [-24, 7]].forEach(([lx, lz]) => {
      const pole = new T.Mesh(new T.CylinderGeometry(.18, .25, 15, 6), mat(0x8b93a8)); pole.position.set(lx, 7.5, lz); pole.castShadow = true; g.add(pole);
      const pan = new T.Mesh(new T.BoxGeometry(2.6, 1.4, .3), new T.MeshBasicMaterial({color: 0xfff6dc})); pan.position.set(lx, 15.2, lz); pan.lookAt(g.position.x - 12, 0, g.position.z - 12); g.add(pan);
      glow(HP.x + lx, 15.2, HP.z + lz, 8, 0xfff0c8, .75);
    });
  }
  if (D.processes.length) {
    const c = document.createElement('canvas'); c.width = 512; c.height = 256; const x = c.getContext('2d');
    x.fillStyle = '#071022'; x.fillRect(0, 0, 512, 256); x.strokeStyle = '#eb6e1f'; x.lineWidth = 6; x.strokeRect(3, 3, 506, 250);
    x.fillStyle = '#eb6e1f'; x.font = '700 26px "Space Grotesk", Inter, sans-serif'; x.fillText('PROCESSES', 22, 40);
    const col = {ok: '#3ddc97', running: '#4cc9f0', late: '#f2b84b', failed: '#ff5c6c', manual: '#8fa3bf', none: '#56657c', ended: '#56657c'};
    D.processes.slice(0, 8).forEach((p, i) => { const yy = 74 + i * 23;
      x.fillStyle = col[p.state] || '#56657c'; x.beginPath(); x.arc(30, yy - 6, 7, 0, 7); x.fill();
      x.fillStyle = '#dfe8f5'; x.font = '600 17px Inter, sans-serif'; x.fillText(p.title.slice(0, 30), 46, yy);
      x.fillStyle = col[p.state] || '#8fa3bf'; x.font = '600 15px "JetBrains Mono", monospace'; x.fillText(p.label.toUpperCase().slice(0, 14), 360, yy); });
    const tex = new T.CanvasTexture(c); tex.encoding = T.sRGBEncoding;
    const face = new T.MeshBasicMaterial({map: tex}), body = mat(0x1a2236), info = {kind: 'processes'};
    const sb = new T.Group(); sb.position.set(HP.x - 21, 0, HP.z - 21); sb.rotation.y = Math.PI / 4; scene.add(sb);
    const board = new T.Mesh(new T.BoxGeometry(13, 6.5, .6), [body, body, body, body, face, body]); board.position.y = 8.6; board.castShadow = true; sb.add(board);
    [-4.5, 4.5].forEach(px => { const post = new T.Mesh(new T.BoxGeometry(.6, 5.4, .6), body); post.position.set(px, 2.7, -.1); sb.add(post); pick(post, info); });
    pick(board, info);
    const okN = D.processes.filter(p => ['ok', 'running', 'manual'].includes(p.state)).length;
    label('Ballpark', new T.Vector3(HP.x + 4, .6, HP.z + 6), 'big', () => openInfo(info), 'var(--ok)');
    bubble(`${okN} of ${D.processes.length} jobs OK`, new T.Vector3(HP.x - 21, 13.4, HP.z - 21), () => openInfo(info));
  }

  /* ---------- THE PORT: research batches dock as ships */
  const ships = [];
  {
    const info = {kind: 'port'}, wood = mat(0x6b5240), px = 53;
    [-8, 4].forEach(pz => { const pier = add(new T.BoxGeometry(16, .5, 2.4), wood, px + 6, -.2, pz); if (D.research.length) pick(pier, info); });
    tower(46, -2, 6, 8, 5, {y: .3, lit: .5, seed: 9, base: '#33405e', cap: 0x6b7aa0, info: D.research.length ? info : null});
    const hulls = [0x2a4d8f, 0x8f2a3a, 0x2a8f6b, 0x8f6b2a, 0x5a2a8f, 0x2a7f8f, 0x8f4f2a];
    D.research.slice(0, 6).forEach((r, i) => {
      const sx = px + 3 + (i % 3) * 4.6, sz = i < 3 ? -4.6 : 7.6, sg = new T.Group(); sg.position.set(sx, -1.1, sz); scene.add(sg);
      const hull = new T.Mesh(new T.BoxGeometry(3.8, 1.3, 1.9), mat(hulls[i % hulls.length])); hull.castShadow = true; sg.add(hull);
      const cab = new T.Mesh(new T.BoxGeometry(1.4, .9, 1.3), mat(0xe8ecf2)); cab.position.set(-.6, 1.1, 0); sg.add(cab);
      const win = new T.Mesh(new T.BoxGeometry(1.42, .25, 1.32), new T.MeshBasicMaterial({color: 0xffd48c})); win.position.set(-.6, 1.25, 0); sg.add(win);
      const sinfo = {kind: 'ship', i}; [hull, cab, win].forEach(m => pick(m, sinfo));
      sg.userData.y0 = -1.1; ships.push(sg);
    });
    if (D.research.length) label('The Port', new T.Vector3(px + 4, .4, 13), 'big', () => openInfo(info), 'var(--run)');
    if (D.research.length) bubble(`${D.research.length} research batches`, new T.Vector3(46, 8, -2), () => openInfo(info));
  }

  /* ---------- trees */
  {
    const taken = [[-61, 6, -10, 49], ...(D.library.length ? [[-61, -49, -10, 0]] : []), [-9.5, -55, -4.5, 55], [-65, 1, 58, 5.5], [10, -46, 34, -15],
      [14, 8, 52, 50], [44, -12, 60, 16], [12, 6, 30, 22]];
    const r = rng(42), leaf = [mat(0x2f6b3f), mat(0x3d7d47), mat(0x2a5c3a)], trunk = mat(0x4a3628);
    let n = 0, tries = 0;
    while (n < 90 && tries < 3000){ tries++;
      const x = -62 + r() * 116, z = -50 + r() * 100;
      if (taken.some(([a, b, c, d]) => x > a && x < c && z > b && z < d)) continue;
      if ((x / 60) ** 2 + (z / 52) ** 2 > 1.05) continue;
      const s = .7 + r() * .7; add(new T.CylinderGeometry(.14 * s, .2 * s, 1 * s, 5), trunk, x, .5 * s, z);
      add(new T.ConeGeometry(1.1 * s, 2.6 * s, 7), leaf[n % 3], x, 1 * s + 1.2 * s, z); n++; }
  }

  /* ---------- people: avatars stand on the project they last touched */
  function avatarTex(letter, color){ const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
    g.fillStyle = 'rgba(0,0,0,.35)'; g.beginPath(); g.arc(64, 68, 58, 0, 7); g.fill();
    g.fillStyle = '#ffffff'; g.beginPath(); g.arc(64, 64, 58, 0, 7); g.fill();
    g.fillStyle = color; g.beginPath(); g.arc(64, 64, 50, 0, 7); g.fill();
    g.fillStyle = '#0b1530'; g.font = '700 58px "Space Grotesk", Inter, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(letter, 64, 68);
    const t = new T.CanvasTexture(c); t.encoding = T.sRGBEncoding; return t; }
  const people = [['zac', 'Z', '#EB6E1F'], ['cael', 'C', '#4cc9f0']];
  people.forEach(([who, letter, color]) => {
    const mine = D.projects.filter(p => p.owner.includes(who) && projPos[p.id]);
    if (!mine.length) return;
    mine.sort((a, b) => ((b.commits[0] || {}).ts || 0) - ((a.commits[0] || {}).ts || 0));
    const p = mine[0], pos = projPos[p.id].clone().add(new T.Vector3(0, 3.4, 0));
    const sp = new T.Sprite(new T.SpriteMaterial({map: avatarTex(letter, color), depthTest: false})); sp.position.copy(pos); sp.scale.set(3.6, 3.6, 1); sp.renderOrder = 10; scene.add(sp);
    pick(sp, {kind: 'person', who, pid: p.id});
  });

  /* ---------- commit pop-ups (cycle the freshest commits over their building) */
  const evts = []; D.projects.forEach(p => (p.commits || []).forEach(c => projPos[p.id] && evts.push({p, c})));
  evts.sort((a, b) => b.c.ts - a.c.ts);
  const recent = evts.slice(0, 10); let ti = 0, toast = null;
  const ping = glow(0, -60, 0, 9, 0xeb6e1f, 0), ring = glow(0, -60, 0, 4, 0xffd0a8, 0);
  function nextToast(){ if (!recent.length) return; const e = recent[ti++ % recent.length], m = /Merge pull request #(\d+)/.exec(e.c.subj);
    $('#wtoast').innerHTML = `<div class="t">${m ? 'Merged #' + m[1] : 'Commit ' + esc(e.c.sha)}</div><div class="sj">${esc(m ? (e.p.title) : e.c.subj.slice(0, 90))}</div>
      <div class="r"><div>Project<b>${esc(e.p.tag || e.p.title.slice(0, 16))}</b></div><div>When<b>${esc(ago(e.c.ts))}</b></div><div>By<b>${esc(e.c.author.split(/[ _]/)[0])}</b></div></div>`;
    toast = projPos[e.p.id]; }
  nextToast(); setInterval(nextToast, 5200);

  /* ---------- hover + click */
  const ray = new T.Raycaster(), mouse = new T.Vector2(-9, -9); let mx = 0, my = 0, down = null, hoverInfo = null;
  const cv = renderer.domElement;
  cv.addEventListener('pointermove', e => { const r = cv.getBoundingClientRect(); mx = e.clientX - r.left; my = e.clientY - r.top;
    mouse.set(mx / r.width * 2 - 1, -(my / r.height) * 2 + 1); });
  cv.addEventListener('pointerleave', () => mouse.set(-9, -9));
  cv.addEventListener('pointerdown', e => { down = [e.clientX, e.clientY]; });
  cv.addEventListener('pointerup', e => { if (down && Math.hypot(e.clientX - down[0], e.clientY - down[1]) < 5 && hoverInfo) openInfo(hoverInfo); down = null; });
  cv.addEventListener('contextmenu', e => e.preventDefault());
  $('#wreset').onclick = () => { cam.position.copy(HOME.pos); cam.zoom = HOME.zoom; cam.updateProjectionMatrix(); ctl.target.copy(HOME.target); ctl.update(); };

  function tipHtml(info){
    if (info.kind === 'project'){ const p = P.find(q => q.id === info.id), pc = pctOf(p);
      return `<div class="h">${esc(p.title)}</div><div class="s">${p.owner.map(ownerName).join(' + ')}${p.tag ? ' &middot; ' + esc(p.tag) : ''} &middot; ${esc(p.lane)}</div>
        <div class="pb"><i style="width:${(pc * 100).toFixed(0)}%"></i></div><div class="s">${(pc * 100).toFixed(0)}% &middot; ${esc(p.stage)}${p.status ? ' &middot; ' + esc(p.status) : ''}</div>
        ${p.next ? `<div class="c">Next: ${esc(p.next)}</div>` : ''}`; }
    if (info.kind === 'shelf'){ const s = D.shelves.find(x => x.key === info.key), xs = D.library.filter(x => x.s.includes(info.key));
      const by = k => xs.filter(x => x.k === k).length;
      return `<div class="h">${esc(s.name)}</div><div class="s">${xs.length} notes: ${by('concept')} concepts, ${by('drill')} drills, ${by('cue')} cues, ${by('source')} sources</div><div class="c">Click to browse the shelf</div>`; }
    if (info.kind === 'ideas') return `<div class="h">Idea Bank</div><div class="s">${D.ideas.length} ideas, ${D.ideas_new} new this week</div>${D.ideas[0] ? `<div class="c">Newest: ${esc(D.ideas[0].title)}</div>` : ''}`;
    if (info.kind === 'processes'){ const bad = PR.filter(p => p.state === 'failed' || p.state === 'late');
      return `<div class="h">Scoreboard: automated jobs</div><div class="s">${PR.length} jobs, ${bad.length} need a look</div>${bad.map(p => `<div class="c">${esc(p.title)}: ${esc(p.label)}</div>`).join('')}`; }
    if (info.kind === 'port') return `<div class="h">The Port</div><div class="s">${D.research.length} research batches docked (last 60 days)</div><div class="c">Click to see them</div>`;
    if (info.kind === 'ship'){ const r = D.research[info.i]; return `<div class="h">${esc(r.title)}</div><div class="s">docked ${esc(r.created)} &middot; ${esc(r.folder)}</div><div class="c">Click to open the notes</div>`; }
    if (info.kind === 'person'){ const p = P.find(q => q.id === info.pid), c = p.commits[0];
      return `<div class="h">${esc(ownerName(info.who))}</div><div class="s">on ${esc(p.title)}</div>${c ? `<div class="c">active ${esc(ago(c.ts))}: ${esc(c.subj.slice(0, 70))}</div>` : ''}`; }
    return '';
  }
  window.openInfo = openInfo; window.tipHtml = tipHtml;
  function openInfo(info){
    let h = '';
    if (info.kind === 'project'){ const p = P.find(q => q.id === info.id);
      h = `<h2>${esc(p.title)}</h2><div class="ds">Project Yard &middot; ${esc(p.lane)}</div><div class="cards">${card(p, false).replace('class="card"', 'class="card open"')}</div>`; }
    else if (info.kind === 'shelf'){ const s = D.shelves.find(x => x.key === info.key);
      const xs = D.library.filter(x => x.s.includes(info.key)).sort((a, b) => (b.c + b.a).localeCompare(a.c + a.a));
      h = `<h2>${esc(s.name)} shelf</h2><div class="ds">${xs.length} notes, newest first &middot; <a href="#" id="wtolib">open in the Library tab</a></div>` +
        xs.slice(0, 60).map(x => `<a class="row" href="${esc(x.u)}"><span class="k k-${x.k}">${x.k}</span><span class="t">${esc(x.t)}</span><span class="d">${esc(x.c)}</span></a>`).join(''); }
    else if (info.kind === 'ideas') h = `<h2>Idea Bank</h2><div class="ds">${D.ideas.length} ideas, newest first</div><div class="igrid" style="grid-template-columns:1fr 1fr">` +
        D.ideas.map(i => `<a class="idea" href="${esc(i.uri || 'javascript:void(0)')}"><div class="t">${esc(i.title)}</div><div class="m"><span class="chip">${esc(i.status)}</span>${i.source !== 'unlabeled' ? `<span class="chip tag">${esc(i.source)}</span>` : ''}</div></a>`).join('') + '</div>';
    else if (info.kind === 'processes') h = `<h2>Automated jobs</h2><div class="ds">laptop jobs are read live; Posit rows are your manual entries</div>` + $('#procs').innerHTML;
    else if (info.kind === 'port' || info.kind === 'ship') h = `<h2>The Port: research</h2><div class="ds">link batches and research notes, newest first</div>` + $('#rrows').innerHTML;
    else if (info.kind === 'person'){ const mine = P.filter(p => p.owner.includes(info.who));
      h = `<h2>${esc(ownerName(info.who))}</h2><div class="ds">${mine.length} project cards</div><div class="cards">${mine.map(p => card(p, false)).join('')}</div>`; }
    $('#wbody').innerHTML = h; $('#wdrawer').classList.add('on');
    const tl = $('#wtolib'); if (tl) tl.onclick = e => { e.preventDefault(); $('#wdrawer').classList.remove('on'); lShelf = info.key; drawShelves(); drawRows(); showTab('lib'); };
    $('#wbody').querySelectorAll('.cards .card').forEach(el => el.addEventListener('click', e => { if (!e.target.closest('a')) el.classList.toggle('open'); }));
  }
  $('#wclose').onclick = () => $('#wdrawer').classList.remove('on');
  document.addEventListener('keydown', e => { if (e.key === 'Escape') $('#wdrawer').classList.remove('on'); });

  /* ---------- loop */
  const v = new T.Vector3(), clock = new T.Clock();
  function place(el, p){ v.copy(p).project(cam); if (v.z > 1 || v.z < -1){ el.style.display = 'none'; return false; }
    el.style.display = ''; el.style.left = ((v.x * .5 + .5) * W()) + 'px'; el.style.top = ((-v.y * .5 + .5) * H()) + 'px'; return true; }
  function layoutLabels(){
    /* project every label, then stack small ones upward so none overlap (big district labels never move) */
    const w = W(), h = H(), boxes = [];
    labels.forEach(L => { v.copy(L.p).project(cam); L.vis = v.z <= 1 && v.z >= -1; L.x = (v.x * .5 + .5) * w; L.y = (-v.y * .5 + .5) * h;
      if (!L.w && L.el.offsetWidth){ L.w = L.el.offsetWidth; L.h = L.el.offsetHeight; } });
    labels.filter(L => !L.vis).forEach(L => { L.el.style.display = 'none'; });
    labels.filter(L => L.vis).sort((a, b) => (b.big ? 1 : 0) - (a.big ? 1 : 0) || b.y - a.y).forEach(L => {
      const lw = L.w || 90, lh = L.h || 22; let y = L.y, n = 0;
      const hit = yy => boxes.some(b => Math.abs(b.x - L.x) < (b.w + lw) / 2 + 4 && Math.abs(b.y - yy) < (b.h + lh) / 2 + 2);
      while (!L.big && hit(y) && n < 5){ y -= lh + 3; n++; }
      boxes.push({x: L.x, y, w: lw, h: lh}); L.el.style.display = ''; L.el.style.left = L.x + 'px'; L.el.style.top = y + 'px'; });
  }
  function resize(){ const w = W(), h = H(); if (!w || !h) return; renderer.setSize(w, h);
    cam.left = -VIEW * w / h; cam.right = VIEW * w / h; cam.top = VIEW; cam.bottom = -VIEW; cam.updateProjectionMatrix(); }
  window.addEventListener('resize', resize);
  function loop(){
    requestAnimationFrame(loop);
    if ($('#sec-world').style.display === 'none') return;
    const t = clock.getElapsedTime(); ctl.update();
    cranes.forEach(c => { c.g.rotation.y += c.s; if (c.tip) c.tip.material.opacity = .45 + .45 * Math.abs(Math.sin(t * 2.2)); });
    ships.forEach((s, i) => { s.position.y = s.userData.y0 + Math.sin(t * 1.3 + i * 1.7) * .14; s.rotation.z = Math.sin(t * .9 + i) * .03; });
    renderer.render(scene, cam);
    layoutLabels();
    const te = $('#wtoast'); te.style.display = toast ? 'block' : 'none';
    if (toast){ const k = (t * .9) % 1; ping.position.copy(toast); ring.position.copy(toast);
      ping.scale.set(4 + 10 * k, 4 + 10 * k, 1); ping.material.opacity = .9 * (1 - k); ring.material.opacity = .8; }
    ray.setFromCamera(mouse, cam); const hit = ray.intersectObjects(picks, false)[0];
    hoverInfo = hit ? hit.object.userData.pick : null; cv.style.cursor = hoverInfo ? 'pointer' : 'grab';
    const tip = $('#wtip');
    if (hoverInfo){ tip.innerHTML = tipHtml(hoverInfo); tip.style.display = 'block';
      const tw = tip.offsetWidth, th = tip.offsetHeight; tip.style.left = Math.min(mx + 18, W() - tw - 8) + 'px'; tip.style.top = Math.min(my + 18, H() - th - 8) + 'px'; }
    else tip.style.display = 'none';
  }
  loop();
  return {resize};
}
let WORLD = null;
window.worldShown = () => { if (!WORLD) WORLD = buildWorld(); else if (WORLD.resize) WORLD.resize(); };
showTab(START_TAB);
/* ?selftest: open every kind of building once and log the verdict (headless check, no clicking) */
if (/[?&]selftest/.test(location.search)) setTimeout(() => {
  /* every building kind that is DRAWN on this copy (the shared copy has no shelves, jobs or ships) */
  const kinds = [{kind: 'project', id: P[0].id}, {kind: 'ideas'}, {kind: 'person', who: 'zac', pid: P[0].id}]
    .concat(D.library.length ? [{kind: 'shelf', key: 'pitching'}] : [], D.processes.length ? [{kind: 'processes'}] : [],
            D.research.length ? [{kind: 'port'}, {kind: 'ship', i: 0}] : []);
  let bad = 0;
  kinds.forEach(k => { try { window.openInfo(k); if (!window.tipHtml(k)) throw new Error('empty tooltip');
    if (!$('#wbody').innerHTML.trim()) throw new Error('empty drawer'); } catch (e){ bad++; console.log('SELFTEST FAIL ' + k.kind + ': ' + e.message); } });
  window.openInfo({kind: 'project', id: (P.find(p => p.id.startsWith('mazzo-6')) || P[0]).id});
  console.log('SELFTEST ' + (bad ? 'FAIL ' + bad : 'OK') + ' kinds=' + kinds.length + ' world=' + !!(WORLD && WORLD.resize));
}, 1500);
</script></body></html>"""


def open_once_daily():
    """Open the page on the first run of the day (same marker as the old refresh_and_open.ps1)."""
    tmp = os.environ.get("TEMP") or os.path.expanduser("~")
    marker = os.path.join(tmp, "bsb_cc_opened_" + datetime.date.today().strftime("%Y%m%d"))
    if os.path.exists(marker):
        return
    for old in glob.glob(os.path.join(tmp, "bsb_cc_opened_*")):
        try:
            os.remove(old)
        except OSError:
            pass
    open(marker, "w").close()
    os.startfile(OUT)


if __name__ == "__main__":
    DATA = build()
    if "--publish" in sys.argv:
        publish(DATA)
    if "--open-once-daily" in sys.argv:
        open_once_daily()
