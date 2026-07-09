# Agent Skills Library

Canonical, agent-agnostic skills for Codex, Claude Code, Gemini CLI, Grok Build, and any tool that reads the [Agent Skills](https://agentskills.io) `SKILL.md` layout.

```
skills/
  <skill-name>/
    SKILL.md          # required
    agents/           # optional (e.g. Codex openai.yaml)
    references/
    scripts/
```

## Install / sync to agents

From the dotfiles root:

```bash
# Preview
DRY_RUN=1 ./scripts/sync-skills/sync-skills.sh install all

# Symlink every skill into every agent
./scripts/sync-skills/sync-skills.sh install all

# One agent
./scripts/sync-skills/sync-skills.sh install codex
./scripts/sync-skills/sync-skills.sh install claude
./scripts/sync-skills/sync-skills.sh install gemini
./scripts/sync-skills/sync-skills.sh install grok
./scripts/sync-skills/sync-skills.sh install agents   # ~/.agents/skills (shared)

# Subset
./scripts/sync-skills/sync-skills.sh install claude log-search metric-search

# Status / list
./scripts/sync-skills/sync-skills.sh status
./scripts/sync-skills/sync-skills.sh list
```

Default mode is **symlink** (edit once in this repo, all agents see updates). Use `MODE=copy` if an agent does not follow symlinks.

| Agent  | Skills directory        |
|--------|-------------------------|
| codex  | `~/.codex/skills`       |
| claude | `~/.claude/skills`      |
| gemini | `~/.gemini/skills`      |
| grok   | `~/.grok/skills`        |
| agents | `~/.agents/skills`      |

## Secrets

Keep credentials in per-skill `.env` files (gitignored locally if needed). Never hardcode agent-home paths in `SKILL.md`; use paths relative to the skill directory.

## Related tools on GitHub

If you need a full GUI/marketplace (not just this library):

- [xingkongliang/skills-manager](https://github.com/xingkongliang/skills-manager) — desktop + CLI, 15+ agents
- `gh skill install … --agent …` — GitHub CLI skill install
- [slash9494/ai-config-sync-manager](https://github.com/slash9494/ai-config-sync-manager) — Claude ↔ Codex config sync
