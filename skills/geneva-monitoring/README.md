# Geneva Monitoring

Queries Geneva Monitoring (MDM) via MCP tools — discovering metrics and monitors, reading time series, and previewing monitor evaluation.

## What it does

- Reads a project-local `geneva-monitoring-config.md` for accounts, namespaces, and dimensions in scope
- Calls Geneva MDM MCP tools to discover metrics/monitors and read time series
- Previews monitor evaluation and inspects V2 monitor configuration

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## How to use

> *"Show me the config for monitor `<GUID>` in `<account>`."*
> *"Read the time series for `<metric>` in `<namespace>` over the last hour."*
> *"Why did `<monitor>` fire at `<time>`? Preview its evaluation."*

## Installation

```bash
./.ai-tools/install.sh --skill geneva-monitoring
```

Then follow the configuration prompts, or ask your agent: *"configure geneva-monitoring"*

## Prerequisites

- A Geneva MCP server registered with your agent host
- .NET 10 SDK (`dotnet dnx`) and `AzureGenevaMonitoring` NuGet feed access
- Geneva tenant access for the monitoring accounts you query

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions |
| `docs/setup.md` | Configuration reference |
| `templates/geneva-monitoring-config.md` | Project config template |
| `library/discovering-metrics.md` | Metric discovery + time-series reads |
| `library/inspecting-monitors.md` | V1/V2 monitor config + preview |
| `library/kqlm-query-patterns.md` | KQL-M query templates |

