# agent-skills

Two portable [Agent Skills](https://agentskills.io) for Claude Code, Codex CLI, and any harness that reads the SKILL.md spec.

| Skill | What it does |
|---|---|
| **usage-pacer** | Calculates the minimum % of each 5-hour Claude usage window you must burn to max your weekly limit before it resets. Live data from the same endpoint `/usage` reads; self-calibrates across invocations. Read-only. |
| **handoff** | Writes one compressed, self-contained handoff file so a fresh session — any agent, zero shared context — resumes your work seamlessly. Fixed 8-section template, integrity gates, `[user]` decision markers. |

## Install

With the [skills CLI](https://skills.sh) (works for Claude Code, Codex, and friends — pick the skills in the prompt):

```sh
npx skills add inbedby12/agent-skills
```

Manual — Claude Code:

```sh
git clone --depth 1 https://github.com/inbedby12/agent-skills /tmp/agent-skills
cp -R /tmp/agent-skills/skills/usage-pacer /tmp/agent-skills/skills/handoff ~/.claude/skills/
```

Manual — Codex CLI / any agentskills.io-compatible harness:

```sh
git clone --depth 1 https://github.com/inbedby12/agent-skills /tmp/agent-skills
mkdir -p ~/.agents/skills
cp -R /tmp/agent-skills/skills/usage-pacer /tmp/agent-skills/skills/handoff ~/.agents/skills/
```

Both skills are explicit-invoke: `/usage-pacer` and `/handoff [topic]` (or ask for them by name).

## Notes

- **usage-pacer** measures a **Claude** account (any plan with 5-hour + weekly limits). Reads your existing Claude Code OAuth credential from the macOS Keychain (`Claude Code-credentials`) or `~/.claude/.credentials.json`; the token never leaves your machine and is never written anywhere. Needs `bash`, `curl`, `python3`. If the (undocumented) usage endpoint ever changes, the skill falls back to numbers you paste from `/usage`.
- **handoff** is fully harness-neutral: a handoff written from Claude Code can be picked up by Codex and vice versa. Non-repo handoffs land in `~/.agents/handoffs/`.
- License: MIT
