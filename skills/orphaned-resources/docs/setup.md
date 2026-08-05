# Setup: orphaned-resources

This skill runs read-only Kusto queries against IPAM and Azure Resource Graph. It needs a
Kusto/ADX MCP wired into your agent plus network + auth access to those clusters.

## Prerequisites

- **Azure VPN connected.** IPAM and ARG clusters are internal-only.
- **Azure CLI** installed and authenticated: `az login` (correct tenant). Optionally used to
  enrich subscription IDs into names (`az account show --subscription <ID> --query name -o tsv`).
- **Kusto Database Viewer** (or higher) on the IPAM and Azure Resource Graph clusters.

## 1. Install a Kusto MCP

If you don't already have a Kusto query tool wired up, add the Azure MCP to your agent.

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

For Claude Desktop, Cline, or Cursor, register the same
`npx -y @azure/mcp@latest server start` command in their MCP settings.

**Verify:** ask your agent to run a trivial query against the IPAM cluster — if the MCP is
wired up it returns a result.

## 2. Configuration

No project-local config file is required. The ServiceTree service IDs used for subscription
discovery and the cluster URIs are documented inline in `SKILL.md`. Adjust the service IDs in
the query if your team owns different ServiceTree services.
