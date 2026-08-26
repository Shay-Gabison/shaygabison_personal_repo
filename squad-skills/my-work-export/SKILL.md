---
name: my-work-export
description: "Export all PRs and work items for a person in a given date range. Use when someone says 'show my work', 'export PRs and work items', 'what did I do since', 'my contributions', 'show work for period', or 'activity report'. Asks for start date and optional person alias, then queries ADO for PRs created/completed and work items changed in that period."
domain: "productivity"
confidence: "high"
---

# My Work Export

Export all Pull Requests and Work Items for a person from a given start date until today. Designed so any colleague can run it to see their own (or someone else's) contributions in a specific period.

## When to Use This Skill

- "Show my work since July 1st"
- "Export PRs and work items for the last month"
- "What did I do since the start of the sprint?"
- "Show shaygabison's contributions since 2026-08-01"
- "Activity report for the last 2 weeks"
- "Export my work for my manager"

## Prerequisites

- **ADO MCP server**: Must be configured (`ado-*` or `github-com-microsoft-azure-devops-mcp-*` tools available)
- The user's ADO alias or email (will prompt if not provided)

## Execution Steps

### 1. Gather Parameters

Ask the user (use the `ask_user` tool) for:

| Parameter | Required | Default |
|-----------|----------|---------|
| **Start date** | Yes | — |
| **Person alias or email** | No | Current user (`@me`) |
| **Project** | No | All projects the user has access to |

Format the start date as ISO-8601 (e.g., `2026-08-01`).

### 2. Query Pull Requests

Use the ADO MCP tool `repo_pull_request` (search for it) to find PRs where the person is the creator.

Search with parameters:
- **creatorId**: The person's alias/email or `@me`
- **status**: `all` (to include Active, Completed, Abandoned)
- **minTime** / date filter: The start date provided

If the tool doesn't support date filtering directly, retrieve recent PRs and filter client-side by `creationDate >= startDate`.

Collect for each PR:
- PR ID and title
- Repository name
- Status (Active / Completed / Abandoned)
- Creation date
- Completion date (if completed)
- URL link

### 3. Query Work Items

Use the ADO MCP tool `wit_query` to run a WIQL query:

```wiql
SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State], [System.ChangedDate], [System.AssignedTo], [System.AreaPath]
FROM WorkItems
WHERE [System.ChangedDate] >= '<start_date>'
  AND [System.AssignedTo] = '<person_alias_or_@me>'
ORDER BY [System.ChangedDate] DESC
```

If querying across all projects, use the project-scoped query endpoint for each relevant project, or use `search_workitem` as a fallback.

Collect for each work item:
- ID and title
- Type (Bug, Task, User Story, Feature)
- State (New, Active, Resolved, Closed)
- Area path
- Changed date

### 4. Present Results

Format output as a clean summary:

```
📊 Work Report for <Person> — <start_date> to today (<end_date>)
═══════════════════════════════════════════════════════════════

🔀 PULL REQUESTS (<count>)
──────────────────────────
✅ Completed: <N>
🔄 Active: <N>
❌ Abandoned: <N>

| # | Repository | Title | Status | Created | Completed |
|---|------------|-------|--------|---------|-----------|
| <id> | <repo> | <title> | <status> | <date> | <date> |
...

📋 WORK ITEMS (<count>)
───────────────────────
By Type:  🐛 Bugs: <N>  |  📖 Stories: <N>  |  ✅ Tasks: <N>  |  🎯 Features: <N>
By State: Active: <N>  |  Resolved: <N>  |  Closed: <N>

| ID | Type | Title | State | Area | Changed |
|----|------|-------|-------|------|---------|
| <id> | <type> | <title> | <state> | <area> | <date> |
...
```

### 5. Offer Export Options

After presenting, offer:
- "Want me to save this as a markdown file?"
- "Should I break this down by week?"
- "Want me to include PR review comments or work item details?"

## Tips for Best Results

- If querying a large time range (>3 months), results may be paginated — ensure all pages are fetched.
- For `@me` queries, the ADO MCP resolves to the authenticated user automatically.
- If the user provides just a first name or alias without domain, try `alias@microsoft.com` or search using `core_get_identity_ids` if available.

## Common Failure Patterns

| Pattern | Cause | Resolution |
|---------|-------|------------|
| No PRs found | Wrong alias or no PRs in period | Verify alias; try broader date range |
| WIQL query fails | Project scope missing | Specify project name explicitly |
| Permission denied | User lacks read access | Ensure the person running has access to the target project |
| Too many results | Very long date range | Narrow the date range or filter by project |

## Related Skills

- `pr-generator` — For creating new PRs
- `ado-workitems` — For detailed work item management
- `release-monitor` — For tracking deployment-related work
