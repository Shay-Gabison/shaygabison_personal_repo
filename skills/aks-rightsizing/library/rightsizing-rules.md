# Rightsizing Rules — Eng Hub Decision Engine

> Canonical decision rules for MDA pod rightsizing.
> Apply these rules per **(cluster, namespace, service)** after collecting 14-day Geneva data.

---

## Container Focus

- Always analyze **`wdatp-service`** only.
- Treat `wdatp-service` as the primary application container in MDA services.
- Ignore sidecars for rightsizing unless the user explicitly asks about them.
- Apply `container_name = wdatp-service` on all Geneva metric reads **except**
  `container:cpu_elevated_throttling_scaled` which uses `container = wdatp-service`.

---

## Evaluation Order

Run the checks in this order so the recommendations stay causal:

1. Confirm data coverage and time window quality.
2. Check CPU throttling **before** touching CPU request.
3. Evaluate CPU request.
4. Evaluate CPU limit.
5. Evaluate memory request.
6. Enforce memory limit = memory request.
7. Evaluate HPA / KEDA behavior.
8. Review topology and cross-cluster drift.
9. Assign confidence separately from waste / risk.

---

## CPU Request Rules

Use **14-day P99 CPU usage** as the demand signal.

### Hard gate: throttling first

- If **CPU throttling ≥ 5%**, **do not reduce CPU request**.
- Interpret **high throttling + low utilization** as a **CPU limit problem**, not a request savings opportunity.
- In this case, recommend removing the CPU limit or increasing it first.

### Decision table

**Compute absolute savings for classification (uses × 1.2 as baseline):**

```text
estimated_core_savings = max(0, cpu_request - cpu_p99 × 1.2) × avg_replicas
```

Both the **ratio** and the **absolute savings** must meet the threshold to classify as High or Medium.

After classification, compute **reported savings** using the actual recommended value for that row
(e.g., `P99 × 1.3` for Medium), not the `× 1.2` baseline used above.

| Condition | Classification | Recommendation |
|---|---|---|
| `throttling ≥ 5%` | Conflicting signal | Hold CPU request steady; investigate CPU limit |
| `request > 2 × P99` and `throttling < 5%` and `estimated_core_savings > 5` | High opportunity | Set request to `P99 × 1.2` |
| `request > 1.5 × P99` and `throttling < 5%` and `estimated_core_savings > 1` | Medium opportunity | Set request to `P99 × 1.3` |
| `request > 1.3 × P99` and `throttling < 5%` | Low opportunity | Set request to `P99 × 1.3` |
| `request` is `1.0×–1.5× P99` | OK | No request change — at or slightly above observed peak |
| `request < P99` | Under-provisioned | Increase CPU request to at least `P99 × 1.2` |

### Absolute waste minimum

**Both the ratio AND the absolute savings must meet the threshold.** A service with 0.5 cores
request and 0.1 cores P99 has a 5× ratio but only saves 0.4 cores — this is **Low**, not **High**.
Absolute thresholds prevent tiny services from dominating the prioritization list.

### Reporting guidance

- Call out the exact current request, P99, throttling %, and recommended request.
- If increasing request, explain that the service is already operating above its declared request.

---

## CPU Limit Rules

CPU limits are optional and often harmful when set too tightly.

| Condition | Classification | Recommendation |
|---|---|---|
| No CPU limit set | OK | Keep the limit removed; do **not** add one |
| `limit == request` | Flag | Guaranteed QoS is likely causing unnecessary throttling; remove limit or set to `3–4 × request` |
| `limit < 3 × request` | Tight limit | Recommend removing limit or setting to `3–4 × request` |
| `limit ≥ 3 × request` | OK | No limit change needed |

### Important interpretation

- A service can show low average / percentile CPU usage while still suffering from throttling if bursts are clipped by the limit.
- When that happens, treat the limit as the primary problem.

---

## Memory Request Rules

Use **14-day average memory usage** (Average sampling) as the demand signal.

