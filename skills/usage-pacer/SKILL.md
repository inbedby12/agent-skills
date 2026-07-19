---
name: usage-pacer
description: Use when the user explicitly invokes /usage-pacer or asks how hard they must use each 5-hour window to max out their weekly Claude usage limit. Works from any harness (measures the Claude account, not the invoking agent's). Explicit-invoke only — never auto-select.
---

# Usage Pacer

Answers one question: **what minimum % of each remaining 5-hour window must be used to hit 100% of the CLAUDE account's weekly limit before it resets.** Read-only; touches nothing but its own snapshot log.

Harness-neutral: the script is plain bash+python3 and measures the Claude account regardless of which agent runs it — invoking from Codex works and still answers the Claude-pacing question. It does NOT measure OpenAI/Codex limits (no comparable endpoint bridged; say so if asked).

## Flow

1. Run the script (default 10 active hours/day; pass user's override through):

```sh
bash ~/.claude/skills/usage-pacer/scripts/pace.sh          # default 10h/day
bash ~/.claude/skills/usage-pacer/scripts/pace.sh 14h/day  # user says they run 14h days
```

2. Relay the report. Lead with the verdict line. If UNCALIBRATED, tell the user: invoke again later in the same 5-hr window (after ≥25 points of session usage) — calibration is automatic from the snapshot log and sharpens with every invocation.
3. Do not re-derive or "correct" the script's math in the reply; the script is the calculator, the model is the messenger.

## Failure paths

- Exit 2 `NO-TOKEN` or exit 3 `NETWORK`: ask the user to open `/usage` and paste session %, weekly %, and the weekly reset time, then run:

```sh
bash ~/.claude/skills/usage-pacer/scripts/pace.sh --manual 87 22 2026-07-22T12:59:59+00:00
```

## How it works (for maintenance, not for relaying)

- Live data from the same OAuth endpoint the /usage screen uses (`api.anthropic.com/api/oauth/usage`); token read in-shell from Keychain (`Claude Code-credentials`) with `~/.claude/.credentials.json` fallback — never printed, never persisted.
- Every invocation appends `{ts, session%, weekly%, resets}` to `~/.claude/usage-snapshots.jsonl`.
- Ratio r (weekly-points consumed per session-point) is the median of Δweekly/Δsession over snapshot pairs within the same 5-hr block with ≥25 points of session movement (weekly % is integer-granular; smaller deltas produce rounding-biased samples). r converts "weekly points per window" into "% of a 5-hr window". Assumes proportional burn between the two meters; if Anthropic changes limit mechanics, calibration self-corrects as new snapshots arrive — but delete the snapshot file to recalibrate from scratch after a plan change.
- Realistic window count = days-until-reset × (active-hours ÷ 5), capped by wall-clock.

## Boundaries

- Not stay-within-limits (that throttles work near caps mid-task; this plans how to SPEND the week). Pairs with /loop or /schedule if the user later wants recurring pacing checks — do not set those up unasked.
- Never run this to justify burning usage; it reports, the user decides.
