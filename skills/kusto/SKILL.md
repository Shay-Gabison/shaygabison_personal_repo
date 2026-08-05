---
name: kusto
description: >
  Use this skill when the user wants to query Azure Data Explorer (Kusto / ADX) — even if they
  just say "run a kusto query", "check the logs", "find values in compliance", "query the cluster",
  or paste a KQL snippet. Use it for diagnostic queries across your team's Kusto clusters
  (compliance / telemetry / feature-flag / ring-rollout / tenant-lookup style data). The skill
  consults a project-local config of the team's clusters, tables, and saved queries first,
  adapts the closest entry to the user's intent, and runs it via the configured Azure MCP
  Kusto query tool. Do not use for SQL Server, Cosmos DB, or non-Kusto data sources.
---

# Kusto

Run KQL queries against your team's Azure Data Explorer (ADX) clusters via a configured
Azure MCP server. Reads cluster/table/query metadata from a project-local config file
instead of writing queries from scratch.

## Setup
For first-time configuration (Azure MCP install + generating the config file), follow
[docs/setup.md](docs/setup.md).

## Project Config

The team's Kusto skill is configured by two files, plus a shipped library
that's read alongside them at runtime:

- [`templates/kusto-config.md`](templates/kusto-config.md) — team **metadata**
  (MCP servers, clusters, env→cluster mapping, databases/tables, dimension
  columns, notes). Stable, always read. Populated via `skills-config`.
- [`templates/kusto-queries.md`](templates/kusto-queries.md) — the team's
  **saved queries**. Read only when the user's ask needs query inspiration.
- [`library/`](library/) — shipped, read-only cross-team content
  ([`library/well-known-clusters.md`](library/well-known-clusters.md) +
  [`library/queries/*.md`](library/queries)). The agent reads it alongside
  the team's files. Never edited at runtime; updates arrive via plugin /
  submodule updates.

Both templates are populated by `skills-config` (which can scan the workspace
or prompt the user to paste — see [docs/setup.md](docs/setup.md)) and may be
refined by hand. Every section in each file is documented inline.

**Saved Queries are reference, not templates.** Each entry is a real query (often pasted
from Kusto's "Share query" link) and may contain hardcoded tenant IDs, dates, filters,
project columns, and helper let-statements that were relevant when first written but are
not necessarily relevant to the current ask.

Use them to learn:

- **Which clusters and databases** hold which data (cross-checked against the Clusters and
  Databases tables in the config).
- **Idioms / extractors** the team uses (e.g. `extract("key=(.+)\\[", ...)`, env-name →
  cluster mapping helpers, the typical `union cluster(...).database(...).table` federation
  pattern).
- **Filter patterns** that match the team's data shape (specific `mhash` values, `level`
  filters, etc.).

Do **not** treat them as fill-in-the-blank templates. **Synthesize a fresh query** for each
ask, borrowing only what's relevant from the closest entry.

## Steps to Execute

1. **Read** [templates/kusto-config.md](templates/kusto-config.md). Use the Clusters,
   Databases/Tables, and Common Dimension Columns sections to ground cluster URI / DB /
   column choices. If a saved-query entry references a cluster label that isn't in the
   team's config, fall back to [library/well-known-clusters.md](library/well-known-clusters.md)
   for the canonical URI. (Database choice still comes from the query's own metadata or
   the user — `well-known-clusters.md` is label → URI only.)

2. **Classify the ask and pick a branch:**
   - **Metadata-only** — questions about clusters, databases, tables, or schemas
     ("what clusters do we use?", "show me the schema of FooTable"). Answer from
     `kusto-config.md` (and `library/well-known-clusters.md` for cross-team clusters)
     when sufficient; otherwise call the Azure MCP's list / schema / describe tools.
     **Do not** load saved queries, do not synthesize a query, and do not offer to save
     one. Stop after returning the answer.
   - **Direct KQL paste** — the user supplied complete KQL. **Do not** load saved
     queries. Skip step 3 and go straight to step 4. If the paste doesn't specify a
     target cluster/database, use the matching cluster's Default DB from
     `kusto-config.md` (ask the user if multiple clusters could plausibly match).
   - **Investigative intent** — the user described an intent. Load both:
     - [templates/kusto-queries.md](templates/kusto-queries.md) — the team's saved
       queries.
     - [library/queries/](library/queries) — list the files and read every
       `*.md` entry whose concern is plausibly related to the ask (file names are
       grouped by concern: `gru-flags.md`, `tenant-lookup.md`, `service-logs.md`, …).
       When in doubt, read more.

     Find the entry closest to the user's ask across both sources. On a title-match
     collision, **the team entry wins** — teams can override library queries locally.
     Continue to step 3.

