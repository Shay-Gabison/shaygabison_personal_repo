---
name: ado-workitems
description: "Query and manage Azure DevOps work items for the MCAS project. Use when scanning backlog, triaging work items, creating user stories, or querying ADO state. Covers WIQL queries, work item updates, tag management, and iteration path handling."
domain: "project-management"
confidence: "high"
---

# ADO Work Items Skill

Query and manage Azure DevOps work items for the MCAS project using `az boards` CLI or the ADO MCP server.

## When to Use This Skill

- Scanning backlog items to triage
- Creating new work items (User Stories, Bugs, Tasks)
- Updating work item state, tags, or assignments
- Querying work items by area path, iteration, or tags

## ADO Configuration

- **Org:** msazure
- **Project:** MCAS
- **Default type:** User Story
- **Area path:** MCAS\Platform\Axon (adjust for your team)
- **Iteration:** Set per sprint cycle (e.g., `MCAS\FY26H2\FY26Q3\Iterations\Iteration NNN`)

## Common WIQL Queries

### All open items in current iteration
```
az boards query --wiql "SELECT [System.Id],[System.Title],[System.State],[System.AssignedTo],[System.Tags] FROM WorkItems WHERE [System.AreaPath] UNDER 'MCAS\\Platform\\Axon' AND [System.IterationPath] = '{CURRENT_ITERATION}' AND [System.State] <> 'Closed' AND [System.State] <> 'Removed' ORDER BY [Microsoft.VSTS.Common.Priority] ASC"
```

### Untriaged items with a specific tag
```
az boards query --wiql "SELECT [System.Id],[System.Title],[System.Tags] FROM WorkItems WHERE [System.Tags] Contains '{TAG}' AND [System.State] <> 'Closed'"
```

### Items assigned to a team member
```
az boards query --wiql "SELECT [System.Id],[System.Title],[System.State] FROM WorkItems WHERE [System.AssignedTo] = '{MEMBER_EMAIL}' AND [System.State] <> 'Closed'"
```

## Creating Work Items

```bash
az boards work-item create \
  --type "User Story" \
  --title "Title here" \
  --area "MCAS\\Platform\\Axon" \
  --iteration "{CURRENT_ITERATION}" \
  --fields "System.Tags=tag1;tag2"
```

## Updating Tags

```bash
# Get current tags first
az boards work-item show --id {ID} --fields "System.Tags" --query "fields.\"System.Tags\""

# Update with new tags (append to existing)
az boards work-item update --id {ID} --fields "System.Tags=existing;newtag1;newtag2"
```

## MCP Alternative

If the ADO MCP server is running, use the ADO MCP tools instead of CLI for richer API access.
