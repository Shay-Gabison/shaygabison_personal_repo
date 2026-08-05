# Discovering Metrics — Namespaces, Dimensions & Time Series

> Tool-call templates for metric discovery and reading time series data.
> All account/namespace/metric names are `<placeholders>` — replace with values
> from the project's `*geneva-monitoring-config.md`.

---

## Metric Discovery Sequence

Run these in order when investigating a metric you haven't queried before:

```
# 1. List namespaces in the account
metrics_get_namespaces(tenantName = "<account>")

# 2. List metrics in the namespace
metrics_get_metric_names(tenantName = "<account>", metricNamespace = "<namespace>")

# 3. Get metric config — dimensions and pre-aggregations
metrics_get_metric_config(
  monitoringAccount = "<account>",
  metricNamespace   = "<namespace>",
  metric            = "<metric_name>"
)
```

From `metrics_get_metric_config`, inspect:
- `dimensions[]` — all known dimension names.
- `preaggregateConfigurations[]` — which dimension combos are materialized. Only these
  combos can be used in `dimensionFilters` at read time. Others return `InvalidSeries`.

---

## Reading Time Series

### Basic read (single dimension filter)

```
metrics_read_multi_time_series(
  monitoringAccount        = "<account>",
  metricNamespace          = "<namespace>",
  metricName               = "<metric>",
  samplingType             = "Count",
  startTimeUtc             = "<ISO-8601 start>",
  endTimeUtc               = "<ISO-8601 end, ≥ 2 min before now>",
  dimensionFilters         = { "<dim>": "<value>" },
  seriesResolutionInMinutes = 5
)
```

### Dimension filter forms

| Form | Syntax | Use case |
|------|--------|----------|
| Exact match | `{ "env": "Prod-02" }` | Single value |
| Wildcard | `{ "env": "*" }` | All values — one series per value |
| Multi-value | `{ "env": ["Prod-02", "Prod-05"] }` | OR-match — one series per value |
| Multiple dims | `{ "env": "Prod-02", "dc": "WEU" }` | AND — must match a pre-agg that includes both dims |

### Sampling types (structured API)

These are used in `metrics_read_multi_time_series` and `monitor_get_monitor_v2_configuration`.
**PascalCase, no spaces.**

| Sampling Type | Notes |
|---------------|-------|
| `Count` | Number of data points in the bucket |
| `Sum` | Sum of values |
| `Average` | Arithmetic mean |
| `Min` | Minimum |
| `Max` | Maximum |
| `90thPercentile` | P90 |
| `95thPercentile` | P95 |
| `99thPercentile` | P99 |
| `99.9thPercentile` | P99.9 |
| `99.99thPercentile` | P99.99 |

> **Warning**: These are NOT the same strings used by KQL-M or Grafana Geneva panels.
> See `kqlm-query-patterns.md` for KQL-M casing and the Grafana skill's
> `panel-targets.md` for Grafana casing.

---

## `metrics_read_multi_time_series` Reliability

This tool is unreliable — it frequently returns generic errors with no diagnostic
details. **Prefer `metrics_read_time_series`** (single series, always works) or
`metrics_kqlm_query` (for accounts with simple dimension names).

---

## Working with Dotted Dimension Names

Many Geneva metrics use dotted dimension names like `kepi.dc.name`,
`app.kubernetes.io.instance`, `node.name`. These **cannot be filtered in KQL-M
`where` clauses**.

**Workaround — use `metrics_read_time_series` with dimension path syntax:**

```
metrics_read_time_series(
  monitoringAccount = "<account>",
  metricNamespace   = "<namespace>",
  metric            = "<metric_name>",
  samplingType      = "Average",
  dimensions        = "kepi.dc.name/PRD-WUS2/name/GET",
  from              = "<ISO-8601 start>",
  to                = "<ISO-8601 end>"
)
```

Dimension path format: `dimension1/value1/dimension2/value2/...`

Returns a flat array of values at 1-minute resolution. Map to timestamps using
the `from`/`to` range.

**When KQL-M DOES work**: for accounts with simple (non-dotted) dimension names
(e.g. `azurecacheacct` with `Name`, `ShardId`, `Region`), KQL-M is the best
tool for aggregation, top-N, and cross-metric joins.

---

## Epoch Timestamp Quick Reference

Geneva tools use Unix epoch **milliseconds**. Common conversion:

```
# PowerShell
[DateTimeOffset]::Parse("<ISO-8601 datetime>").ToUnixTimeMilliseconds()

# Python
import datetime
int(datetime.datetime(<year>, <month>, <day>, <hour>, 0, 0, tzinfo=datetime.timezone.utc).timestamp() * 1000)
```

> **Double-check the year.** Getting 2025 instead of 2026 returns data from the wrong
> period with no error.
