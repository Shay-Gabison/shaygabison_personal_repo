---
name: kusto-engine-health-snapshot
description: Produce a fleet-wide 30-day snapshot of the Geneva KustoProd / MdmEngineMetrics / "engine health V3" dashboard as a single xlsx — one row per Kusto cluster, two columns per metric (Avg, Max). Triggers — use this skill whenever the user says any of "engine health snapshot", "dashboard for all clusters", "fleet-wide kusto health", "kusto right-sizing data", "30-day kusto metrics export", "before/after scale-in", "ICM evidence for all clusters", or asks for the engine-health dashboard exported as a table/spreadsheet. The skill makes you (the agent) install the Geneva MCP if missing, derive the cluster list from any input shape (pasted names, csv, xlsx, Kusto/ARG query), resolve regions if not given, write a parallel Python fetcher using the 77 metrics and region→account map embedded below, run it, and deliver the enriched xlsx.
---

<!--
═══════════════════════════════════════════════════════════════════════════════
  HUMANS: read this top section to install + use. Everything below it is the
  agent contract — you don't need to read it unless you're curious.
═══════════════════════════════════════════════════════════════════════════════
-->

# Kusto Engine Health → 30-Day Fleet Snapshot

A single-file agent skill. Drop it in your skills folder and ask your agent to do the snapshot.

## Install (one command)

```bash
mkdir -p ~/.copilot/skills/kusto-engine-health-snapshot
mv kusto-engine-health-snapshot.SKILL.md ~/.copilot/skills/kusto-engine-health-snapshot/SKILL.md
```

(Adjust the path if your agent loads skills from elsewhere — e.g. `~/.claude/skills/`. The file just needs to land somewhere your agent scans.)

## Use it

Start a session in any working directory and say one of:

> *"Snapshot the engine-health dashboard for these clusters: \<paste names\>"*
> *"Give me 30-day engine health for the clusters in `compute-details.xlsx`"*
> *"Engine health snapshot, fleet-wide"* — agent will ask which list to use
> *"Re-run last week's snapshot for the same fleet, 7-day window this time"*

The agent will:
1. Install the Geneva MCP if it's missing.
2. Normalize whatever cluster input you gave it into `(name, region)` pairs (resolving regions via Azure Resource Graph if you only gave names).
3. Write a parallel Python fetcher into your cwd.
4. Preflight on one cluster.
5. Fetch 77 metrics × N clusters over the last 30 days (~25 min for ~540 clusters on 6 workers; resumable on Ctrl-C).
6. Deliver a flat xlsx — one row per cluster, two columns per metric (`30dAvg`, `30dMax`).

Prereqs the agent will check / fix automatically: `dotnet` SDK, `genevamonitoring-mcp` tool, Geneva auth, `python3 + openpyxl`.

## Why a skill and not just a script

The script is the easy part. This skill captures the operational knowledge it took two weeks to learn — which regional MDM account hosts which region, which Geneva read API actually works vs. the three that silently return zero rows, which sampling types exist on the regional accounts vs. only on the dashboard owner account, how to handle MDM ingestion-lag trailing zeros, and which metrics legitimately have no Cluster-dim data and should be auto-dropped. It's all encoded below so the next person never re-discovers any of it.

---

<!--
═══════════════════════════════════════════════════════════════════════════════
  AGENT: this is your contract. Read end-to-end before acting, then execute the
  Agent Procedure. Every constant below is authoritative — do not "simplify"
  them away.
═══════════════════════════════════════════════════════════════════════════════
-->

# Agent contract

You are the agent. **You will build and run a Python script** that fetches the Engine Health V3 dashboard signals for the user's Kusto fleet and delivers a single enriched xlsx. This file is the **complete** spec — every constant, request shape, and skeleton you need is embedded below. There are no sibling files.

## What the user wants from you

A single xlsx where every Kusto cluster in their list is a row and every Engine Health metric (77 of them) contributes two columns: `<Metric> 30dAvg` and `<Metric> 30dMax`, computed over the last 30 days. This replaces the manual "click each cluster in the Geneva dashboard and screenshot" loop.

Pairs with the `kusto-compute-rightsizing` and `geneva-monitoring-mcp` skills.

## Inputs to collect from the user (use **one** `ask_user` form, up front)

