---
name: geneva-engine-health-dashboard
description: Enumerate every chart/metric on the Geneva MDM "Engine Health V3" dashboard for a Kusto cluster and dump full per-metric details (config, sampling types, dimensions, recent values, thresholds, what it means) into a single reference table. Use whenever someone asks "what does <chart> on the engine health dashboard mean", "what metric drives <panel>", "give me everything about this Kusto cluster's engine health", or wants to mass-document the dashboard for a runbook / right-sizing exercise. Pairs with kusto-compute-rightsizing (for sizing decisions) and geneva-monitoring-mcp (for the underlying MCP tools).
---

# Geneva MDM "Engine Health V3" — Metric Reference Skill

## Purpose

Treat the **Engine Health V3** dashboard (Geneva account `KustoProd` view, but the data lives in `KustoWestUS` for MDA) as an enumerable catalog. For every chart on the dashboard, this skill produces a row with: metric name, what it measures, sampling types used, dimensions, recent values for a target cluster, healthy / warning / critical thresholds, and "what's interesting".

Use this when you need to:

- Explain what a panel means without clicking around the dashboard.
- Bulk-fetch all engine metrics for a single cluster (or a list).
- Build a per-cluster engine-health report to attach to an ICM, PR review, or right-sizing memo.
- Feed `kusto-compute-rightsizing` with richer-than-7-day signal.

## Source Dashboard

**Base URL (clusterless template)**

```
https://portal.microsoftgeneva.com/dashboard/KustoProd/MdmEngineMetrics/engine%20health%20V3
?overrides=[
  {"query":"//*[id='Account']","key":"regex","replacement":"*"},
  {"query":"//*[id='Cluster']","key":"value","replacement":"<CLUSTER_UPPER>"},
  {"query":"//dataSources","key":"account","replacement":"KustoWestUS"},
  {"query":"//*[id='TargetCluster']","key":"value","replacement":"<CLUSTER_UPPER>"},
  {"query":"//*[id='Account']","key":"value","replacement":""}
]
```

Replace `<CLUSTER_UPPER>` (twice) with the uppercase cluster name (e.g. `COMPPRDWUSSTREAMFILES`).

**Geneva fixed params for fetching the data behind the panels:**

| Param | Value |
| --- | --- |
| Monitoring account | `KustoWestUS` (probe siblings if empty — see `kusto-compute-rightsizing` Connectivity preflight) |
| Namespace | `MdmEngineMetrics` (also try `engineMetrics`, `MdmEngineHosterMetrics`) |
| Dimension | `Cluster == <CLUSTER_UPPER>` |
| Optional dims | `RoleInstance`, `Account`, `Database`, `Region` |

## Dashboard Panel → Metric Map

The dashboard organizes ~40 panels into 8 sections. Below is the canonical map with the actual MDM metric backing each panel (verified 2026-06-03 against `metrics_get_metric_names(KustoWestUS, MdmEngineMetrics)` — keep this table in sync when Geneva renames metrics).

### 1. Liveness & Heartbeat

| Panel | Metric | Sampling | What it tells you |
| --- | --- | --- | --- |
| Is Engine Alive | `IsEngineAlive` | Average | 0/1 heartbeat. Anything < 1 in last 5 min = down node. |
| Engine Uptime | `EngineUptimeInMinutes` | Max | Minutes since last restart. Sudden drop = restart event. |
| Keep-Alive Failures | `KeepAliveFailures` | Sum | Count of missed heartbeats. > 0 = node flapping. |

### 2. CPU & Threads

| Panel | Metric | Sampling | What it tells you |
| --- | --- | --- | --- |
| Engine CPU (Avg) | `EngineCpuThread` | Average | Per-thread CPU %. > 80 avg = hot. |
| Engine CPU (P95) | `EngineCpuThread` | Percentile(95) | P95 used for the official Weighted Peak CPU calculation. |
| CPU per Role Instance | `EngineCpuThread` (by RoleInstance) | Average | Hot single node = bad data distribution. |
| Thread Pool Pressure | `ThreadPoolQueueLength` | Max | Backed-up worker queue = saturated CPU. |

### 3. Memory

| Panel | Metric | Sampling | What it tells you |
| --- | --- | --- | --- |
| Memory Load Factor (Avg) | `MemoryLoadFactor` | Average | 0-1; > 0.85 = pressure. |
| Memory Load Factor (P95) | `MemoryLoadFactor` | Percentile(95) | Drives Weighted Peak Memory. |
| Working Set MB | `WorkingSetInMB` | Average | Absolute RAM use per role instance. |
| GC Pause Seconds | `GcPauseDurationInSeconds` | Max | > 1s pauses = bad GC pressure. |

### 4. Hot Cache

| Panel | Metric | Sampling | What it tells you |
| --- | --- | --- | --- |
| Cache Shards % | `CurrentDiskCacheShardsPercentage` | Average | 100% = cache full → cold queries. |
| Cache Hit Ratio | `CacheHitRatio` | Average | < 0.7 = poor cache locality. |
| Bytes Loaded from Hot | `HotCacheBytesLoaded` | Sum | Throughput from SSD. |
| Bytes Loaded from Cold | `ColdCacheBytesLoaded` | Sum | Throughput from blob — high = $$ + latency. |

