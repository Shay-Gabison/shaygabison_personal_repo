# Java Memory Right-Sizing Guide for K8s

## The Problem

Java services with high `-Xms`/`-Xmx` values reserve memory upfront, even if the app doesn't need it.
Kubernetes sees high memory utilization — but the app may only use a fraction of it.

This guide helps you find out **how much memory your Java service actually needs**.

---

## Preferred: OTEL-Based JVM Analysis

Many MDA Java services have the OpenTelemetry Java agent enabled, which exports JVM memory metrics
to Geneva. When available, this provides a **fully automated** path to right-size JVM memory without
manual pod access.

### Step 1: Detect OTEL Availability from Helm Values

When the user provides a Helm values file (or a directory/repo link containing multiple regional
Helm files), look for these signals:

```yaml
# Primary signal — OTEL Java agent is enabled
environmentVariables:
  OTEL_JAVAAGENT_ENABLED: true

# Confirms OTEL metrics are flowing to Geneva MDM
mdm:
  otel:
    enabled: true
```

If `OTEL_JAVAAGENT_ENABLED: true` is present, proceed with OTEL-based analysis.

### Step 2: Enumerate ALL Regional Helm Files

> ⚠️ **CRITICAL: Per-Cluster Scope Rule**
>
> A `jvm.memory.used` query filtered to one `data_center` is evidence **only for that
> data center / cluster**. Never extrapolate JVM memory usage from one region to another.
> Regions can vary drastically in workload, data sizes, and cache patterns.
> JVM recommendations must be produced per `(cluster, data_center)`.

**If the user provides a directory or repo folder** (e.g., `/copernicus/Deployment/worker/`):
- Enumerate ALL regional Helm values files (e.g., `helm-prd-eus2-values.yaml`,
  `helm-prd-weu-values.yaml`, `helm-prd-uks-values.yaml`, etc.)
- Read each file to extract its `data_center`, `service_name`, `mdm.account`, and `Xms`/`Xmx`
- Build a per-region table before querying Geneva

**If the user provides only ONE Helm file**:
- Analyze only that region
- Explicitly state that other regions need their own Helm files / `data_center` queries before
  JVM recommendations can be made for them
- Do NOT extrapolate the single region's result fleet-wide

### Step 3: Build Per-Region Inventory

Before querying Geneva, assemble this table from the Helm files:

| Region/Cluster | Helm File | mdm.account | service_name | data_center | Current Xms | Current Xmx | OTEL? |
|----------------|-----------|-------------|--------------|-------------|-------------|-------------|-------|
| EUS2-101 | helm-prd-eus2-values.yaml | McasDiscoveryProd | copernicus-worker | EUS2 | 55G | 55G | ✅ |
| WEU-102 | helm-prd-weu-values.yaml | McasDiscoveryProd | copernicus-worker | WEU | 55G | 55G | ✅ |
| ... | ... | ... | ... | ... | ... | ... | ... |

### Step 4: Query Geneva PER DATA CENTER

For **each row** in the table with OTEL enabled, independently query:

| Parameter | Value |
|-----------|-------|
| **Account** | That row's `mdm.account` (e.g., `McasDiscoveryProd`) |
| **Namespace** | `otelagent` (always this namespace for OTEL metrics) |
| **Metric** | `jvm.memory.used` |
| **Time window** | Last 14 days |
| **Sampling** | Average |
| **Dimensions to filter** | `service_name` = that row's value, `data_center` = that row's value |

The metric reports total JVM memory across all pools (heap + non-heap: Eden, Old Gen, Metaspace,
Code Cache, etc.). Use the **sum of all pools** — this represents the full JVM memory footprint
for a single JVM instance (pod).

> ⚠️ Do NOT sum JVM memory across replicas. Size per-pod, not per-replica-set.

### Step 5: Analyze and Recommend PER CLUSTER

For **each data_center** independently, apply the sizing formula:

