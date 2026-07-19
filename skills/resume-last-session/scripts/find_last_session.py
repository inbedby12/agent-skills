#!/usr/bin/env python3
"""List recent Claude Code and Codex CLI sessions recorded for a directory.

Usage: find_last_session.py [DIR] [--exclude SESSION_ID] [--limit N]

Prints one candidate per line, newest first, tab-separated:
  HARNESS  SESSION_ID  MTIME  LINES  TITLE_OR_FIRST_PROMPT  PATH
The caller (agent) decides which candidate is the session to resume —
typically the newest one that is not the currently running session.
"""
import json
import os
import re
import sys
import time
from pathlib import Path

def parse_args(argv):
    target = os.getcwd()
    exclude = None
    limit = 5
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "--exclude" and args:
            exclude = args.pop(0)
        elif a == "--limit" and args:
            limit = int(args.pop(0))
        else:
            target = os.path.abspath(a)
    return target, exclude, limit

def fmt(ts):
    return time.strftime("%Y-%m-%d %H:%M", time.localtime(ts))

def snippet(text, n=90):
    text = re.sub(r"\s+", " ", text).strip()
    return text[:n] if text else "-"

def claude_candidates(target, exclude):
    proj = Path.home() / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", target)
    if not proj.is_dir():
        return
    for f in sorted(proj.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True):
        sid = f.stem
        if sid == exclude:
            continue
        title, first_user, cwd_ok, lines = None, None, False, 0
        try:
            with open(f, errors="replace") as fh:
                for line in fh:
                    lines += 1
                    if lines > 4000 and title and cwd_ok:
                        lines = sum(1 for _ in fh) + lines
                        break
                    try:
                        d = json.loads(line)
                    except (ValueError, UnicodeDecodeError):
                        continue
                    if d.get("cwd") == target:
                        cwd_ok = True
                    if d.get("type") == "ai-title":
                        title = d.get("aiTitle") or title
                    elif d.get("type") == "user" and not d.get("isSidechain") and not first_user:
                        c = d.get("message", {}).get("content")
                        if isinstance(c, str) and not c.startswith("<"):
                            first_user = c
                        elif isinstance(c, list):
                            for b in c:
                                if isinstance(b, dict) and b.get("type") == "text" and not b.get("text", "").startswith("<"):
                                    first_user = b["text"]
                                    break
        except OSError:
            continue
        if not cwd_ok:  # dir-name munging collision or moved project
            continue
        yield ("claude", sid, f.stat().st_mtime, lines, snippet(title or first_user or ""), str(f))

def codex_candidates(target, exclude):
    root = Path.home() / ".codex" / "sessions"
    if not root.is_dir():
        return
    files = sorted(root.glob("*/*/*/rollout-*.jsonl"),
                   key=lambda p: p.stat().st_mtime, reverse=True)
    for f in files[:400]:
        try:
            with open(f, errors="replace") as fh:
                first = json.loads(fh.readline())
        except (OSError, ValueError):
            continue
        meta = first.get("payload") or first.get("session_meta") or first
        cwd = meta.get("cwd")
        sid = meta.get("id") or meta.get("session_id") or f.stem
        if cwd != target or sid == exclude:
            continue
        instructions = meta.get("instructions") or ""
        try:
            lines = sum(1 for _ in open(f, errors="replace"))
        except OSError:
            lines = 0
        yield ("codex", sid, f.stat().st_mtime, lines, snippet(instructions), str(f))

def main():
    target, exclude, limit = parse_args(sys.argv[1:])
    out = []
    for gen in (claude_candidates(target, exclude), codex_candidates(target, exclude)):
        for i, c in enumerate(gen):
            out.append(c)
            if i + 1 >= limit:
                break
    out.sort(key=lambda c: c[2], reverse=True)
    if not out:
        print(f"NO_SESSIONS_FOUND for {target}", file=sys.stderr)
        sys.exit(1)
    for harness, sid, mtime, lines, label, path in out[:limit]:
        print(f"{harness}\t{sid}\t{fmt(mtime)}\t{lines}\t{label}\t{path}")

if __name__ == "__main__":
    main()
