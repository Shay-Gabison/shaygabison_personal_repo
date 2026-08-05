---
name: kusto-compute-rightsizing
description: 'Drive MDA Kusto compute cluster right-sizing toward the MSEE Optimization target (Weighted Peak CPU 45% / Memory 60%). Uses the weekly "Compute Details" xlsx as input and **GenevaMonitoring.MCP.Server** (account `KustoWestUS`, namespace `MdmEngineMetrics`) to enrich every cluster row with WeekAvg/WeekMax/MonthAvg/MonthMax for 14 engine metrics (CPU, memory, cache, ingestion, query duration, throttling, streaming, export, keep-alive). Applies the official MSEE methodology: Weighted Peak CPU = Σ[(Cores_i / Total_Cores) × P95_CPU_i], Cores Returnable = Cores × (1 − WtdPeakCPU / 45%), bucketed into the 4 official recommendations (Consolidate near-zero, Right-size scale units, Enable optimized autoscale, Migrate deprecated SKUs). Produces an enriched xlsx mirroring the IDX Analytics report shape and per-cluster Geneva MDM Engine Health V3 dashboard links. Use when the user mentions Kusto/ADX right-sizing, MSEE optimization, Wtd Peak CPU/Mem, Cores Returnable, Compute Details sheet, Feature #6, aka.ms/mseedash, MDA Kusto cost, deprecated SKUs (D16A_V4 / D32D_V4 / E16AS_V4 → v5), or enriching the sheet with Geneva engine metrics.'
---

# MDA Kusto Compute Right-Sizing Skill

