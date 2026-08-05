# PR Generator

Generates comprehensive pull request descriptions and creates PRs in Azure DevOps by analyzing git diffs.

## What it does

- Reads current `git diff` and extracts work item IDs from branch/commit history
- Generates a structured PR title and description
- Creates the PR in Azure DevOps via MCP tool

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## How to use

> *"Create a PR for my current changes"*
> *"Generate a pull request description"*
> *"Open a PR for work item 12345"*

## Installation

```bash
./.ai-tools/install.sh --skill pr-generator
```

Then follow the configuration prompts, or ask your agent: *"configure pr-generator"*

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions |
| `docs/setup.md` | Configuration reference |
| `templates/pr-generator-config.md` | Project config template |
| `templates/pull_request_template.md` | PR description template |
| `examples/pr-generator-config.example.md` | Example configuration |
