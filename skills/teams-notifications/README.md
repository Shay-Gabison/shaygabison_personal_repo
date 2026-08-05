# Teams Notifications

Generates and sends Microsoft Teams notifications about pull requests using PowerShell and the Microsoft Graph API.

## What it does

- Generates a concise, emoji-formatted Teams message summarizing the PR
- Sends it to configured Teams channels or chats via `Send-PRTeamsNotification.ps1`

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## How to use

> *"Send a Teams notification for PR #123"*
> *"Notify the team about the new pull request"*
> *"Post PR update to Teams"*

## Installation

```bash
./.ai-tools/install.sh --skill teams-notifications
```

Then follow the configuration prompts, or ask your agent: *"configure teams-notifications"*

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- PowerShell 5.1+ or PowerShell Core
- Permission to post to target Teams channel/chat

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions |
| `docs/setup.md` | Configuration reference |
| `scripts/Send-PRTeamsNotification.ps1` | PowerShell notification script |
| `templates/Send-PRTeamsNotification.config.ps1` | Teams destinations config template |
