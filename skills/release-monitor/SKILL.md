---
name: release-monitor
description: 'Monitor ADO pipeline builds for approval gates, extract the OneBranch approval link, and send a release-approval notification to Teams. Automates the workflow of polling the build timeline, finding the "Waiting for Approval" task log, and posting the formatted approval message.'
---

# Release Monitor Skill

Monitor an ADO pipeline build through its approval gate, extract the approval link, and send a formatted notification to the `release-approval` Teams channel.

## Quick Start

```bash
~/.copilot/skills/release-monitor/monitor-and-notify.sh <buildId>
```

The script will:
1. Fetch build info and validate it's still running
2. Poll the build timeline every 30s looking for `*_APPROVAL` stages
3. Find the **"Waiting for Approval"** task and read its log
4. Extract the `https://approval.azengsys.com/approvalRequest?id=...` URL and expiration
5. Send a formatted message to the `release-approval` Teams channel (via teams-sender)

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--project <name>` | `MCAS` | ADO project |
| `--org <name>` | `msazure` | ADO organization |
| `--title <text>` | auto from build name | Short title for the notification |
| `--target <alias>` | `release-approval` | Teams channel alias |
| `--poll-interval <sec>` | `30` | Seconds between polls |
| `--max-wait <sec>` | `1800` | Max seconds to wait (30 min) |
| `--dry-run` | — | Extract link but don't send to Teams |

## Examples

```bash
# Basic — monitor and send approval notification
~/.copilot/skills/release-monitor/monitor-and-notify.sh 160534110

# With a custom title
~/.copilot/skills/release-monitor/monitor-and-notify.sh 160534110 --title "Fix cross-tenant auth trigger"

# Dry run — just extract the link without posting
~/.copilot/skills/release-monitor/monitor-and-notify.sh 160534110 --dry-run

# Send to a different Teams channel
~/.copilot/skills/release-monitor/monitor-and-notify.sh 160534110 --target pr-review
```

## Agent Workflow (without the script)

If you need more control or the script isn't suitable, here's how to do it manually with ADO MCP tools:

### 1. Poll for the approval stage

Call the build timeline API repeatedly:
```
GET https://dev.azure.com/msazure/MCAS/_apis/build/builds/{buildId}/timeline?api-version=7.0
```

Look for a **Stage** record with `APPROVAL` in its name (e.g., `FAIRFAX_APPROVAL`, `STG_APPROVAL`, `PRD_APPROVAL`).

### 2. Find the "Waiting for Approval" task

Within the approval stage's descendants, find the task named **"Waiting for Approval"** (NOT "Approval service"). It has the actual approval URL in its log.

- When this task has `state: "completed"` and a `log.id`, the URL is ready.
- The "Approval service" task may still be `pending` — that's normal.

### 3. Read the task log

```
get_build_log_by_id(project="MCAS", buildId=<ID>, logId=<logId>)
```

Extract from the log content:
- **URL**: `Please approve release from https://approval.azengsys.com/approvalRequest?id=<GUID>`
- **Expiry**: `Approval Task will expire on <date>`

### 4. Send the Teams notification

Use the teams-sender skill:
```bash
~/.copilot/skills/teams-sender/send-message.sh release-approval "<message>"
```

### Message format

```
🚀 <component> <ENV> Release Approval

Build: <build_number>
🔗 Build: <build_url>
👉 Approve Here: <approval_link>
⏰ Approval expires: <date>
```

The `release-approval` alias automatically @mentions the channel so all members get notified.

## Key Technical Details

- **Timeline API hierarchy**: Stage → Phase → Job → Task. Use `parentId` to walk the tree.
- **The "Waiting for Approval" task** (not "Approval service") contains the URL.
- Build logs from `get_build_log` don't include task names — correlate via the timeline.
- Environment is auto-detected from the approval stage name: `FAIRFAX_APPROVAL` → `FF`, `STG_APPROVAL` → `STG`, etc.
- Script auto-generates a clean title from the build name if `--title` is not provided.

## Prerequisites

- Azure CLI logged in (`az account get-access-token` must work for ADO)
- teams-sender skill installed at `~/.copilot/skills/teams-sender/`