```
┌──────────────────────────────────────────────────────────────┐
│  recommended_Xmx  = avg(jvm.memory.used, 14d) × 1.2         │
│  recommended_Xms  = recommended_Xmx  (Xms == Xmx)          │
│  container_memory  = recommended_Xmx × 1.2                  │
│                      (covers native overhead beyond JVM)      │
└──────────────────────────────────────────────────────────────┘
```

Produce a per-cluster recommendation table:

| Cluster | data_center | Avg JVM Used | Rec. Xmx | Rec. Container | Current Xmx | Savings |
|---------|-------------|--------------|-----------|----------------|-------------|---------|
| EUS2-101 | EUS2 | 31 GB | 38 GB | 65 Gi | 55 GB | 35 Gi/pod |
| WEU-102 | WEU | 35 GB | 42 GB | 70 Gi | 55 GB | 30 Gi/pod |
| ... | ... | ... | ... | ... | ... | ... |

Do **not** create a fleet-wide single JVM recommendation unless every included region has been
queried separately and the per-region evidence supports the same value.

### Step 6: Fallback Strategy (if metric is empty for a specific data_center)

If the OTEL metric query returns empty data for a specific `data_center` despite
`OTEL_JAVAAGENT_ENABLED: true`:

1. **Try without `service_name` filter** — the dimension may be named differently
   (e.g., `service`, `service.name`, `otel.service.name`)
2. **Try without `data_center` filter** — some services don't set this dimension.
   ⚠️ If removing `data_center` returns data, use it **only for diagnostic purposes** to
   discover the correct dimension names. Do NOT use unscoped aggregate JVM data to size
   a specific cluster's `Xmx` — re-query with the correct filters once discovered.
3. **List available dimensions** for the `jvm.memory.used` metric in the `otelagent` namespace
   to discover the correct filter names
4. **If all attempts fail** — report what was tried, explain the likely cause (OTEL agent
   configured but not emitting metrics, or metrics routed to a different account/namespace),
   and fall back to the manual `jcmd` approach below

When falling back, suggest the user verify:
- That the OTEL agent is actually running (check pod logs for `opentelemetry-javaagent` startup)
- That metrics are flowing to the expected Geneva account
- That the namespace is correct (might be a custom namespace instead of `otelagent`)

---

## Fallback: Manual Analysis via jcmd

Use this approach when OTEL metrics are **not available** — either because `OTEL_JAVAAGENT_ENABLED`
is not set, or because the OTEL metric query returned empty data after exhausting fallback attempts.

### Step-by-Step

### 1. Find the Java Process ID

PID 1 in a container is often a shell wrapper, not Java. Find the real PID:

```bash
kubectl exec <POD> -n <NAMESPACE> -c <CONTAINER> -- \
  ls /proc/ | grep -E '^[0-9]+$'
```

Then confirm which PID is Java:

```bash
kubectl exec <POD> -n <NAMESPACE> -c <CONTAINER> -- \
  cat /proc/<PID>/cmdline | tr '\0' '\n' | head -3
```

> Look for the one that starts with `java`.

---

### 2. Check JVM Heap Usage

```bash
kubectl exec <POD> -n <NAMESPACE> -c <CONTAINER> -- \
  jcmd <JAVA_PID> GC.heap_info
```

Example output:
```
garbage-first heap   total 7522304K, used 2988349K [...]
  region size 2048K, 1268 young (2596864K), 37 survivors (75776K)
Metaspace       used 145925K, capacity 155776K, committed 156108K
```

**What to look at:**
| Field | Meaning |
|-------|---------|
| `total` | Heap committed by JVM (grabbed from OS) |
| `used` | Heap currently in use (includes garbage not yet collected) |
| `Metaspace used` | Non-heap memory for class metadata |

> ⚠️ If `jcmd` fails on PID 1, try other PIDs from Step 1.

---

### 3. Check GC Logs for Real Live Data

GC logs show heap **before and after** each garbage collection — the "after" value is your **true live data size**.