### 5. Ingestion

| Panel | Metric | Sampling | What it tells you |
| --- | --- | --- | --- |
| Ingestion Latency (sec) | `IngestionLatencyInSeconds` | Average / Max | End-to-end commit time. > 30s sustained = backlog. |
| Ingestion Volume (MB) | `IngestCommandOriginalSizeInMb` | Sum | Throughput. |
| Ingestion Capacity Utilization | `IngestionCapacityUtilization` | Average | 0-1; > 0.8 = capacity-bound. |
| Streaming Ingest Rate (req/s) | `StreamingIngestRequestRate` | Average | Inverse: 0 on engines that don't take streaming. |
| Failed Ingestion Count | `FailedIngestionCount` | Sum | > 0 = data loss risk. |

### 6. Query

| Panel | Metric | Sampling | What it tells you |
| --- | --- | --- | --- |
| Query Duration P95 (s) | `QueryDuration` | Percentile(95) | SLO indicator. |
| Query Duration P99 (s) | `QueryDuration` | Percentile(99) | Long tail. |
| Query Rate (qps) | `QueriesCount` | Sum | Workload size. |
| Failed Query Count | `QueryFailedCount` | Sum | > 0 sustained = error budget burn. |
| Cancelled Query Count | `QueriesCancelled` | Sum | Often user-side timeout. |

### 7. Throttling & Errors

| Panel | Metric | Sampling | What it tells you |
| --- | --- | --- | --- |
| External Throttling | `ExternalThrottling` | Sum | Caller hit a 429. > 0 = capacity push-back. |
| Internal Throttling | `InternalThrottling` | Sum | Engine self-throttled. |
| Throttled Commands | `ThrottledCommandsCount` | Sum | Admin commands rate-limited. |
| Engine Errors | `EngineErrorsCount` | Sum | Internal errors. |

### 8. Export & Continuous Export

| Panel | Metric | Sampling | What it tells you |
| --- | --- | --- | --- |
| Continuous Export Records | `ContinuousExportNumRecordsExported` | Sum | Exported row count. |
| Continuous Export Lag | `ContinuousExportLagInSeconds` | Max | > 600s = export pipeline behind. |
| Export Utilization | `ExportUtilization` | Average | 0-1; > 0.8 = export capacity bound. |

