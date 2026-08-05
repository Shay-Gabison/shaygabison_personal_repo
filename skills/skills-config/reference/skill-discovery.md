# Skill Discovery

When the prompt does not specify where skills were installed, or when skills cannot be found at the provided path, search **all** of the following locations:

| Path | Description |
|------|-------------|
| `skills/*/SKILL.md` | Source skills (this repo / submodule root) |
| `.github/skills/*/SKILL.md` | GitHub Copilot — installed symlinks |
| `.agents/skills/*/SKILL.md` | Cross-agent standard (agentskills.io) |
| `.cline/skills/*/SKILL.md` | Cline — installed symlinks |
| `.claude/skills/*/SKILL.md` | Claude — installed symlinks |
| `.cursor/skills/*/SKILL.md` | Cursor — installed symlinks |
| `~/.copilot/pkg/universal/*/skills/*/SKILL.md` | Copilot CLI installed plugins (if any) |
| `~/.copilot/pkg/darwin-arm64/*/skills/*/SKILL.md` | Copilot CLI platform plugins (if any) |
| `~/.copilot/skills/*/SKILL.md` | Personal Copilot skills |
| `~/.claude/skills/*/SKILL.md` | Personal Claude skills |

> **Note:** Many of the above paths contain symlinks created by `install.sh`.
> When globbing, follow symlinks to resolve SKILL.md files.

If a glob returns no results but a directory listing shows skill subdirectories exist, fall back to direct path reads (e.g. `cat .github/skills/<name>/SKILL.md`).
