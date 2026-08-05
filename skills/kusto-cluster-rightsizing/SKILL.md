---
name: kusto-cluster-rightsizing
description: "End-to-end ADX/Kusto cluster right-sizing. Fetches 30-day Engine Health metrics from Geneva MDM for a fleet of Kusto clusters, then runs a decision engine that writes Hold / Scale-in % / SKU Change recommendations back into the same xlsx with traffic-light row coloring. Use when the user asks to 'right-size', 'analyze', 'snapshot', 'generate recommendations for' Kusto/ADX clusters, or wants the engine-health dashboard as a table with recommendations. Replaces the older kusto-engine-health-snapshot + adx-rightsizing skill pair."
metadata:
  domain: "infrastructure"
  confidence: "high"
---

<!--
═══════════════════════════════════════════════════════════════════════════════
  HUMANS: read this top section to install + use. Everything below the
  "Agent contract" divider is the agent's contract — you don't need to read it
  unless you're curious.
═══════════════════════════════════════════════════════════════════════════════
-->

# Kusto Cluster Right-Sizing (Snapshot + Analyze)

A single self-contained skill that does both phases in one shot:

1. **Snapshot** — fetch 30-day Engine Health metrics (77 of them) for every Kusto cluster in the user's fleet from Geneva MDM, append them as `<Metric> 30dAvg` / `<Metric> 30dMax` columns into an xlsx.
2. **Analyze** — apply the decision tree to each row, write `Recommendation` and `Why` columns, regenerate the `Summary` tab, and **color every data row** with a traffic-light palette by recommendation.