**Always start by calling `ask_user` with a single structured form** asking for the cluster list **plus** the right-sizing context, before doing anything else. Do not begin fetching until the user has provided (or explicitly declined) this data. The fields you must request in that one form:

| Field | Required? | Notes |
|---|---|---|
| Cluster list (paste, csv path, or xlsx path) | ✅ | One cluster per row. Per-row columns: `Name, Region, SKU, Peak CPU, Peak Memory, Cost/Day` (extra columns ignored). |
| Lookback days | ⚙ default 30 | |
| Workers | ⚙ default 6 | |
| Auto-run `adx-rightsizing` after snapshot | ⚙ default yes | Auto-skipped anyway if SKU / Peak CPU / Peak Memory / Cost/Day are missing. |

A typical paste from the MDA *Compute Details* / *Right-Sizing Snapshot* xlsx is tab-separated and looks like:

```
Subscription            Region    Public   SKU                State   ComputeResource          ClusterName     Engine     Cores    Peak Mem%   Peak CPU%   Cost/Day
Adallom PROD-05 (USW2)  uswest    Yes      standard_d32d_v4   Active  kucompute-mcaspr05usw6-s mcaspr05usw6    ksengine   32002    18.53       32.07       $8,325
```

Required columns you must parse from each row: `Name` (ClusterName / col 7), `Region` (col 2), `SKU` (col 4), `Peak Memory` (col 10), `Peak CPU` (col 11), `Cost/Day` (col 12). Strip `$` and thousands separators from `Cost/Day`. If a row lacks one of the right-sizing fields (`SKU` / `Peak CPU` / `Peak Memory` / `Cost/Day`), record it but mark that cluster's right-sizing data as missing — the rightsizing chain (Step 9) will skip that row, not the whole run.

### Other accepted shapes for the cluster list

| Input shape | What to do |
|---|---|
| Pasted text — bare cluster names, one per line | Resolve each name to a region (Step 3). Rightsizing chain auto-skips. |
| Pasted text — `name,region` per line | Parse directly. Rightsizing chain auto-skips. |
| `.csv` / `.tsv` file path | Read it. Detect if it has the right-sizing columns; if not, ask. |
| `.xlsx` file path | Read the relevant sheet; if columns aren't obvious, ask for indexes. |
| Kusto query / ARG query result | Run it, collect `(name, region)` rows. Rightsizing chain auto-skips. |
| Just "the whole fleet" / "all of them" | Ask which source of truth (Compute Details xlsx? ARG query? saved list?). |

Optional inputs and their defaults:
| Input | Default |
|---|---|
| Output directory | `./out` under the user's cwd |
| Lookback window | 30 days |
| Resolution | daily (1440 min) |
| Workers | 6 |
| Append to source xlsx vs. standalone | Append if the user gave you an xlsx; otherwise standalone |
| Run `adx-rightsizing` chain (Step 9) | Yes by default. Auto-skips per-cluster if SKU / Peak CPU / Peak Memory / Cost/Day are missing for that row. |

---

## Agent Procedure

### Step 1 — Verify / install the Geneva MCP

Check for the binary:

```bash
command -v genevamonitoring-mcp || ls ~/.dotnet/tools/genevamonitoring-mcp 2>/dev/null
```

If missing, install:

```bash
dotnet tool install -g GenevaMonitoring.MCP.Server
export PATH="$PATH:$HOME/.dotnet/tools"
```

If `dotnet` itself is missing, tell the user: *"Install the .NET SDK first (https://dotnet.microsoft.com/download), then re-run me."* and stop.

Trigger Geneva auth once so the token is cached for the parallel workers (without this the workers each prompt for auth and stall):

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1.0"}}}' \
  | ~/.dotnet/tools/genevamonitoring-mcp --stdio | head -1
