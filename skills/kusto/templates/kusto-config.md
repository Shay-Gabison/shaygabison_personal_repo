# Kusto Configuration

<!--
Runtime configuration the `kusto` skill reads on every run.
Fill in the `{{PLACEHOLDER}}` values below — or run `skills-config` to be guided
through it automatically: it scans your workspace for KQL/MD artifacts first,
prompts you to paste queries if the scan is empty or partial, then asks only for
any remaining missing values manually.
See ../docs/setup.md → "Populate the templates".

Keep the section headings stable so the skill can parse the file.
Add or remove rows in the tables as needed. Delete sections that don't apply.
-->

## MCP Servers

<!--
Which MCP server exposes the Kusto query tool. Most teams need only one entry.

  MCP Server Name — the key under `mcpServers` in ~/.copilot/mcp-config.json
                    (or your agent's equivalent) whose `command: npx` + args
                    include `@azure/mcp`. Typically `azure`.
-->

| MCP Server Name | Cluster | Database | Use For |
|---|---|---|---|
| `{{MCP_SERVER_NAME}}` | any (passed per-call via `--cluster-uri`) | any | All Kusto queries below |

## Clusters

<!--
Every Kusto cluster the skill is allowed to target. Add one row per cluster.

  Label        — short nickname used elsewhere in this file.
  Cluster URI  — full ADX URL including scheme, e.g. https://foo.kusto.windows.net
                 Paste the URI exactly as it appears in Kusto Explorer / your config
                 files; the skill uses it as-is (no string concatenation).
                 Where to find it:
                   • Kusto Explorer connection strings,
                   • appsettings*.json / values*.yaml — search for `kusto.windows.net`,
                   • the cluster dropdown in dataexplorer.azure.com.
  Default DB   — database to use when none is explicitly specified.
  Use For      — what kind of data lives here (1 short phrase).
-->

| Label | Cluster URI | Default DB | Use For |
|---|---|---|---|
| `{{CLUSTER_LABEL}}` | `{{CLUSTER_URI}}` | `{{CLUSTER_DEFAULT_DB}}` | `{{CLUSTER_USE_FOR}}` |

### Environment → cluster lookup

<!--
Optional. Use this if your team has a stable mapping from environment / stamp /
datacenter to one of the clusters above. Delete this subsection if not needed.

  Environment       — your team's env name (Prod, Stage, Dogfood, …).
  Datacenter Tag    — internal datacenter / stamp identifier, if applicable.
  Primary Region    — Azure region for the primary cluster.
  Secondary Region  — Azure region for failover, if any.
  Cluster           — Label from the Clusters table above.
-->

| Environment | Datacenter Tag | Primary Region | Secondary Region | Cluster |
|---|---|---|---|---|
| `{{ENV_NAME}}` | `{{ENV_DC_TAG}}` | `{{ENV_PRIMARY_REGION}}` | `{{ENV_SECONDARY_REGION}}` | `{{ENV_CLUSTER_LABEL}}` |

## Databases and Tables

<!--
Tables the skill should know about. Time Column matters because the skill
defaults queries to `ago(1d)` on that column.

  Cluster      — Label from the Clusters table above.
  Database     — the DB the table lives in.
  Table        — the KQL table name.
  Purpose      — one-line description of what the table is for.
  Time Column  — the column the agent should filter on for time ranges
                 (often `Timestamp`, `PreciseTimeStamp`, `EventTime`).
                 Find it by running `<TableName> | take 1` and inspecting columns.
  Key Columns  — comma-separated identifier columns useful as filters
                 (e.g. `mhash, tenantId, deploymentRing`).
-->

| Cluster | Database | Table | Purpose | Time Column | Key Columns |
|---|---|---|---|---|---|
| `{{TABLE_CLUSTER_LABEL}}` | `{{TABLE_DB}}` | `{{TABLE_NAME}}` | `{{TABLE_PURPOSE}}` | `{{TABLE_TIME_COLUMN}}` | `{{TABLE_KEY_COLUMNS}}` |

## Common Dimension Columns

<!--
Glossary of columns the skill will use as filters / group-bys. Helps it pick
sensible projections and avoid hallucinating column names.

  Column          — the KQL column name.
  Meaning         — what it represents (1 short phrase).
  Example values  — 2-3 representative values so the agent can recognise them
                    in user prompts ("mhash 881a5ba6" → filter by mhash).
-->

| Column | Meaning | Example values |
|---|---|---|
| `{{COLUMN_NAME}}` | `{{COLUMN_MEANING}}` | `{{COLUMN_EXAMPLES}}` |

## Notes

<!--
Free-form section for investigation patterns, gotchas, naming conventions, and
anything else the skill should know that doesn't fit the tables above.
-->

- `{{NOTE}}`
