---
name: aks-rightsizing
description: >
  Use this skill when the user wants to analyze, optimize, or right-size AKS pod resource allocation —
  even if they just say "check CPU usage", "rightsizing", "reduce cores", "analyze utilization",
  "optimize resources", "check memory", "reduce costs", or "generate rightsizing PR".
  Use it for CPU/memory request and limit analysis, HPA/KEDA min replica optimization,
  topology constraint review, JVM memory alignment, and generating PRs with recommended changes.
  The skill queries Geneva Monitoring (WCDProduction/WCDPRDInfraSystem) for utilization data,
  applies Eng Hub pod rightsizing methodology, and can generate PRs via the pr-generator skill.
  Do not use for Kusto log queries (use kusto skill), general Geneva monitoring (use geneva-monitoring skill),
  or non-MDA clusters.
---

# AKS Rightsizing

Analyze AKS pod CPU / memory requests and limits, replica settings, and related deployment knobs for
MDA services using Geneva Monitoring data and Eng Hub pod-rightsizing guidance. Treat each
`(cluster, namespace, service)` deployment independently, surface cross-cluster differences as
informational context, and optionally turn recommendations into PRs or ADO tracking items.

## Setup

For first-time configuration (Geneva MCP install + generating the config file), follow
[docs/setup.md](docs/setup.md).

## Runtime Preflight

This skill depends on a working Geneva MCP connection and access to the team's production infra
account. If Geneva tool calls fail with startup / connection / auth / permission errors:

- Confirm the environment was set up per [docs/setup.md](docs/setup.md).
- Confirm the configured Geneva MCP server can read from `WCDProduction` / `WCDPRDInfraSystem`.
- Confirm the user has access to the needed account / namespace.

If preflight fails, report the likely cause and stop. Do **not** invent metric names or proceed with
guessed data.

## Project Config

The team's AKS rightsizing skill is driven by one project-local template plus shipped reference files
that are read alongside it at runtime:

- [`templates/aks-rightsizing-config.md`](templates/aks-rightsizing-config.md) — team **metadata**
  for Geneva MCP server / tool names, cluster topology (Primary / DR / Inline), container focus,
  and ADO tracking settings. Stable, always read first. Service inventory is discovered via Geneva
  at runtime — the config does not enumerate individual services.
- [`library/geneva-dashboard-guide.md`](library/geneva-dashboard-guide.md) — canonical metric names,
  dimensions, dashboard mappings, and Geneva query patterns for `WCDProduction` /
  `WCDPRDInfraSystem`.
- [`library/rightsizing-rules.md`](library/rightsizing-rules.md) — thresholds, buffers, and MDA /
  Eng Hub rules for CPU, memory, HPA/KEDA, topology, and JVM recommendations.
- [`library/analysis-methodology.md`](library/analysis-methodology.md) — the end-to-end method for
  confidence scoring, risk scoring, cross-cluster comparison, and how to explain recommendations.
- [`library/pr-generation-guide.md`](library/pr-generation-guide.md) — how to locate Config Gen vs
  manual Helm config, safely edit values files, and structure rightsizing PRs.
- [`library/java-memory-guide.md`](library/java-memory-guide.md) — step-by-step JVM heap
  investigation for services with high memory requests (>20 GB).
- [`library/html-report-guide.md`](library/html-report-guide.md) — HTML report section structure,
  component patterns, and conventions for generating the detailed rightsizing report file.
- [`assets/report-template.html`](assets/report-template.html) — complete HTML/CSS template
  used as the structural base for generated reports.
- [`library/mda-cluster-inventory.md`](library/mda-cluster-inventory.md) — authoritative list of
  all MDA production clusters (Core 101/103/105/106/111/112 with Primary/DR, and Inline clusters).
  Use this to classify clusters by type and role instead of discovering by ID range.

The template is populated by project configuration and may be refined by hand. Library files are
read-only reference material; updates to them land through repo / plugin updates, not at runtime.

## Steps to Execute

