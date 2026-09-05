"""Per-item pipeline state, persisted as one JSON file.

Statuses: new -> fetched -> summarized -> (promoted | rejected)
          any -> failed (retries += 1, error kept)
Nothing is ever deleted from state; an item that keeps failing is surfaced
by `lint`, not dropped.
"""
from __future__ import annotations

import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path

STATUSES = ("new", "fetched", "summarized", "promoted", "rejected", "skipped", "failed")


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class State:
    def __init__(self, path: Path, data: dict | None = None):
        self.path = Path(path)
        self.data = data or {"items": {}, "cursors": {}}
        self.data.setdefault("items", {})
        self.data.setdefault("cursors", {})

    @classmethod
    def load(cls, path: Path) -> "State":
        path = Path(path)
        if path.exists():
            with open(path, encoding="utf-8") as f:
                return cls(path, json.load(f))
        return cls(path)

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=self.path.parent, suffix=".json.partial")
        try:
            with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
                json.dump(self.data, f, indent=1, ensure_ascii=False, sort_keys=True)
            os.replace(tmp, self.path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    # --- items -----------------------------------------------------------
    def add(self, item: dict) -> bool:
        """Insert if unseen. Returns True when the item was new."""
        iid = item["id"]
        if iid in self.data["items"]:
            return False
        rec = dict(item)
        rec.setdefault("status", "new")
        rec.setdefault("retries", 0)
        rec.setdefault("error", None)
        rec.setdefault("raw", None)
        rec.setdefault("note", None)
        rec.setdefault("added", _now())
        self.data["items"][iid] = rec
        return True

    def get(self, iid: str) -> dict | None:
        return self.data["items"].get(iid)

    def update(self, iid: str, **fields) -> None:
        self.data["items"][iid].update(fields)

    def set_status(self, iid: str, status: str, error: str | None = None) -> None:
        if status not in STATUSES:
            raise ValueError(f"unknown status {status!r}")
        rec = self.data["items"][iid]
        rec["status"] = status
        rec["updated"] = _now()
        if status == "failed":
            rec["retries"] = rec.get("retries", 0) + 1
            rec["error"] = error
        else:
            rec["error"] = None

    def by_status(self, status: str, source: str | None = None) -> list[dict]:
        out = [r for r in self.data["items"].values() if r.get("status") == status]
        if source:
            out = [r for r in out if r.get("source") == source]
        out.sort(key=lambda r: (r.get("published") or "", r["id"]))
        return out

    # --- cursors (backfill position per source feed) --------------------
    def cursor(self, key: str, default=None):
        return self.data["cursors"].get(key, default)

    def set_cursor(self, key: str, value) -> None:
        self.data["cursors"][key] = value
