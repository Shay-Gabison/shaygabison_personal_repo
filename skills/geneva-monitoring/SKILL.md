---
name: geneva-monitoring
description: >
  Use this skill when the user needs to query Geneva Monitoring (MDM) — even if they just say "check the metric", "what's MDM showing", "preview this monitor", "why did this fire", "read the time series", or "what's unhealthy". Use it for metric and monitor discovery, time-series reads, monitor evaluation previews (V1 + V2), monitor config history, and health-model navigation across your team's Geneva accounts. The skill consults a project-local config of accounts, namespaces, and dimensions first, then drives the Geneva MDM MCP server's tools. Do not use for Kusto/KQL log queries (use kusto skill), Grafana dashboard operations (use grafana skill), or non-Geneva monitoring systems (Prometheus, Datadog, etc.).
---

# Geneva Monitoring

Discover metrics and monitors, read time series, preview monitor evaluation, and navigate the Geneva health model via a configured Geneva MDM MCP server. Reads account / namespace / dimension metadata from a project-local config file instead of guessing at the surface area.

## Setup

For first-time configuration (MCP server install + generating the config file), follow [docs/setup.md](docs/setup.md).

## Runtime Preflight

The Geneva Monitor MCP server is launched via `dotnet dnx` and pulls from a private NuGet feed on first run. If any Geneva MCP tool call fails with a connection / transport / startup error, **do not retry blindly**. Tell the user:

