---
name: geneva-monitoring-mcp
description: 'Query, troubleshoot, and manage Geneva Monitoring data via the Geneva Monitoring MCP Server. Covers tenants/accounts, metrics (read, KQL-M, aggregations), V1/V2 monitors (create/update/delete/silence/validate/preview), health topology and watchdogs, IcM incidents, and ad-hoc Kusto queries. Use whenever the user mentions Geneva, MDM, MDS, Geneva metrics/logs, Geneva monitors, watchdogs, IcM incidents, or asks to read/aggregate metric time series, render metric charts, manage monitor configs, or run KQL/KQL-M queries against Geneva data.'
---

# Geneva Monitoring MCP Skill

Use the **Geneva Monitoring MCP Server** to query, troubleshoot, and analyze Geneva Monitoring data (tenants, metrics, monitors, health, watchdogs, IcM incidents) using natural language.

- **Package**: `GenevaMonitoring.MCP.Server` on Azure Artifacts feed `https://msblox.pkgs.visualstudio.com/_packaging/AzureGenevaMonitoring/nuget/v3/index.json`
- **Docs**: Engineering Hub → Geneva Monitoring → AI-Agentic Tools → Geneva MCP Server

## Prerequisites

- VS Code with GitHub Copilot (Chat) enabled (or any MCP-capable client)
- Microsoft Corp account (`@microsoft.com`) with access to the target Geneva tenant
- **.NET 10 SDK** (required for `dnx`): `winget install Microsoft.DotNet.SDK.10`

## Installation

Add the server to your MCP configuration (`mcp.json` for VS Code, or `~/.copilot/mcp-config.json` for Copilot CLI).

### Option 1 — Via `dnx` (recommended, auto-updates)

```json
{
  "servers": {
    "GenevaMonitoringMCP": {
      "type": "stdio",
      "command": "dnx",
      "args": [
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

### Option 2 — Manual install via `dotnet tool`

```bash
dotnet tool install --global GenevaMonitoring.MCP.Server \
  --add-source https://msblox.pkgs.visualstudio.com/_packaging/AzureGenevaMonitoring/nuget/v3/index.json
