---
name: teams-notifications
description: >
  Use this skill when the user wants to notify a Microsoft Teams channel or chat about a
  development event — even if they just say "tell the team", "post in Teams", or "send an update".
  Use it for PR announcements, build results, deployment notices, or any formatted message to a
  Teams destination. Do not use if the destination is Slack, email, or another channel.
---

# Teams Notifications

## Setup
For first-time configuration, follow [docs/setup.md](docs/setup.md).

## Available Scripts

- **`scripts/Send-PRTeamsNotification.ps1`** — Posts a formatted Adaptive Card to a Teams channel or chat via Microsoft Graph API. Accepts `-DryRun` to preview without sending.

## Steps to Execute

1. Generate a concise notification message (see format below)
2. Run [scripts/Send-PRTeamsNotification.ps1](scripts/Send-PRTeamsNotification.ps1)

## Message Format

```
<emoji> **<PR title>**

👤 Author: <author>
📋 Type: <change type>
🔗 Work Items: #<id>

<1–2 sentence summary>
<call to action>
```

**Emojis:** 🐛 bugfix · ✨ feature · 🔒 security · ⚡ perf · 📝 docs · ⚙️ config · 🔧 build · ✅ tests · ♻️ refactor · ⚠️ breaking · 🔥 urgent

## Run Script

```powershell
# Normal run
scripts/Send-PRTeamsNotification.ps1 `
    -PullRequestId <id> `
    -Message $generatedMessage `
    -Destination PRChannel

# Dry run — previews payload without sending
scripts/Send-PRTeamsNotification.ps1 `
    -PullRequestId <id> `
    -Message $generatedMessage `
    -Destination PRChannel `
    -DryRun
```

Config template: [templates/Send-PRTeamsNotification.config.ps1](templates/Send-PRTeamsNotification.config.ps1)

## Constraints
- Keep messages under 200 words
- Always include author, type, and work item links
- Mark breaking changes and urgent PRs clearly
