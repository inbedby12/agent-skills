# agent-skills

Three portable [Agent Skills](https://agentskills.io) for Claude Code, Codex CLI, and any harness that reads the SKILL.md spec.

| Skill | What it does |
|---|---|
| **usage-pacer** | Calculates the minimum % of each 5-hour Claude usage window you must burn to max your weekly limit before it resets. Live data from the same endpoint `/usage` reads; self-calibrates across invocations. Read-only. |
| **handoff** | Writes one compressed, self-contained handoff file so a fresh session — any agent, zero shared context — resumes your work seamlessly. Fixed 8-section template, integrity gates, `[user]` decision markers. |
| **resume-last-session** | Finds the most recent prior session recorded for the current directory — across both Claude Code (`~/.claude/projects/`) and Codex (`~/.codex/sessions/`) stores — summarizes where it stopped, and continues that work in the current session. Ships a cross-store finder script. |

## Install

With the [skills CLI](https://skills.sh) (works for Claude Code, Codex, and friends — pick the skills in the prompt):

```sh
npx skills add inbedby12/agent-skills
```

Manual — Claude Code:

```sh
git clone --depth 1 https://github.com/inbedby12/agent-skills /tmp/agent-skills
cp -R /tmp/agent-skills/skills/usage-pacer /tmp/agent-skills/skills/handoff /tmp/agent-skills/skills/resume-last-session ~/.claude/skills/
```

Manual — Codex CLI / any agentskills.io-compatible harness:

```sh
git clone --depth 1 https://github.com/inbedby12/agent-skills /tmp/agent-skills
mkdir -p ~/.agents/skills
cp -R /tmp/agent-skills/skills/usage-pacer /tmp/agent-skills/skills/handoff /tmp/agent-skills/skills/resume-last-session ~/.agents/skills/
```

All skills are explicit-invoke: `/usage-pacer`, `/handoff [topic]`, `/resume-last-session` (or ask for them by name).

## Notes

- **usage-pacer** measures a **Claude** account (any plan with 5-hour + weekly limits). Reads your existing Claude Code OAuth credential from the macOS Keychain (`Claude Code-credentials`) or `~/.claude/.credentials.json`; the token never leaves your machine and is never written anywhere. Needs `bash`, `curl`, `python3`. If the (undocumented) usage endpoint ever changes, the skill falls back to numbers you paste from `/usage`.
- **handoff** is fully harness-neutral: a handoff written from Claude Code can be picked up by Codex and vice versa. Non-repo handoffs land in `~/.agents/handoffs/`.
- **resume-last-session** is the inverse of handoff: no handoff file needed — it reconstructs state straight from the last transcript. Its finder verifies the `cwd` recorded inside each session file (directory-name munging collides), excludes the currently running session, and merges both harness stores ranked by recency. Needs `python3`.
- License: MIT