1. **Read config and validate Geneva access.**
   - Read [templates/aks-rightsizing-config.md](templates/aks-rightsizing-config.md).
   - Resolve the concrete Geneva MCP server / tool names from config.
   - Validate connectivity to `WCDProduction` / `WCDPRDInfraSystem` before doing rightsizing work.
   - If connectivity fails, report the issue and stop rather than guessing.

2. **Identify the target and scope.**
   - The user provides the target via prompt — typically a **service name** and optionally a
     **link to the Helm values file** (most straightforward case). The skill can also accept a
     namespace, cluster, or "biggest opportunities" as scope.
   - Possible scopes:
     - one service on one cluster
     - one service across all clusters (discovered via Geneva)
     - an entire namespace
     - an entire cluster
     - "biggest opportunities"
   - Expand the request into concrete `(cluster, namespace, service)` targets using Geneva
     discovery for cross-cluster presence and config metadata for cluster topology.
   - **Classify each cluster by role** using
     [library/mda-cluster-inventory.md](library/mda-cluster-inventory.md):
     - **Inline clusters** (listed in the inventory) are **Active-Active** — no Primary/DR
       distinction. All carry live traffic equally.
     - **Core clusters**: classified as **Primary** or **DR** per cluster group in the inventory.
       Primary clusters carry live traffic; DR clusters are typically paused (0 replicas).
   - If the same service exists on multiple clusters, analyze **each cluster independently**.
   - Note config differences across clusters (requests, limits, HPA/KEDA, topology, JVM settings)
     as **informational context** — different regions may have legitimately different resource needs
     (e.g., Gov is typically less loaded than commercial PRD). Present differences as "FYI, worth
     verifying" rather than critical issues to fix.
   - **Do NOT flag config differences between Primary and DR clusters as "drift"** for non-inline
     clusters — these differences are expected (DR typically has paused KEDA, different scaling
     settings, etc.).

3. **Extract utilization and configuration data via Geneva MCP.**
   - Pull data from `WCDProduction` / `WCDPRDInfraSystem`.
   - **Always filter for `container_name = wdatp-service`** on most metrics. This is the primary
     application container; small sidecars are intentionally ignored unless the user explicitly asks
     otherwise.
   - ⚠️ **Exception**: the throttling metric `container:cpu_elevated_throttling_scaled` uses
     dimension **`container`** (not `container_name`). Using the wrong dimension returns empty data
     silently.
   - Use [library/geneva-dashboard-guide.md](library/geneva-dashboard-guide.md) for the exact metric
     names, dimensions, scaling factors, and query shapes.
   - Collect **CPU** data over the last 14 days:
     - current request via `container:resource_requests_cpu_millicores` (÷1000 for cores)
     - current limit via `container:resource_limits_cpu_millicores` (÷1000 for cores)
     - actual usage `P50`, `P95`, `P99`, `Max` via `container:cpu_usage_rate_millicores`
       (÷1000 for cores) — this is the **only** CPU metric with percentile support
     - CPU throttling via `container:cpu_elevated_throttling_scaled` (**÷10** for actual %,
       uses `container` dim not `container_name`)
   - Collect **memory** data over the last 14 days:
     - current request via `container:resource_requests_memory_bytes` (÷1024³ for GB)
     - current limit via `container:resource_limits_memory_bytes` (÷1024³ for GB)
     - actual average usage via `container:memory_usage_bytes` with **Average** sampling (÷1024³ for GB)
       — ⚠️ Do NOT use Max sampling for memory: Geneva pre-aggregates across pods, so Max
       captures multi-pod peaks during rolling restarts (e.g., 2 pods × 8 GB = 16 GB > single-pod
       limit), producing utilization values above 100% which are physically impossible per-pod.
   - Collect **replica / scaling** data over the last 14 days:
     - actual replica count via `keda:hpa_current_replicas` with **Average** sampling (for avg
       analysis) AND **Max** sampling (for drift detection); if this metric is unavailable, fall
       back to `kube_deployment_status_replicas`
     - configured min via `keda:hpa_min_replicas` (or from Helm values if metric unavailable)
     - configured max via `keda:hpa_max_replicas` (or from Helm values if metric unavailable)
     - Dimensions: `K8sClusterName`, `namespace`, service dimension (check pre-aggregation —
       typically `service_name` or `pServiceName`)
     - Compute from the time-series:
       - `avg_replicas` = mean of Average-sampled series over the 14-day window
       - `max_observed` = peak of Max-sampled series (detects manual scaling)
       - `% time at min` = fraction of data points where `actual ≈ min` (within ±10%)
       - `% time at max` = fraction of data points where `actual ≈ max` (within ±10%)
     - **Replica drift**: if `max_observed > configured_max`, flag immediately — someone manually
       scaled the deployment and it was never reverted.
   - Also capture any signals needed for confidence scoring, such as data coverage, sharp variance,
     or evidence of recent deployment changes if available from the configured sources.
   - **DR cluster handling**: For non-inline clusters, if a DR cluster has KEDA paused
     (`autoscaling.keda.sh/paused-replicas: "0"`) or disabled (`keda.enabled: false` +
     `replicaCount: 0`), it will have 0 replicas and no Geneva utilization data. This is expected.
     Skip utilization metric queries for paused DR services — record the service's existence and
     config but do not treat missing data as a coverage gap.
   - **DR running detection**: If a non-inline cluster in a DR region shows active
     replicas in Geneva, flag it — this may be an optimization opportunity (unexpected DR compute).
   - Collect **OOM kill** data over the last 14 days:
     - OOM kills via `container:oomkills_total` with **Sum** sampling (uses `container_name` dim)
     - Any non-zero value indicates memory pressure or under-provisioning
   - **⚠️ Dimension normalization**: when merging data from multiple metrics, always normalize
     namespace to lowercase and K8sClusterName to UPPERCASE. Geneva metrics may return different
     casing for the same dimension values (e.g., `weu-102` vs `WEU-102`, `discovery` vs `Discovery`).

