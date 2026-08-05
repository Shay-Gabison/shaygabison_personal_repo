# Inspecting Monitors — V1/V2 Config, Preview & Health Model

> Tool-call templates for investigating monitor configurations, previewing evaluations,
> and navigating the Geneva health model tree.

---

## V1 vs V2 Monitor Comparison

| | V1 (Legacy) | V2 (Current) |
|---|---|---|
| Data model | Single metric + sampling + threshold | Multi-metric expressions, lookback, percentile math |
| Alert condition | Simple threshold | `bucketCount` of `totalBucketCount` consecutive evals |
| Preview API | **None** — read the underlying metric instead | `monitor_v2_preview_result` |
| Addressing | `(namespace, metric, monitorName)` — no GUID | GUID-based |
| List all | `monitor_get_all_monitor_v1_configuration(tenantName)` | `monitor_get_monitor_v2_configuration(tenantName)` (no monitorGuid → all) |
| Get one | `monitor_get_monitor_v1_configuration(tenantName, namespace, metric)` — filter by name | `monitor_get_monitor_v2_configuration(tenantName, monitorGuid)` |
| Config history | `kusto_get_monitor_v1_config_history` | `kusto_get_monitor_v2_config_history` |

---

## V2 Monitor Investigation Templates

### Get all V2 monitors for a resource type

```
monitor_get_monitor_v2_by_resource_type(
  tenantName   = "<account>",
  resourceType = "<resource_type>"
)
```

### Preview a V2 monitor's evaluation

```
monitor_v2_preview_result(
  tenantName = "<account>",
  monitorId  = "<monitor_guid>",
  requestJson = {
    "combinations": [
      {
        "Monitor.Tenant": "<account>",
        "<dim1>": "<v1>",
        "<dim2>": "<v2>"
      }
    ],
    "previewResultTypes": ["ThresholdResult"],
    "startTime": <epoch_ms_start>,
    "endTime":   <epoch_ms_end>
  }
)
```

**Critical**: `Monitor.Tenant` must always be included if the monitor uses it as an
environment variable. Omitting it causes "combination does not have the same set of
dimensions" error.

### Discover which dimension combinations a monitor evaluates

```
monitor_v2_preview_combination(
  tenantName = "<account>",
  monitorId  = "<monitor_guid>"
)
```

Run this first when you don't know the exact dimension values to pass to `preview_result`.

---

## V1 Monitor Details

### Key fields in a V1 config

- `metricNamespace`, `metricName`, `samplingType` — what the monitor watches.
- `threshold` and `operator` — the alert condition.
- `severity` — ICM severity.
- `dimensions` / `dimensionFilters` — which slice the monitor evaluates.
- `lastModifiedTime` — config change timestamp.

### Get V1 monitor configs filtered by namespace / metric

```
monitor_get_monitor_v1_configuration(
  tenantName = <account>,
  namespace  = <namespace>,   # supports '.*' wildcard
  metric     = <metric>       # supports '.*' wildcard
)
```

> V1 monitors are addressed by `(namespace, metric, monitorName)` — not by a GUID.
> Filter by namespace + metric and pick by `monitorName` from the result.

### Get V1 monitor config history

```
kusto_get_monitor_v1_config_history(
  tenantName  = <account>,
  namespace   = <namespace>,
  metric      = <metric>,
  monitorName = <name>,
  startTime   = <ISO_datetime>,   # optional, defaults to 3h ago
  endTime     = <ISO_datetime>    # optional, defaults to now
)
```

### Get metric evaluation data for a V1 monitor

```
monitor_get_v1_monitor_metrics(
  monitoringAccount = <account>,
  metricNamespace   = <namespace>,
  metric            = <metric>,
  monitorId         = <monitorName>,
  dimensions        = "<dim1>/<v1>/<dim2>/<v2>"   # path-segment form, REQUIRED
)
```

Dimensions must match the monitor's preaggregate dimensions.

---

## Debugging a V1 Firing (No Preview API)

There is no `monitor_v1_preview_result`. To reconstruct what the monitor saw:

1. Get the active config at the firing time via `kusto_get_monitor_v1_config_history`.
2. Fetch the merged metric the monitor was evaluating via `monitor_get_v1_monitor_metrics`,
   OR read the underlying metric directly via `metrics_read_multi_time_series` using the
   V1's `metricNamespace` / `metricName` / `samplingType` and matching dimension filters.
3. Compare against the threshold yourself.

---

## Health Model Navigation

```
# 1. Get all topologies (no parameters)
health_get_topologies()

# 2. Get health view tree for a specific resource
health_get_resource_tree(
  tenantName   = "<account>",
  resourceType = "<resource_type>",
  resourceName = "<resource_name>"
)

# 3. Walk children of a specific node
health_get_children(
  tenantName = "<account>",
  nodeId     = "<node_id>"       # optional — omit for root-level children
)

# 4. Which watchdogs are failing?
health_get_failing_watchdogs(
  tenantName = "<account>",
  failing    = true              # false for passing watchdogs
)

# 5. Monitors and health status for a specific metric
health_get_monitors_and_health(
  monitoringAccount = "<account>",
  metricNamespace   = "<namespace>",
  metric            = "<metric>"
)

# 6. Is a suppression rule hiding alerts?
health_get_suppression_rules(
  tenantName = "<account>"
)
```

---

## Health Model Investigation Workflow

### "Why is this resource red?"

1. `health_get_resource_tree(tenantName, resourceType, resourceName)` — get the health view tree for the resource.
2. `health_get_monitors_and_health(monitoringAccount, metricNamespace, metric)` — see which monitors are unhealthy for the metric.
3. For the failing monitor, get its config via `monitor_get_monitor_v2_configuration`
   (or V1 equivalent) and preview or read the underlying metric to understand the breach.
4. Check `health_get_suppression_rules(tenantName)` if an expected alert didn't fire.
