---
name: resume-last-session
description: Use when the user explicitly invokes /resume-last-session or asks to find, identify, or pick up the last/previous session in the current directory. Explicit-invoke only — never auto-select. Works in both Claude Code and Codex CLI; finds the most recent prior session recorded for the working directory and resumes its work.
---

# Resume Last Session

Identify the most recent prior session recorded for the current directory (Claude Code or Codex CLI), reconstruct what it was doing, and continue that work in the current session.

## Session stores

| Harness | Location | Per-session file |
|---|---|---|
| Claude Code | `~/.claude/projects/<munged-dir>/` where munged-dir = absolute path with every non-alphanumeric char replaced by `-` (`/Users/x/my.app` → `-Users-x-my-app`) | `<session-uuid>.jsonl`; lines carry `cwd`, `sessionId`, `type` (`user`, `assistant`, `ai-title`, …) |
| Codex CLI | `~/.codex/sessions/YYYY/MM/DD/` | `rollout-<timestamp>-<uuid>.jsonl`; first line is `session_meta` with the session `id` and `cwd` |

## Steps

1. **Find candidates.** Run the bundled finder (works for both stores at once):

   ```sh
   python3 <skill-dir>/scripts/find_last_session.py [DIR] [--exclude CURRENT_SESSION_ID] [--limit N]
   ```

   Output: `HARNESS  SESSION_ID  MTIME  LINES  TITLE_OR_FIRST_PROMPT  PATH`, newest first. Exit 1 + `NO_SESSIONS_FOUND` when nothing matches — report that and stop.

2. **Exclude the current session.** The newest candidate is usually the session you are running in right now. Pass `--exclude` with the current session id when you know it (Claude Code: it appears in harness-provided paths like the scratchpad/transcript dir; Codex: the newest rollout whose `session_meta` matches this run). If you cannot determine it, treat the newest candidate as current when its first prompt is this skill invocation, and pick the next one.

3. **Reconstruct state from the transcript.** Read the target `.jsonl` selectively — first ~30 lines for the opening request, last ~150 lines for where it stopped (large transcripts; never read whole file blindly). Filter to lines with `"type":"user"` or `"type":"assistant"`; head and tail also contain bookkeeping records (`last-prompt`, `mode`, `permission-mode`, `file-history-*`) and command envelopes that are not conversation. Title: `grep '"ai-title"' FILE | tail -1` and read the `aiTitle` key. Extract: original goal, what was completed, what was in progress or promised next, files touched, unresolved errors.

4. **Confirm, then continue.** Report one short summary — "Last session (<title>, <mtime>): was doing X, stopped at Y" — and continue that work in the current session unless the user redirects. If several recent candidates look plausible (parallel sessions same day), list them and ask which one.

## Native CLI resume (alternative)

When the user would rather reopen the old session itself than continue in this one, give them the command — you cannot run it from inside a session:

- Claude Code: `claude --continue` (most recent in cwd) or `claude --resume <SESSION_ID>`
- Codex CLI: `codex resume --last` (most recent in cwd) or `codex resume <SESSION_ID>`; `codex resume` opens a picker filtered to cwd (`--all` lifts the filter)

## Common mistakes

- **Resuming the session you are in.** Newest file ≈ current session. Always exclude it (step 2).
- **Trusting the munged dir name alone.** `-` munging collides (`/a/b-c` vs `/a/b/c`); the finder verifies the `cwd` field inside each file — keep that check if you hand-roll commands.
- **Reading a whole transcript.** 800+ line files with embedded tool output flood context. Filtered head + tail is enough (step 3).
- **Assuming one harness.** Directory may have both Claude and Codex history; the finder merges both, ranked by mtime — pick by recency, not by which harness you are running in, and summarize/continue the work regardless of origin.