> Do **not** use Max sampling — Geneva pre-aggregates memory as a sum across pods, so Max captures
> multi-pod spikes during rolling restarts and produces utilization values above 100%.

### Hard gate: OOM kills first

- Query `container:oomkills_total` (Sum) over the 14-day window.
- If **OOM kills > 0**, memory is **under-provisioned** — do **not** reduce memory request.
- Investigate whether the issue is a memory leak, insufficient limit, or JVM misconfiguration.
- Set the classification to **OOMKilled** and estimated memory savings to 0.

### Decision table

**Compute per-pod waste for classification (uses × 1.2 as baseline):**

```text
waste_per_pod_gb = max(0, mem_request - mem_avg_usage × 1.2)
```

Multiply by `avg_replicas` for total fleet savings (`fleet_savings_gb`).
After classification, compute **reported savings** using the actual recommended value for that row
(e.g., `avg_usage × 1.3` for Medium).

| Condition | Classification | Recommendation |
|---|---|---|
| `request > 2 × avg_usage` and `waste_per_pod_gb > 5` | High opportunity | Set request to `avg_usage × 1.2` |
| `request > 1.5 × avg_usage` and `waste_per_pod_gb > 1` | Medium opportunity | Set request to `avg_usage × 1.3` |
| `request > 1.3 × avg_usage` | Low opportunity | Set request to `avg_usage × 1.3` |
| `request` is `1.2×–1.5× avg_usage` | OK | No request change — includes safety buffer against OOM |
| `request < 1.2 × avg_usage` | Under-provisioned | Increase memory request to at least `avg_usage × 1.2` (OOM risk below this threshold) |

### Memory recommended action

When memory waste is clear and safe, generate a concrete recommended action:

| Condition | Action |
|---|---|
| `request > 2 × avg_usage` AND `waste_per_pod > 5 GB` AND `OOM kills == 0` | "Reduce memory request from X GB to Y GB" where Y = `ceil(avg_usage × 1.2)` rounded to nearest 1 GB |
| `request > 1.5 × avg_usage` AND `waste_per_pod > 1 GB` AND `OOM kills == 0` | "Reduce memory request from X GB to Y GB" where Y = `ceil(avg_usage × 1.3)` rounded to nearest 1 GB |
| `request > 1.3 × avg_usage` AND `OOM kills == 0` | "Consider reducing memory request from X GB to Y GB" (lower confidence — minor waste) |
| `OOM kills > 0` | "Do NOT reduce memory — investigate OOM kills" |
| `request` within `±30%` of `avg_usage` | No memory action needed |

**Rounding rule**: Always round recommended memory to the nearest **1 GB** increment (e.g., 18.7 GB → 19 GB).
Unlike CPU which rounds to 0.5-core increments, memory values are typically larger and 1 GB granularity is sufficient.

**Memory limit reminder**: When recommending a memory request change, always include: "Set memory limit = memory request" (MDA standard).

### JVM alignment rules

If the service uses a JVM:

- Check whether `-Xmx` is materially lower than the container memory request.
- **Guard condition**: Only recommend `Xmx × 1.2` when `avg_usage ≤ Xmx × 1.2`.
  - If `avg_usage ≤ Xmx × 1.2` and `request ≫ Xmx × 1.2`: container has excess headroom →
    recommend `Xmx × 1.2`.
  - If `avg_usage > Xmx × 1.2`: the process uses more memory than JVM heap alone (off-heap,
    native libraries, thread stacks). Do **NOT** reduce to `Xmx × 1.2` — use the standard
    `avg_usage × 1.2` formula instead, and note the non-heap overhead as a finding.
- Use the overhead factor for off-heap memory, native libraries, GC, thread stacks, and runtime overhead.
- Example (guard met):
  - `-Xmx = 32GB`, avg_usage = 35 GB (≤ 32 × 1.2 = 38.4 GB)
  - recommended request ≈ `39GB` (`32 × 1.2`, rounded to nearest 1 GB)
  - `60GB` request is likely oversized — reduce to 39 GB
