#!/bin/bash
# usage-pacer: minimum %-per-5hr-window needed to max the weekly usage limit.
# Read-only against the user's own account. Token stays in memory, never printed.
#
# Usage:
#   pace.sh [Nh/day]                  # live fetch; N = active hours/day (default 10)
#   pace.sh [Nh/day] --manual S W R   # no network: S=session%, W=weekly%, R=weekly reset ISO
set -euo pipefail

SNAPSHOTS="$HOME/.claude/usage-snapshots.jsonl"
ACTIVE_HOURS=10
MANUAL=""

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    *h/day) ACTIVE_HOURS="${1%h/day}"; shift ;;
    --manual) MANUAL="1"; M_S="${2:?session%}"; M_W="${3:?weekly%}"; M_R="${4:?weekly reset ISO}"; shift 4 ;;
    *) args+=("$1"); shift ;;
  esac
done

if [[ -z "$MANUAL" ]]; then
  TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | python3 -c "import sys,json;print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null) || true
  if [[ -z "${TOKEN:-}" && -r "$HOME/.claude/.credentials.json" ]]; then
    TOKEN=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/.credentials.json')))['claudeAiOauth']['accessToken'])" 2>/dev/null) || true
  fi
  if [[ -z "${TOKEN:-}" ]]; then
    echo "ERROR: NO-TOKEN — could not read OAuth credential. Ask user to paste /usage numbers, then rerun with: pace.sh --manual <session%> <weekly%> <weekly-reset-ISO>" >&2
    exit 2
  fi
  RESPONSE=$(curl -sS --fail --max-time 15 \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" \
    https://api.anthropic.com/api/oauth/usage) || {
    echo "ERROR: NETWORK — usage endpoint unreachable. Rerun with --manual (see header)." >&2; exit 3; }
else
  RESPONSE=$(python3 -c "
import json,sys
print(json.dumps({'five_hour':{'utilization':float(sys.argv[1]),'resets_at':None},
                  'seven_day':{'utilization':float(sys.argv[2]),'resets_at':sys.argv[3]}}))" "$M_S" "$M_W" "$M_R")
fi

export RESPONSE SNAPSHOTS ACTIVE_HOURS MANUAL
python3 <<'PY'
import json, os, statistics, sys
from datetime import datetime, timezone

resp = json.loads(os.environ["RESPONSE"])
snap_path = os.environ["SNAPSHOTS"]
active_hours = float(os.environ["ACTIVE_HOURS"])
manual = bool(os.environ.get("MANUAL"))

now = datetime.now(timezone.utc)
s_pct = float(resp["five_hour"]["utilization"])
w_pct = float(resp["seven_day"]["utilization"])
s_reset = resp["five_hour"].get("resets_at")
w_reset = resp["seven_day"]["resets_at"]

# --- append snapshot ---
snap = {"ts": now.isoformat(), "session_pct": s_pct, "session_reset": s_reset,
        "weekly_pct": w_pct, "weekly_reset": w_reset, "source": "manual" if manual else "api"}
os.makedirs(os.path.dirname(snap_path), exist_ok=True)
with open(snap_path, "a") as f:
    f.write(json.dumps(snap) + "\n")

# --- calibrate r: weekly-points consumed per session-point, from history ---
rows = []
with open(snap_path) as f:
    for line in f:
        try: rows.append(json.loads(line))
        except Exception: pass
ests = []
by_block = {}
for row in rows:
    if row.get("session_reset"):
        by_block.setdefault((row["session_reset"], row["weekly_reset"]), []).append(row)
for block in by_block.values():
    block.sort(key=lambda x: x["ts"])
    for a, b in zip(block, block[1:]):
        ds = b["session_pct"] - a["session_pct"]
        dw = b["weekly_pct"] - a["weekly_pct"]
        if ds >= 25 and dw >= 0:         # weekly % is integer-granular; small session deltas give bogus r=0 samples
            ests.append(dw / ds)
r = statistics.median(ests) if ests else None

# --- windows math ---
w_reset_dt = datetime.fromisoformat(w_reset)
hours_left = max(0.0, (w_reset_dt - now).total_seconds() / 3600)
days_left = hours_left / 24
theoretical = hours_left / 5
realistic = min(theoretical, days_left * (active_hours / 5))
weekly_remaining = max(0.0, 100 - w_pct)

def fmt(x): return f"{x:.1f}"

print(f"now (local)          : {now.astimezone().strftime('%a %Y-%m-%d %H:%M')}")
print(f"session window       : {fmt(s_pct)}% used" + (f", resets {datetime.fromisoformat(s_reset).astimezone().strftime('%H:%M')}" if s_reset else ""))
print(f"weekly               : {fmt(w_pct)}% used, resets {w_reset_dt.astimezone().strftime('%a %Y-%m-%d %H:%M')} ({fmt(hours_left)}h away)")
print(f"windows until reset  : {fmt(theoretical)} theoretical (24/7) | {fmt(realistic)} realistic at {active_hours:g} active h/day")
print(f"weekly remaining     : {fmt(weekly_remaining)} points")
print(f"calibration          : " + (f"r = {r:.3f} weekly-pts per session-pt ({len(ests)} sample(s); full 5h window ≈ {fmt(r*100)} weekly-pts)" if r else f"UNCALIBRATED — {len(rows)} snapshot(s) logged; need 2+ in one 5h block with ≥25pt session movement"))

if w_pct >= 100:
    print("verdict              : weekly limit already exhausted")
    sys.exit(0)
if hours_left <= 0 or realistic < 0.01:
    print("verdict              : weekly reset imminent — nothing to pace")
    sys.exit(0)

pts_per_window = weekly_remaining / realistic
line = f"needed per window    : {fmt(pts_per_window)} weekly-pts across each of {fmt(realistic)} windows"
if r:
    req = pts_per_window / r
    if req > 100:
        min_windows = weekly_remaining / (100 * r)
        print(line)
        print(f"verdict              : IMPOSSIBLE at {active_hours:g}h/day — needs {fmt(req)}% of each window. Maxing the week requires ≥{fmt(min_windows)} full windows ({fmt(min_windows*5)}h of capped usage) before reset.")
    else:
        print(line + f" = {fmt(req)}% of each 5h window")
        print(f"verdict              : burn ≥{fmt(req)}% of every 5-hr window from now to weekly reset to max the week (current window already at {fmt(s_pct)}%).")
else:
    print(line)
    print("verdict              : session-% conversion pending calibration — invoke again later this window (after some usage) to calibrate.")
PY
