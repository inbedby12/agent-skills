---
name: handoff
description: Use when the user explicitly invokes /handoff or asks to write a handoff file so a fresh session can pick up the work. Explicit-invoke only — never auto-select. No topic given = encapsulate the entire session; topic given = cover only that thread.
---

# Handoff

Write one self-contained file from the current session's context so a fresh session (any agent, zero shared context) resumes the work seamlessly. Comprehensive on substance, ruthless on tokens. Harness-neutral both directions: a Claude Code session's handoff is written to be picked up by Codex (or any agent) and vice versa — never assume the reader has your harness's tools, plugins, or subagent types.

## Location

- Repo cwd → `HANDOFF-<slug>-<YYYY-MM-DD>.md` at repo root (travels with the worktree)
- Non-repo session → `~/.agents/handoffs/<YYYY-MM-DD>-<slug>.md` (shared harness-neutral dir; create if missing)
- Tell the user the exact path when done, plus the one-line pickup instruction: "next session: read <path> fully before acting."

## Template (fixed order; every section present; "none" is a valid body)

```markdown
# HANDOFF: <topic> — <YYYY-MM-DD>
Read fully before acting. Written by a prior session for a fresh one.

## Scope
<whole session | named thread> · cwd: <abs path> · repo/branch: <or none>

## Objective + state
<what the work is; one line on exactly where it stands>

## Done
<chronological where order matters; outcomes not narrative. User decisions marked [user] — treat as non-negotiable. Agent steps unmarked. Example:
- migrated auth middleware to typed errors (src/middleware/auth.ts:40-88)
- [user] chose PostgreSQL over SQLite — do not revisit
>

## Key context
<files touched as path:line · decisions with the why · constraints discovered>

## Next steps
<ordered; each executable without asking: command or file + acceptance criterion>

## Watch for
<gotchas · assumptions marked (unverified) · risks · things that looked done but were not verified · failed attempts live here only>

## Peripheral
<related memories/skills/URLs/tickets · credential LOCATIONS never values · open questions for the user>

## Verify on pickup
<exact commands to confirm state still matches this file>
```

## Writing rules

- **Compression:** caveman-style body — drop articles/filler/hedging; keep technical terms, commands, paths, exact error strings verbatim. Code blocks unchanged.
- **Selectivity:** include only what changes the next agent's behavior. Outcomes, not process narrative. "First I tried X" is banned unless the failure is a watch-for.
- **Absolutes:** absolute dates and paths always — never "today", "this file", "the repo".
- **Budget:** target ≤600 words. Over 1000 = scope too big — split into two files by thread and say so.
- **[user] markers:** every human decision tagged. Fresh agent must not relitigate them.

## Integrity gates (before saving)

1. Verify every cited `path:line` exists (open the file with whatever read tool the harness has) — no hallucinated refs handed forward.
2. No secret values anywhere — locations only.
3. Claims not verified this session carry `(unverified)`.
4. Completeness sweep: reread the in-scope conversation; anything discussed that changes next-agent behavior but is missing from the file gets added or consciously dropped. Then save.

## Boundaries

- Not orca-cli full handoff (live terminal ownership transfer). Not memory (durable cross-project facts — write those separately if the session produced any). Not visual-recap (diff presentation). (Those three are Claude-side lanes; from other harnesses this skill is simply the handoff mechanism.)
- Next steps must name commands/paths, never harness-specific tool or agent names ("run visual-qa" → "verify in browser at <url>, checking <criteria>").
- Writes exactly one file; installs nothing, schedules nothing.