- Example (guard NOT met):
  - `-Xmx = 55GB`, avg_usage = 71 GB (> 55 × 1.2 = 66 GB)
  - Process uses 5 GB more than Xmx × 1.2 explains — non-heap overhead is significant
  - Do NOT recommend 66 GB — use standard formula: `71 × 1.2 = 85 GB`
- If observed memory usage suggests `-Xmx` itself is too low, recommend adjusting `-Xmx` as well rather than only changing the container request.

### OTEL-based JVM sizing (preferred when available)

When OTEL metrics are available (detected via `OTEL_JAVAAGENT_ENABLED: true` in Helm values):

- **Metric**: `jvm.memory.used` from Geneva namespace `otelagent`, account from `mdm.account`.
- **Scope**: Sum all memory pools (heap + non-heap) per-pod — this is the full JVM memory footprint.
- **⚠️ Per-cluster rule**: Query and recommend **per data_center independently**. Never extrapolate
  one region's JVM usage to other regions. Different regions have different workload intensity,
  data volumes, and cache sizes.
- **Formula** (applied per data_center):

```text
recommended_Xmx = avg(jvm.memory.used for that DC, 14d) × 1.2
recommended_Xms = recommended_Xmx
container_memory = recommended_Xmx × 1.2
```

- **Decision table** (per cluster):

| Condition | Recommendation |
|---|---|
| `current_Xmx > recommended_Xmx` | Reduce Xmx to `avg(jvm.memory.used) × 1.2` |
| `current_Xmx ≈ recommended_Xmx` (within 20%) | Xmx is well-sized, no change needed |
| `current_Xmx < avg(jvm.memory.used)` | Xmx is undersized — JVM may be under GC pressure; recommend increasing |
| `container_memory ≫ recommended_Xmx × 1.2` | Container oversized relative to JVM needs — reduce to `Xmx × 1.2` |

- **Advantage over jcmd**: Provides 14-day continuous data (not a point-in-time snapshot),
  captures steady-state behavior across traffic patterns, and requires no pod access.
- **Dimension filters**: Use `service_name` and `data_center` from the specific region's Helm
  file. If query returns empty for a region, try alternative filters for that region only.
  Do NOT use unscoped (no `data_center` filter) aggregate data to size a specific cluster.

### JVM deep-dive for high-memory services

When memory request > 20 GB, flag the service for JVM investigation:

- **K8s memory utilization is misleading for JVM services.** JVM reserves the full `-Xmx` heap
  upfront via `mmap`, so K8s sees high RSS even when actual live data is a fraction of heap.
  A service showing 75-95% K8s memory utilization may have 60 GB reserved but only 5 GB of
  actual live data.
- **Xmx should match actual need, not be guessed.** The right `-Xmx` is `peak_live_data × 3-4`.
  See [java-memory-guide.md](java-memory-guide.md) for the full workflow:
  1. Find Java PID (`jcmd` or `/proc`)
  2. Check heap: `jcmd <PID> GC.heap_info` → look at `used` vs `total`
  3. Check GC logs: the "after GC" heap is the **true live data size**
  4. Recommend: `-Xmx = live_data × 3-4`, container memory = `Xmx × 1.2`.
     `1.2×` is the right multiplier — more than that is likely wasteful.
- **Impact on bin packing:** Oversized memory requests mean fewer pods per node, which directly
  reduces overall CPU utilization (the primary goal of this initiative). A 60 GB pod on a 128 GB
  node leaves only 68 GB for other pods; reducing to 25 GB frees 35 GB per pod.
- **Best practice (medium criticality):** `-Xms == -Xmx` (avoid JVM heap resize overhead and GC
  pauses), `mem_request == mem_limit` (MDA standard). Flag `Xms ≠ Xmx` when found — it causes
  unnecessary GC pressure — but focus first on whether each value is reasonable for the workload.

