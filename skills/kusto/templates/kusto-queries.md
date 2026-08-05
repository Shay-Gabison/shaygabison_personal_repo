# Kusto Saved Queries

<!--
Reference KQL the team has run before. The `kusto` skill reads this file
**only when** the user's ask needs query inspiration — direct KQL pastes and
metadata-only questions ("list our clusters") skip it. Cluster labels, DBs,
and table schemas live in ../templates/kusto-config.md, not here.

Each entry should have:
  - a short descriptive heading (### ...)
  - a short "When to use" line (the trigger/intent)
  - the `Cluster(s)` and `Database` it targets (use the labels from
    kusto-config.md → Clusters table). If the query federates across multiple
    clusters, list all labels — the skill uses the **first** label as the MCP
    execution target and lets KQL federation handle the rest.
  - the KQL inside a ```kusto fenced block

How to supply queries to `skills-config`:
  - the flow is: scan workspace first, then paste queries if needed, then manual for missing values,
  - paste raw KQL,
  - give a file path (e.g. `./docs/runbooks/timeouts.kql`),
  - or paste a Kusto "Share query" URL — the agent decodes the
    gzip+base64url `query` parameter to recover the KQL and infers the
    cluster + database from the URL path.
  - for each pasted query, provide one thing only:
      - when this query should be used (trigger/intent)
    (the agent infers metadata and generates a short title)
  - after each saved query, the agent asks whether to add another query or finish.

Paste queries as-is — including hardcoded values, helper let-statements, and
project columns. The skill treats each entry as inspiration (cluster /
database / table choices, idioms, filter patterns) and synthesises a fresh
query for each new ask.

Add as many entries as you like. Delete the example below once you have real
queries.
-->

### `{{SAVED_QUERY_TITLE}}`
**When to use:** `{{SAVED_QUERY_WHEN_TO_USE}}`
**Cluster(s):** `{{SAVED_QUERY_CLUSTER_LABEL}}`
**Database:** `{{SAVED_QUERY_DB}}`

```kusto
{{SAVED_QUERY_KQL}}
```