- Confirm the .NET 10 SDK is installed (`dotnet --list-sdks` must show a 10.x SDK — `dnx` ships with it).
- Confirm the interactive NuGet auth against `msblox.pkgs.visualstudio.com` has completed at least once (first launch prompts in a browser).
- If neither, the Geneva Monitor MCP server may not be registered — point them at [docs/setup.md](docs/setup.md#0-mcp-server-setup).

## Project Config

The team's Geneva skill is configured by one file, plus a shipped library that's read alongside it at runtime:

- [`templates/geneva-monitoring-config.md`](templates/geneva-monitoring-config.md) — team **metadata** (MCP server name, monitoring accounts, namespaces, well-known metrics, dimension naming conventions, infra-account patterns). Stable, always read. Populated via `skills-config`.
- [`library/`](library/) — shipped, read-only cross-team content ([`library/discovering-metrics.md`](library/discovering-metrics.md), [`library/inspecting-monitors.md`](library/inspecting-monitors.md), [`library/kqlm-query-patterns.md`](library/kqlm-query-patterns.md)). The agent reads it alongside the team's file. Never edited at runtime; updates arrive via plugin / submodule updates.

The template is populated by `skills-config` (which can scan the workspace or prompt the user to paste — see [docs/setup.md](docs/setup.md)) and may be refined by hand. Every section in the file is documented inline.

**Library files are reference, not gospel.** They document canonical tool-call shapes, parameter conventions, and common gotchas. Read the section relevant to the current ask; do not copy entire templates blindly.

## Steps to Execute

1. **Read** [templates/geneva-monitoring-config.md](templates/geneva-monitoring-config.md). Use the Accounts, Namespaces, and Well-Known Metrics sections to ground account / namespace / dimension choices. If the user names a metric or monitor that isn't in the config, ask which account/namespace they mean before discovering blindly.

2. **Classify the ask and pick a branch:**
   - **Discovery / metadata-only** — "what accounts do we have?", "list namespaces in X", "show the metric config / dimensions", "what monitors live on this resource type?". Answer from `geneva-monitoring-config.md` when sufficient; otherwise call discovery tools (`tenant_get_all_names`, `metrics_get_namespaces`, `metrics_get_metric_names`, `metrics_get_metric_config`, `monitor_get_monitor_v2_configuration` with no GUID). Tool-call shapes: [library/discovering-metrics.md](library/discovering-metrics.md#metric-discovery-sequence). Continue to step 3 to run them. Once the metadata question is answered, stop — do not read time series or inspect monitors unless asked.
   - **Time-series read** — the user wants values for a known metric over time. Verify the metric exists in the chosen account/namespace via `metrics_get_metric_config`, then read via `metrics_read_time_series` (preferred — most reliable). Use `metrics_read_multi_time_series` only when you need wildcard / multi-series semantics, and `metrics_kqlm_query` for accounts with simple (non-dotted) dimension names. See [library/discovering-metrics.md](library/discovering-metrics.md#metrics_read_multi_time_series-reliability). Continue to step 3.
   - **Monitor inspection / firing investigation** — "why did monitor X fire at T?", "preview this monitor", "show monitor config history". V2: get config, preview combinations, preview result. V1: no preview tool — get config history, then read the underlying metric and compare against the threshold manually. Continue to step 3.
   - **Health-model investigation** — "what's unhealthy?", "which watchdogs are failing on resource Y?". Navigate tree: `health_get_resource_tree` (or `health_get_children` for a subtree) → `health_get_monitors_and_health` → drill into the failing monitor's config. Continue to step 3.

3. **Run the tool calls.** Follow the templates and parameter rules in the matching library file:
   - Discovery / metadata → [library/discovering-metrics.md](library/discovering-metrics.md#metric-discovery-sequence).
   - Time-series reads → [library/discovering-metrics.md](library/discovering-metrics.md#reading-time-series).
   - KQL-M queries → [library/kqlm-query-patterns.md](library/kqlm-query-patterns.md).
   - V2 monitor preview → [library/inspecting-monitors.md](library/inspecting-monitors.md#v2-monitor-investigation-templates).
   - V1 monitor debugging → [library/inspecting-monitors.md](library/inspecting-monitors.md#v1-monitor-details).
   - Health model → [library/inspecting-monitors.md](library/inspecting-monitors.md#health-model-navigation).

4. **Validate before reporting "no data".** If a read returns empty or `InvalidSeries`:
   - Re-check `preaggregateConfigurations` — your dimension filter may not be in a pre-agg.
   - Re-check `endTimeUtc` — the last ~2 minutes of MDM data are incomplete; set `endTimeUtc` at least 2 minutes before "now".
   - Re-check account / namespace — a wrong pair returns empty silently.
   - For V2 monitors using `Monitor.Tenant` as an env var, include `"Monitor.Tenant": "<account>"` in the preview combination.

5. **Return results** as a compact table (time series) or structured summary (monitor config / health tree). For time series, surface the sampling type, dimension filters, and time range used.

6. **For firing investigations**, if the current monitor config differs from what fired (`lastModifiedTime` is recent), use `kusto_get_monitor_v2_config_history` / `kusto_get_monitor_v1_config_history` to retrieve the config at firing time and report the diff.

## Constraints

- **Don't invent accounts, namespaces, or metric names.** Only use values that appear in [templates/geneva-monitoring-config.md](templates/geneva-monitoring-config.md), are returned by discovery tools, or that the user explicitly provides.
- **Recent data is incomplete.** Always set `endTimeUtc` at least 2 minutes before "now". Don't report "no data" for the last 2 minutes without flagging this.
- **Pre-agg determines filterable dimensions.** Check `preaggregateConfigurations` before filtering by a dimension. Filtering by a dimension absent from any pre-agg returns `InvalidSeries` at read time.
- **KQL-M is not standard KQL.** Don't use ADX operators (`materialize()`, `series_decompose()`, joins across cluster/database). Sampling types in KQL-M use Title Case for aggregates (`'Sum'`, `'Average'`) and lowercase-with-spaces for percentiles (`'99th percentile'`).
- **Epoch timestamps in milliseconds.** Geneva uses Unix-epoch milliseconds. Double-check the year and the unit before passing.
- **Don't run write / mutating tools.** Refuse V1 write/admin tools, V2 write tools, and `health_create_or_update_resource_type_config`. This skill is read-only.
- **On MCP auth / permission errors** that aren't startup failures (see Runtime Preflight above for those), report the likely cause (expired token mid-session, wrong tenant, missing account access) and ask the user to verify. Don't silently retry with different parameters.
- **Current monitor config ≠ what fired.** For any firing investigation, check `lastModifiedTime` and pull config history if it's recent.
