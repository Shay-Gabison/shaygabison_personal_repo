# Configuration: geneva-monitoring

The install script copied [`templates/geneva-monitoring-config.md`](../templates/geneva-monitoring-config.md) into your installed skill directory. Follow the steps below to customize it for your project.

## Prerequisites

- **.NET 10 SDK** installed — `dotnet dnx` ships out-of-the-box with .NET 10 and is required to launch the Geneva Monitor MCP server. Verify with `dotnet --list-sdks`.
- **Access to the [`AzureGenevaMonitoring` NuGet feed](https://msblox.pkgs.visualstudio.com/_packaging/AzureGenevaMonitoring/nuget/v3/index.json)** on `msblox.pkgs.visualstudio.com`. First launch will run an interactive auth flow.
- **Geneva tenant access** for any monitoring accounts you intend to query.

## 0. MCP server setup

The geneva-monitoring skill requires a Geneva Monitor MCP server. Register it with your agent host:

- **VS Code** — `.vscode/mcp.json` in your repo, or VS Code User Settings → MCP. Uses the `servers` key.
- **Copilot CLI** — `./mcp.json` in your repo, or your user-level config (e.g. `~/.copilot/mcp-config.json` on Windows: `%USERPROFILE%\.copilot\mcp-config.json`). Uses the `mcpServers` key.

VS Code form:

```json
{
  "servers": {
    "{{GENEVA_MCP_SERVER_NAME}}": {
      "type": "stdio",
      "command": "dotnet",
      "args": [
        "dnx",
        "GenevaMonitoring.MCP.Server",
        "--source", "https://msblox.pkgs.visualstudio.com/_packaging/AzureGenevaMonitoring/nuget/v3/index.json",
        "--interactive",
        "--yes",
        "--",
        "--stdio"
      ]
    }
  }
}
```

Copilot CLI form (same server definition, different top-level key):

```json
{
  "mcpServers": {
    "{{GENEVA_MCP_SERVER_NAME}}": {
      "type": "stdio",
      "command": "dotnet",
      "args": [
        "dnx",
        "GenevaMonitoring.MCP.Server",
        "--source", "https://msblox.pkgs.visualstudio.com/_packaging/AzureGenevaMonitoring/nuget/v3/index.json",
        "--interactive",
        "--yes",
        "--",
        "--stdio"
      ]
    }
  }
}
```

After adding, your agent host will start the server (VS Code prompts; Copilot CLI starts it on next session). Verify it's running by asking the agent to `list monitoring accounts` — it should return your Geneva tenant names.

## 1. Identify your Geneva surface area

Before filling the template, gather:

1. **MCP server name** — the key the Geneva MCP server is registered under in your agent host's MCP config (e.g. `./mcp.json` in the repo root for Copilot CLI, or VS Code Settings → "MCP" / `.vscode/mcp.json`). Replace `{{GENEVA_MCP_SERVER_NAME}}` in the snippets above with a name of your choice (common values: `geneva`, `genevamonitor`, `GenevaMonitoringMCP`). Your `geneva-monitoring-config.md` must use the same name.
2. **Monitoring accounts** your team queries. Run `tenant_get_all_names` against the MCP server (or use the Geneva web portal) to confirm exact casing.
3. **Namespaces in each account** — for each account, run `metrics_get_namespaces(tenantName = <account>)` and pick the ones your project owns or reads from.

## 2. Fill the template

Open [`geneva-monitoring-config.md`](../templates/geneva-monitoring-config.md) and replace every `{{PLACEHOLDER}}` with a real value. Each placeholder has an inline comment explaining its meaning.

For each (account, namespace) row in the table, write:

- **What lives here** — one short phrase describing the data category (e.g. "Worker JVM diagnostics", "K8s alerts and throttling", "Redis latency and errors").
- **When to use** — when the agent should reach for this row instead of others.

Drop rows that do not apply to your project rather than leaving them with placeholders.

## 3. Optional sections

The following sections are optional — delete them entirely if they don't apply:

- **Account aliases** — only if your team uses short internal names for accounts.
- **Common Dimensions** — most useful when there's a well-known set of dimensions the agent will filter on repeatedly. List the value vocabulary so the agent can build correct `dimensionFilters` payloads without first calling `metrics_get_metric_config`.
- **Resource Naming Patterns** — if you generate resource names (Redis caches, storage accounts) from a template based on region/env, document the template so the agent can map region → resource name automatically.
- **Well-Known Metrics** — a short cheat-sheet of the metrics most often queried.

## 4. Verify

After saving, ask the agent something like:

> "Using geneva-monitoring, list the namespaces in `<one of your accounts>`."

The agent should:
1. Read your `geneva-monitoring-config.md`.
2. Pick the right MCP server name from the config.
3. Call `metrics_get_namespaces` against the account.

If the agent can't find the config, make sure `geneva-monitoring-config.md` sits next to the skill's `SKILL.md` in your installed skill directory.

## 5. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Geneva MCP tools fail with connection / transport / "server not running" errors | .NET 10 SDK not installed, or `dotnet` not on PATH | Install the .NET 10 SDK and verify with `dotnet --list-sdks`. `dnx` ships with the SDK; no separate install is needed. |
| First-run hangs or fails with a NuGet auth / 401 error | Interactive auth against `msblox.pkgs.visualstudio.com` hasn't been completed | Launch the server once from a terminal so the device-code / browser prompt is visible, complete the auth, then restart the agent host. |
| Agent can't find the Geneva MCP server at all | Server not registered with the agent host, or the key in your config doesn't match the key in `mcp.json` | Re-check the `mcp.json` snippet in section 0. VS Code uses the `servers` key; Copilot CLI uses `mcpServers`. The key you chose for `{{GENEVA_MCP_SERVER_NAME}}` must match the `MCP Server Name` field in your `geneva-monitoring-config.md`. |
| Tool calls fail with "forbidden" / "unauthorized" against a specific account | Your AAD identity lacks Geneva tenant access for that account | Request access to the Geneva tenant that owns the account. |