```

If you see an auth/browser prompt, follow it. If you see a JSON-RPC `initialize` response, you're good.

**Auth-hang detection.** If your fetch hangs for >30s on the very first call with no checkpoint progress, the MCP is most likely waiting for an `InteractiveBrowserCredential` token that can't be acquired in a non-interactive shell. The smoking gun appears on the MCP **stdout** (not stderr): a line like `[HH:MM:SS] Starting to acquire an access token ...` that never completes. When you see this:
1. Kill the fetch + all `genevamonitoring-mcp` subprocesses.
2. Re-run the auth one-shot above **interactively** (in a shell where a browser can open). Sign in.
3. Re-run the fetch — the cached token will now satisfy the workers.

This is an environmental issue, not a script bug; do not try to "fix" the script by widening timeouts.

### Step 2 — Verify Python deps

```bash
python3 -c "import openpyxl" || pip install openpyxl
```

(That's the only third-party dep. Everything else is stdlib.)

### Step 3 — Normalize the user's input to `(name, region)` pairs

The script needs `(name, region)` pairs because the region picks the regional MDM account. If the user gave you **only cluster names** (no regions), resolve each name to a region using one of these, in order of preference:

1. **Azure Resource Graph** (authoritative) — query the Kusto cluster ARM resource and read `location`:
   ```kql
   resources
   | where type =~ "microsoft.kusto/clusters"
   | where name in~ ("mcaspr05usw6", "mcaspr07euw2", ...)
   | project name, location
   ```
   Then map `location` (e.g. `westus2`) → the region key used in the `REGION_TO_ACCOUNT` table below (e.g. `uswest2`).
2. **Cluster-name convention** — MDA cluster names encode region in chars 5–9 (e.g. `MCASPR05USW6` → `USW6` → `uswest2`, `MCASPR07EUW2` → `EUW2` → `europewest`). Last resort, warn the user it's a guess.
3. **Ask the user** — if you can't resolve confidently, list the unresolvable names and ask.

**Cluster name normalization** for the Geneva `Cluster` dimension: `UPPER()` and strip trailing `-S`. (`MCASPR05USW6-S` → `MCASPR05USW6`.) Do this inside your script.

### Step 4 — Write the script

Create `geneva_fetch.py` in the user's working directory. Assemble it from the constants and skeletons below — they are all the building blocks you need. Standard patterns (argparse CLI, threading, queue) you can fill in yourself.

**Required behaviour:**

1. Accept the cluster list (CSV path or inline list — your choice based on Step 3).
2. For each (cluster, metric) pair, call the Geneva MCP and store `{avg, max, last, n}` in a JSON checkpoint keyed by `"<CLUSTER>__<METRIC>"`. Skip keys already present (resumable).
3. Run N parallel workers (default 6), each owning its own `genevamonitoring-mcp --stdio` subprocess.
4. Flush the checkpoint to disk every 100 results.
5. After fetching, build the xlsx (append to source sheet if xlsx input, else standalone with one row per cluster).

#### Constant 1 — The 77 metrics (from `KustoProd/MdmEngineMetrics/engine health V3`)

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

If the dashboard has been updated, regenerate by re-exporting `KustoProd/MdmEngineMetrics/engine health V3` from Jarvis as JSON and walking `content` for every `{ metric, samplingType }` pair. Otherwise prefer the embedded list — it's the validated set.

#### Constant 2 — Region → regional MDM account

```python
REGION_TO_ACCOUNT = {
    "uswest":        "KustoWestUS",        # ✅ confirmed
    "uswest2":       "KustoWestUS",        # ✅ same stamp
    "uswest3":       "Kustowestus3",
    "useast":        "Kustoeastus",        # ✅
    "useast2":       "Kustoeastus2",       # ✅
    "uscentral":     "Kustocentralus",     # ✅
    "usnorth":       "Kustonorthcentralus",
    "uswestcentral": "Kustowestcentralus", # ✅
    "ukwest":        "Kustoukwest",        # ✅
    "uksouth":       "Kustouksouth",       # ✅
    "europewest":    "Kustowesteurope",    # ✅
    "europenorth":   "Kustonortheurope",   # ✅
    "usgoveast":     "KustoUSGovVirginia", # not probed
    "usgovsc":       "KustoUSGovTexas",    # not probed
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

`KustoProd` is the dashboard *owner* account, not where the series live — never query it for data. The pattern for any region not in the table is `Kusto<regionname>` (lowercase, no hyphens/spaces).

#### Constant 3 — The MCP request shape that actually works

```python
request = {
    "jsonrpc": "2.0", "id": req_id, "method": "tools/call",
    "params": {
        "name": "metrics_read_multi_time_series",
        "arguments": {
            "monitoringAccount": acct,                # regional, e.g. "Kustowesteurope"
            "metricNamespace":   "MdmEngineMetrics",
            "metricName":        metric,              # from ALL_METRICS
            "samplingType":      "Average",           # see fallback table below
            "startTimeUtc":      start_utc,           # ISO-8601 Z
            "endTimeUtc":        end_utc,             # ISO-8601 Z, ≥ 2 min in the past
            "seriesResolutionInMinutes": 1440,        # daily; use 60 for hourly
            "dimensionFilters":  json.dumps({"Cluster": gname, "DataCenter": "*"}),
        },
    },
}
```

**Use only `metrics_read_multi_time_series`.** These all fail and waste hours if you try them:
* `metrics_read_time_series_aggregated` — breaks on the space in `"West US"` dimension value (path-segment encoding bug).
* `metrics_read_time_series` (REST) — same encoding issue.
* `metrics_kqlm_query` — KQL-M is not standard KQL; `summarize`, percentile bracket escaping, etc. silently misbehave.

#### Constant 4 — Sampling-type fallback

Many dashboard panels declare exotic sampling types that don't exist on the regional accounts. Always pass `"Average"`. Confirmed safe types: `Average`, `NullableAverage`, `Rate`. Everything else (`Count`, `Sum`, `Max`, `50th/95th/99.9th percentile`, `RateMBs`, `RateRequestsPerSecond`, `null`) must fall back to `Average` — empirically within a few percent of the dashboard panel value.

#### Constant 5 — Trailing-zero handling

The last 1–2 datapoints in any window are usually `0` due to MDM ingestion lag. Strip them before computing `mean()` / `max()`:

```python
values = [dp["value"] for dp in datapoints]
while values and values[-1] == 0:
    values.pop()
```

Otherwise Max will be wrong for clusters that are a few minutes behind realtime.

#### Constant 6 — Metrics that legitimately have no Cluster-dim data

These return `isError: true` (caught as `"status": "no_cluster_dim"`) for every cluster — Total-only preagg or different preagg shape. Leave them in `ALL_METRICS`; the xlsx builder auto-drops columns where no cluster has data:

* `QueryDuration`, `RowStoreWriteAheadLogSizeBytes` — Total-only.
* `ConcurrentQueries`, `ExternalThrottling`, `MaterializedViewAgeMinutes` — different preagg shape.

In a healthy run on the regional accounts, ~13 metrics will be `no_cluster_dim` per cluster and another ~40 will be legitimate `no_data` (signal exists but is constant zero — silent features like Mirroring, MaterializedViews, ContinuousExport, QueryAcceleration on clusters that don't use them). Net: **expect ~20–25 active metrics per cluster** out of 77 unless the fleet uses every Kusto feature.

#### Skeleton 1 — MCP stdio worker

Each worker owns its own MCP subprocess and reads JSON-RPC responses line by line. This is the full plumbing — copy-adapt:

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
    """Returns {'avg':..., 'max':..., 'last':..., 'n':...} or {'avg':None, 'status':...}."""
    if not resp or "result" not in resp:
        return {"avg": None, "max": None, "status": "error"}
    res = resp["result"]
    # Server-side error for this (metric, account, cluster) combo — typically a
    # metric whose preagg doesn't include the Cluster dim (see Constant 6).
    if res.get("isError"):
        return {"avg": None, "max": None, "status": "no_cluster_dim"}
    try:
        content = res.get("content", [])
        if not content:
            return {"avg": None, "max": None, "status": "no_content"}
        rd = json.loads(content[0].get("text", ""))
        dps = rd.get("datapoints") or (rd.get("series", [{}])[0].get("datapoints", []) if rd.get("series") else [])
        values = [dp["value"] for dp in dps if dp.get("value") is not None]
        while values and values[-1] == 0:        # ingestion-lag stripping
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

#### Skeleton 2 — Driver (batched, resumable)

```python
def run(clusters, mcp_bin, checkpoint_path, start_utc, end_utc,
        num_workers=6, batch_size=50):
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

#### Constant 7 — Per-cluster Geneva dashboard link

Every row in the output xlsx **must** include a clickable hyperlink to the live Engine Health V3 dashboard pre-filtered to that cluster, so the user can jump from a suspicious number back to the dashboard with one click. URL template:

```
https://portal.microsoftgeneva.com/dashboard/KustoProd/MdmEngineMetrics/Engine%2520Health%2520V3?overrides=[{"query":"//*[id='Cluster']","key":"value","replacement":"<GENEVA_CLUSTER_NAME>"}]
```

`<GENEVA_CLUSTER_NAME>` is the uppercased, `-S`-stripped Geneva name (same one used in `dimensionFilters`). URL-encode the `overrides=` JSON when writing into the xlsx cell (use `urllib.parse.quote`). In openpyxl, set `cell.hyperlink = url` and `cell.value = "open dashboard"` (or the cluster name) so the cell renders as a link, plus a blue/underlined font for affordance.

Add this as the **second column** in the standalone builder (right after `Cluster`) and as a new column when appending to a source xlsx. Header label: `Dashboard`.

#### Skeleton 3 — XLSX builder (Engine Health sheet **+** Right-Sizing sheet)

The output xlsx has two sheets:

1. **`Engine Health 30d`** — the always-present raw snapshot. Columns: `Cluster | Dashboard | Region | <metric> 30dAvg ... | <metric> 30dMax ...`. The `Dashboard` cell is a hyperlink (Constant 7).
2. **`Right-Sizing Snapshot updated`** — built **only** if the user supplied `SKU` / `Peak CPU` / `Peak Memory` / `Cost/Day` for at least one cluster. This is the **exact schema the `adx-rightsizing` analyzer consumes** in Step 9. Columns (in order, header strings must match exactly):

   ```
   Name | Dashboard | Region | SKU | Peak CPU | Peak Memory | Cost/Day |
   MachinesTotal avg |
   HotDataDiskSpaceUsage max | HotDataDiskSpaceUsage avg |
   MergesLoadFactor max | MergesLoadFactor avg |
   IngestionsLoadFactor max | IngestionsLoadFactor avg |
   IngestionCapacityUtilization max | IngestionCapacityUtilization avg |
   MaterializedViewsLoadFactor max | MaterializedViewsLoadFactor avg |
   ExportsLoadFactor max | ExportsLoadFactor avg |
   Recommendation | Why
   ```

   Leave `Recommendation` and `Why` empty — the analyzer fills them. Drop a cluster row from this sheet only if all four right-sizing fields are missing for it; otherwise include it with whatever it has.

After the `adx-rightsizing` analyzer runs (Step 9), a **post-processing pass (Step 9.5)** copies the `Recommendation` / `Why` columns from `Right-Sizing Snapshot updated` back into `Engine Health 30d` as the last two columns, and applies a traffic-light row color (green = Hold, yellow = Scale-in, red = SKU Change) to the whole row on the Engine Health sheet. This keeps a single, scannable sheet for review while preserving the analyzer-owned source of truth on the right-sizing sheet. See Skeleton 4 and Step 9.5 for details.

```python
import openpyxl, urllib.parse
from openpyxl.styles import Font, PatternFill

HDR_FILL = PatternFill("solid", fgColor="4472C4")
HDR_FONT = Font(bold=True, color="FFFFFF", size=9)
LINK_FONT = Font(color="0563C1", underline="single")

FACTOR_METRICS = [
    "HotDataDiskSpaceUsage", "MergesLoadFactor", "IngestionsLoadFactor",
    "IngestionCapacityUtilization", "MaterializedViewsLoadFactor", "ExportsLoadFactor",
]

def cluster_to_geneva(name):
    u = name.strip().upper()
    return u[:-2] if u.endswith("-S") else u

def dashboard_url(geneva_name):
    overrides = '[{"query":"//*[id=\'Cluster\']","key":"value","replacement":"' + geneva_name + '"}]'
    return ("https://portal.microsoftgeneva.com/dashboard/KustoProd/MdmEngineMetrics/"
            "Engine%2520Health%2520V3?overrides=" + urllib.parse.quote(overrides, safe=""))

def _style_header(ws, n):
    for col in range(1, n + 1):
        c = ws.cell(1, col); c.fill = HDR_FILL; c.font = HDR_FONT

def _set_link(ws, row, col, geneva_name):
    c = ws.cell(row, col); c.value = "open dashboard"
    c.hyperlink = dashboard_url(geneva_name); c.font = LINK_FONT

def active_metrics(data):
    clusters = {k.split("__")[0] for k in data}
    return [m for m in ALL_METRICS
            if any(data.get(f"{c}__{m}", {}).get("avg") is not None for c in clusters)]

def _val(d, m, stat):
    v = d.get(f"{m}", {}).get(stat) if isinstance(d, dict) else None
    return round(v, 2) if v is not None else None

def build_xlsx(data, clusters, out_path):
    """clusters: list of dicts with keys: name, region, sku?, peak_cpu?, peak_mem?, cost?"""
    metrics = active_metrics(data)
    wb = openpyxl.Workbook()
    # --- sheet 1: Engine Health 30d
    ws = wb.active; ws.title = "Engine Health 30d"
    hdr = ["Cluster", "Dashboard", "Region"] + \
          [f"{m} 30dAvg" for m in metrics] + [f"{m} 30dMax" for m in metrics]
    ws.append(hdr); _style_header(ws, len(hdr))
    for c in clusters:
        g = cluster_to_geneva(c["name"])
        row = [g, "", c.get("region","")]
        row += [(_val({m: data.get(f"{g}__{m}", {})}, m, "avg")) for m in metrics]
        row += [(_val({m: data.get(f"{g}__{m}", {})}, m, "max")) for m in metrics]
        ws.append(row)
        _set_link(ws, ws.max_row, 2, g)
    # --- sheet 2: Right-Sizing Snapshot updated (only if any cluster has rs context)
    rs_clusters = [c for c in clusters
                   if any(c.get(k) is not None for k in ("sku", "peak_cpu", "peak_mem", "cost"))]
    if rs_clusters:
        ws2 = wb.create_sheet("Right-Sizing Snapshot updated")
        hdr2 = ["Name", "Dashboard", "Region", "SKU", "Peak CPU", "Peak Memory",
                "Cost/Day", "MachinesTotal avg"]
        for fm in FACTOR_METRICS:
            hdr2.append(f"{fm} max"); hdr2.append(f"{fm} avg")
        hdr2 += ["Recommendation", "Why"]
        ws2.append(hdr2); _style_header(ws2, len(hdr2))
        for c in rs_clusters:
            g = cluster_to_geneva(c["name"])
            row = [c["name"], "", c.get("region",""), c.get("sku"),
                   c.get("peak_cpu"), c.get("peak_mem"), c.get("cost"),
                   data.get(f"{g}__MachinesTotal", {}).get("avg")]
            for fm in FACTOR_METRICS:
                row.append(data.get(f"{g}__{fm}", {}).get("max"))
                row.append(data.get(f"{g}__{fm}", {}).get("avg"))
            row += [None, None]  # Recommendation, Why — analyzer fills
            ws2.append(row)
            _set_link(ws2, ws2.max_row, 2, g)
    wb.save(out_path)
    return {"sheet_engine_health": True, "sheet_rightsizing": bool(rs_clusters),
            "active_metrics": len(metrics), "rows": len(clusters)}
```

#### CLI surface (suggested)

```
geneva_fetch.py
  --list <csv>            name,region per line (xor --xlsx)
  --xlsx <path>           source xlsx (xor --list)
  --sheet <name>          sheet in xlsx (default: active)
  --name-col <n>          0-indexed Name col in xlsx (default 6)
  --region-col <n>        0-indexed Region col in xlsx (default 1)
  --out-dir <dir>         default ./out
  --mcp-bin <path>        default ~/.dotnet/tools/genevamonitoring-mcp
  --workers <n>           default 6
  --batch-size <n>        default 50
  --days <n>              lookback days (default 30)
  --resolution <min>      series resolution (default 1440 = daily)
  --rebuild-only          skip fetch; rebuild xlsx from checkpoint
```

Compute `end_utc = now_utc - 10min` and `start_utc = end_utc - days` to dodge the ingestion-lag artifact.

### Step 5 — Preflight: one cluster, all metrics

Before launching the full fleet fetch, validate one cluster end-to-end. Pick any cluster, run the script with `--workers 1` against a single-row list, check the resulting checkpoint:

* **Success criteria**: ≥10 keys with `avg != null`. (Healthy clusters land around 20–25 active metrics — see Constant 6.)
* If **0 keys** have `avg` and **all 77** are `no_data` → region→account mapping is wrong. Verify the region key, fix `REGION_TO_ACCOUNT`, retry.
* If **all 77** are `status: error` (no result envelope) → MCP auth not cached; re-run the auth one-shot from Step 1.
* If you see a mix of `no_data` + `no_cluster_dim` + some `has_data` → this is healthy, proceed.

### Step 6 — Full fleet fetch

Run the script over the full normalized cluster list. Expected throughput on 6 workers: ~28 calls/s → ~25 min for ~540 clusters × 77 metrics ≈ 42K series. The script's checkpoint makes Ctrl-C safe — re-running picks up where it stopped.

### Step 7 — Copy the final xlsx to the user's Desktop

After the xlsx is built, always copy it to `~/Desktop/` so the user can grab it without digging through the cwd:

```bash
cp "<out_path>" ~/Desktop/
```

Keep the original filename. If a file with the same name already exists on the Desktop, overwrite it (the freshly built one is the source of truth). Mention the Desktop path in the hand-off below.

### Step 8 — Hand off the output

Tell the user:
* Output xlsx path (and the Desktop copy path).
* Number of clusters with data vs. total rows.
* Number of metrics with data (some of the 77 will be empty fleet-wide — see Constant 6; xlsx builder auto-drops them).
* Any unmapped regions logged during the run.

### Step 9 — Automatically chain into `adx-rightsizing`

After the snapshot xlsx is built **and** copied to the Desktop, immediately invoke the `adx-rightsizing` analyzer on that same file — do not wait for the user to ask. The two skills are designed to run back-to-back: this one produces the raw 30-day Avg/Max signals **plus a pre-shaped `Right-Sizing Snapshot updated` sheet** (Skeleton 3), then `adx-rightsizing` reads that sheet and writes `Recommendation` / `Why` columns plus a `Summary` tab.

Procedure:

1. **Skip condition.** If the xlsx has no `Right-Sizing Snapshot updated` sheet (i.e. user supplied no SKU/CPU/Mem/Cost for any cluster), tell the user the chain is skipped and how to get it (re-run with right-sizing context). Stop after Step 8.
2. Load the `adx-rightsizing` skill (`SKILL.md` at `~/.copilot/skills/adx-rightsizing/SKILL.md`). The full analyzer Python is embedded inside it between the `# ===BEGIN analyze.py===` / `# ===END analyze.py===` markers.
3. Extract the embedded script to a temp file and run it against the xlsx you just produced:

   ```bash
   awk '/^# ===BEGIN analyze.py===$/{flag=1;next}/^# ===END analyze.py===$/{flag=0}flag' \
     ~/.copilot/skills/adx-rightsizing/SKILL.md > /tmp/adx_rightsizing_analyze.py

   python3 /tmp/adx_rightsizing_analyze.py "<xlsx_on_desktop>"
   ```

4. If the analyzer errors on missing columns despite our pre-shaped sheet, the analyzer was updated and now expects new headers. Surface the error to the user and stop — do **not** invent columns.
5. After the analyzer succeeds, run **Step 9.5** (post-process), then re-copy the now-enriched + colored xlsx to the Desktop (overwrite) so the Desktop copy is the final version.
6. Report to the user: snapshot path, recommendation distribution printed by the analyzer, and the final Desktop path.

This chaining is mandatory unless the user explicitly says *"snapshot only, no recommendations"* — in that case, stop after Step 8.

### Step 9.5 — Merge Recommendation/Why into Engine Health sheet + color rows

Goal: a single scannable sheet (`Engine Health 30d`) where each cluster row is color-coded by recommendation, and the `Recommendation`/`Why` cells are visible at the end of the row. The `Right-Sizing Snapshot updated` sheet is left intact as the analyzer's source of truth.

Color mapping (case-insensitive, by recommendation prefix):

| Recommendation prefix | Fill        | Hex      |
|-----------------------|-------------|----------|
| `Hold`                | green       | `C6EFCE` |
| `Scale-in` (or `Scale in`) | yellow | `FFEB9C` |
| `SKU Change` (or `SKU-Change`) | red | `FFC7CE` |
| (blank / other)       | no fill     | —        |

Use this script (write it as `post_process_engine_health.py` next to `geneva_fetch.py`):

```python
#!/usr/bin/env python3
"""Backfill Recommendation/Why from RS sheet into Engine Health sheet,
and apply traffic-light row colors. Usage: post_process_engine_health.py <xlsx>"""
import sys, openpyxl
from openpyxl.styles import PatternFill, Font, Alignment

EH_SHEET = "Engine Health 30d"
RS_SHEET = "Right-Sizing Snapshot updated"
FILL_GREEN  = PatternFill("solid", fgColor="C6EFCE")
FILL_YELLOW = PatternFill("solid", fgColor="FFEB9C")
FILL_RED    = PatternFill("solid", fgColor="FFC7CE")
HDR_FILL    = PatternFill("solid", fgColor="4472C4")
HDR_FONT    = Font(bold=True, color="FFFFFF", size=9)

def color_for(rec):
    if not rec: return None
    r = str(rec).strip().lower()
    if r.startswith("hold"): return FILL_GREEN
    if r.startswith("scale-in") or r.startswith("scale in"): return FILL_YELLOW
    if r.startswith("sku change") or r.startswith("sku-change"): return FILL_RED
    return None

def normalize(n):
    if n is None: return ""
    u = str(n).strip().upper()
    return u[:-2] if u.endswith("-S") else u

def main(path):
    wb = openpyxl.load_workbook(path)
    if EH_SHEET not in wb.sheetnames or RS_SHEET not in wb.sheetnames:
        print(f"⚠ missing sheet(s); have {wb.sheetnames}"); return
    rs, eh = wb[RS_SHEET], wb[EH_SHEET]
    rs_hdr = [c.value for c in rs[1]]
    n_i, r_i, w_i = (rs_hdr.index(x)+1 for x in ("Name","Recommendation","Why"))
    rec_map = {}
    for row in rs.iter_rows(min_row=2):
        nm = normalize(row[n_i-1].value)
        if nm: rec_map[nm] = (row[r_i-1].value, row[w_i-1].value)
    eh_hdr = [c.value for c in eh[1]]
    if "Recommendation" in eh_hdr and "Why" in eh_hdr:
        rec_col = eh_hdr.index("Recommendation")+1; why_col = eh_hdr.index("Why")+1
    else:
        rec_col = eh.max_column+1; why_col = eh.max_column+2
        eh.cell(1, rec_col, "Recommendation"); eh.cell(1, why_col, "Why")
        for ci in (rec_col, why_col):
            c = eh.cell(1, ci); c.fill = HDR_FILL; c.font = HDR_FONT
    cluster_col = eh_hdr.index("Cluster")+1 if "Cluster" in eh_hdr else 1
    colored = 0
    for row in eh.iter_rows(min_row=2):
        cname = normalize(row[cluster_col-1].value)
        rec, why = rec_map.get(cname, (None, None))
        eh.cell(row[0].row, rec_col, rec); eh.cell(row[0].row, why_col, why)
        fill = color_for(rec)
        if fill is not None:
            for cell in row: cell.fill = fill
            eh.cell(row[0].row, rec_col).fill = fill
            eh.cell(row[0].row, why_col).fill = fill
            colored += 1
    eh.cell(1, why_col).alignment = Alignment(wrap_text=True)
    eh.column_dimensions[openpyxl.utils.get_column_letter(rec_col)].width = 16
    eh.column_dimensions[openpyxl.utils.get_column_letter(why_col)].width = 60
    wb.save(path)
    print(f"Post-processed {path} (colored={colored})")

if __name__ == "__main__":
    main(sys.argv[1])
```

Run it on the xlsx after the analyzer finishes:

```bash
python3 post_process_engine_health.py "<xlsx_on_desktop>"
```

Then re-copy to the Desktop (the post-process writes in place, but if your working path differs from the Desktop path, copy again to keep them in sync).

---

## What "done" looks like

You are done when:
1. The MCP is installed and authed (verified via the preflight run).
2. The script ran without errors and printed a final `Saved: <path>` line.
3. The `adx-rightsizing` analyzer ran on the produced xlsx and wrote `Recommendation`/`Why` + a `Summary` tab (Step 9), unless the user opted out.
4. **Step 9.5 ran**: `Recommendation`/`Why` are also present on the `Engine Health 30d` sheet and rows are color-coded (green/yellow/red).
5. You have reported to the user: output path (Desktop), cluster count with data, metric count with data, recommendation distribution, and any unmapped regions.

If the fleet fetch crashes part-way: re-run the same command. The checkpoint is on disk and the script will skip already-fetched keys.
