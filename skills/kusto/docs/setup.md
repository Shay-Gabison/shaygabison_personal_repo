# Setup: kusto

This skill needs two things:

1. The **Azure MCP** wired into your AI agent (provides the `azure-kusto kusto_query` tool).
2. Two project-local config files populated for your team:
   - [`../templates/kusto-config.md`](../templates/kusto-config.md) — clusters, databases,
     tables, dimension columns. Always loaded.
   - [`../templates/kusto-queries.md`](../templates/kusto-queries.md) — saved KQL corpus.
     Loaded only when the ask needs query inspiration.

## Prerequisites

- **Azure VPN connected.** Most internal Kusto clusters are only reachable over the
  corporate VPN; queries fail with opaque auth/network errors otherwise.
- **Azure CLI** installed and authenticated: `az login`. The Azure MCP uses these
  credentials by default.
- **Permission** (Database Viewer or higher) on every cluster you'll target.

## 1. Install the Azure MCP

If you don't already have the Azure MCP wired up, add it to your agent's MCP config.

**`~/.copilot/mcp-config.json`** (Copilot CLI):

```json
{
  "mcpServers": {
    "azure": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@azure/mcp@latest", "server", "start"],
      "tools": ["*"]
    }
  }
}
```

For Claude Desktop, Cline, or Cursor, register the same `npx -y @azure/mcp@latest server start`
command in their MCP settings.

**Verify:** ask your agent "list kusto databases on cluster X" — if the MCP is wired
up, it will respond with a database list.

## 2. Populate the templates

Run `skills-config` (or ask your agent to "configure the kusto skill"). It walks you
through both template files; each `{{PLACEHOLDER}}` has an inline comment explaining
what the value is and where to find it.

When configuring `kusto`, `skills-config` should use this order:

1. **Scan workspace for KQL/MD files first** — searches your current workspace recursively for
   `.kql` / `.csl` files, ` ```kusto ` fenced blocks in markdown, and cluster URIs in
   config files (`appsettings*.json`, Helm values, etc), then proposes a draft.
   The following paths are excluded to avoid false positives from skill files:
   - `**/skills/kusto/library/**`
   - `**/skills/kusto/templates/**`
   - `**/skills/kusto/docs/**`
   - `**/skills/*/templates/**`
   - `**/node_modules/**`
2. **If scan is empty/partial, ask to paste queries** — paste raw KQL (for example copied
   from Azure Data Explorer) and/or Kusto "Share query" URLs.
3. **Manual last** — enter values directly only for placeholders still missing.

For each pasted query, `skills-config` should ask only one extra question:
- **When should this query be used?** (short trigger/intent)

`skills-config` should infer everything else from the query when possible
(clusters, database, table hints, time window) and auto-generate a short title.

After saving a pasted query, `skills-config` should ask whether to add another query
or finish.

If scan/paste does not provide all values, `skills-config` asks only for the remaining
placeholders.

Saved queries can be supplied as raw KQL, a file path, or a Kusto "Share query" URL
(the agent decodes the gzip+base64url `query` parameter).

> **Cross-team queries ship with the skill.** Common queries (gru flag lookups,
> tenant lookups etc) and a list of well-known MDA clusters
> live in [`../library/`](../library/). You don't configure them — the skill
> reads them alongside your `templates/` at runtime. Updates arrive via plugin
> updates; no re-running `skills-config` needed.