Drives the **MSEE Optimization Initiative** for MDA Kusto compute toward the **45% Weighted Peak CPU** / **60% Weighted Peak Memory** target tracked in [ADO Feature #6](https://dev.azure.com/MSecEE/MSEE%20Optimization%20Initiatives/_workitems/edit/6). Input is the weekly **Compute Details** xlsx; output is an enriched xlsx + cluster-level recommendations aligned to the official IDX Analytics report.

> Source of truth dashboard: **`http://aka.ms/mseedash`** (Kusto tab).
> Source of truth Kusto table: **`CoreUtilizationDailyAggregatesV3`** filtered to ARM type `Microsoft.Kusto` and joined via `HOBO_ServiceTreeId` to MDA (`2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d`).

## Official Methodology (MSEE / IDX Analytics)

| Quantity | Formula |
| --- | --- |
| **Weighted Peak CPU** | `Σ[(Cores_i ÷ Total_Cores) × P95_CPU_i]` — large scale units dominate |
| **Weighted Peak Memory** | `Σ[(Cores_i ÷ Total_Cores) × P95_Memory_i]` |
| **Cores Returnable** | `Cores_i × (1 − WtdPeakCPU_scope / 45%)` — clamp ≥ 0 |
| **Monthly $ Savings** | `(Monthly $_scope) × (1 − WtdPeakCPU_scope / 45%)` — clamp ≥ 0 |

- **"Peak" means P95** — not arithmetic max. The sheet's `Peak CPU Util` / `Peak Memory Util` columns are already P95 over the week.
- **Targets**: `45%` CPU, `60%` Memory. Update only if a service team negotiates a different target via the Feature's `Effort` field.
- **Scope** can be **fleet**, **region**, **scale-unit** (== Resource Group / `Name`), or **cluster pool** (e.g., all `mcaspr*`). The same formula applies at every scope.
- **MDA fleet baseline** (from the PDF, May 12–23 2026): 597 VMs · 261K daily cores · WtdCPU **10.6%** · WtdMem **27.1%** · Returnable **~199K cores** · est. savings **$1.6M/mo**.

## Inputs

### 1. Weekly Compute Details xlsx
- Pattern: `YYYY-MM-DD Compute Details.xlsx` (attached to Feature #6 each week).
- **Often password-protected** (CDFV2 Encrypted). If `openpyxl` fails with `BadZipFile`, ask the user for the password or paste TSV.
- Columns:
  - `Subscription Name`, `Region`, `Region Restricted` (Yes/No), `SKU`, `SKU Status` (`Active`/`Deprecated`)
  - `Resource Group` (`kucompute-<scaleunit>` or `kudatamgmt-<scaleunit>`), `Name` (scale-unit short name), `Resource` (`kengine`/`ksengine`/`kdatamana`)
  - `Cores` (provisioned vCPU), `Peak CPU Util` (P95 %), `Peak Memory Util` (P95 %), `Cost/Day` (USD, formatted `$N,NNN`)

### 2. Geneva MDM Engine Health V3 dashboard (per-cluster drill-down)
Base URL — both `Cluster` and `TargetCluster` overrides must be the **UPPERCASE** value of the `Name` column:

```
https://portal.microsoftgeneva.com/dashboard/KustoProd/MdmEngineMetrics/engine%20health%20V3?overrides=[
  {"query":"//*[id='Account']","key":"regex","replacement":"*"},
  {"query":"//*[id='Cluster']","key":"value","replacement":"<CLUSTER_UPPER>"},
  {"query":"//dataSources","key":"account","replacement":"KustoWestUS"},
  {"query":"//*[id='TargetCluster']","key":"value","replacement":"<CLUSTER_UPPER>"},
  {"query":"//*[id='Account']","key":"value","replacement":""}
]
```

URL-builder snippet:

```python
import json, urllib.parse
def engine_health_v3_url(name: str) -> str:
    c = name.upper()
    o = [
      {"query":"//*[id='Account']","key":"regex","replacement":"*"},
      {"query":"//*[id='Cluster']","key":"value","replacement":c},
      {"query":"//dataSources","key":"account","replacement":"KustoWestUS"},
      {"query":"//*[id='TargetCluster']","key":"value","replacement":c},
      {"query":"//*[id='Account']","key":"value","replacement":""},
    ]
    return ("https://portal.microsoftgeneva.com/dashboard/KustoProd/MdmEngineMetrics/"
            "engine%20health%20V3?overrides=" + urllib.parse.quote(json.dumps(o, separators=(",",":")), safe=""))
```

## The 4 Official Recommendations (bucket every row into exactly one)

Apply in priority order. A cluster goes into the **first** bucket it qualifies for.

### R1 — Consolidate Near-Zero Clusters  *(highest $ impact)*
- **Trigger**: cluster's individual `Peak CPU < 5%` **and** ≥ 1,000 cores **and** (ideally) sustained for **14+ days**.
- **Action**: merge data into fewer, right-sized clusters per region. Start with the largest, lowest-utilization.
- **PDF estimate**: $627K–$940K/mo (fleet-wide).

### R2 — Right-Size Over-Provisioned Scale Units
- **Trigger**: `5% ≤ Peak CPU < 25%` **and** `Peak Memory < 50%`, **or** `Cores Returnable ≥ 500`.
- **Action**: reduce instance count per scale unit (PDF suggests up to **76%** reduction at the 45% target).
- **PDF estimate**: $313K–$548K/mo.

### R3 — Enable Optimized Autoscale
- **Trigger**: any active cluster with `Cores ≥ 200` not already covered by R1/R2 — especially those with bursty profiles (high P95 but low average). Static provisioning pays for peak 24/7.
- **Action**: enable Kusto optimized autoscale with aggressive min, scale-in cooldown, weekend/off-hours to min.
- **PDF estimate**: $103K–$205K/mo.

### R4 — Migrate Deprecated SKUs
- **Trigger**: `SKU Status == Deprecated`. Priority families to retire: `D16A_V4`, `D32D_V4`, `D8A_V4`, `D2A_V4`, `E16AS_V4`, `E16S_V4`, `E2A_V4`.
- **Action**: rotate to current-gen (`L*as_v3`, `E*ads_v5`, `E16d_v4` for compute-heavy).
- **PDF estimate**: 8–10% on the deprecated fleet.

### "Keep" (no action)
- Already at or above the target (`Peak CPU ≥ 45%` and `Peak Memory ≥ 60%` with no deprecated SKU). Document and watch.

### Hot — explicit upsize/scale-out *(safety bucket, surfaces alongside R1–R4)*
- `Peak CPU > 85%` **or** `Peak Memory > 80%` → flag as `HOT` regardless of any other bucket; cannot be downsized.

## Per-Cluster Output Columns

For each row in the enriched xlsx:

| Column | How it's computed |
| --- | --- |
| `WtdPeakCPU_Cluster` | `Peak CPU Util` of this row (already P95) |
| `WtdPeakMem_Cluster` | `Peak Memory Util` of this row |
| `CoresReturnable@45` | `max(0, Cores × (1 − WtdPeakCPU_Cluster / 45))` |
| `MonthlySavings@45` | `max(0, Cost/Day × 30 × (1 − WtdPeakCPU_Cluster / 45))` |
| `Recommendation` | One of `R1_CONSOLIDATE`, `R2_RIGHTSIZE`, `R3_AUTOSCALE`, `R4_SKU_ROTATE`, `KEEP`, `HOT` |
| `HotFlag` | `Y` if `Peak CPU > 85` or `Peak Memory > 80`, else blank |
| `DashboardUrl` | Per-cluster MDM Engine Health V3 link |

## Aggregations to Compute

At each scope, weight by `Cores`:

```python
def weighted_peak(rows, util_col):
    total = sum(r["Cores"] for r in rows) or 1
    return sum(r["Cores"] * r[util_col] for r in rows) / total
```

Roll up:
- **Fleet** (all rows): `WtdPeakCPU`, `WtdPeakMem`, `Cores`, `Monthly $`, `Cores Returnable`, est. `Monthly $ Savings`.
- **Per Region**: same metrics, sorted by `Cores` desc.
- **Per Subscription**: same metrics, sorted by `Monthly $` desc.
- **Per Cluster Family**: group by prefix (`mcaspr`, `mcasge`, `mdapr`, `tpprd`, `ceprd`, `compprd`, `complianceprd`, `mda-adxmcas`, etc.).
- **Top 10 by Cores** (mirror the PDF's headline table).
- **Recommendation bucket totals** (R1..R4 + HOT + KEEP): cluster count, cores, monthly $, cores returnable, est. savings.

## End-to-End Workflow

1. **Load the sheet** with `openpyxl` (or parse pasted TSV). Normalize `Cost/Day` (`$8,325` → `8325.0`), uppercase `Name` for URLs.
2. **Per-row enrichment**: compute `CoresReturnable@45`, `MonthlySavings@45`, `Recommendation`, `HotFlag`, `DashboardUrl`.
3. **Aggregate**: build all rollups listed above.
4. **Write enriched xlsx** with sheets:
   - `Per Cluster` — full enriched rows, color-coded by Recommendation, autofilter + frozen header.
   - `Fleet Summary` — single-row KPI block (WtdCPU, WtdMem, Cores, $/mo, Returnable, $ Savings, gap to 45%).
   - `Recommendations` — counts + cores + $ per bucket; matches the PDF's Savings Summary table.
   - `By Region` — region rollup, sorted by cores.
   - `By Subscription` — subscription rollup, sorted by $/mo.
   - `Top 10 by Cores` — mirrors the PDF.
   - `Deprecated SKUs` — every R4 cluster with SKU + suggested replacement.
   - `Hot` — every HOT-flagged cluster.
5. **Report to user**: fleet WtdCPU vs 45%, total est. monthly savings, top contributors per recommendation bucket, and dashboard links for follow-up.

## SKU Rotation Map (for R4 reasoning)

| Deprecated | Suggested replacement | Notes |
| --- | --- | --- |
| `standard_d16a_v4` / `standard_d8a_v4` / `standard_d2a_v4` | `standard_l16as_v3` (or `standard_e16ads_v5` if memory-bound) | General-purpose AMD → storage-opt v3 or memory-opt v5 |
| `standard_d32d_v4` | `standard_l16as_v3` × scale-out, or `standard_e16d_v4` if Intel required | Largest deprecated family in MDA |
| `standard_e16as_v4` / `standard_e2a_v4` | `standard_e16ads_v5` | Memory-optimized v4 → v5 |
| `standard_e16s_v4` | `standard_e16ads_v5` | Intel mem-opt → AMD mem-opt v5 |

## Naming Conventions (decoding `Name`)

- `mcaspr<NN><region><idx>` — MCAS prod stamps (e.g., `mcaspr05usw6-s` = MCAS Prod 05, US West 2, stamp 6, secondary)
- `mcaspr*follow*` / `mcaspr*follower*` — read-replica followers (expect low CPU; **don't** downsize blindly — measure read-query latency)
- `mcasge00<region><id>` — MCAS Geneva (Genie)
- `compprd<region>streamfiles`, `complianceprd<region>files` — Compliance pipeline
- `tpprd<region>hunt*` — Threat Protection hunting
- `ceprd<region>activitiesdr-s` — Customer Experience activities (DR copies, secondary)
- `mda-adxmcas-prd-<region>` — MDA shared ADX
- Suffix `-s` = secondary node-set; `-dm` = data-management
- `Resource` column: `kengine` = primary, `ksengine` = secondary, `kdatamana` = data-management

## Geneva MDM Engine-Metric Enrichment (MANDATORY)

The skill **must** call the **`GenevaMonitoring.MCP.Server`** MCP server to populate per-cluster engine metrics. These columns are required in the enriched xlsx output:

- For each cluster (sheet `Name`, **uppercased** for the dimension filter)
- For each metric listed below
- For each window: `WeekAvg` (7 d mean), `WeekMax` (7 d max), `MonthAvg` (30 d mean), `MonthMax` (30 d max)

Fixed Geneva parameters:

| Parameter | Value |
| --- | --- |
| Monitoring account | **`KustoWestUS`** (verify via `tenant_search_by_prefix`; if data is empty, try `KustoProd`, `Kustowestus2`, `Kustoeastus`, `Kustowesteurope`, or `*-ahm` siblings) |
| Metric namespace | **`MdmEngineMetrics`** (also try `engineMetrics`, `MdmEngineHosterMetrics` if empty) |
| Dimension filter | **`Cluster == <NAME_UPPER>`** |

### Metrics — actual names in `KustoWestUS/MdmEngineMetrics`

The 14 "canonical" names below are **conceptual buckets**. The real metric names that exist in production (verified 2026-06-03 via `metrics_get_metric_names`) are different — map canonical → actual at runtime. **Don't fail the run if a canonical name is missing; use the mapped actual name.**

| Canonical (skill jargon) | Actual metric in MdmEngineMetrics | Notes |
| --- | --- | --- |
| `CpuUsagePercent` | `EngineCpuThread` | per-engine CPU thread % |
| `MemoryUsagePercent` | `MemoryLoadFactor` | 0-1 load factor (×100 for %) |
| `CacheUtilization` | `CurrentDiskCacheShardsPercentage` | hot-cache fullness |
| `IngestionLatency` | `IngestionLatencyInSeconds` (or `IngestionLatency_Seconds`) | seconds |
| `IngestionUtilization` | `IngestionCapacityUtilization` | 0-1 |
| `IngestionVolumeMB` | `IngestCommandOriginalSizeInMb` | per command, sum is best |
| `QueryDurationP95` | derived: `QueryDuration` with `Percentile(95)` sampling type | not a standalone metric |
| `QueryDurationP99` | derived: `QueryDuration` with `Percentile(99)` sampling type | not a standalone metric |
| `QueryFailedCount` | `QueryFailedCount` or `QueriesFailedCount` | count |
| `TotalNumberOfThrottledCommands` | `ExternalThrottling` (or `ThrottledCommandsCount`) | count |
| `StreamingIngestRequestRate` | `StreamingIngestRequestRate` (or `StreamingIngestionRequestRate`) | req/sec |
| `ExportUtilization` | `ExportUtilization` (rare; may not exist on all clusters) | 0-1 |
| `ContinuousExportNumOfRecordsExported` | `ContinuousExportNumRecordsExported` | count |
| `KeepAlive` | `IsEngineAlive` | 0/1 heartbeat |

> **Always discover first** (one call at startup):
> ```
> metrics_get_metric_names(account="KustoWestUS", namespace="MdmEngineMetrics")
> ```
> Build the canonical→actual map from the returned list using **case-insensitive substring match**, with the table above as priority order. Log the map in the run summary.

### Required MCP call sequence

Use these tools from `GenevaMonitoring.MCP.Server` (do **not** silently skip them and write `N/A`):

1. **Health + account validation** (once)
   ```
   health()
   tenant_search_by_prefix(prefix="KustoWestUS")
   ```
2. **Metric-name discovery + canonical mapping** (once)
   ```
   metrics_get_metric_names(account="KustoWestUS", namespace="MdmEngineMetrics")
   ```
3. **Probe one cluster** (MANDATORY before bulk fetch — proves the account/namespace combo actually returns data):
   ```
   metrics_kqlm_query(account="<ACCT>",
     query="metricNamespace('<NS>').metric('<MAPPED_METRIC>').samplingTypes('Average').where(Cluster=='<PROBE_CLUSTER_UPPER>').timeRange(ago(1h), now())")
   ```
   - If `datapointsCount == 0` for every probed cluster: **halt**, fall back through the account/namespace candidates listed above, and re-probe.
   - Only proceed to bulk fetch once a probe returns non-zero data.
4. **Fetch per cluster** (preferred — one call per cluster, all mapped metrics, both windows)
   ```
   metrics_kqlm_query(
     account = "<ACCT>",
     query = """
       metricNamespace('<NS>')
       .metric(<MAPPED_METRIC>)
       .samplingTypes('Average','Max')
       .where(Cluster == '<CLUSTER_UPPER>')
       .timeRange(ago(30d), now())
       .summarize(weekAvg=avgIf(Average, TIMESTAMP>ago(7d)),
                  weekMax=maxIf(Max,     TIMESTAMP>ago(7d)),
                  monthAvg=avg(Average),
                  monthMax=max(Max))
         by metric=Metric
     """
   )
   ```
5. **Fallback** (per-metric, per-window) if KQL-M is unavailable:
   ```
   metrics_read_time_series_aggregated(
     account     = "<ACCT>",
     namespace   = "<NS>",
     metric      = <MAPPED_METRIC>,
     dimensions  = {"Cluster": "<CLUSTER_UPPER>"},
     start       = now() - timedelta(days=<7|30>),
     end         = now(),
     aggregations= ["Average","Max"],
     windowSeconds = <7|30> * 86400
   )
   ```
6. **Optional drill-down chart** for a HOT or R1 cluster:
   ```
   metrics_read_multi_time_series(account="<ACCT>", namespace="<NS>",
                                  metric=<MAPPED_METRIC>, dimensions={"Cluster":"<NAME_UPPER>"},
                                  start=ago(7d), end=now(), aggregations=["Average","Max"])
   render_chart(series=...)
   ```

### Connectivity preflight (must run before fetching)

Run this once at the start of an enrichment pass and abort/raise if it fails:

```python
def preflight():
    """Verify GenevaMonitoring.MCP.Server is reachable, account is accessible, AND data flows."""
    h = call_mcp("GenevaMonitoring.MCP.Server", "health")
    assert h.get("status") in ("ok","healthy","Healthy"), h

    # Try each candidate account in order until one returns data
    for account in ["KustoWestUS", "KustoProd", "Kustowestus2",
                    "Kustoeastus", "Kustowesteurope"]:
        accounts = call_mcp("GenevaMonitoring.MCP.Server", "tenant_search_by_prefix",
                            {"prefix": account})
        if not any(a.lower().startswith(account.lower()) for a in accounts):
            continue
        for ns in ["MdmEngineMetrics", "engineMetrics", "MdmEngineHosterMetrics"]:
            names = call_mcp("GenevaMonitoring.MCP.Server", "metrics_get_metric_names",
                             {"account": account, "namespace": ns})
            if not names:
                continue
            mapping = build_canonical_mapping(names)         # see table above
            probe_metric = mapping.get("KeepAlive") or mapping.get("CpuUsagePercent") or names[0]
            probe = call_mcp("GenevaMonitoring.MCP.Server", "metrics_kqlm_query", {
                "account": account,
                "query": f"metricNamespace('{ns}').metric('{probe_metric}').samplingTypes('Average').timeRange(ago(1h), now())"
            })
            if probe.get("datapointsCount", 0) > 0:
                return {"account": account, "namespace": ns, "mapping": mapping}
    raise RuntimeError(
        "No Geneva account / namespace combination returned engine-metric data. "
        "Ask the user to confirm the current MDA Kusto monitoring account name "
        "(KustoWestUS may have been retired/renamed). Halt — DO NOT write W* columns."
    )
```

If `preflight()` raises:
- **Do NOT** silently fill W* columns with `N/A` or `0`.
- **Do NOT** overwrite the source xlsx.
- Tell the user the exact accounts/namespaces tried and ask which to use; stop.

### Output file rule (NEVER overwrite)

Every enrichment pass writes to a **new** xlsx:

```
<source_stem> (with metrics <YYYY-MM-DD HH-MM>).xlsx
```

- The source file is read-only input.
- The previous enriched file is left intact (history / diff).
- Before starting a fetch, **ask the user**: *"This will create `<new_filename>` (~ N clusters × M metrics calls, est. T min). Proceed?"* — and wait for confirmation. Skip the confirmation only if the user message already says "go" / "yes" / "do it".

### Cell-population rules

- `WeekAvg` / `MonthAvg` → numeric (rounded to 2 decimals for percentages, 0 decimals for counts/MB).
- `WeekMax` / `MonthMax` → numeric (same rounding).
- Metric **does not exist for this node role** (e.g., `QueryDurationP95` on a `kdatamana` row, `ExportUtilization` on a `kengine` row): leave **blank**, not `0` and not `N/A`.
- Metric **exists but has no samples** in the window: write `0`.
- Geneva API error for a single cluster: write the literal string `ERR:<short-reason>` so the row is auditable.
- A whole-fleet zero-data result is **never** a per-row error — it's a preflight failure (see above) and halts the run.
- Throttling / batching: cap to ~5 parallel `metrics_kqlm_query` calls; back off on `429`.

### Flag rules (computed after enrichment)

Add a `Flags` column (comma-separated) using the W* data:

| Flag | Condition |
| --- | --- |
| `CPU_HOT` | `CpuUsagePercent WeekMax > 85` |
| `CPU_COLD` | `CpuUsagePercent MonthAvg < 15` |
| `MEM_HOT` | `MemoryUsagePercent WeekMax > 90` |
| `MEM_COLD` | `MemoryUsagePercent MonthAvg < 30` |
| `CACHE_FULL` | `CacheUtilization WeekAvg > 95` |
| `CACHE_EMPTY` | `CacheUtilization WeekAvg < 40` |
| `INGEST_LAG` | `IngestionLatency WeekMax > 1.5 × MonthAvg` |
| `INGEST_TIGHT` | `IngestionUtilization WeekMax > 0.8` |
| `QUERY_SLOW` | `QueryDurationP95 WeekAvg > 2 × QueryDurationP95 MonthAvg` |
| `THROTTLED` | `TotalNumberOfThrottledCommands WeekMax > 0` |
| `EXPORT_TIGHT` | `ExportUtilization WeekMax > 0.8` |
| `DEPRECATED_SKU` | `SKU Status == Deprecated` |

The W* signals **override** the simpler P95-based Recommendation when they conflict (e.g., a cluster that looks like R1 by P95 but has `CACHE_FULL` or `INGEST_TIGHT` must be downgraded out of R1 — downsizing would break it).

## Cross-Skill Bridge — Geneva MCP

For deeper interactive drill-down on a flagged cluster (charts, multi-dimension breakdowns, IcM lookup), use the **`geneva-monitoring-mcp`** skill — same MCP server, full tool catalog. This skill (`kusto-compute-rightsizing`) **owns** the bulk-enrichment of the weekly xlsx; `geneva-monitoring-mcp` owns ad-hoc exploration.

## Reference Workflow (Code Skeleton)

```python
import re, json, urllib.parse, openpyxl
from openpyxl.styles import Font, PatternFill
from collections import defaultdict

TARGET_CPU = 45.0   # %
TARGET_MEM = 60.0   # %

def parse_cost(s): return float(re.sub(r"[^\d.]", "", str(s) or "0"))

def url_for(name):
    c = name.upper()
    o = [{"query":"//*[id='Account']","key":"regex","replacement":"*"},
         {"query":"//*[id='Cluster']","key":"value","replacement":c},
         {"query":"//dataSources","key":"account","replacement":"KustoWestUS"},
         {"query":"//*[id='TargetCluster']","key":"value","replacement":c},
         {"query":"//*[id='Account']","key":"value","replacement":""}]
    return ("https://portal.microsoftgeneva.com/dashboard/KustoProd/MdmEngineMetrics/"
            "engine%20health%20V3?overrides=" + urllib.parse.quote(json.dumps(o, separators=(",",":")), safe=""))

def recommend(r):
    cpu, mem, cores, dep = r["Peak CPU Util"], r["Peak Memory Util"], r["Cores"], r["SKU Status"] == "Deprecated"
    if cpu > 85 or mem > 80:                              return "HOT"
    if cpu < 5 and cores >= 1000:                         return "R1_CONSOLIDATE"
    if cpu < 25 and mem < 50:                             return "R2_RIGHTSIZE"
    if dep:                                               return "R4_SKU_ROTATE"
    if cores >= 200 and cpu < TARGET_CPU:                 return "R3_AUTOSCALE"
    return "KEEP"

def cores_returnable(cores, wtd_cpu): return max(0.0, cores * (1 - wtd_cpu / TARGET_CPU))

def weighted_peak(rows, col):
    tot = sum(r["Cores"] for r in rows) or 1
    return sum(r["Cores"] * r[col] for r in rows) / tot
```

## Example Prompts

- *"Run the right-sizing skill on `2026-06-02 Compute Details.xlsx` and tell me where we are vs the 45% target."*
- *"What's MDA's current Weighted Peak CPU / Memory? How many cores are returnable and what's the est. monthly savings?"*
- *"List every R1 (consolidate) candidate ranked by cores returnable, with dashboard links."*
- *"Top 10 clusters by core count — mirror the PDF table."*
- *"Region rollup: WtdCPU, WtdMem, $/mo, est. savings by region."*
- *"For the deprecated SKUs in this week's sheet, propose v5 replacements and the SKU-rotate plan."*
- *"Which clusters are HOT (>85% CPU or >80% mem) and need an upsize, not a downsize?"*
- *"Pull live Geneva metrics for `mcaspr05usw6` to validate it's safe to consolidate."*

## Canonical One-Shot Prompt (paste in VS Code Copilot Chat — Agent mode, Geneva MCP enabled)

> Use this verbatim when Yossi/Or/leadership asks for "the enriched xlsx with 30d metrics". Produces the deliverable in a single pass.

```
Use the kusto-compute-rightsizing skill at ~/.copilot/skills/kusto-compute-rightsizing/SKILL.md.

Source xlsx: /Users/shaygabison/.copilot/session-state/<SESSION>/files/<WEEKLY>.xlsx
Output xlsx: same path with suffix " (with metrics).xlsx"

Goal (Yossi's ask, Teams "Kusto Core Reduction" thread): 30-day analysis of every cluster + as many engine metrics as possible + Geneva dashboard link + scale-in recommendation with by-how-much.

For EACH cluster row in the "Per Cluster" sheet:
1. Resolve the Geneva account = "KustoWestUS", namespace = "MdmEngineMetrics", dimension Cluster = UPPER(Name)
2. For each of these 14 metrics:
   CpuUsagePercent, MemoryUsagePercent, CacheUtilization, IngestionLatency,
   IngestionUtilization, IngestionVolumeMB, QueryDurationP95, QueryDurationP99,
   QueryFailedCount, TotalNumberOfThrottledCommands, StreamingIngestRequestRate,
   ExportUtilization, ContinuousExportNumOfRecordsExported, KeepAlive
   Call metrics_kqlm_query with samplingTypes Average + Max, two windows:
     - last 7d  -> W7_Avg, W7_Max
     - last 30d -> W30_Avg, W30_Max
3. Write 56 columns (14 metrics × 4 stats) per row.
4. Recompute Flags + Recommendation per skill rules using REAL P95 CPU
   (CpuUsagePercent W30_Max as proxy if no P95 available, else fall back to sheet's Peak CPU Util).
5. Add columns: "Safe to Scale In?" (YES/MAYBE/NO), "Suggested Cores Cut",
   "Suggested Cut %", "Suggested $/mo Savings", "Scale-In Notes".
6. Color-code rows by recommendation (HOT=red, R1=orange, R2=yellow, R3=green, R4=blue, KEEP=grey).
7. Be efficient: batch by region/stamp, parallelize calls, skip clusters with no
   metric data and mark them "No Geneva data".

Throttling: if you hit MCP rate limits, sleep 2s and retry up to 3x.

When done, summarize:
- # clusters enriched / # skipped
- Top 20 scale-in candidates (by $/mo savings)
- Total $/mo savings opportunity
- Save the xlsx and print full path
```

**Why VS Code, not Copilot CLI**: Geneva MCP server (`GenevaMonitoring.MCP.Server`) requires an interactive Edge auth on first call. VS Code's MCP host can launch that browser flow; Copilot CLI's MCP host cannot. The tool itself is `dotnet tool install --global GenevaMonitoring.MCP.Server` from the AzureGenevaMonitoring Azure Artifacts feed. See `geneva-monitoring-mcp` sister skill for full install + 56-tool catalog.

## Notes / Gotchas

- `Peak` in the sheet **is already P95** (per the official methodology). Don't apply another percentile on top.
- `Name` is lowercase in the sheet; dashboard `Cluster`/`TargetCluster` overrides expect **UPPERCASE**.
- Followers (`*follow*`, `*follower*`) naturally show low CPU — judge by query latency on the dashboard, not by raw CPU.
- `Region Restricted = Yes` → SKU swap must respect sovereign/regional availability.
- `Cores Returnable` can mathematically exceed `Cores × (45/45)` when WtdCPU > 45 — clamp to 0 (over-target clusters return nothing).
- Per-cluster `WtdPeakCPU_Cluster` is just its own Peak CPU (Cores ÷ Cores = 1). Weighting only matters when aggregating across rows.
- This skill never modifies anything in Azure; it reads the sheet + (optionally) Geneva, and writes a new enriched xlsx.