3. **Synthesize the query** (investigative branch only). Start from the matching entry's
   cluster + database + table + federation pattern (or from the Clusters/Tables sections
   in config if no entry matched). Then:
   - Drop fields, projections, lets, and filters that don't apply to the current ask.
   - Adapt time range, identifier filters, aggregations to what the user actually asked.
   - Add new joins / extends / summarizes when the ask requires them — don't be limited to
     the entry's shape.
   - Keep the entry's cluster/database/table choices unless the user explicitly redirects.

4. **Run via the configured Azure MCP Kusto query tool** (see the MCP Servers section of
   [templates/kusto-config.md](templates/kusto-config.md) for the concrete server/tool names).
   - `--cluster-uri`: the Cluster URI from the Clusters table — used as-is (cluster URIs
     are stored as full `https://...kusto.windows.net` URIs in the config). For a saved
     entry whose `Cluster(s)` lists multiple labels, use the **first** label as the
     execution target; KQL federation (`union cluster(...).database(...)...`) covers the
     rest.
   - `--database`: the database from the entry's metadata, or the cluster's Default DB
     for direct pastes.
   - `--query`: the full KQL.

5. **Return results** as a compact table. Cap at top 50 rows; mention if there are more.

6. **(Investigative branch only) If no saved entry matched the intent**, say so, run the
   fresh query, then ask the user whether to append it to
   [templates/kusto-queries.md](templates/kusto-queries.md) for next time. **Never write
   to `library/`** — library updates only land via PR to this repo. If the new query
   looks broadly reusable across MDA teams (targets `mda-*` or `prodstats` clusters,
   uses no team-specific identifiers), additionally suggest the user open a PR to add
   a sanitized version under `skills/kusto/library/queries/`.

## Constraints

- **Saved Queries are reference, not gospel.** Borrow the cluster/database/table/idioms;
  don't copy hardcoded filters or project columns blindly.
- **Never hardcode tenant IDs, mhashes, flag names, or dates** — read them from the user's prompt.
- **Default time range is `ago(1d)`** unless the user specifies otherwise. For asks > 7d
  include a brief heads-up (e.g. *"scanning 30 days — this may take a while"*) and run
  directly; do not block on confirmation. **Refuse open-ended scans with no explicit bound
  that would exceed 30 days** (e.g. "show me everything") — ask the user to supply an
  explicit time range. For explicit ranges > 30 days (e.g. "last 90 days"), run with a
  prominent warning; do not block for confirmation.
- **Don't invent cluster URIs.** Only use clusters that appear in the Clusters section of
  [templates/kusto-config.md](templates/kusto-config.md) (or that the user explicitly provides).
- **Don't run mutating commands.** Only tabular queries and explicitly read-only management
  commands (`.show ...`) are allowed. Refuse `.drop`, `.delete`, `.purge`, `.clear`,
  `.set`, `.append`, `.ingest`, `.alter`, `.create`, `.create-or-alter`, `.rename`,
  `.grant`, `.revoke`, and any policy / materialized-view / function management commands.
- **On MCP auth / network / permission errors**, report the likely cause (VPN not
  connected, expired `az login`, wrong tenant, missing Database Viewer permission) and
  ask the user to verify. Don't silently rewrite the query and retry.
- **Minimize PII in result tables.** Avoid projecting columns that identify people —
  email / UPN, display name / username, IP address, phone number, and user / object IDs
  that resolve to individuals — unless the ask explicitly requires them. When the user
  asks for PII columns, return the minimum necessary and flag in the response that the
  result contains sensitive fields.
