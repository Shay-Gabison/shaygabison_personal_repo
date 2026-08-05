# Geneva Dashboard Guide — WCDProduction / WCDPRDInfraSystem

> How to discover and query the Geneva utilization metrics used by the AKS rightsizing skill.
> Treat the dashboard reference as a discovery aid, not a runtime dependency.

---

## Account and Namespace

Use these defaults for MDA production infra rightsizing:

| Field | Value |
|---|---|
| Monitoring Account | `WCDProduction` |
| Namespace | `WCDPRDInfraSystem` |
| Dashboard Reference | `ADEBF3F1` |

### Important note

- `ADEBF3F1` is for human discovery and validation only.
- At runtime, query metrics directly through Geneva MCP tools.

---

## Dimensions

Most rightsizing metrics are sliced by these dimensions:

| Dimension | Meaning | Notes |
|---|---|---|
| `DC` | Datacenter / region | Often aligns with physical region label |
| `K8sClusterName` | Cluster name | Example: `UKS-101`, `WEU-102` |
| `namespace` | Kubernetes namespace | Service deployment namespace |
| `service_name` / `pServiceName` / `service` | Service name | Check the actual dimension name per metric |
| `container_name` / `container` | Container name | Always filter for `wdatp-service` |

### Container rule

- Always filter the main application container:

```text
container_name = wdatp-service
```

- Some metrics may expose this dimension as `container` instead of `container_name`; verify in metric config.

### Namespace and cluster casing rule

⚠️ **Dimension values may differ in casing across metrics.** Some Geneva metrics report namespaces
in title case (e.g., `Discovery`) while others use lowercase (e.g., `discovery`). Similarly,
`K8sClusterName` may appear as `WEU-102` in one metric and `weu-102` in another.

When merging data from multiple metrics by `(cluster, namespace, service)`, **always normalize**:
- **namespace** → lowercase
- **K8sClusterName** → UPPERCASE

Failure to normalize causes rows to not merge — producing `0` values for fields from
the mismatched metric (e.g., `mem_req = 0` when the memory metric returns `weu-102` but CPU
returns `WEU-102`).

---

## MDA Cluster Filter

MDA production clusters are in the **100–199** range and typically follow:

```text
{REGION}-{ID}
```

Examples:

- `UKS-101`
- `UKS-106`
- `WEU-102`
- `WEU-105`
- `WUS-101`
- `WUS2-101`
- `EUS-103`

### Primary / DR / Inline note

MDA clusters are classified as **Inline**, **Primary**, or **DR** based on cluster identity (not
namespace). Inline clusters (all `-108` clusters plus CIN-101, CNC-101, EAS-101, etc.) are
active-active. Non-inline clusters in DR regions (`EUS`, `NEU`, `CUS`, `UKW`, `WCUS`, `USGT`,
`USMT`) typically have KEDA paused or disabled with 0 replicas. These clusters will show **no
utilization data** in Geneva — this is expected behavior, not a data quality or coverage issue.
Do not treat missing Geneva data from DR clusters as a problem or downgrade confidence because of it.
See [mda-cluster-inventory.md](mda-cluster-inventory.md) for the full cluster classification.

### Pattern guidance

- Region prefixes are usually `2–4` characters: `UKS`, `WEU`, `WUS`, `WUS2`, `EUS`, `EUS2`, and similar.
- Filter `K8sClusterName` to match MDA clusters only.

Practical regex for reasoning:

```text
^[A-Z0-9]{2,4}-1\d{2}$
```

Use the concrete cluster names from project config whenever possible rather than relying on regex at query time.

---

## Metric Reference

Use this verified reference first for the core AKS rightsizing metrics. These values were validated against Geneva dashboard `8B012708` and live metric configs.

### Metric Reference Table

**CPU Metrics:**

| Metric | Container Dim | Scale | Supported Samplings | Pre-aggregation | Use For |
|--------|--------------|-------|---------------------|-----------------|---------|
| `container:resource_requests_cpu_millicores` | `container_name` | ÷1000 for cores | Average | By-DC-K8sClusterName-namespace-service_name-container_name | Current CPU request |
| `container:resource_limits_cpu_millicores` | `container_name` | ÷1000 for cores | Average | By-DC-K8sClusterName-namespace-service_name-container_name | Current CPU limit |
| `container:cpu_usage_rate_millicores` | `container_name` | ÷1000 for cores | **P50, P95, P99, Max, Average** (percentileMetricsEnabled) | By-DC-K8sClusterName-namespace-service_name-container_name | **PRIMARY**: CPU actual usage — the only CPU metric with percentile support |
| `container:cpu_usage_percent_by_request_scaled` | `container_name` | **÷10** for actual % | Average only (no percentiles!) | By-DC-K8sClusterName-namespace-service_name-container_name | Quick utilization view |
| `container:cpu_elevated_throttling_scaled` | **`container`** ⚠️ | **÷10** for actual % | Average only | By-DC-K8sClusterName-namespace-service_name (note: different pre-agg, no container_name!) | CPU throttling detection |

