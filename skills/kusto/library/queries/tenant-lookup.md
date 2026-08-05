# Tenant lookup

Cross-references between Entra tenant IDs, MCAS TIDs, McasDatacenter, and the
PROD env mapping. Lives in `ProdStats` on the `prodstats` cluster (see
[`../well-known-clusters.md`](../well-known-clusters.md) for the cluster URI
and the `Environment → cluster mapping` table that translates `McasDatacenter`
to PROD env).

---

### `Find tenant details by Entra tenant ID`
**Cluster(s):** `prodstats`
**Database:** `ProdStats`

Replace the IDs in `EntraTenants` with the tenant(s) you're looking up. When
reporting results, translate the `McasDatacenter` value to its PROD env using
the `Environment → cluster mapping` table in
[`../well-known-clusters.md`](../well-known-clusters.md).

```kusto
let EntraTenants = dynamic(['00000000-0000-0000-0000-000000000000']);
cluster("https://mcaskusto1.kusto.windows.net/").database("ProdStats").prodStatsData_v1
| where McasSnapshotTime > ago(2d) and McasStatus has "Enabled"
| where ContextId in (EntraTenants)
| summarize arg_max(McasSnapshotTime, *) by McasTID, ContextId
| project Alias, McasTID = tostring(McasTID), ContextId, McasDatacenter
```