First, find the GC log file:
```bash
kubectl exec <POD> -n <NAMESPACE> -c <CONTAINER> -- \
  find /var/log -name "gc*" -type f 2>/dev/null
```

Then extract the GC events:
```bash
kubectl exec <POD> -n <NAMESPACE> -c <CONTAINER> -- \
  grep "GC pause" <GC_LOG_PATH> | tail -10
```

Example output:
```
[GC pause (young), 0.020s]
  [Eden: 4364M->0B  Heap: 4790M(7346M)->390M(7346M)]
```

**How to read it:**
```
Heap: 4790M (before GC) → 390M (after GC), out of 7346M (committed)
       ↑                     ↑                       ↑
   Heap with garbage    ACTUAL LIVE DATA         Total committed
```

> ✅ **The "after GC" number is what your app truly needs.**
> Run this across multiple hours to find the peak.

---

### 4. Check OS-Level Memory (RSS)

```bash
kubectl exec <POD> -n <NAMESPACE> -c <CONTAINER> -- \
  cat /proc/<JAVA_PID>/status | grep -E 'VmRSS|VmHWM|Threads'
```

| Field | Meaning |
|-------|---------|
| `VmRSS` | Current physical memory used by the process |
| `VmHWM` | Peak physical memory ever used (high water mark) |
| `Threads` | Number of active threads |

---

### 5. Check Container Allocation

```bash
kubectl get pod <POD> -n <NAMESPACE> \
  -o jsonpath='{.spec.containers[?(@.name=="<CONTAINER>")].resources}' | python3 -m json.tool
```

---

## Sizing from Manual Analysis (jcmd/GC logs)

Once you have the numbers from the manual steps above, use this formula:

```
┌─────────────────────────────────────────────────┐
│  -Xmx  =  peak live data (after GC) × 3-4      │
│  -Xms  =  same as -Xmx (or lower if you want   │
│            gradual growth)                       │
│  Container request/limit = Xmx × 1.2            │
│            (covers metaspace, threads, native)   │
│            Use 1.3-1.4 only if measured off-heap │
│            evidence justifies more headroom.     │
└─────────────────────────────────────────────────┘
```

### Example

| Metric | Your Value |
|--------|-----------|
| Live data after GC | 400 MB |
| → Recommended `-Xmx` | **1.5–2 GB** (conservative: 4× live data) |
| → Recommended `-Xms` | **1.5–2 GB** (match Xmx) |
| Metaspace + threads + native overhead | ~1.5 GB |
| → Recommended container memory | **3–4 Gi** |

### ⚠️ Before You Change Anything

1. **Check multiple pods** — don't base decisions on a single pod
2. **Check peak hours** — run the GC log check during busy periods
3. **Start conservative** — reduce by 30-50% first, monitor, then reduce more
4. **Watch for OOMKilled** — if pods get killed after changes, you went too low
5. **Monitor GC frequency** — smaller heap = more frequent GC. If GC pauses become too frequent, increase Xmx

---

## Quick Reference (Copy-Paste)

Replace `$POD`, `$NS`, `$CTR`, `$PID` with your values:

```bash
# Find Java PID
kubectl exec $POD -n $NS -c $CTR -- ls /proc/ | grep -E '^[0-9]+$'

# Confirm it's Java
kubectl exec $POD -n $NS -c $CTR -- cat /proc/$PID/cmdline | tr '\0' '\n' | head -3

# Heap snapshot
kubectl exec $POD -n $NS -c $CTR -- jcmd $PID GC.heap_info

# GC history (true live data)
kubectl exec $POD -n $NS -c $CTR -- grep "GC pause" <GC_LOG_PATH> | tail -10

# OS-level memory
kubectl exec $POD -n $NS -c $CTR -- cat /proc/$PID/status | grep -E 'VmRSS|VmHWM|Threads'

# Container allocation
kubectl get pod $POD -n $NS -o jsonpath='{.spec.containers[?(@.name=="'$CTR'")].resources}'
```