**Memory Metrics:**

| Metric | Container Dim | Scale | Supported Samplings | Use For |
|--------|--------------|-------|---------------------|---------|
| `container:resource_requests_memory_bytes` | `container_name` | ÷(1024³) for GB | Average | Current memory request |
| `container:resource_limits_memory_bytes` | `container_name` | ÷(1024³) for GB | Average | Current memory limit (must == request in MDA) |
| `container:memory_usage_bytes` | `container_name` | ÷(1024³) for GB | Average, Max | Actual memory usage — **use Average for utilization/waste calculations** (see warning #5 below) |

**Replica Metrics:**

| Metric | Key Dimensions | Use For |
|--------|---------------|---------|
| `keda:hpa_min_replicas` | Check config — may differ from other metrics | HPA/KEDA minimum |
| `keda:hpa_max_replicas` | Check config — may differ from other metrics | HPA/KEDA maximum (compare with actual to detect drift) |
| `keda:hpa_current_replicas` | Check config | Current replica count |
| `kube_deployment_status_replicas` | Check config | Deployment replicas |

**OOM Kill Metrics:**

| Metric | Container Dim | Supported Samplings | Pre-aggregation | Use For |
|--------|--------------|---------------------|-----------------|---------|
| `container:oomkills_total` | `container_name` | Sum — if Geneva returns only Average or Rate, multiply Average × data-point-count to derive total events | By-DC-K8sClusterName-namespace-service_name-container_name | OOM kill count — any > 0 means memory pressure |

## ⚠️ Critical Dimension and Scaling Rules

1. **`_scaled` metrics use ÷10, not ÷100**: A value of 735 from `cpu_usage_percent_by_request_scaled` means **73.5%** utilization. A value of 450 from `cpu_elevated_throttling_scaled` means **45%** throttling.

2. **Throttling uses `container` not `container_name`**: The `container:cpu_elevated_throttling_scaled` metric has dimension `container`, while all other container metrics use `container_name`. Querying throttling with `container_name` returns `InvalidSeries` silently — no error message, just empty data!

3. **`container:cpu_usage_rate_millicores` is the ONLY CPU metric with percentile support**: Do NOT try to query P95/P99 from `cpu_usage_percent_by_request_scaled` — it only supports Average. Use `cpu_usage_rate_millicores` for P50, P95, P99, Max.

4. **Always query CPU limit alongside request**: The `container:resource_limits_cpu_millicores` metric is essential for throttling analysis. A service can look like it has low utilization while being heavily throttled because the limit caps actual usage.

5. **Do NOT use Max sampling for `memory_usage_bytes` in utilization or waste calculations**: Geneva pre-aggregates this metric as a **sum across all pods**. Max sampling captures the peak of this sum, which spikes during rolling restarts when 2 pods briefly coexist (e.g., 2 × 8 GiB = 16 GiB). Dividing by single-pod request (e.g., 10 GiB) yields >100% utilization — physically impossible per-pod. **Always use Average sampling** for memory utilization ratios. Average for both usage and request gives a consistent per-pod ratio because both are equally affected by replica count changes.

---

## Metric Discovery Workflow

Do not hard-code metric names unless they already exist in project config, but prefer the verified reference above before exploring alternatives.

### Step 1 — confirm the namespace

```text
metrics_get_namespaces(tenantName = "WCDProduction")
```

Verify `WCDPRDInfraSystem` is present.

### Step 2 — list metrics in the namespace

```text
metrics_get_metric_names(
  tenantName      = "WCDProduction",
  metricNamespace = "WCDPRDInfraSystem"
)
```

### Step 3 — start with the known rightsizing metrics

Check for these first:

- `container:resource_requests_cpu_millicores`
- `container:resource_limits_cpu_millicores`
- `container:cpu_usage_rate_millicores`
- `container:cpu_usage_percent_by_request_scaled`
- `container:cpu_elevated_throttling_scaled`
- `container:resource_requests_memory_bytes`
- `container:resource_limits_memory_bytes`
- `container:memory_usage_bytes`
- `keda:hpa_min_replicas`
- `keda:hpa_max_replicas`
- `keda:hpa_current_replicas`
- `kube_deployment_status_replicas`
- `container:oomkills_total`

If a metric is absent or renamed in a given environment, then search for related candidates by concept:

- CPU request: `CpuRequest`, `cpu_request`
- CPU limit: `CpuLimit`, `cpu_limit`
- CPU usage: `CpuUsage`, `cpu_usage`, `CpuMillicores`
- CPU throttling: `CpuThrottle`, `cpu_throttled`, `ThrottledTime`
- Memory request: `MemoryRequest`, `memory_request`
- Memory limit: `MemoryLimit`, `memory_limit`
- Memory usage: `MemoryUsage`, `memory_usage`, `MemoryWorkingSet`
- Replica count: `ReplicaCount`, `replica`, `PodCount`
- HPA min / max: `HpaMin`, `HpaMax`, `hpa_min_replicas`, `hpa_max_replicas`
- OOM kills: `OOMKill`, `oomkill`, `oom_total`

### Step 4 — inspect the config of each candidate metric

```text
metrics_get_metric_config(
  monitoringAccount = WCDProduction,
  metricNamespace   = WCDPRDInfraSystem,
  metric            = <candidate_metric>
)
```

From the metric config, capture:

- available dimensions
- pre-aggregate configurations
- supported sampling types such as `Average`, `P50`, `P95`, `P99`, `Max`
- whether `percentileMetricsEnabled` is present

### Why config inspection matters

- Filtering on a dimension that is not present in any pre-aggregation often returns empty data silently.
- Different metrics may spell service and container dimensions differently.
- `container:cpu_elevated_throttling_scaled` uses `container`, not `container_name`.
- `container:cpu_usage_percent_by_request_scaled` supports `Average` only.
- `container:cpu_usage_rate_millicores` is the CPU metric to use for percentile analysis.

---

## Query Patterns

Once metric discovery is complete, reuse these query shapes.

### CPU analysis for one service

```text
# Step 1: Get CPU request and limit
Metric: container:resource_requests_cpu_millicores
Metric: container:resource_limits_cpu_millicores
Sampling: Average
Dimensions: K8sClusterName, namespace, service_name, container_name=wdatp-service

# Step 2: Get CPU actual usage with percentiles
Metric: container:cpu_usage_rate_millicores
Sampling: P50, P95, P99, Max, Average  (percentiles available!)
Dimensions: K8sClusterName, namespace, service_name, container_name=wdatp-service

# Step 3: Get CPU throttling (NOTE: different container dimension!)
Metric: container:cpu_elevated_throttling_scaled
Sampling: Average
Dimensions: K8sClusterName, namespace, service_name, container=wdatp-service  ← NOT container_name!
Scale: ÷10 for actual percentage

# Step 4: Get CPU utilization % (optional, for quick view)
Metric: container:cpu_usage_percent_by_request_scaled
Sampling: Average (only Average available!)
Scale: ÷10 for actual percentage

Time range: now - 14d to now - 2min
```

If the metric uses `service` or `pServiceName`, substitute the actual dimension name from config.

### Enumerate services in a namespace

Use `metrics_read_multi_time_series` with a wildcard on the service dimension:

```text
service_name = *
```

This is useful for discovering which services emit a metric in a given namespace.

### Replica analysis

Use the discovered replica-count metric with:

- `K8sClusterName`
- `namespace`
- service dimension (`service_name`, `service`, or `pServiceName`)

Read actual replicas over the 14-day window, then compare that series to HPA / KEDA min and max
configuration. Use **Max sampling** for actual replicas to detect drift — if `max(actual) > hpa_max`,
someone manually scaled the deployment.

---

## Time Range Rules

- Default time window: `14 days`
- Always set `endTimeUtc` to at least `2 minutes before now`
- Use **Unix epoch milliseconds** where the Geneva tool expects epoch-based input

This avoids incomplete trailing data and keeps results consistent across metrics.

---

## Important Notes

- Check pre-aggregation before assuming a dimension filter will work.
- Expect dimension-name drift across metrics:
  - `service_name`
  - `service`
  - `pServiceName`
  - `container_name`
  - `container`
- For the verified throttling metric, use `container` and `Average` only.
- Recent Geneva data can appear partially populated; the `now - 2min` rule is mandatory.

---

## Runtime Discipline

At runtime, the skill should:

1. Prefer project-configured metric names if present.
2. Fall back to discovery only when needed.
3. Validate each metric's dimensions before reading data.
4. Always include the `wdatp-service` container filter.

Do not guess metric names or dimension names from memory.
