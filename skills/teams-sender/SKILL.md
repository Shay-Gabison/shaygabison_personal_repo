---
name: teams-sender
description: 'Send Microsoft Teams notifications to multiple Teams channels using Microsoft Graph API (`az rest`). Supports built-in channel aliases, direct Teams channel URLs, and cached custom aliases for faster repeated sends. Personal/group/meeting chat messages are not supported in this tenant policy context.'
---

# Teams Sender Skill

This skill sends notifications to Teams channels via Azure CLI (`az rest`).

## Prerequisites

**Important:** You must be logged into Azure CLI with the required Microsoft Graph permissions (`Chat.ReadWrite`, `ChannelMessage.Send`).

Run this command to login with the correct scopes:

```bash
az login --scope https://graph.microsoft.com/Chat.ReadWrite https://graph.microsoft.com/ChannelMessage.Send https://graph.microsoft.com/User.Read
```

If you get `AADSTS65002`, your tenant blocks Azure CLI from requesting chat scopes. In this tenant:
- channel notifications work
- personal/group/meeting chat targets are blocked and not supported by this skill

## Usage

You can send notifications by:
1. built-in aliases
2. a Teams channel URL
   - supports both `/l/channel/...` links and channel message links (`/l/message/...`) when `groupId` is present
3. a cached custom alias

### Targets

### Built-in targets

Under **MDA Platform Axon** team:
- `daily`
- `on-call`
- `pr-review` (also supports alias `pr-reviewers`)
- `tenant-mgmt` (also supports alias `tenant-management`)
- `release-approval` (also supports alias `release-approvals`) — auto-tags @Release approvals channel on every post

Under **Defender for Cloud Apps** team:
- `platform-axon-support` (also supports alias `defender-axon-support`)

### Commands

Run the script directly:

```bash
./scripts/send-message.sh <target_or_teams_channel_url> "<message>"
```

Cache frequently used channels:

```bash
./scripts/send-message.sh cache-add <alias> "<teams_channel_url>"
./scripts/send-message.sh cache-list
```

For unknown channels, use WorkIQ to find a Teams channel deep-link and then either:
- send directly with that URL, or
- cache it with `cache-add` for faster future use.

## Examples

**Send to PR Review channel:**
```bash
./scripts/send-message.sh pr-review "Please review my latest PR."
```

**Send to Tenant Management channel:**
```bash
./scripts/send-message.sh tenant-mgmt "Tenant 123 provisioned successfully."
```

**Send using a direct Teams channel URL:**
```bash
./scripts/send-message.sh "https://teams.microsoft.com/l/channel/19%3A...%40thread.tacv2/ChannelName?groupId=...&tenantId=..." "Message text"
```

**Cache a custom channel alias and use it later:**
```bash
./scripts/send-message.sh cache-add defender-ops "https://teams.microsoft.com/l/channel/19%3A.../Ops?groupId=...&tenantId=..."
./scripts/send-message.sh defender-ops "Investigating incident 123."
```

**Use WorkIQ to discover a missing channel and then cache it:**
```bash
# 1) Ask WorkIQ for the channel deep-link (for example: Defender for Cloud Apps Ops)
# 2) Cache the returned URL
./scripts/send-message.sh cache-add defender-ops "https://teams.microsoft.com/l/message/19:...@thread.skype/...?...&groupId=7544b4bb-29df-48d3-a90d-eb835f1124a6"
# 3) Send quickly by alias
./scripts/send-message.sh defender-ops "Please check the latest Ops alert."
```

## Sending 1:1 Messages with Clickable Links (via Teams MCP)

When you need to send a message **to an individual user** (not a channel), use the Teams MCP tools (`PostMessage`, `CreateChat`, etc.) instead of `az rest`.

### Making links clickable

**Always use Adaptive Cards** for messages containing links. Plain text URLs and HTML `<a href>` tags do NOT render as clickable links in Teams Graph API messages.

Use the `adaptiveCardJson` parameter on `PostMessage` with `Action.OpenUrl` buttons:

```json
{
  "body": [
    { "type": "TextBlock", "text": "Title Here", "weight": "Bolder", "size": "Medium" },
    { "type": "TextBlock", "text": "Description or context", "spacing": "Small" }
  ],
  "actions": [
    { "type": "Action.OpenUrl", "title": "Link Label 1", "url": "https://..." },
    { "type": "Action.OpenUrl", "title": "Link Label 2", "url": "https://..." }
  ]
}
```

Set the `content` parameter to a plain-text fallback (e.g. the message title).

### Workflow

1. Look up the user with `GetMultipleUsersDetails` or `SearchUserTools` to get their email/UPN
2. `CreateChat` with `chatType: "oneOnOne"` and the user's UPN → returns `chatId`
3. `PostMessage` with the `chatId` and `adaptiveCardJson` containing `Action.OpenUrl` buttons

## Release Approval Workflow

When posting a release approval request to the `release-approval` channel, you need the **OneBranch Approval Service** link from the pipeline logs. Here's how to find it:

### How to find the Approval Service link

1. **Get the build timeline** — query the ADO build timeline API to list all stages, jobs, and tasks:
   - Look for a **Phase** or **Job** named `ApprovalService` (state: `pending`)
   - Look for a **Task** named `Approval service` or `Waiting for Approval`

2. **Read the "Waiting for Approval" task log** — this task (not the "Approval service" task itself) contains the actual approval URL. In the build logs list, find the log ID for the task named "Waiting for Approval" and read it. The log content will say:
   ```
   Please approve release from https://approval.azengsys.com/approvalRequest?id=<GUID>
   Approval Task will expire on <date>
   ```

3. **The approval link format is:**
   ```
   https://approval.azengsys.com/approvalRequest?id=<GUID>
   ```

### Step-by-step with ADO MCP tools

```
1. get_build_log(project="MCAS", buildId=<ID>)
   → Scan the log list for entries with task name "Waiting for Approval"
   → Note its logId (e.g. logId=18)

2. get_build_log_by_id(project="MCAS", buildId=<ID>, logId=<ID>)
   → Extract the URL: https://approval.azengsys.com/approvalRequest?id=...
   → Extract the expiration date
```

### Composing the message

Keep it short — title should include only the most notable/recent change:

```
🚀 TenantService Release Approval Request - <main change summary>

Build: <build_number> (link to build results)
👉 Approve Here: <approval.azengsys.com link>
⏰ Approval expires: <date>
```

The `release-approval` alias automatically @mentions the channel so all members get notified.
