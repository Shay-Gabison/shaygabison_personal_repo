# Spec-Driven Development

Guides AI assistants through implementing Azure DevOps work items using a structured, approval-gated workflow with planning, implementation, and completion phases.

## What it does

- **Plans** — Reads the work item, proposes a design, gets your approval before writing code
- **Implements** — Creates branches, writes code, runs tests, asks approval before every commit and push
- **Closes** — Verifies PRs merged, updates ADO work item state, cleans up progress tracking

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## How to use

Just ask your AI assistant naturally:

> *"Let's work on work item 12345"*
> *"Implement ADO task 67890 using the spec-driven workflow"*
> *"Start spec-driven development for bug #111"*

The skill activates automatically and guides you through the entire workflow.

## Installation

```bash
./.ai-tools/install.sh --skill spec-driven-development
```

Then follow the configuration prompts, or ask your agent: *"configure spec-driven-development"*

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions |
| `docs/setup.md` | Configuration reference |
| `docs/WORKFLOW-GUIDE.md` | Full workflow overview |
| `reference/planning.md` | Planning phase details |
| `reference/implementation.md` | Implementation phase details |
| `reference/completion.md` | Completion phase details |
| `reference/ado-operations.md` | ADO MCP operation reference |
| `templates/spec-driven-config.md` | Project config template |
| `examples/spec-driven-config.example.md` | Example configuration |