> **Note**: Not every metric exists on every cluster (e.g. streaming/export metrics are zero on engines that don't run those workloads). The skill must mark those cells **blank**, not `0` — same rule as `kusto-compute-rightsizing`.

## What "details" means in this skill

For every panel above, produce a row with these columns:

| Column | Source |
| --- | --- |
| `Section` | from the table above |
| `Panel` | from the table above |
| `Metric` | actual MDM metric name |
| `Sampling` | sampling type used (Average / Max / Sum / Percentile(N)) |
| `Unit` | from `metrics_get_metric_config_v2` (e.g. seconds, MB, count, ratio) |
| `Dimensions` | from `metrics_get_metric_config_v2` (publishable + preagg) |
| `Last1h_Value` | most recent reading via `metrics_kqlm_query` |
| `Last1d_Avg` / `Last1d_Max` | aggregated 24h |
| `Last7d_Avg` / `Last7d_Max` | aggregated 7d |
| `Last30d_Avg` / `Last30d_Max` | aggregated 30d |
| `Healthy` / `Warning` / `Critical` | from the threshold table below |
| `Status` | computed: max(Last7d_Max, Last1h_Value) bucketed against thresholds |
| `What's Interesting` | from this skill's notes column |
| `V1 Monitors` | from `monitor_get_monitor_v1_configuration(namespace=MdmEngineMetrics, metric=<m>)` |
| `V2 Monitors` | from `monitor_get_monitor_v2_by_resource_type(resourceType="MdmEngineMetrics:<m>")` |
| `Dashboard URL` | base URL + cluster override |

## Default Thresholds (override per-cluster as needed)

| Metric | Healthy | Warning | Critical |
| --- | --- | --- | --- |
| IsEngineAlive | 1.0 | < 1.0 last 5m | < 1.0 last 30m |
| EngineCpuThread (Avg) | < 60% | 60-80% | > 80% |
| EngineCpuThread (P95) | < 75% | 75-90% | > 90% |
| MemoryLoadFactor | < 0.7 | 0.7-0.85 | > 0.85 |
| GcPauseDurationInSeconds | < 0.5 | 0.5-1.0 | > 1.0 |
| CurrentDiskCacheShardsPercentage | < 80 | 80-95 | > 95 |
| CacheHitRatio | > 0.85 | 0.7-0.85 | < 0.7 |
| IngestionLatencyInSeconds | < 10 | 10-30 | > 30 |
| IngestionCapacityUtilization | < 0.6 | 0.6-0.8 | > 0.8 |
| FailedIngestionCount | 0 | 1-10 | > 10 |
| QueryDuration (P95) | < 30s | 30-120s | > 120s |
| QueryFailedCount | 0 | 1-100 | > 100 |
| ExternalThrottling | 0 | 1-100 | > 100 |
| ContinuousExportLagInSeconds | < 60 | 60-600 | > 600 |
| ExportUtilization | < 0.6 | 0.6-0.8 | > 0.8 |

## End-to-End Workflow

```
INPUT: cluster_name (lower or upper), optional time_window=30d

1. preflight (reuse from kusto-compute-rightsizing):
     pick {account, namespace} that returns data for this cluster.
     build canonical→actual metric mapping.

2. for each (section, panel, canonical_metric, sampling) in PANEL_MAP:
     actual = mapping.get(canonical_metric) or canonical_metric
     config = metrics_get_metric_config_v2(account, namespace, actual)
     row = {Section, Panel, Metric: actual, Sampling,
            Unit: config.unit, Dimensions: config.dimensions,
            "What's Interesting": notes[canonical_metric]}

     # one KQL-M roundtrip per metric covers all 5 windows
     q = f"""
       metricNamespace('{namespace}')
       .metric('{actual}')
       .samplingTypes('{sampling}')
       .where(Cluster == '{cluster_upper}')
       .timeRange(ago(30d), now())
       .summarize(
         last1h    = arg_max(TIMESTAMP, *),
         last1d_avg= avgIf(value, TIMESTAMP > ago(1d)),
         last1d_max= maxIf(value, TIMESTAMP > ago(1d)),
         last7d_avg= avgIf(value, TIMESTAMP > ago(7d)),
         last7d_max= maxIf(value, TIMESTAMP > ago(7d)),
         last30d_avg=avg(value),
         last30d_max=max(value))
     """
     row.update(metrics_kqlm_query(account, q))
     row["Status"] = bucket(row["last7d_max"], thresholds[canonical_metric])
     row["V1 Monitors"] = monitor_get_monitor_v1_configuration(namespace, actual)
     row["V2 Monitors"] = monitor_get_monitor_v2_by_resource_type(f"{namespace}:{actual}")
     row["Dashboard URL"] = build_url(cluster_upper)
     yield row

3. write xlsx:
     Sheet 1 "Cluster Health" — one row per panel, sorted by Status DESC.
     Sheet 2 "Critical" — rows where Status == Critical.
     Sheet 3 "Warnings" — rows where Status == Warning.
     Sheet 4 "Active Monitors" — V1+V2 monitor configs.
     Sheet 5 "Metadata" — chosen account/namespace, mapping, run timestamp.

4. print summary:
     <N> Critical, <M> Warning, <K> Healthy.
     Top 5 worst panels with current value vs threshold.
     One-line verdict: HOT / OK / COLD per the kusto-compute-rightsizing buckets.
```

## Output File Rule

Always a **new** file — never overwrite source:

```
~/.copilot/session-state/<SESSION>/files/EngineHealth_<CLUSTER_UPPER>_<YYYY-MM-DD HH-MM>.xlsx
```

If the user passes a list of clusters, produce one xlsx with one sheet per cluster (plus a `Fleet Summary` sheet that pivots panel × cluster status).

## Connectivity Preflight (DO NOT skip)

Reuse the preflight from `kusto-compute-rightsizing/SKILL.md`. If it fails:
- Don't write a file.
- Tell the user exactly which account/namespace combinations were tried and ask which to use.

## Example Prompts

- *"Give me everything Geneva knows about engine health for cluster `mcaspr05usw6`."*
- *"Dump the Engine Health V3 dashboard for `COMPPRDWUSSTREAMFILES` to an xlsx."*
- *"Compare engine health between `mcaspr05usw6` and `mcaspr05usw6-s` panel-by-panel."*
- *"What's the threshold and current value for IngestionLatency on cluster `compprdwusstreamfiles`?"*
- *"List every Critical panel for all R1 candidates from this week's right-sizing run."*

## Cross-Skill Bridge

- **`geneva-monitoring-mcp`** → underlying 67-tool MCP catalog (install, auth, tool details).
- **`kusto-compute-rightsizing`** → upstream consumer of these per-cluster signals; uses CPU/Memory P95 + Cache + Ingestion flags to decide R1/R2/R3/R4/HOT.

## Notes / Gotchas

- The dashboard URL has **two** `Cluster` overrides (`Cluster` + `TargetCluster`) — both must match.
- Cluster names in the sheet are lowercase; the MDM dimension and URL overrides are **uppercase**.
- `QueryDuration` is sampled — there's no `QueryDurationP95` standalone metric; request `samplingTypes('Percentile(95)')`.
- Followers (`*follow*`, `*follower*`) intentionally show low CPU and near-100% cache — judge them on query latency, not CPU.
- A whole-fleet zero-data result is a **preflight failure**, not a per-row error — halt and ask the user.
- Some panels show derived expressions (e.g. ratios across two metrics). When the panel formula isn't 1:1 with a stored metric, this skill records the closest underlying metric and notes the derivation in `What's Interesting`.
