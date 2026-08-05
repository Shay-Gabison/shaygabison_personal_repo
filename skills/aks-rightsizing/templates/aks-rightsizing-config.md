# AKS Rightsizing Configuration

<!--
Runtime configuration the `aks-rightsizing` skill reads on every run.
Fill in the `{{PLACEHOLDER}}` values below — or run `skills-config` to be guided
through it automatically.
See ../docs/setup.md → "Populate the templates".

Keep the section headings stable so the skill can parse the file.
-->

## Geneva Monitoring

<!--
Which MCP server and account to query for utilization metrics.
-->

| Setting | Value |
|---|---|
| MCP Server Name | {{GENEVA_MCP_SERVER_NAME}} |
| Monitoring Account | WCDProduction |
| Namespace | WCDPRDInfraSystem |

<!--
MCP Server Name — the key your Geneva MCP server is registered under in
your agent host's MCP config (e.g. ./mcp.json for Copilot CLI, or
VS Code Settings → "MCP" / .vscode/mcp.json). Typical: "geneva", "genevamonitor"
-->

## Dashboard Reference

<!--
The Geneva dashboard used for initial metric discovery. The skill uses
the underlying metric names at runtime, not the dashboard ID.
-->

| Setting | Value |
|---|---|
| Dashboard ID | ADEBF3F1 |
| Dashboard URL | https://portal.microsoftgeneva.com/s/ADEBF3F1 |

## Cluster Scope & Inventory

<!--
The complete MDA cluster inventory is in the library file:
  library/mda-cluster-inventory.md

That file lists all Core clusters (101, 103, 105, 106, 111, 112) with their
Primary/DR assignments, and all Inline clusters.
-->

- Full inventory: see [`library/mda-cluster-inventory.md`](../library/mda-cluster-inventory.md)
- Cluster ID range: 100-199
- Naming pattern: `{REGION}-{ID}` (e.g., UKS-101, WEU-102, EUS-103)

## Cluster Topology

<!--
MDA clusters are classified as Inline or Core (Primary/DR).
See mda-cluster-inventory.md for the full cluster lists.
-->

### Inline Clusters (Active-Active)

Inline clusters run the inline workloads (`inline-access-connectors`, `inline-connectors`,
`inline-session-connectors`) in an **active-active** topology — all carry live traffic equally.

See [library/mda-cluster-inventory.md](../library/mda-cluster-inventory.md) for the full list
(30 clusters: 15 × -101 suffix + 15 × -108 suffix).

### Core Clusters (Primary / DR)

All other clusters follow a **Primary / DR** topology per cluster group.

See [library/mda-cluster-inventory.md](../library/mda-cluster-inventory.md) for the full
Primary/DR assignments per group (101, 103, 105, 106, 111, 112).

## Container Focus

<!--
The main application container in all MDA services.
Sidecar containers are small and can be ignored for rightsizing.
-->

- Primary container: `wdatp-service`
- Filter: Always use `container_name = wdatp-service` in Geneva queries
- ⚠️ **Exception**: `container:cpu_elevated_throttling_scaled` uses dimension **`container`** (not
  `container_name`). Use `container = wdatp-service` for this metric only.

### DR Paused Patterns

DR clusters for non-inline workloads typically have services paused via one of:

1. **KEDA paused annotation**: `autoscaling.keda.sh/paused-replicas: "0"` — KEDA is enabled but
   the annotation tells KEDA to scale to 0 replicas.
2. **KEDA disabled + zero replicas**: `keda.enabled: false` and `replicaCount: 0` — scaling is
   off entirely and no pods run.

When a DR service is paused, Geneva will show no utilization data (0 replicas = 0 pods). This is
expected, not a data coverage issue.

### Rightsizing Focus

- **Primary clusters** are the main rightsizing target — they carry production traffic and consume compute.
- **DR clusters** that are correctly paused consume no compute; rightsizing recommendations do not apply.
- **DR clusters that are unexpectedly running** (not paused) are an optimization opportunity — flag them.
- **Config differences between Primary and DR** (requests, limits, KEDA settings) are expected and
  should NOT be flagged as drift for non-inline clusters.

## ADO Settings (for tracking work items)

<!--
Used when the skill creates User Story work items to track rightsizing.
-->

| Setting | Value |
|---|---|
| MCP Server Name | {{ADO_MCP_SERVER_NAME}} |
| Organization URL | {{ORGANIZATION_URL}} |
| Project | {{PROJECT_NAME}} |
| Area Path | {{AREA_PATH}} |
| Work Item Type | User Story |
| Tags | rightsizing, compute-efficiency |

## Eng Hub References

| Topic | URL |
|---|---|
| Pod Rightsizing Overview | https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/internal/defender-k8s/engineering/kubernetes/pod_rightsizing/overview |
| How to Pick CPU Request | https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/internal/defender-k8s/engineering/kubernetes/pod_rightsizing/how_to_pick_good_cpu_request.html |
| How to Pick CPU Limit | https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/internal/defender-k8s/engineering/kubernetes/pod_rightsizing/how_to_pick_good_cpu_limit.html |
| Compute Utilization | https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/internal/defender-k8s/engineering/kubernetes/pod_rightsizing/compute_utilization.html |
| CPU/Memory Ratio | https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/internal/defender-k8s/engineering/kubernetes/pod_rightsizing/cpu_memory_ratio.html |
| Cluster Autoscaler | https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/internal/defender-k8s/engineering/kubernetes/pod_rightsizing/cluster_autoscaler.html |

## Notes

- Replace all `{{PLACEHOLDER}}` values with your actual values.
- Keep this file next to the skill's `SKILL.md` (in the installed `templates/` directory) so the skill loads it automatically.
