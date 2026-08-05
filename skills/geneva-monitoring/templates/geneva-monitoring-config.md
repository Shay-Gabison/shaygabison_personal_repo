# Geneva Monitoring Configuration

This file defines the project-specific Geneva (MDM) surface area used by the
`geneva-monitoring` skill. Fill in every `{{PLACEHOLDER}}` and remove the placeholder rows that
do not apply to your project.

## MCP Server

```
MCP Server Name: {{GENEVA_MCP_SERVER_NAME}}   # The key your Geneva MCP server is registered under in your agent host's MCP config (e.g. ./mcp.json for Copilot CLI, or VS Code Settings → "MCP" / .vscode/mcp.json). Typical: "geneva", "genevamonitor"
```

**To find your MCP server name**: open the MCP config used by your agent host —
`./mcp.json` in the repo root (Copilot CLI) or VS Code Settings → "MCP" / `.vscode/mcp.json` —
and use the exact key name as configured.

## Monitoring Accounts and Namespaces

Geneva data is spread across multiple **monitoring accounts**, each containing one or more
**namespaces**. The `tenantName` / `monitoringAccount` parameter in every Geneva MCP tool
refers to one of these accounts.

> Add one row per (account, namespace) pair the project actually queries. Drop rows that do
> not apply. Use this table to decide which `(account, namespace)` to point a metric / monitor
> lookup at — querying the wrong one returns empty data with no error.

| Account | Namespace | What lives here | When to use |
|---|---|---|---|
| `{{ACCOUNT_1}}` | `{{NAMESPACE_1}}` | {{WHAT_LIVES_HERE_1}} | {{WHEN_TO_USE_1}} |
| `{{ACCOUNT_1}}` | `{{NAMESPACE_2}}` | {{WHAT_LIVES_HERE_2}} | {{WHEN_TO_USE_2}} |

<!-- Add one row per (account, namespace) the project actually queries. Common
     categories teams add: container/pod infra metrics, cache (e.g. Redis) latency,
     JVM diagnostics, queue depth, custom business metrics. Drop the second row
     above if you only have one namespace. -->

> **Staging vs prod accounts.** Many teams have separate Geneva accounts per environment
> (e.g. an RS / staging account and one or more prod accounts; some also have a Gov
> account). Default to the prod account; only target the staging account when the
> investigation is specifically about pre-prod traffic.

## Well-Known Metrics (optional)

If the project has a small set of metrics queried often, list them here so the agent can pick
the right `(account, namespace, metric)` immediately.

```
- {{ACCOUNT}} / {{NAMESPACE}} / {{METRIC}}   # what it measures, when to use
- ...
```

## Common Dimensions

Dimensions you regularly filter on. Including the value vocabulary helps the agent build
correct `dimensionFilters` payloads without round-tripping through `metrics_get_metric_config`.

| Dimension | Meaning | Example values |
|---|---|---|
| `{{DIM_1}}` | {{DIM_1_MEANING}} | {{DIM_1_EXAMPLES}} |
| `{{DIM_2}}` | {{DIM_2_MEANING}} | {{DIM_2_EXAMPLES}} |
| `{{DIM_3}}` | {{DIM_3_MEANING}} | {{DIM_3_EXAMPLES}} |

## Notes

- Replace all `{{TEMPLATE_VARIABLES}}` with your actual values.
- Delete the Well-Known Metrics section if it does not apply rather than leaving it with
  placeholders.
- Keep this file next to the skill's `SKILL.md` (in the installed `templates/` directory) so the skill loads it automatically. `skills-config` writes back to this same path.
