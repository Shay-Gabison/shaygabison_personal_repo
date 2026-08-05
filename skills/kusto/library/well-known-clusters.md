# Well-known Kusto Clusters

Canonical MDA Kusto clusters used by the queries in [`queries/`](queries). The
`kusto` skill falls back to this table when a library query references a
cluster label that isn't in the team's `templates/kusto-config.md`.

Teams may copy any rows below into their own `kusto-config.md → Clusters`
table if they want to address these clusters by label in their own saved
queries.

Each row below is a **physical cluster**. The same cluster may host multiple
databases; the `Databases` column lists only the ones with broad cross-team
use (e.g. `core`, `compliance`). Team-specific databases belong in your own
`templates/kusto-config.md`, not here. Pick the database per-query, not
per-cluster.

| Label | Cluster URI | Databases | Use For |
|---|---|---|---|
| `prod-us` | `https://mcasge00usw1pxrni.westus.kusto.windows.net` | `core`, `compliance` | US prod environments — Prod-01 (US1/WUS), Prod-03 (US2/EUS2), Prod-05 (US3/WUS2) |
| `prod-eu` | `https://mcasge00euw1pxcqv.westeurope.kusto.windows.net` | `core`, `compliance` | EU prod environment — Prod-02 (EU1/WEU) |
| `prod-uk` | `https://mcasge00uks1pxnci.uksouth.kusto.windows.net` | `core`, `compliance` | UK prod environment — Prod-04 (EU2/UKS) |
| `staging-eu` | `https://mcasge00euw1pxynv.westeurope.kusto.windows.net` | `core`, `compliance` | Staging — RS-02 (WEU) |
| `wcdprod` | `https://wcdprod.kusto.windows.net` | `Geneva` | KubeEvents (pod lifecycle, OOMKilled, evictions) + infralog (nginx ingress) — cross-tenant |
| `prodstats` | `https://mcaskusto1.kusto.windows.net` | `ProdStats` | Tenant / datacenter metadata (Entra TID → MCAS TID, McasDatacenter, status) |

## Environment → cluster mapping

`McasDatacenter` is the value reported by the `prodstats` cluster's
`ProdStats.prodStatsData_v1` table (see [`queries/tenant-lookup.md`](queries/tenant-lookup.md));
`RoleInstance` is the per-region tag emitted in service logs (e.g. the `entities`
table on `core`).

| Environment | McasDatacenter (`ProdStats`) | Primary Region (`RoleInstance`) | Secondary Region (`RoleInstance`) | Cluster |
|---|---|---|---|---|
| Prod-01 | `US1` | West US (`WUS`) | East US (`EUS`) | `prod-us` |
| Prod-02 | `EU1` | West Europe (`WEU`) | North Europe (`NEU`) | `prod-eu` |
| Prod-03 | `US2` | East US 2 (`EUS2`) | Central US (`CUS`) | `prod-us` |
| Prod-04 | `EU2` | UK South (`UKS`) | UK West (`UKW`) | `prod-uk` |
| Prod-05 | `US3` | West US 2 (`WUS2`) | West Central US (`WCUS`) | `prod-us` |
| RS-02 (staging) | — | West Europe (`WEU`) | North Europe (`NEU`) | `staging-eu` |