The Python analyzer is **embedded** inside this SKILL.md (no external `.py` file ships with the skill — the agent writes it to the user's cwd at runtime).

## Install (one command)

```bash
mkdir -p ~/.copilot/skills/kusto-cluster-rightsizing
mv SKILL.md ~/.copilot/skills/kusto-cluster-rightsizing/SKILL.md
```

## Use it

Trigger phrases:

> *"Right-size these Kusto clusters: \<paste names\>"*
> *"Snapshot + analyze the fleet in `compute-details.xlsx`"*
> *"Run the right-sizing pipeline on `engine_health.xlsx`"*
> *"Analyze this existing right-sizing xlsx"* — skip the fetch, just run the analyzer.
> *"Re-run analysis with the colors"* — analyze-only mode.

The agent will:
1. Install the Geneva MCP if missing, ensure auth is cached.
2. Normalize whatever cluster input you gave it into `(name, region)` pairs.
3. Fetch 77 metrics × N clusters over the last 30 days into the source xlsx.
4. Run the embedded analyzer (also written to `./analyze.py` in your cwd for transparency).
5. Deliver the final xlsx with `Recommendation`, `Why`, traffic-light row colors, and a regenerated `Summary` tab.
6. **Preserve all existing dashboard hyperlinks** in the source tab and Summary tab (a regression from the older standalone analyzer).

Prereqs the agent checks/fixes automatically: `dotnet` SDK, `genevamonitoring-mcp` tool, Geneva auth, `python3 + openpyxl`.

## Retiring the older skills

This skill **supersedes** both `kusto-engine-health-snapshot` and `adx-rightsizing`. Once you've validated a successful run, you can safely delete:

```bash
rm -rf ~/.copilot/skills/kusto-engine-health-snapshot
rm -rf ~/.copilot/skills/adx-rightsizing
```

This skill never deletes them automatically.

---

<!--
═══════════════════════════════════════════════════════════════════════════════
  AGENT: this is your contract. Read end-to-end before acting, then execute
  the Agent Procedure. Every constant below is authoritative — do not
  "simplify" them away. The embedded analyzer source is the SECOND code block
  at the bottom under "Embedded analyzer".
═══════════════════════════════════════════════════════════════════════════════
-->

# Agent contract

You are the agent. **You will build and run a Python snapshot fetcher** that pulls Engine Health V3 signals from Geneva MDM, and then **you will write the embedded analyzer to `./analyze.py`** and run it against the resulting xlsx.

## Two modes

| Mode | Trigger | What you do |
|---|---|---|
| **Full pipeline** | User wants snapshot + recommendations | Run Steps 1–7 (fetch + analyze). |
| **Analyze-only** | User says "analyze this existing xlsx" / "re-run the recommendations" / "just rerun the analyzer" | **Skip Steps 1–6**. Go straight to Step 7 — write `analyze.py` from the embedded block and run it on the xlsx the user gave you. |

If the user is ambiguous, ask which mode (one question, structured).

## Inputs to collect

| Input | Required? | Default |
|---|---|---|
| Cluster list (any shape) | Full pipeline only | — |
| Source xlsx path | Analyze-only: yes. Full pipeline: optional. | Standalone xlsx in `./out/` |
| Source tab name | No | `Right-Sizing Snapshot updated` |
| Lookback window | No | 30 days |
| Resolution | No | daily (1440 min) |
| Workers | No | 6 |

---

## Step 1 — Verify / install the Geneva MCP

```bash
command -v genevamonitoring-mcp || ls ~/.dotnet/tools/genevamonitoring-mcp 2>/dev/null
```

If missing:

```bash
dotnet tool install -g GenevaMonitoring.MCP.Server
export PATH="$PATH:$HOME/.dotnet/tools"
```

If `dotnet` is missing too: tell the user to install the .NET SDK (https://dotnet.microsoft.com/download) and stop.

Cache Geneva auth once (otherwise the parallel workers each prompt and stall):

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1.0"}}}' \
  | ~/.dotnet/tools/genevamonitoring-mcp --stdio | head -1
```

## Step 2 — Verify Python deps

```bash
python3 -c "import openpyxl" || pip install openpyxl
```

## Step 3 — Normalize cluster input to `(name, region)` pairs

Accept any shape (bare names, name+region CSV, xlsx, ARG query). If you only have names, resolve regions via:

1. **Azure Resource Graph** (preferred):
   ```kql
   resources
   | where type =~ "microsoft.kusto/clusters"
   | where name in~ ("mcaspr05usw6", ...)
   | project name, location
   ```
   Map `location` (`westus2`) → the region key in `REGION_TO_ACCOUNT` (`uswest2`).
2. **Name convention** — MDA cluster names encode region in chars 5–9 (e.g. `MCASPR05USW6` → `USW6` → `uswest2`). Last resort, warn the user.
3. **Ask the user** — if you can't resolve, list the unresolvable names.

Cluster-name normalization for the Geneva `Cluster` dimension: `UPPER()` and strip trailing `-S`.

## Step 4 — Write the snapshot fetcher

Create `geneva_fetch.py` in the user's cwd. Use the constants and skeletons below.

### Constant 1 — The 77 metrics

```python
ALL_METRICS = [
    "ActiveServiceInstances","AllPartitionedRecordsPercentage","ConcurrentIngests",
    "ConcurrentQueries","ConcurrentSeals","ContinuousExportDurationSeconds",
    "ContinuousExportLatencyMinutes","ContinuousExportNumArtifactsExported",
    "ContinuousExportSizeInBytesArtifactsExported","DataPartitioningLoadFactor",
    "DataPartitioningOperationsInProgress","DbMetadataSizeBytes","DbObjectsSizeBytes",
    "ExportsLoadFactor","ExtentsCount","ExtentsSize","ExtentsTotal",
    "ExternalThrottling","FollowerFullRefreshDurationMs","HotDataDiskSpaceUsage",
    "HotPartitionedRecordsPercentage","IngestDuration","IngestSizeBytes",
    "IngestionCapacityUtilization","IngestionResult","IngestionsInProgress",
    "IngestionsLoadFactor","IngestionsSuccessRate","IngestsLoadFactor",
    "InstancesTargetBasedOnDataCapacity","IsEngineAlive","IsEngineAnsweringQuery",
    "IsRowStoreUnhealthy","MachinesOffline","MachinesTotal",
    "MaterializedViewAgeMinutes","MaterializedViewExtentsRebuild",
    "MaterializedViewExtentsRebuildConcurrency","MaterializedViewHealth",
    "MaterializedViewResult","MaterializedViewsInProgress","MaterializedViewsLoadFactor",
    "MaxContinuousExportLatenessMinutes","MergesInProgress","MergesLoadFactor",
    "MergesSuccessRate","MirroringDurationSeconds","MirroringOperationsInProgress",
    "MirroringOperationsLoadFactor","PartitionedRecords","PartitionedShards",
    "PendingContinuousExports","PurgeExtentsRebuildInProgress",
    "PurgeExtentsRebuildLoadFactor","PurgesInProgress",
    "QueryAccelerationCatalogAgeMinutes","QueryAccelerationCatalogStaleWithHealthyState",
    "QueryAccelerationCompletePercentage","QueryAccelerationNumberOfArtifactsPendingCaching",
    "QueryAccelerationOperationsInProgress","QueryAccelerationOperationsLoadFactor",
    "QueryAccelerationUnexpectedErrorInCachedTableRefresh",
    "QueryAccelerationUnexpectedErrorInCatalogRefresh",
    "QueryDuration","QueryThrottled","RowStoreWriteAheadLogSizeBytes",
    "SandboxInitializationFailed","SealsLoadFactor","ServiceLevelObjective",
    "ShardsMergePendingOperationsCount","ShardsMergePendingShardsCount",
    "ShardsPartitioningPendingOperationsCount","ShardsPartitioningPendingShardsCount",
    "StreamingIngestionLocalStorageBytes","StuckQueries","TotalExtentSize",
    "WeakConsistencySnapshotLatencySeconds",
]
```

### Constant 2 — Region → regional MDM account

```python
REGION_TO_ACCOUNT = {
    "uswest":        "KustoWestUS",
    "uswest2":       "KustoWestUS",
    "uswest3":       "Kustowestus3",
    "useast":        "Kustoeastus",
    "useast2":       "Kustoeastus2",
    "uscentral":     "Kustocentralus",
    "usnorth":       "Kustonorthcentralus",
    "uswestcentral": "Kustowestcentralus",
    "ukwest":        "Kustoukwest",
    "uksouth":       "Kustouksouth",
    "europewest":    "Kustowesteurope",
    "europenorth":   "Kustonortheurope",
    "usgoveast":     "KustoUSGovVirginia",
    "usgovsc":       "KustoUSGovTexas",
    "southafrican":  "Kustosouthafricanorth",
    "norwaye":       "Kustonorwayeast",
    "koreacentral":  "Kustokoreacentral",
    "asiasoutheast": "Kustosoutheastasia",
    "australiaeast": "Kustoaustraliaeast",
    "brazilsouth":   "Kustobrazilsouth",
    "canadacentral": "Kustocanadacentral",
    "francec":       "Kustofrancecentral",
    "germanywc":     "Kustogermanywestcentral",
    "indiacentral":  "Kustocentralindia",
    "japaneast":     "Kustojapaneast",
    "swedenc":       "Kustoswedencentral",
    "switzerlandn":  "Kustoswitzerlandnorth",
    "uaen":          "Kustouaenorth",
}
```

`KustoProd` is the dashboard owner account — never query it for data. Pattern for any region not in the table: `Kusto<regionname>` lowercase.

### Constant 3 — The MCP request shape

```python
request = {
    "jsonrpc": "2.0", "id": req_id, "method": "tools/call",
    "params": {
        "name": "metrics_read_multi_time_series",
        "arguments": {
            "monitoringAccount": acct,
            "metricNamespace":   "MdmEngineMetrics",
            "metricName":        metric,
            "samplingType":      "Average",
            "startTimeUtc":      start_utc,
            "endTimeUtc":        end_utc,
            "seriesResolutionInMinutes": 1440,
            "dimensionFilters":  json.dumps({"Cluster": gname, "DataCenter": "*"}),
        },
    },
}
```

**Use only `metrics_read_multi_time_series`.** The other Geneva metric APIs (`metrics_read_time_series_aggregated`, `metrics_read_time_series`, `metrics_kqlm_query`) silently misbehave on dimension values with spaces or KQL-M quirks.

### Constant 4 — Sampling-type fallback

Always pass `"Average"`. Confirmed safe: `Average`, `NullableAverage`, `Rate`. Everything else falls back to `Average` — empirically within a few percent of dashboard values.

### Constant 5 — Trailing-zero handling

```python
values = [dp["value"] for dp in datapoints]
while values and values[-1] == 0:
    values.pop()
```

### Constant 6 — Metrics with no Cluster-dim data (auto-drop)

`QueryDuration`, `RowStoreWriteAheadLogSizeBytes`, `ConcurrentQueries`, `ExternalThrottling`, `MaterializedViewAgeMinutes`.

### Skeleton 1 — MCP stdio worker

```python
import subprocess, json, select, time, queue, threading, statistics

def start_mcp(mcp_bin):
    proc = subprocess.Popen(
        [mcp_bin, "--stdio"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, bufsize=1,
    )
    init = {"jsonrpc":"2.0","id":0,"method":"initialize",
            "params":{"protocolVersion":"2024-11-05","capabilities":{},
                      "clientInfo":{"name":"worker","version":"1.0"}}}
    proc.stdin.write(json.dumps(init) + "\n"); proc.stdin.flush()
    _read_line(proc, timeout=20)
    proc.stdin.write(json.dumps({"jsonrpc":"2.0","method":"notifications/initialized"}) + "\n")
    proc.stdin.flush()
    time.sleep(0.5)
    return proc

def _read_line(proc, timeout=30):
    t0 = time.time()
    while time.time() - t0 < timeout:
        ready, _, _ = select.select([proc.stdout], [], [], 1)
        if ready:
            line = proc.stdout.readline()
            if line.strip():
                try: return json.loads(line.strip())
                except Exception: continue
    return None

def parse_result(resp):
    if not resp or "result" not in resp:
        return {"avg": None, "max": None, "status": "error"}
    try:
        content = resp["result"].get("content", [])
        if not content:
            return {"avg": None, "max": None, "status": "no_content"}
        rd = json.loads(content[0].get("text", ""))
        dps = rd.get("datapoints") or (rd.get("series", [{}])[0].get("datapoints", []) if rd.get("series") else [])
        values = [dp["value"] for dp in dps]
        while values and values[-1] == 0:
            values.pop()
        if not values:
            return {"avg": None, "max": None, "status": "no_data"}
        return {"avg": round(statistics.mean(values), 4),
                "max": round(max(values), 4),
                "last": round(values[-1], 4), "n": len(values)}
    except Exception:
        return {"avg": None, "max": None, "status": "parse_err"}

def worker(worker_id, mcp_bin, task_q, data, lock, checkpoint_path,
           start_utc, end_utc, resolution=1440):
    proc = start_mcp(mcp_bin)
    req_id = 0
    while True:
        try:
            acct, gname, metric = task_q.get(timeout=2)
        except queue.Empty:
            break
        req_id += 1
        request = {
            "jsonrpc":"2.0","id":req_id,"method":"tools/call",
            "params":{"name":"metrics_read_multi_time_series","arguments":{
                "monitoringAccount": acct,
                "metricNamespace": "MdmEngineMetrics",
                "metricName": metric,
                "samplingType": "Average",
                "startTimeUtc": start_utc, "endTimeUtc": end_utc,
                "seriesResolutionInMinutes": resolution,
                "dimensionFilters": json.dumps({"Cluster": gname, "DataCenter":"*"}),
            }},
        }
        try:
            proc.stdin.write(json.dumps(request) + "\n"); proc.stdin.flush()
            resp = _read_line(proc, timeout=30)
        except Exception:
            resp = None
        result = parse_result(resp)
        with lock:
            data[f"{gname}__{metric}"] = result
            if len(data) % 100 == 0:
                with open(checkpoint_path, "w") as f: json.dump(data, f)
        task_q.task_done()
    try: proc.stdin.close(); proc.kill()
    except Exception: pass
```

### Skeleton 2 — Driver (batched, resumable)

```python
def run(clusters, mcp_bin, checkpoint_path, start_utc, end_utc,
        num_workers=6, batch_size=50):
    import os
    data = json.load(open(checkpoint_path)) if os.path.exists(checkpoint_path) else {}
    lock = threading.Lock()
    remaining = [(g, n, r) for g, n, r in clusters
                 if any(f"{g}__{m}" not in data for m in ALL_METRICS)]
    for i in range(0, len(remaining), batch_size):
        batch = remaining[i:i+batch_size]
        task_q = queue.Queue()
        for g, n, r in batch:
            acct = REGION_TO_ACCOUNT.get(r.lower())
            if not acct:
                print(f"⚠ no MDM account for region '{r}' (cluster {g})"); continue
            for m in ALL_METRICS:
                if f"{g}__{m}" not in data:
                    task_q.put((acct, g, m))
        threads = [threading.Thread(target=worker,
                    args=(w, mcp_bin, task_q, data, lock, checkpoint_path,
                          start_utc, end_utc), daemon=True)
                   for w in range(num_workers)]
        for t in threads: t.start(); time.sleep(1)
        for t in threads: t.join()
        with open(checkpoint_path, "w") as f: json.dump(data, f)
    return data
```

### Skeleton 3 — XLSX builder (snapshot append)

```python
import openpyxl
from openpyxl.styles import Font, PatternFill

def cluster_to_geneva(name):
    u = name.strip().upper()
    return u[:-2] if u.endswith("-S") else u

def active_metrics(data, ALL_METRICS):
    clusters = {k.split("__")[0] for k in data}
    return [m for m in ALL_METRICS
            if any(data.get(f"{c}__{m}", {}).get("avg") is not None for c in clusters)]

def build_appended(data, src_xlsx, sheet, name_col, out_path, ALL_METRICS):
    # IMPORTANT: keep_links=True to preserve any external/dashboard links in the workbook
    wb = openpyxl.load_workbook(src_xlsx, keep_links=True)
    ws = wb[sheet] if sheet else wb.active
    start = ws.max_column + 1
    hdr_fill = PatternFill("solid", fgColor="4472C4")
    hdr_font = Font(bold=True, color="FFFFFF", size=8)
    metrics = active_metrics(data, ALL_METRICS)
    for i, m in enumerate(metrics):
        for off, stat in enumerate(("30dAvg", "30dMax")):
            c = ws.cell(1, start + i*2 + off, f"{m} {stat}")
            c.fill = hdr_fill; c.font = hdr_font
    for row in range(2, ws.max_row + 1):
        nm = ws.cell(row, name_col + 1).value
        if not nm: continue
        g = cluster_to_geneva(str(nm))
        for i, m in enumerate(metrics):
            d = data.get(f"{g}__{m}")
            if d and d.get("avg") is not None:
                ws.cell(row, start + i*2,   round(d["avg"], 2))
                ws.cell(row, start + i*2+1, round(d["max"], 2))
    wb.save(out_path)
```

### Snapshot CLI surface

```
geneva_fetch.py
  --list <csv>            name,region per line (xor --xlsx)
  --xlsx <path>           source xlsx (xor --list)
  --sheet <name>          sheet in xlsx (default: active)
  --name-col <n>          0-indexed Name col in xlsx (default 6)
  --out-dir <dir>         default ./out
  --mcp-bin <path>        default ~/.dotnet/tools/genevamonitoring-mcp
  --workers <n>           default 6
  --batch-size <n>        default 50
  --days <n>              default 30
  --resolution <min>      default 1440
  --rebuild-only          skip fetch; rebuild xlsx from checkpoint
```

Compute `end_utc = now_utc - 10min` and `start_utc = end_utc - days`.

## Step 5 — Preflight

Before the full fetch, run one cluster with `--workers 1 --batch-size 1` and check the checkpoint:
- ~77 keys for that cluster, most with non-null `avg` → good.
- All `"status": "no_data"` → wrong region→account mapping.
- All `"status": "error"` → auth not cached.

## Step 6 — Full fleet fetch

Run the script over the full list. Expected throughput on 6 workers: ~28 calls/s. The checkpoint makes Ctrl-C safe.

## Step 7 — Write `analyze.py` and run the analyzer

This is where the consolidated skill differs from the old one. **Write the embedded analyzer to `./analyze.py`** in the user's cwd (the entire contents of the "Embedded analyzer" code block below — copy verbatim), then run:

```bash
python3 ./analyze.py "<path_to_xlsx>" --source-tab "Right-Sizing Snapshot updated"
```

Flags:
- `--source-tab "Tab Name"` — override (default `Right-Sizing Snapshot updated`)
- `--cpu-threshold 45` — override Hold threshold
- `--factor-threshold 45` — override SKU Change threshold
- `--dry-run` — print without writing
- `--no-color` — skip the traffic-light row coloring

The analyzer will:
1. Load the workbook with `keep_links=True` (preserves dashboard hyperlinks).
2. Resolve metric columns whether they end with `max`/`avg` or `30dMax`/`30dAvg`.
3. Compute `Recommendation` and `Why` for each row.
4. **Color every data row** by recommendation (traffic-light palette).
5. Regenerate the `Summary` tab **in place** (via `delete_rows`, not by deleting+recreating the sheet — to preserve any links/structure).
6. Save the workbook.

## Step 8 — Hand off

Tell the user:
- Output xlsx path.
- Clusters with data vs total rows.
- Metrics with data (some of the 77 will be empty fleet-wide; analyzer auto-handles).
- Any unmapped regions logged during fetch.
- Recommendation distribution (e.g. `Hold: 12, Scale in 30%: 4, SKU Change: 2`).
- **Confirm dashboard hyperlinks survived** — spot-check one known link cell after the run.

---

# Embedded analyzer

**AGENT: write everything inside the next code block, verbatim, to `./analyze.py` in the user's cwd before running.** This is the authoritative analyzer source; do not edit at runtime.

```python
#!/usr/bin/env python3
"""ADX Cluster Right-Sizing Analyzer (embedded copy from kusto-cluster-rightsizing skill).

Reads an Engine Health Excel spreadsheet, applies decision logic to each cluster,
and writes recommendations (Hold, Scale-in %, SKU Change) back to the file with
traffic-light row coloring. Preserves all existing hyperlinks in the workbook.
"""
import argparse
import sys
from collections import Counter
from openpyxl import load_workbook
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side

# ---------------------------------------------------------------------------
# Capacity factors to check (in priority order for SKU-change diagnosis)
# ---------------------------------------------------------------------------
CAPACITY_FACTORS = [
    "HotDataDiskSpaceUsage max",
    "MergesLoadFactor max",
    "IngestionsLoadFactor max",
    "IngestionCapacityUtilization max",
    "MaterializedViewsLoadFactor max",
    "ExportsLoadFactor max",
]

FACTOR_SHORT_NAMES = {
    "HotDataDiskSpaceUsage max": "HotDisk",
    "MergesLoadFactor max": "MergeLF",
    "IngestionsLoadFactor max": "IngLF",
    "IngestionCapacityUtilization max": "ICU",
    "MaterializedViewsLoadFactor max": "MatViewLF",
    "ExportsLoadFactor max": "ExportLF",
}

FACTOR_BOTTLENECK_DESC = {
    "HotDataDiskSpaceUsage max": "storage/SSD pressure",
    "MergesLoadFactor max": "background merge compute",
    "IngestionsLoadFactor max": "ingestion throughput",
    "IngestionCapacityUtilization max": "ingestion capacity",
    "MaterializedViewsLoadFactor max": "materialized view maintenance",
    "ExportsLoadFactor max": "export workload",
}

# ---------------------------------------------------------------------------
# SKU reference table
# ---------------------------------------------------------------------------
SKU_CATALOG = {
    "standard_d2_v2":      {"cores": 2,  "ram": 7,   "ssd_gb": 100,  "cat": "compute"},
    "standard_d11_v2":     {"cores": 2,  "ram": 14,  "ssd_gb": 100,  "cat": "compute"},
    "standard_d13_v2":     {"cores": 8,  "ram": 56,  "ssd_gb": 400,  "cat": "compute"},
    "standard_d14_v2":     {"cores": 16, "ram": 112, "ssd_gb": 800,  "cat": "compute"},
    "standard_ds14_v2":    {"cores": 16, "ram": 112, "ssd_gb": 224,  "cat": "compute"},
    "standard_d2a_v4":     {"cores": 2,  "ram": 8,   "ssd_gb": 50,   "cat": "compute"},
    "standard_d4a_v4":     {"cores": 4,  "ram": 16,  "ssd_gb": 100,  "cat": "compute"},
    "standard_d8a_v4":     {"cores": 8,  "ram": 32,  "ssd_gb": 200,  "cat": "compute"},
    "standard_d16a_v4":    {"cores": 16, "ram": 64,  "ssd_gb": 400,  "cat": "compute"},
    "standard_d8d_v4":     {"cores": 8,  "ram": 32,  "ssd_gb": 300,  "cat": "compute"},
    "standard_d32d_v4":    {"cores": 32, "ram": 128, "ssd_gb": 1200, "cat": "compute"},
    "standard_e2a_v4":     {"cores": 2,  "ram": 16,  "ssd_gb": 50,   "cat": "compute"},
    "standard_e8as_v4":    {"cores": 8,  "ram": 64,  "ssd_gb": 128,  "cat": "compute"},
    "standard_e8s_v4":     {"cores": 8,  "ram": 64,  "ssd_gb": 128,  "cat": "compute"},
    "standard_e16a_v4":    {"cores": 16, "ram": 128, "ssd_gb": 256,  "cat": "compute"},
    "standard_e16as_v4":   {"cores": 16, "ram": 128, "ssd_gb": 256,  "cat": "compute"},
    "standard_e16as_v5":   {"cores": 16, "ram": 128, "ssd_gb": 256,  "cat": "compute"},
    "standard_e16s_v4":    {"cores": 16, "ram": 128, "ssd_gb": 256,  "cat": "compute"},
    "standard_e16d_v4":    {"cores": 16, "ram": 128, "ssd_gb": 600,  "cat": "compute"},
    "standard_e16d_v5":    {"cores": 16, "ram": 128, "ssd_gb": 600,  "cat": "compute"},
    "standard_e2d_v5":     {"cores": 2,  "ram": 16,  "ssd_gb": 75,   "cat": "compute"},
    "standard_e4d_v5":     {"cores": 4,  "ram": 32,  "ssd_gb": 150,  "cat": "compute"},
    "standard_e8d_v5":     {"cores": 8,  "ram": 64,  "ssd_gb": 300,  "cat": "compute"},
    "standard_e2ads_v5":   {"cores": 2,  "ram": 16,  "ssd_gb": 75,   "cat": "compute"},
    "standard_e4ads_v5":   {"cores": 4,  "ram": 32,  "ssd_gb": 150,  "cat": "compute"},
    "standard_e8ads_v5":   {"cores": 8,  "ram": 64,  "ssd_gb": 300,  "cat": "compute"},
    "standard_e16ads_v5":  {"cores": 16, "ram": 128, "ssd_gb": 600,  "cat": "compute"},
    "standard_l8as_v3":    {"cores": 8,  "ram": 64,  "ssd_gb": 1000, "cat": "storage"},
    "standard_l16as_v3":   {"cores": 16, "ram": 128, "ssd_gb": 2000, "cat": "storage"},
    "standard_l32as_v3":   {"cores": 32, "ram": 256, "ssd_gb": 4000, "cat": "storage"},
    "standard_l8s_v3":     {"cores": 8,  "ram": 64,  "ssd_gb": 1000, "cat": "storage"},
    "standard_l16s_v3":    {"cores": 16, "ram": 128, "ssd_gb": 2000, "cat": "storage"},
    "standard_l32s_v3":    {"cores": 32, "ram": 256, "ssd_gb": 4000, "cat": "storage"},
    "standard_e8as_v5+1tb_ps":  {"cores": 8,  "ram": 64,  "ssd_gb": 1000, "cat": "storage-ps"},
    "standard_e16as_v5+2tb_ps": {"cores": 16, "ram": 128, "ssd_gb": 2000, "cat": "storage-ps"},
    "standard_e16as_v5+4tb_ps": {"cores": 16, "ram": 128, "ssd_gb": 4000, "cat": "storage-ps"},
    "standard_ds14_v2+4tb_ps":  {"cores": 16, "ram": 112, "ssd_gb": 4000, "cat": "storage-ps"},
}

STORAGE_UPGRADE_CANDIDATES = [
    "standard_l8as_v3",
    "standard_l8s_v3",
    "standard_l16as_v3",
    "standard_l16s_v3",
    "standard_e16as_v5+4tb_ps",
    "standard_l32as_v3",
    "standard_l32s_v3",
]

# ---------------------------------------------------------------------------
# Traffic-light palette for row coloring
# ---------------------------------------------------------------------------
ROW_COLORS = {
    "Hold":              "C6EFCE",  # light green
    "Scale in 25%":      "FFEB9C",  # light yellow
    "Scale in 30%":      "FFD966",  # yellow
    "Scale in 40%":      "F4B084",  # orange
    "Scale in 50%":      "ED7D31",  # deep orange
    "SKU Change":        "FFC7CE",  # light red
    "Insufficient data": "D9D9D9",  # grey
}


def _ssd_gb_label(gb):
    if gb >= 1000:
        return f"{gb // 1000} TB"
    return f"{gb} GB"


def _val(v):
    if v is None:
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


def _normalize_header(h):
    """Normalize a header name so 'max' and '30dMax' (and 'avg'/'30dAvg') are equivalent.

    Returns the canonical form used by the analyzer (suffix '<metric> max' / '<metric> avg').
    """
    if not h:
        return h
    s = str(h).strip()
    low = s.lower()
    if low.endswith(" 30dmax"):
        return s[:-len(" 30dmax")] + " max"
    if low.endswith(" 30davg"):
        return s[:-len(" 30davg")] + " avg"
    return s


def _build_header_map(ws):
    """Build {canonical_header_name: column_index} from row 1.

    Stores BOTH the original and the canonicalized name so legacy and snapshot
    column naming work transparently.
    """
    hmap = {}
    for cell in ws[1]:
        if cell.value is None:
            continue
        original = str(cell.value).strip()
        canonical = _normalize_header(original)
        hmap[original] = cell.column
        if canonical != original and canonical not in hmap:
            hmap[canonical] = cell.column
    return hmap


def _require_headers(hmap, required):
    missing = [h for h in required if h not in hmap]
    if missing:
        raise ValueError(f"Missing required columns: {missing}")


def _get_sku_suggestion(current_sku, primary_bottleneck, high_factors, nodes_avg=None):
    sku_lower = (current_sku or "").lower().strip()
    cur = SKU_CATALOG.get(sku_lower)
    cur_ssd_gb = cur["ssd_gb"] if cur else None
    nodes = int(round(nodes_avg)) if nodes_avg else None

    if primary_bottleneck == "HotDataDiskSpaceUsage max":
        if cur and cur["cat"] in ("storage", "storage-ps"):
            bigger = []
            for sku_name in STORAGE_UPGRADE_CANDIDATES:
                spec = SKU_CATALOG[sku_name]
                if spec["ssd_gb"] > cur_ssd_gb:
                    bigger.append(f"{sku_name} ({spec['cores']}c, {_ssd_gb_label(spec['ssd_gb'])})")
                    if len(bigger) >= 2:
                        break
            if bigger:
                return f"already storage-optimized ({_ssd_gb_label(cur_ssd_gb)}/node); upgrade to {' or '.join(bigger)}, or scale out (more nodes)"
            return f"already on largest storage SKU ({_ssd_gb_label(cur_ssd_gb)}/node); scale out (add more nodes)"

        suggestions = []
        for sku_name in STORAGE_UPGRADE_CANDIDATES:
            spec = SKU_CATALOG[sku_name]
            if cur_ssd_gb is None or spec["ssd_gb"] >= cur_ssd_gb:
                label = f"{sku_name} ({spec['cores']}c, {_ssd_gb_label(spec['ssd_gb'])})"
                if nodes and cur_ssd_gb and spec["ssd_gb"] > 0:
                    hot_disk_pct = high_factors.get("HotDataDiskSpaceUsage max", 100)
                    total_data_gb = (hot_disk_pct / 100) * nodes * cur_ssd_gb
                    needed_nodes = max(2, -(-int(total_data_gb) // spec["ssd_gb"]))
                    label += f" ~{needed_nodes} nodes"
                suggestions.append(label)
            if len(suggestions) >= 2:
                break
        if not suggestions:
            suggestions = ["standard_l16as_v3 (16c, 2TB)", "standard_l32as_v3 (32c, 4TB)"]
        cur_label = f" (current: {_ssd_gb_label(cur_ssd_gb)}/node)" if cur_ssd_gb else ""
        return f"move to storage-optimized SKU{cur_label}: { ' or '.join(suggestions)}"

    if primary_bottleneck in ("MergesLoadFactor max", "IngestionsLoadFactor max",
                               "IngestionCapacityUtilization max"):
        return "consider scaling out (more nodes) to spread compute/ingestion load"

    if primary_bottleneck == "MaterializedViewsLoadFactor max":
        return "consider scaling out (more nodes) to spread materialized-view maintenance"

    if primary_bottleneck == "ExportsLoadFactor max":
        return "consider scaling out (more nodes) to handle export workload"

    return "review SKU options for this workload profile"


def classify_cluster(ws, hmap, row_idx, cpu_threshold=45, factor_threshold=45):
    def cell(header):
        col = hmap.get(header)
        if col is None:
            return None
        return _val(ws.cell(row=row_idx, column=col).value)

    cpu = cell("Peak CPU")
    mem = cell("Peak Memory")
    current_sku = ws.cell(row=row_idx, column=hmap.get("SKU", 5)).value

    factors = {}
    missing_factors = []
    for f in CAPACITY_FACTORS:
        v = cell(f)
        if v is None:
            missing_factors.append(FACTOR_SHORT_NAMES[f])
            factors[f] = 0
        else:
            factors[f] = v

    if cpu is None and mem is None:
        return "Insufficient data", "No CPU/MEM metrics available"

    cpu = cpu if cpu is not None else 0
    mem = mem if mem is not None else 0

    high_factors = {k: v for k, v in factors.items() if v >= factor_threshold}
    max_factor_val = max(factors.values()) if factors else 0

    if cpu >= cpu_threshold or mem >= cpu_threshold:
        why = f"CPU {cpu:.0f}% / Mem {mem:.0f}%"
        if cpu >= 80 or mem >= 80:
            why += " — at ceiling"
        else:
            why += " — in-band"
        if high_factors:
            top = sorted(high_factors.items(), key=lambda x: x[1], reverse=True)[:2]
            parts = [f"{FACTOR_SHORT_NAMES[k]} {v:.0f}%" for k, v in top]
            why += f" (note: {', '.join(parts)} elevated)"
        return "Hold", why

    if not high_factors:
        max_util = max(cpu, mem, max_factor_val)
        if max_util <= 10:
            pct = 50
        elif max_util <= 20:
            pct = 40
        elif max_util <= 30:
            pct = 30
        else:
            pct = 25
        why = f"CPU {cpu:.0f}% / Mem {mem:.0f}% / max factor {max_factor_val:.0f}%"
        if missing_factors and len(missing_factors) >= 4:
            why += f" (limited data: {len(missing_factors)} factors missing)"
        why += f" — scale in {pct}%"
        return f"Scale in {pct}%", why

    nodes_avg = cell("MachinesTotal avg")
    sorted_high = sorted(high_factors.items(), key=lambda x: (
        CAPACITY_FACTORS.index(x[0]), -x[1]
    ))
    primary = sorted_high[0][0]
    suggestion = _get_sku_suggestion(current_sku, primary, high_factors, nodes_avg)

    parts = [f"{FACTOR_SHORT_NAMES[k]} {v:.0f}%" for k, v in sorted_high]
    why = f"CPU {cpu:.0f}% / Mem {mem:.0f}% / {', '.join(parts)} — {suggestion}"
    return "SKU Change", why


def _apply_row_color(ws, row_idx, max_col, color_hex):
    """Apply a fill to every existing cell in the row, preserving each cell's
    hyperlink, value, font, and other style attributes. We mutate `.fill` only —
    never replace the cell object — so dashboard links survive."""
    fill = PatternFill("solid", fgColor=color_hex)
    for c in range(1, max_col + 1):
        cell = ws.cell(row=row_idx, column=c)
        cell.fill = fill


def regenerate_summary(wb, results, hmap_source, ws_source, color_rows=True):
    """Rebuild the Summary tab IN PLACE (clearing rows) instead of deleting the
    sheet, so any external references / links survive."""
    if "Summary" in wb.sheetnames:
        summary = wb["Summary"]
        if summary.max_row > 0:
            summary.delete_rows(1, summary.max_row)
    else:
        summary = wb.create_sheet("Summary")

    headers = ["Recommendation", "Cluster count", "Total Cost/Day", "Potential Saving/Day (heuristic)"]
    header_fill = PatternFill("solid", fgColor="4472C4")
    header_font_white = Font(bold=True, size=11, color="FFFFFF")
    num_fmt = '#,##0.00'
    thin_border = Border(bottom=Side(style='thin', color='D9D9D9'))

    for ci, h in enumerate(headers, 1):
        c = summary.cell(row=1, column=ci, value=h)
        c.font = header_font_white
        c.fill = header_fill
        c.alignment = Alignment(horizontal="center")

    summary.column_dimensions['A'].width = 28
    summary.column_dimensions['B'].width = 16
    summary.column_dimensions['C'].width = 18
    summary.column_dimensions['D'].width = 30

    cost_col = hmap_source.get("Cost/Day")
    buckets = {}
    for row_idx, (rec, why) in results.items():
        cost = _val(ws_source.cell(row=row_idx, column=cost_col).value) or 0 if cost_col else 0
        buckets.setdefault(rec, {"count": 0, "cost": 0.0, "saving": 0.0})
        buckets[rec]["count"] += 1
        buckets[rec]["cost"] += cost
        pct_match = None
        if rec.startswith("Scale in"):
            try:
                pct_match = int(rec.split()[-1].replace('%', ''))
            except ValueError:
                pass
        if pct_match:
            buckets[rec]["saving"] += cost * pct_match / 100

    order = ["Scale in 50%", "Scale in 40%", "Scale in 30%", "Scale in 25%",
             "SKU Change", "Hold", "Insufficient data"]
    sorted_keys = sorted(buckets.keys(), key=lambda x: order.index(x) if x in order else 999)

    row = 2
    total_count = 0; total_cost = 0.0; total_saving = 0.0
    for key in sorted_keys:
        b = buckets[key]
        summary.cell(row=row, column=1, value=key).border = thin_border
        summary.cell(row=row, column=2, value=b["count"]).border = thin_border
        c = summary.cell(row=row, column=3, value=round(b["cost"], 2))
        c.number_format = num_fmt; c.border = thin_border
        s = summary.cell(row=row, column=4, value=round(b["saving"], 2))
        s.number_format = num_fmt; s.border = thin_border
        if color_rows and key in ROW_COLORS:
            _apply_row_color(summary, row, len(headers), ROW_COLORS[key])
        total_count += b["count"]; total_cost += b["cost"]; total_saving += b["saving"]
        row += 1

    row += 1
    total_font = Font(bold=True, size=11)
    summary.cell(row=row, column=1, value="TOTAL").font = total_font
    summary.cell(row=row, column=2, value=total_count).font = total_font
    c = summary.cell(row=row, column=3, value=round(total_cost, 2))
    c.font = total_font; c.number_format = num_fmt
    s = summary.cell(row=row, column=4, value=round(total_saving, 2))
    s.font = total_font; s.number_format = num_fmt


def main():
    parser = argparse.ArgumentParser(description="ADX Cluster Right-Sizing Analyzer")
    parser.add_argument("excel_path", help="Path to the Engine Health Excel file")
    parser.add_argument("--source-tab", default="Right-Sizing Snapshot updated",
                        help="Tab name to analyze (default: 'Right-Sizing Snapshot updated')")
    parser.add_argument("--cpu-threshold", type=float, default=45)
    parser.add_argument("--factor-threshold", type=float, default=45)
    parser.add_argument("--dry-run", action="store_true",
                        help="Print recommendations without modifying the file")
    parser.add_argument("--no-color", action="store_true",
                        help="Skip traffic-light row coloring")
    args = parser.parse_args()

    print(f"Loading {args.excel_path} ...")
    # keep_links=True preserves external workbook links (incl. dashboard URLs).
    wb = load_workbook(args.excel_path, keep_links=True)

    if args.source_tab not in wb.sheetnames:
        print(f"ERROR: Tab '{args.source_tab}' not found. Available: {wb.sheetnames}")
        sys.exit(1)

    ws = wb[args.source_tab]
    hmap = _build_header_map(ws)

    required = ["Name", "SKU", "Peak CPU", "Peak Memory", "Cost/Day"]
    _require_headers(hmap, required)

    rec_col = hmap.get("Recommendation")
    why_col = hmap.get("Why")
    if rec_col is None or why_col is None:
        print("ERROR: 'Recommendation' and/or 'Why' columns not found in headers.")
        sys.exit(1)

    name_col = hmap["Name"]
    max_row = ws.max_row
    max_col = ws.max_column
    data_rows = max_row - 1
    print(f"Found {data_rows} clusters in '{args.source_tab}'")

    for f in CAPACITY_FACTORS:
        if f not in hmap:
            print(f"WARNING: Capacity factor '{f}' not found (also tried 30dMax suffix) — treated as 0")

    results = {}
    for row_idx in range(2, max_row + 1):
        name = ws.cell(row=row_idx, column=name_col).value
        if not name:
            continue
        rec, why = classify_cluster(ws, hmap, row_idx, args.cpu_threshold, args.factor_threshold)
        results[row_idx] = (rec, why)

    rec_counts = Counter(r[0] for r in results.values())
    print(f"\nRecommendation distribution:")
    for rec, count in rec_counts.most_common():
        print(f"  {rec}: {count}")
    print(f"  Total: {sum(rec_counts.values())}")

    if args.dry_run:
        print("\n[DRY RUN] — changes not written.")
        for row_idx, (rec, why) in sorted(results.items()):
            name = ws.cell(row=row_idx, column=name_col).value
            print(f"  {name}: {rec} — {why}")
        return

    # Write Recommendation + Why (mutating .value only; hyperlinks preserved).
    for row_idx, (rec, why) in results.items():
        ws.cell(row=row_idx, column=rec_col).value = rec
        ws.cell(row=row_idx, column=why_col).value = why

    # Apply traffic-light row coloring (mutates .fill only; hyperlinks preserved).
    if not args.no_color:
        for row_idx, (rec, _why) in results.items():
            color = ROW_COLORS.get(rec)
            if color:
                _apply_row_color(ws, row_idx, max_col, color)

    regenerate_summary(wb, results, hmap, ws, color_rows=not args.no_color)

    wb.save(args.excel_path)
    print(f"\nSaved to {args.excel_path}")
    print("Done!")


if __name__ == "__main__":
    main()
```

---

## What "done" looks like

You are done when:
1. (Full pipeline) The snapshot fetcher ran without errors and the xlsx now has the `<Metric> 30dAvg` / `<Metric> 30dMax` columns.
2. The analyzer ran and printed a final `Saved: <path>` line.
3. The source tab has `Recommendation` and `Why` filled and rows colored by recommendation.
4. The `Summary` tab is regenerated with totals and is itself row-colored.
5. **Dashboard hyperlinks in the source tab are still clickable** — confirm by spot-check before handing off.
6. You report to the user: output path, cluster count with data, recommendation distribution, any unmapped regions.

If the fleet fetch crashes part-way: re-run the same command. The checkpoint is on disk and the script skips already-fetched keys.

## Smoke test (analyze-only)

When you only changed the analyzer and want a fast sanity check, run a dry-run on any existing xlsx:

```bash
python3 ./analyze.py /path/to/engine_health.xlsx --dry-run
```

This prints the recommendation per row without touching the file.