4. **🚫 BLOCKING — Query OTEL JVM memory if Java service detected.**

   > **This step is NOT optional.** If `OTEL_JAVAAGENT_ENABLED: true` is found in the Helm values,
   > you MUST query `jvm.memory.used` BEFORE producing any memory recommendation. Do NOT skip this
   > step to save time. Do NOT defer it. Do NOT produce memory recommendations based only on K8s
   > `memory_usage_bytes` when OTEL is available — K8s memory is misleading for JVM services
   > (reports mmap reservation, not live data). Skipping this step produces recommendations that
   > are 5× too conservative.

   **Detection**: Check all Helm values files for `OTEL_JAVAAGENT_ENABLED: true` in
   `environmentVariables`. If found on ANY region:

   1. Extract `mdm.account` from the Helm `mdm` section (e.g., `McasDiscoveryProd`).
   2. Verify the metric exists: `metrics_get_metric_config(monitoringAccount=<account>,
     metricNamespace="otelagent", metric="jvm.memory.used")`.
   3. **For EACH data_center** (from each regional Helm file's `mdm.transformRules`), query:
     - Account = extracted `mdm.account`
     - Namespace = `otelagent`
     - Metric = `jvm.memory.used`
     - Sampling = Average, 14-day window
     - Dimension filters: `service_name=<service>`, `data_center=<DC>`,
       `jvm.memory.pool.name=*`, `jvm.memory.type=*`, `pod_name=*`
   4. **Aggregate**: Sum all memory pools per pod, then compute per-pod average and max across pods.
   5. **Per-cluster recommendation**:
     - `recommended_Xmx = avg_per_pod_jvm_used × 1.2`
     - `recommended_Xms = recommended_Xmx`
     - `recommended_container = recommended_Xmx × 1.2`
   6. **Flag outliers**: If any pod's total JVM usage exceeds 2× the regional average, flag it
     as a potential memory leak requiring investigation. Use conservative sizing
     (`max_pod × 1.5`) for that region until the outlier is resolved.
   7. ⚠️ **Never extrapolate** one region's JVM data to another. Each region must be independently
     queried.
   8. If the metric query returns empty for a specific region, try alternative dimension filters.
     If all fail, fall back to the K8s-level methodology (step 5) for that region only.

   **If OTEL is NOT detected** (no `OTEL_JAVAAGENT_ENABLED` in any Helm file), skip this step
   entirely and proceed to step 5.

5. **Analyze the data using the library guidance.**
   Read [library/rightsizing-rules.md](library/rightsizing-rules.md) and
   [library/analysis-methodology.md](library/analysis-methodology.md), then apply these rules:

   - **CPU request**
     - Check **CPU throttling first**.
     - If throttling is `≥ 5%`, do **not** recommend reducing CPU request yet; investigate CPU limit
       behavior first.
     - If request is `> 2x P99`, throttling is low, **and** absolute fleet savings `> 5 cores`
       (`(request - P99 × 1.2) × avg_replicas`):
       **High opportunity** → recommend `P99 × 1.2`.
     - If request is `> 1.5x P99`, throttling is low, **and** absolute fleet savings `> 1 core`:
       **Medium opportunity** → recommend `P99 × 1.3`.
     - If request is `1.0×–1.5× P99`: mark as **OK** — request is at or slightly above observed peak.
     - If request is below `P99`: mark as **Under-provisioned** → recommend increasing to at least `P99 × 1.2`.

   - **CPU limit**
     - If the limit is already removed: keep it removed; do not add one back.
     - If a limit exists and is `< 3x request`: recommend removing it or raising it to roughly
       `3x-4x` request.
     - If `limit == request` (Guaranteed QoS): flag it as a likely throttling risk.
     - High throttling with low utilization usually means the **limit** is too restrictive even if
       the request looks high.

   - **Memory request**
     - Use **14-day average** usage (Average sampling), not Max, because Geneva's Max captures
       multi-pod aggregate peaks during rolling restarts which inflate the ratio above 100%.
     - **Check OOM kills first.** If `container:oomkills_total` > 0 in 14 days, memory is
       under-provisioned — do NOT recommend reducing. Investigate possible memory leaks or
       insufficient limit instead.
     - If request is `> 2x avg_usage` AND absolute waste per pod > 5 GB: **High opportunity** → recommend `avg_usage × 1.2`.
     - If request is `> 1.5x avg_usage` AND absolute waste per pod > 1 GB: **Medium opportunity** → recommend `avg_usage × 1.3`.
     - If request is `1.2×–1.5× avg_usage`: mark as **OK** — includes safety buffer against OOM.
     - If request is below `1.2× avg_usage`: mark as **Under-provisioned** (OOM risk) → recommend increasing to at least `avg_usage × 1.2`.
     - Check JVM alignment. If `-Xmx` is known and `avg_usage ≤ Xmx × 1.2`, the container has
       excess headroom above JVM needs — recommend reducing memory request to `Xmx × 1.2`.
       However, if `avg_usage > Xmx × 1.2`, the process uses more memory than JVM heap alone
       explains (off-heap, native libraries, large thread stacks, etc.) — do **NOT** recommend
       reducing to `Xmx × 1.2` as this would cause OOM. Instead, note the non-heap overhead and
       recommend the standard `avg_usage × 1.2` formula.
     - **JVM deep-dive for high-memory services (MEM request > 20 GB)**:
       - If step 4 (OTEL query) was executed, **use the OTEL-derived recommendations directly** —
         they supersede K8s-level memory analysis. The OTEL data shows actual live JVM data, which
         is typically 4-8× less than what K8s `memory_usage_bytes` reports (because K8s counts
         the full Xmx mmap reservation as RSS).
       - If step 4 was skipped (no OTEL available), fall back to:
         - Manual jcmd analysis — reference [library/java-memory-guide.md](library/java-memory-guide.md)
           for `jcmd GC.heap_info` → GC log analysis → `peak_live_data × 3-4` for Xmx, then
           container = `Xmx × 1.2`.
         - Or the K8s-level formula above (`avg_usage × 1.2`) as a last resort — but note in the
           report that this is likely too conservative for JVM services.
       - Example: if `-Xmx=60GB` but OTEL shows actual JVM used is 12GB, recommend `-Xmx=15GB` and
         container=18GB — saves 62GB per pod.

   - **Memory limit**
     - Memory limit must **always equal** memory request in this environment.
     - If `limit != request`, recommend setting `limit = request`.

   - **HPA / KEDA**
     - Using the replica time-series collected in step 3, apply these rules:
     - If `avg_replicas ≈ min_replicas` (within 10%) for `>90%` of the observed period:
       min is likely too high — cautiously recommend lowering min.
     - If `avg_replicas ≈ max_replicas` (within 10%) for `>50%` of the observed period:
       service is likely under-provisioned — recommend increasing max replicas.
     - Suggested min is `P10` of observed replica count, with a floor of `2` for HA.
     - Always call out that service-owner context is required before changing min replicas.
     - KEDA trigger thresholds / cooldowns / polling are tightly coupled to business behavior;
       ask the owner before changing them.
     - **Replica drift**: if `actual_replicas > HPA/KEDA max_replicas`, someone manually scaled the
       deployment (e.g., `kubectl scale`) and it was never reverted. Flag this prominently — the
       service bypasses autoscaling entirely and runs at a fixed, potentially wasteful count.
       Recommend verifying if the override is still needed; if not, revert to let autoscaling resume.

   - **Topology / placement**
     - Flag `maxSkew=1` as a potential efficiency cost, but note that it may be intentional for HA.

   - **Confidence scoring**
     - **High**: `>=80%` data coverage, stable usage, no recent deploy indicators.
     - **Medium**: `50-80%` coverage or moderate variance.
     - **Low**: `<50%` coverage, highly spiky behavior, or recent deploy indicators.

6. **Generate the HTML report file.**
   - Read [library/html-report-guide.md](library/html-report-guide.md) for the exact HTML
     structure, CSS theme, component catalog, and section layout.
   - Generate **one self-contained HTML file per service** with the full detailed analysis:
     - File name: `{service}-rightsizing.html` (kebab-case)
     - Location: `~/` (user home folder). On macOS use `~/`; on Windows use `$HOME\`
       (PowerShell) or `%USERPROFILE%\` (CMD).
     - Sections: Executive Summary → CPU Analysis → Memory Analysis → Replica/KEDA →
       Cross-Cluster Comparison → JVM Deep-Dive (if Java) → Structured Recommendations → Action Items
   - The HTML file must include all tables, badges, alerts, utilization bars, and savings
     calculations. This is where the full depth of the analysis lives.
   - After writing the file, **open it**:
     - macOS: `open ~/{service}-rightsizing.html`
     - Windows (PowerShell — try first): `Start-Process "$HOME\{service}-rightsizing.html"`
     - Windows (CMD — fallback): `start "" "%USERPROFILE%\{service}-rightsizing.html"`
   - Include a **CPU table** with current request, current limit, `P50/P95/P99`, throttling, the
     recommended value, and rationale.
   - Include a **memory table** with current request, current limit, 14-day average usage, OOM kills
     (14d), the recommended request, and the reminder that recommended memory limit must equal request.
   - Include an **HPA/KEDA table** with current min/max, observed behavior, a suggested min/max if
     appropriate, and any owner follow-up required.
   - Include **topology / JVM / miscellaneous notes** when they affect the recommendation.
   - When the same service appears on multiple clusters, include a **cross-cluster comparison
     table** noting configuration differences as informational context. Different regions may have
     legitimately different resource needs — present differences as "FYI, worth verifying" rather
     than as problems. Only compare clusters of the same role (Primary vs Primary, or DR vs DR).
     Config differences between Primary and DR clusters are expected for non-inline clusters.
   - For **DR clusters**:
     - If correctly paused: note "DR cluster, KEDA paused — no action needed."
     - If unexpectedly running: flag as "DR cluster X is running active replicas — verify if
       intentional. Consider pausing KEDA to eliminate idle compute."
   - Include **cluster role** (Primary / DR / Active-Active) in each per-cluster report section.
   - Always include **confidence** and **risk / caution notes**, plus any caveats that reduce certainty.

7. **Print a concise executive summary in the CLI.**
   - After generating the HTML report, print a **short summary** (10-15 lines max) in the CLI.
   - The CLI summary must include:
     - Service name and namespace
     - Number of clusters analyzed
     - Headline savings: estimated CPU cores saved and memory GiB saved
     - Count of critical findings (🚨) and warnings (⚠️)
     - Top 1-2 critical findings as one-liners
     - The file path to the HTML report
   - **Do NOT print** the full analysis, tables, per-cluster breakdowns, or detailed
     recommendations in the CLI. All detail belongs in the HTML report.
   - Example CLI output format:

     ```
     ── AKS Rightsizing: {service} ({namespace}) ──────────────
     Clusters analyzed: 5 primary
     Est. CPU savings:  ~5,240 cores  |  Est. memory savings: ~4,860 GiB
     Critical findings: 3  |  Warnings: 2

     🚨 WEU replica drift: 150 replicas vs Helm max 100
     🚨 All clusters pinned at KEDA max — autoscaling bypassed
     ⚠️ CPU 4-9× over-provisioned on 4 of 5 regions

     📄 Full report: ~/{service}-rightsizing.html
     ────────────────────────────────────────────────────────────
     ```

8. **Generate a PR when the user explicitly asks for one.**
   - Read [library/pr-generation-guide.md](library/pr-generation-guide.md) before proposing file
     edits or PR content.
   - Confirm whether the source of truth is **Config Gen** or **manual Helm values**.
   - Confirm which repo and file path should be changed if the user has not already provided them.
   - Generate changes for **all regions**; SDP handles the staged rollout.
   - If the same service differs across clusters, ask whether the goal is to preserve divergence or
     unify the configs.
   - Prioritize:
     - CPU / memory requests and limits
     - HPA / KEDA min / max
   - Only include secondary changes when clearly justified by the data:
     - JVM `-Xmx` / `-Xms`
     - topology settings
     - node selectors / placement knobs
   - Hand off PR creation to the `pr-generator` skill.
   - Include confidence warnings, owner-context requirements, and any cross-cluster caveats in the
     PR description.

9. **Create ADO tracking when the user explicitly asks for it.**
   - Create a User Story titled:
     - `[Rightsizing] {service} — reduce CPU request from X to Y`
   - Add tags:
     - `rightsizing`
     - `compute-efficiency`
   - Include the target cluster / namespace, the before→after recommendation, the main Geneva
     evidence, confidence level, and any follow-up required from the service owner.

## Constraints

- **Do not invent Geneva metric names.** Only use values from
  [templates/aks-rightsizing-config.md](templates/aks-rightsizing-config.md), from
  [library/geneva-dashboard-guide.md](library/geneva-dashboard-guide.md), from discovery, or from
  explicit user input.
- **Always filter for `container_name = wdatp-service`** except for the throttling metric which uses
  `container = wdatp-service` (see exception below).
- **Always check CPU throttling before recommending CPU request reduction.**
- **Memory limit must always equal memory request.**
- **HPA / KEDA changes require service-owner input.** Recommend cautiously and surface the questions
  that must be answered.
- **Low confidence is a warning, not a blocker.** Surface uncertainty clearly, but still provide the
  best bounded recommendation available.
- **Do not use this skill for Kusto queries or general Geneva monitoring.** Use `kusto` for log /
  ADX work and `geneva-monitoring` for non-rightsizing Geneva asks.
- **Do not flag Primary/DR config differences as drift** for non-inline clusters. These are
  expected — DR clusters typically have paused KEDA, different replica settings, or lower resource
  requests. Cross-cluster config differences between same-role clusters are informational — different
  regions may have legitimately different resource needs.
- **Focus analysis on Primary clusters.** DR clusters that are correctly paused consume no compute
  and do not need CPU/memory rightsizing. DR clusters that are unexpectedly running should be flagged
  as optimization opportunities.
- **Refer to Eng Hub for detailed methodology, but treat the local library files as the primary
  runtime source.**
