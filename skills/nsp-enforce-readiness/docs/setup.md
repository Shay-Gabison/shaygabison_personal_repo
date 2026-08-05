# Setup: nsp-enforce-readiness

This skill reads NSP access logs from Kusto. It needs a Kusto/ADX MCP wired into your agent
plus network + auth access to the per-RP NSP access-log clusters.

## Prerequisites

- **Azure VPN connected.** The NSP access-log clusters are internal-only.
- **Azure CLI** installed and authenticated: `az login` (correct tenant).
- **Kusto Database Viewer** (or higher) on the per-RP NSP access-log clusters you target
  (Storage / Cosmos / SQL / Key Vault).

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

**Verify:** ask your agent to run a trivial query (`print 'ok'`) against one of the NSP
access-log clusters — if the MCP is wired up it returns a result.

## 2. Inputs you provide at runtime

| Input | Example | Notes |
|-------|---------|-------|
| **NSP ARM ID** | `/subscriptions/…/providers/Microsoft.Network/networkSecurityPerimeters/<name>` | Required |
| **Lookup window** | `7d` (default), `30d` for cautious services | KQL timespan |

No project-local config file is required — the skill derives the correct RP access-log
cluster from the resource type in the logs.

## Reference

- TSG overview: https://aka.ms/ns221tsg
- Enforced mode: https://aka.ms/ns221enforced
- Logging: https://aka.ms/ns221logging
- Traffic Analysis Tool: https://aka.ms/NSPTrafficAnalysis
