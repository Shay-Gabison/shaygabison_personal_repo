# Analysis Methodology — Interpreting Geneva Signals

> How to collect Geneva metrics, compute recommendations, and explain savings.
> Use this together with `rightsizing-rules.md`.

---

## Data Collection

Default collection standards:

| Input | Standard |
|---|---|
| Container filter | Usually `container_name = wdatp-service`; throttling uses `container = wdatp-service` |
| Time window | Last `14 days` |
| `endTimeUtc` | At least `2 minutes` before current time |
| Required sampling types | Use only the sampling types supported by the metric being queried |
| CPU usage metric | `container:cpu_usage_rate_millicores` (P50, P95, P99, Max) |
| CPU utilization % | `container:cpu_usage_percent_by_request_scaled` ÷ 10 (Average only) |
| CPU throttling metric | `container:cpu_elevated_throttling_scaled` ÷ 10 (use `container` dim!) |
| CPU limit metric | `container:resource_limits_cpu_millicores` |
| OOM kills metric | `container:oomkills_total` Sum (uses `container_name` dim) |
| Data coverage check | Compare actual points vs expected points; flag `<80%` |
| Namespace normalization | **Always lowercase** namespace and **UPPERCASE** K8sClusterName before merging — Geneva metrics may report different casing for the same dimension values |

### Coverage handling

- Count the observed data points for each metric and compare them with the expected count for the selected resolution.
- If coverage is below `80%`, surface that caveat in the report.
- If coverage is below `50%`, downgrade confidence to **Low** unless there is a compelling reason not to.

### Per-pod vs aggregate values

Geneva metrics using **Average** sampling with the standard pre-aggregations return **per-pod**
values (because both usage and request are equally affected by replica count). This means:

- `container:resource_requests_cpu_millicores` (Average) = per-pod CPU request
- `container:cpu_usage_rate_millicores` (P99) = per-pod P99 CPU usage
- `container:memory_usage_bytes` (Average) = per-pod average memory usage

When computing **savings**, multiply the per-pod delta by `avg_replicas`:

```text
estimated_core_savings = (current_request_per_pod - recommended_request_per_pod) × avg_replicas
```

Do **not** multiply raw Geneva values by replica count before comparing request vs usage — that
would double-count.

---

## CPU Analysis

CPU is **compressible**, so percentile usage is the main signal and throttling is the safety check.

### Primary metric

- Use **`container:cpu_usage_rate_millicores`** with **P99 sampling** over 14 days.
- This is the **only** CPU metric that supports percentiles (P50, P95, P99, Max).
- Convert from millicores to cores: **÷ 1000**.
- Do **not** use `container:cpu_usage_percent_by_request_scaled` for percentiles — it only supports Average.
- Do **not** size CPU from average alone.

### Utilization quick-check

- `container:cpu_usage_percent_by_request_scaled` gives utilization as a percentage of request.
- **Scaling: divide by 10** to get actual percentage (e.g., value 735 = 73.5%).
- This metric only supports Average sampling — do not query P95/P99 from it.
- For precise utilization: `(cpu_usage_rate_millicores / resource_requests_cpu_millicores) × 100`

### Required throttling check

Always analyze throttling alongside utilization:

- Use metric: **`container:cpu_elevated_throttling_scaled`**
- ⚠️ **This metric uses dimension `container`, NOT `container_name`!**
  - Filter: `container = wdatp-service`
  - Using `container_name` will return `InvalidSeries` silently!
- **Scaling: divide by 10** for actual throttling percentage.
  - Value 450 = **45% throttled**
  - Value 35 = **3.5% throttled**
- If throttling is `≥ 5%`, do not reduce the CPU request yet.
- Investigate the CPU limit first.

### CPU Limit analysis

Always query **`container:resource_limits_cpu_millicores`** alongside request.

Key patterns:
- If P99 usage ≈ CPU limit → service is being capped by the limit → **throttling is expected**
- If limit == request → Guaranteed QoS → almost certainly throttled
- High throttling + P99 at limit + avg utilization moderate → the limit is too tight, NOT a request reduction opportunity

Example (obione-worker UKS-101):
- Request: 10 cores, Limit: 16 cores
- P99: ~16 cores (hitting limit!), Avg: ~7.5 cores (73.5% of request)
- Throttling: 35-55%
- Correct action: **raise or remove CPU limit**, not reduce request

### Pattern interpretation