```

```json
{
  "servers": {
    "GenevaMonitoringMCP": {
      "type": "stdio",
      "command": "genevamonitoring-mcp",
      "args": ["--stdio"]
    }
  }
}
```

Update later: `dotnet tool update --global GenevaMonitoring.MCP.Server --add-source <feed>`
Uninstall: `dotnet tool uninstall --global GenevaMonitoring.MCP.Server` then remove from `mcp.json`.

### Authentication

After config, restart the client. On the **first tool call** Edge opens for interactive Microsoft login; subsequent calls reuse the cached credential. If a call returns an auth error, the next call will re-trigger the browser login.

### Verify

```bash
dotnet tool list --global | Select-String genevamonitoring
# expect: genevamonitoring.mcp.server  <version>  genevamonitoring-mcp
```

## Tool Catalog (67 tools)

All tools are prefixed with their category in usage. The most common ones you will reach for:

### Server & Config (5)
- `health` — server health check
- `list_all_tools` — list every registered tool + parameters
- `set_endpoint_override` / `clear_endpoint_override` / `get_endpoint_overrides` — pin/clear stamp endpoint for an account

### Tenant / Account (5)
- `tenant_search_by_prefix` — **start here** when you don't know the exact account name
- `tenant_get_all_names`, `tenant_get_all_stamp_hostnames`
- `tenant_get_stamps` — datacenters the tenant is deployed to
- `tenant_get_publication_endpoints` — where metrics are routed

### Metrics (10)
- `metrics_get_namespaces`, `metrics_get_metric_names`
- `metrics_get_metric_config` (V1), `metrics_get_metric_config_v2` (V2 with filters)
- `metrics_read_time_series` — REST, exact dimensions only
- `metrics_read_multi_time_series` — SDK, supports wildcard / multi-value dimensions
- `metrics_read_time_series_aggregated` — aggregated over a window
- `metrics_kqlm_query` — KQL-M with filtering / aggregation
- `metrics_get_monitor_ids`, `event_config_create_or_update_metric`

### Monitor V1 — threshold-based (8)
- `monitor_get_all_monitor_v1_configuration`, `monitor_get_monitor_v1_configuration`
- `monitor_get_v1_monitor_metrics`
- `monitor_v1_create_or_update`, `monitor_v1_delete`, `monitor_v1_disable`, `monitor_v1_silence`, `monitor_v1_validate`

### Monitor V2 — GUID-keyed (8)
- `monitor_get_monitor_v2_configuration`, `monitor_get_monitor_v2_by_resource_type`, `monitor_get_monitor_v2_count_by_resource_type`
- `monitor_v2_create`, `monitor_v2_update`, `monitor_v2_delete`
- `monitor_v2_preview_combination` — dimension combinations the monitor would evaluate
- `monitor_v2_preview_result` — preview evaluation output **before saving**

### Monitor General (3)
- `monitor_get_all_health_monitor_configuration`
- `monitor_get_tenant_configuration` — home stamp, admins, certs, limits
- `render_chart` — render a metric time series as an interactive Chart.js HTML chart

### Health Topology & Resources (13)
- `health_get_topologies`, `health_get_datacenters`, `health_get_children`
- `health_get_resource_tree`, `health_get_resource_health_data`
- `health_get_resource_type_config(s)`, `health_create_or_update_resource_type_config`
- `health_get_tree_nodes`, `health_get_tree_nodes_by_filter`, `health_batch_get_nodes`
- `health_get_suppression_rules`, `health_get_enrichment_settings`

### Health Monitors & Watchdogs (8)
- `health_get_monitor_health_status`, `health_get_monitor_summary`, `health_get_monitor_v2_summary`
- `health_get_monitors_and_health`, `health_get_monitors_for_resource_type`
- `health_get_failing_watchdogs`, `health_get_watchdog_categories`, `health_get_watchdog_report`

### Health IcM (2)
- `health_get_icm_configuration` — routing, severity mapping
- `health_get_incident_id` — Geneva source GUID → IcM incident ID

### Incidents (2)
- `incident_get_details`, `incident_get_discussion_details`

### Kusto (3)
- `kusto_execute_query` — arbitrary KQL on any Kusto cluster
- `kusto_get_monitor_v1_config_history`, `kusto_get_monitor_v2_config_history`

## Workflows & Recipes

### 1. Find an account when you only know a fragment
```
tenant_search_by_prefix(prefix: "MyService")
→ pick the exact tenant name, then use it as `account` for downstream calls
```

### 2. Read recent metric data
```
metrics_get_namespaces(account: "<tenant>")
metrics_get_metric_names(account: "<tenant>", namespace: "<ns>")
metrics_read_time_series(account, namespace, metric, dimensions, start, end)
# or for wildcards / multi-value:
metrics_read_multi_time_series(...)
# then optionally:
render_chart(series=...)
```

### 3. Create a V1 threshold monitor (with a dry-run first)
```
monitor_v1_validate(config={...})        # never skip this
monitor_v1_create_or_update(config={...})
monitor_v1_silence(monitor=..., silenced=true)   # if you need to mute alerting
```

### 4. Create / preview a V2 monitor
```
monitor_v2_preview_combination(config=...)   # which dimension combos will evaluate
monitor_v2_preview_result(config=...)        # what alerts would fire on past data
monitor_v2_create(config=...)
```

### 5. Triage failing watchdogs / health
```
health_get_failing_watchdogs(tenant: "<tenant>")
health_get_resource_health_data(resourceId: ...)
health_get_monitor_health_status(monitorId: ...)
```

### 6. IcM incident lookup
```
health_get_incident_id(sourceGuid: ...)      # map Geneva GUID → IcM ID
incident_get_details(incidentId: ...)
incident_get_discussion_details(incidentId: ...)
```

### 7. Ad-hoc Kusto / config history
```
kusto_execute_query(cluster: "<cluster>", database: "<db>", query: "...")
kusto_get_monitor_v1_config_history(account: "<tenant>", lookbackHours: 24)
kusto_get_monitor_v2_config_history(account: "<tenant>", lookbackHours: 24)
```

## Example Prompts

**Troubleshooting**
- "Show me failing watchdogs for tenant `MyServiceAccount`"
- "What's the health status of monitor `XYZ` for tenant `MyServiceAccount`?"
- "Get IcM incident details for incident `123456789`"

**Monitor configuration**
- "List all V2 monitors for tenant `MyServiceAccount`"
- "How many V2 monitors are there by resource type for `MyServiceAccount`?"
- "Show me the V1 monitor config for namespace `MyNamespace`, metric `MyMetric` in `MyServiceAccount`"
- "What changed in V1 monitor config for `MyServiceAccount` in the last 24 hours?"

**Monitor management**
- "Create a V1 Sum monitor on `MyAccount` for metric `Errors/Count`. Alert Sev3 when Sum > 100 over 10 min."
- "Validate this monitor config without saving it"
- "Silence monitor `TestMonitor` on `MyAccount` — stop alerting but keep evaluating"
- "Create a V2 monitor for metric `Duration` with dynamic threshold, sensitivity 2.5"
- "Preview what dimension combinations V2 monitor `76495782-…` would evaluate"

**Metrics**
- "Read the last 30 minutes of metric `MyMetric` in namespace `MyNamespace` for tenant `MyServiceAccount`"
- "What metric namespaces exist for tenant `MyServiceAccount`?"
- "Render a chart of the last hour of `Latency/P99` for `MyAccount`"

**KQL-M**
- "Top 10 collections by `NormalizedRUConsumption` for `MyAccount` where `GlobalDatabaseAccountName == MyCosmosAccount`"
- "Hourly aggregated error counts for `MyAccount`, metric `Errors`, namespace `MyNS`, last 12 h"
- "Run on `GenevaUx`: `metricNamespace('MdmQos').metric('MStoreActiveTimeSeriesCount').samplingTypes('Sum')` for the last hour"

**Tenant discovery**
- "Search for tenants starting with `Geneva`"
- "What stamps is `MyServiceAccount` deployed to?"
- "Show tenant config for `MyServiceAccount`"

**Kusto**
- "Run on the Geneva cluster: `MonitorConfigSnapshot | where account_id == 'MyAccount' | summarize dcount(monitor_name) by monitorType`"
- "Show discussion history for IcM incident `123456789`"

## Best Practices

- **Always validate / preview before writing.** Use `monitor_v1_validate`, `monitor_v2_preview_combination`, and `monitor_v2_preview_result` before any `create_or_update` / `create` / `update` call.
- **Resolve the exact account name first** via `tenant_search_by_prefix` — most downstream tools fail silently on a typo.
- **Prefer `metrics_read_multi_time_series`** when you need wildcards or multi-value dimension filters; use `metrics_read_time_series` only for exact dimensions.
- **Use `set_endpoint_override`** only when automatic stamp resolution is wrong; clear it as soon as you're done so you don't pollute future calls.
- **Render charts (`render_chart`)** when the user asks to "see" or "visualize" a metric — produces an interactive Chart.js HTML.
- **For config drift / change attribution**, use `kusto_get_monitor_v1_config_history` / `_v2_config_history` rather than diffing snapshots manually.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| MCP server not responding | Run `genevamonitoring-mcp --stdio` directly to verify, then restart the client. Check the MCP Server Log in the client's output panel. |
| Authentication failed | Edge should open for login on first use. If a token expired, the next tool call re-triggers browser login. Confirm you have access to the Geneva account. |
| Tool returned "not found" / empty | Verify the tenant/account name with `tenant_search_by_prefix`. Confirm your account has access to that Geneva monitoring account. |
| Stamp/endpoint errors | Try `set_endpoint_override` with the correct stamp; check `tenant_get_stamps` and `tenant_get_publication_endpoints` for the expected hostnames. |

## Feedback

For issues, feature requests, or questions, reach out to the **Geneva Monitoring MCP Team** via the Engineering Hub feedback channel.
