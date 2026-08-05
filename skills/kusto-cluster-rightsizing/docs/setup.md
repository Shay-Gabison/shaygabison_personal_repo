# Setup: kusto-cluster-rightsizing

This skill fetches Engine Health metrics from **Geneva MDM** and writes recommendations into
an xlsx. The agent checks and fixes most prerequisites automatically, but you need the
following available.

## Prerequisites

- **Azure VPN connected** and **`az login`** to the correct tenant.
- **Geneva monitoring MCP** (`genevamonitoring-mcp`) wired into your agent, with Geneva auth
  cached. The skill installs it if missing.
- **.NET SDK** (`dotnet`) — required by the Geneva MCP tooling.
- **Python 3 + `openpyxl`** — used by the embedded analyzer to read/write the xlsx.
  `pip install openpyxl`.
- **Geneva read access** to the `KustoProd` / `MdmEngineMetrics` account (Engine Health V3
  metrics).

## Inputs you provide at runtime

- A **cluster list** — paste cluster names, or an xlsx with a `Name` column (the weekly
  Compute Details sheet works as-is). The agent normalizes input into `(name, region)` pairs.
- The **target xlsx** to enrich (or let the agent create one).

## Verify

Ask your agent to "list Geneva metrics for cluster X" — if the Geneva MCP is wired up and
authenticated, it responds with metric data.

## Configuration

No project-local config file is required. The region→Geneva-account map and the 77 Engine
Health metric definitions are embedded in `SKILL.md`. Adjust them there if your fleet uses
different Geneva accounts or metrics.