- Low P99 + low throttling → likely safe rightsizing opportunity.
- Low P99 + high throttling → likely tight CPU limit, not overprovisioned request.
- High P99 near or above request → under-provisioned CPU request.

### Weekly shape check

- Compare weekday and weekend patterns.
- Use the **higher** demand profile when choosing the recommendation.
- If the service has materially different weekday / weekend behavior, mention it in the rationale and reduce confidence if the profile is unstable.

---

## Memory Analysis

Memory is **not compressible**. Exceeding safe headroom risks OOMKilled behavior, so use the
**14-day average** usage as the demand signal — not Max or peak.

### Primary metric

- Use **Average** memory usage over 14 days via `container:memory_usage_bytes` with **Average sampling**.
- ⚠️ **Do NOT use Max sampling** for memory utilization or waste calculations. Geneva pre-aggregates
  `memory_usage_bytes` as a **sum across all pods**. Max sampling captures the peak of this sum,
  which spikes during rolling restarts when 2 pods briefly coexist (e.g., 2 pods × 8 GiB = 16 GiB).
  Dividing this by the single-pod request produces utilization values >100%, which is physically
  impossible per-pod.
- Average sampling gives a consistent per-pod ratio because both usage and request are equally
  affected by replica count changes.

### OOM kills check (mandatory before any memory recommendation)

- Query `container:oomkills_total` (Sum sampling, `container_name` dimension) over 14 days.
- If **OOM kills > 0**: memory is **under-provisioned** or there is a memory leak.
  - Do NOT recommend reducing memory request or limit.
  - Flag the service as **OOMKilled**.
  - Recommend investigating:
    1. Memory leaks (if OOMs are increasing over time)
    2. Insufficient memory limit (if workload genuinely needs more)
    3. JVM misconfiguration (if `-Xmx` exceeds container limit, or GC is not collecting effectively)

### Buffering guidance

- Use larger safety buffers than CPU because memory is non-compressible.
- Standard buffer range: `20–30%` (20% for High opportunity, 30% for Medium).
- Apply buffer to **average** usage: `recommended = avg_usage × 1.2` (High) or `avg_usage × 1.3` (Medium).

### JVM investigation for high-memory services

When memory request > 20 GB, flag the service for JVM deep-dive:

- **K8s memory utilization is misleading for JVM services.** JVM reserves the full `-Xmx` heap
  upfront. K8s sees high RSS (75-95% utilization) even if actual live data is a small fraction.
  Example: `-Xmx=60GB`, container=80GB → K8s shows ~75% utilization → looks "fine" but may be
  massively wasteful if actual live data is only 5GB.
- **Oversized memory hurts CPU utilization.** Large memory requests reduce pods-per-node, leaving
  CPU stranded — a 80GB pod on a 128GB node wastes 48GB that could have hosted other workloads.

#### Preferred path: OTEL-based JVM analysis

When the user provides Helm values, check if OTEL metrics are available:

> ⚠️ **Per-cluster scope rule:** A `jvm.memory.used` query filtered to one `data_center` is
> evidence only for that data center / cluster. **Never extrapolate** JVM memory usage from one
> region to another. Regions vary drastically in workload, data sizes, and cache patterns.

1. **Detect**: Look for `OTEL_JAVAAGENT_ENABLED: true` in `environmentVariables`.
2. **Enumerate all regional Helm files** for the service (e.g., `helm-prd-*-values.yaml`).
   From each, extract: `mdm.account`, `service_name`, `data_center`, `MIN_MEMORY`, `MAX_MEMORY`.
   If only one Helm file is provided, produce a recommendation only for that region.
3. **For EACH data_center independently**, query Geneva:
   - Account = that region's `mdm.account`
   - Namespace = `otelagent`
   - Metric = `jvm.memory.used`
   - Sampling = Average over 14 days
   - Dimension filters: `service_name` and that region's `data_center`
   - Scope: sum all memory pools (heap + non-heap) per-pod
4. **Size from OTEL data per cluster**:
   - `recommended_Xmx = avg(jvm.memory.used for that DC, 14d) × 1.2`
   - `recommended_Xms = recommended_Xmx` (Xms == Xmx best practice)
   - `container_memory = recommended_Xmx × 1.2`
5. **If metric is empty for a specific region** — try alternative dimension filters for that
   region only:
   - Without `service_name` filter (dimension may be named `service`, `service.name`, etc.)
   - Without `data_center` filter — use only for diagnostic/discovery; do NOT use unscoped
     aggregate data to size a specific cluster
   - List available dimensions for the metric to discover correct names
   - If all fail for that region → fall back to manual analysis for that region only