---

## Memory Limit Rules

Memory limit policy is fixed in MDA:

- **Memory limit must always equal memory request.**
- If `limit != request`, recommend setting:
  - `memory limit = memory request`
- There are no exceptions in this methodology.

---

## HPA / KEDA Rules

Analyze actual replica count over the same 14-day window.

### Min replica rules

- Query **average replica count** over the 14-day window alongside min/max.
- If `avg_replicas ≈ min_replicas` (within 10%) for **more than 90% of the time**: min is likely
  too high — cautiously recommend lowering min replicas.
- If `avg_replicas ≈ max_replicas` (within 10%) for **more than 50% of the time**: the service is
  likely under-provisioned — recommend increasing max replicas to give autoscaling headroom.
- Suggested new min:
  - `P10(actual replica count)`
  - with a floor of `2` for HA services

### Required caution

Frame min-replica recommendations as **owner-validated suggestions**, not automatic changes.

Call out the operational context the service owner must confirm:

- cold-start duration
- connection pool warm-up
- cache warm-up
- partition / shard ownership
- any other workload-specific readiness costs

### KEDA owner questions

Ask the service owner:

- Can the scaling trigger be adjusted?
  - Example: `5 messages/pod` → `10 messages/pod`
- Is there a business dashboard that defines acceptable processing latency?
- For queue-based services, what message delay is acceptable?

### Replica drift detection (actual > max)

Query `keda:hpa_max_replicas` alongside `keda:hpa_current_replicas`:

| Condition | Classification | Recommendation |
|---|---|---|
| `actual_replicas > hpa_max_replicas` | **Replica Drift** | Someone manually scaled the deployment beyond the autoscaler's max. Verify if still needed; if not, revert so autoscaling resumes. If max is genuinely too low, update `maxReplicaCount` in Helm config. |
| `actual_replicas == hpa_max_replicas` for `>50%` of window | Max ceiling hit | Consider increasing `maxReplicaCount` — the service may need headroom |

**Why this matters**: Manual `kubectl scale` overrides bypass KEDA/HPA entirely. The service runs at a
fixed count regardless of load, wasting cores during low-traffic periods and missing autoscaling
benefits. This is a common post-incident artifact that gets forgotten.

### Additional scaling flags

- If no HPA / KEDA exists and replicas are static, flag this as an **autoscaling opportunity**.
- If max replicas are never approached, note it; this can mean scaling is healthy or max is simply generous.

---

## Topology Constraints

Review topology spread settings as part of capacity efficiency.

- Flag `maxSkew: 1` as a capacity-efficiency concern.
- Recommend `maxSkew: 2` or removal when appropriate.
- Explicitly note that the stricter setting may be intentional for HA, so the service owner should confirm before changing it.

---

## Confidence Scoring

Confidence measures **how trustworthy the recommendation is**, not how large the waste is.

| Confidence | Criteria |
|---|---|
| High | `≥80%` 14-day data coverage, stable usage, no recent config deploys, clear waste signal |
| Medium | `50–80%` coverage or moderate variance |
| Low | `<50%` coverage, spiky usage, recent deploys, or conflicting signals such as low utilization with high throttling |

### Important distinction

- Confidence is separate from risk and separate from waste magnitude.
- Valid example: **High waste, Medium confidence, Low risk**.

---

## Cross-Cluster Rules

- Analyze the same service on different clusters **independently**.
- Do not auto-normalize requests, limits, or scaling settings across clusters.
- Flag config differences explicitly, but treat them as potentially intentional.
- Regional traffic shape, customer mix, or dependency behavior may justify different configs.

---

## Final Recommendation Shape

For each `(cluster, namespace, service)` target, produce:

- the current config
- the observed 14-day signals
- the recommended config
- the rationale tied to the rule that fired
- confidence
- risk / caution notes

Keep the recommendation deterministic: explain **which rule fired**, **why**, and **what value it produced**.