6. **Report per-cluster JVM recommendations.** Do not produce a fleet-wide JVM recommendation
   unless every included region has been independently queried and the evidence supports it.

#### Fallback path: Manual jcmd analysis

Use when OTEL is not available (no `OTEL_JAVAAGENT_ENABLED` in Helm, or metric queries all empty):

- **Workflow** (see [java-memory-guide.md](java-memory-guide.md)):
  1. Ask user for `-Xmx` / `-Xms` values
  2. If `avg_usage ≤ Xmx × 1.2` AND container memory ≫ `Xmx + 20%`: container is oversized →
     reduce to `Xmx × 1.2`
  3. If `avg_usage > Xmx × 1.2`: the process uses more memory than JVM heap alone explains
     (off-heap, native, thread stacks). Do **NOT** reduce to `Xmx × 1.2` — use standard
     `avg_usage × 1.2` formula instead, and note the non-heap overhead.
  4. If Xmx itself seems oversized: investigate actual heap via `jcmd GC.heap_info` and GC logs
  5. Right-size Xmx = `peak_live_data × 3-4`, then container = `Xmx × 1.2`.
     `1.2×` is the right multiplier — more than that is likely wasteful.

- **Best practice (medium criticality):** `-Xms == -Xmx` (avoids heap resize overhead and GC
  pauses) and `mem_request == mem_limit`. Flag `Xms ≠ Xmx` when found but prioritize whether each
  value is reasonable for the workload over cross-cluster consistency.

### JVM alignment

For JVM services:

```text
recommended_memory = Xmx × 1.2
```

Use this to check whether the container request is oversized relative to JVM heap settings.
**This recommendation only applies when `avg_usage ≤ Xmx × 1.2`.**

Interpretation:

- If `avg_usage ≤ Xmx × 1.2` and request is much larger than `Xmx × 1.2`:
  the container has excess headroom → recommend reducing request to `Xmx × 1.2`.
- If `avg_usage > Xmx × 1.2`: the process uses more memory than JVM heap alone explains
  (off-heap, native libraries, thread stacks, etc.). Do **NOT** recommend `Xmx × 1.2` — use
  the standard `avg_usage × 1.2` formula instead, and note the non-heap overhead.
- If actual memory usage is near or above `Xmx`, recommend reviewing `-Xmx` / `-Xms` as well.

---

## Replica Analysis

Replica analysis focuses on whether the minimum is doing real work or simply pinning idle capacity,
and whether the maximum is providing adequate headroom.

### Core comparison

- Compare configured HPA / KEDA min replicas to actual replica count over 14 days.
- Also query **average replica count** to understand typical operating point.
- Compute the percentage of time where:

```text
actual_replicas ≈ min_replicas  (within 10%)
actual_replicas ≈ max_replicas  (within 10%)
```

- If `avg ≈ min` for `>90%` of the time: min replicas are probably too high — the service rarely
  scales above minimum, wasting baseline capacity.
- If `avg ≈ max` for `>50%` of the time: the service is likely under-provisioned — it is hitting
  the scaling ceiling frequently and may need a higher max to handle load spikes.

### Replica drift detection (actual > max)

Query both `keda:hpa_max_replicas` and `keda:hpa_current_replicas` (or the deployment replica metric).
Use **Max sampling** for actual replicas to detect drift — Average can hide periods where replicas
exceeded the configured max.

Compare: `max(actual_replicas)` over 14 days vs `keda:hpa_max_replicas`.

If **max actual replica count > configured HPA/KEDA max replicas**:
- This means someone **manually scaled** the deployment (e.g., `kubectl scale` or direct patch) and
  the override was **never reverted**.
- Manual overrides bypass autoscaling entirely — the service runs at a fixed, potentially wasteful
  replica count regardless of load.
- Flag with `Replica Drift? = Yes` and include the delta (`actual - max`) in the rationale.
- **Recommended action**: Verify whether the manual override is still needed. If not, remove it so
  autoscaling can resume. If the max is genuinely too low, increase `maxReplicaCount` in the Helm
  config instead.

Example: Copernicus-worker WEU has KEDA min=10, max=100, but actual=150. This is 50 replicas above
the configured maximum — clear evidence of manual scaling that was never cleaned up.

### Suggested new min

```text
suggested_min = max(2, P10(actual_replica_count))
```

Use the floor of `2` for HA services unless the workload is explicitly single-instance or non-HA by design.

### KEDA caution

- For KEDA, the trigger parameters often encode business latency goals.
- The skill can suggest a lower min replica count, but service-owner input is required before changing trigger thresholds or acceptable backlog behavior.

---

## Savings Calculation

Compute savings per **(cluster, service)** unless the user explicitly asks for aggregation.

### CPU savings

```text
estimated_core_savings =
  (current_cpu_request - recommended_cpu_request) × average_replicas
```

**Only calculate positive savings when throttling < 5%.** When throttling >= 5%, the
service may actually need MORE CPU, not less. Set estimated savings to 0 for throttled
services and flag them as "needs limit investigation" instead.

### Memory

```text
estimated_memory_savings =
  (current_memory_request - recommended_memory_request) × average_replicas
```

### Reporting rule

- Keep savings calculations cluster-local by default.
- Do not sum across clusters unless the user asks for a fleet-level view.

---

## Prioritization Score

Use a simple waste × confidence weighting model.

```text
priority_score = absolute_waste × confidence_weight
```

| Confidence | Weight |
|---|---|
| High | `1.0` |
| Medium | `0.7` |
| Low | `0.3` |

Sort opportunities by descending score so the biggest, most trustworthy savings appear first.

---

## Primary / DR / Inline Topology

MDA clusters are classified as **Inline**, **Primary**, or **DR**. The classification is determined
by cluster identity, not by namespace.

### Cluster classification

Refer to [mda-cluster-inventory.md](mda-cluster-inventory.md) for the authoritative list of all MDA
clusters and their classification (Inline, Primary, DR). Do not duplicate the inventory here.

### DR paused state

DR services on non-inline clusters are typically paused via:

1. KEDA paused annotation: `autoscaling.keda.sh/paused-replicas: "0"`
2. KEDA disabled + zero replicas: `keda.enabled: false` with `replicaCount: 0`

When a service is paused:
- Geneva will show **no utilization data** (0 replicas = 0 pods). This is expected — not a data
  coverage issue.
- Skip utilization analysis for paused DR services.
- Do NOT downgrade confidence because of missing DR data.

### Expected configuration differences

Config differences between Primary and DR clusters are **expected** for non-inline clusters:
- DR may have lower requests/limits, different KEDA settings, or paused annotations.
- Do NOT flag these as "config drift" or "cross-cluster inconsistency."

Config differences between Primary clusters in different regions are **often intentional**:
- Different regions may have different traffic volumes, customer mixes, or dependency latencies.
- Example: Gov clusters are typically less loaded than commercial PRD.
- Present cross-cluster config differences as **informational** ("FYI, worth verifying") rather
  than as critical issues to fix. The service owner should decide whether to unify or keep them.
- Only flag as a potential issue if a cluster's config is inconsistent with its own utilization
  data (e.g., high CPU request but very low P99).

### DR running unexpectedly

If a non-inline cluster in a DR region shows **active replicas** and KEDA is not paused:
- This is an **optimization opportunity**.
- Flag it: "DR cluster X is running active replicas — verify if this is intentional. Consider pausing
  KEDA to eliminate idle compute."
- Estimate the waste from the unnecessary DR replicas.

### Savings attribution

- Attribute rightsizing savings primarily to **Primary clusters** — they carry production traffic.
- Paused DR clusters consume no compute; their savings potential is zero.
- DR clusters that are unexpectedly running contribute to savings, but categorize them separately.

---

## Edge Cases

### Spiky traffic

- Use P99 with a larger CPU buffer.
- Mark the recommendation as **Medium confidence** unless the peaks are very well understood.

### Recent deployment or config change

- If a config change landed in the last `7 days`, treat the recommendation as **Low confidence**.
- Explain that the usage profile may not yet represent steady state.

### Missing data

- If data coverage is `<50%`, mark **Low confidence** and say the recommendation is bounded by missing telemetry.

### Init containers

- Ignore init containers for sizing decisions; they are startup-only and should not drive steady-state requests.

### Batch / CronJob workloads

- Flag batch and CronJob workloads for manual review.
- Their execution pattern differs from always-on services, so replica and percentile logic may not transfer cleanly.

---

## Recommendation Framing

When reporting findings:

1. State the observed metric used for the decision (`P99`, `Peak`, throttling %, or replica behavior).
2. State the rule that fired.
3. State the exact recommended value.
4. State the confidence and any caveats.

This keeps the output auditable and easy for service owners to validate.
