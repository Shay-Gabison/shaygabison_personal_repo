# KQL-M Query Patterns

> KQL-M is Geneva's server-side query language for pre-aggregated time series. It is
> **not** standard Kusto/KQL — it runs against MDM, not ADX.

---

## Sampling Types (KQL-M)

KQL-M uses **different casing** from the structured API:

| KQL-M syntax | Structured API equivalent |
|---|---|
| `'Sum'` | `Sum` |
| `'Average'` | `Average` |
| `'Count'` | `Count` |
| `'Min'` | `Min` |
| `'Max'` | `Max` |
| `'95th percentile'` | `95thPercentile` |
| `'99th percentile'` | `99thPercentile` |
| `'99.9th percentile'` | `99.9thPercentile` |
| `'99.99th percentile'` | `99.99thPercentile` |

> Aggregates are **Title Case** (`'Sum'`, `'Count'`). Percentiles are **lowercase with
> spaces** (`'99th percentile'`). Mixing them up returns empty data with no error.

---

## Query Templates

### Basic: single metric, single sampling type

```kqlm
metric('<metric_name>').samplingTypes('Count')
| where <dim> == '<value>'
```

### Top-N by a dimension

```kqlm
metric('<metric_name>').samplingTypes('Sum')
| summarize total = sum(value) by <dim>
| top 10 by total desc
```

### Breakdown by dimension over time

```kqlm
metric('<metric_name>').samplingTypes('Average')
| where <filter_dim> == '<value>'
| summarize avg_val = avg(value) by <breakdown_dim>, bin(timestamp, 5m)
```

### P99 latency with dimension filter

```kqlm
metric('<metric_name>').samplingTypes('99th percentile')
| where <dim> in ('<v1>', '<v2>')
| summarize p99 = avg(value) by <dim>, bin(timestamp, 1m)
| top 20 by p99 desc
```

### Cross-metric join

```kqlm
let errors = metric('error_count').samplingTypes('Sum')
  | where env == '<value>'
  | summarize err = sum(value) by bin(timestamp, 5m);
let total = metric('request_count').samplingTypes('Sum')
  | where env == '<value>'
  | summarize req = sum(value) by bin(timestamp, 5m);
errors
| join kind=inner total on timestamp
| project timestamp, error_rate = toreal(err) / toreal(req) * 100
```

### Zoom (resample)

```kqlm
metric('<metric_name>').samplingTypes('Count')
| zoom 15m sum
```

Changes the time bucket to 15 minutes, aggregating with `sum`.

### Tool call template

```
metrics_kqlm_query(
  monitoringAccount = "<account>",
  queryText         = "<kqlm query from above>",
  startTimeUtc      = "<ISO-8601 start>",
  endTimeUtc        = "<ISO-8601 end, ≥ 2 min before now>",
  metricNamespace   = "<namespace>"
)
```

---

## KQL-M Syntax Pitfalls

KQL-M is a restricted subset of KQL. Several standard KQL operators and patterns
silently fail or error in KQL-M. Always test with simple queries first.

### Operators that do NOT work in KQL-M

| ❌ Does NOT work | ✅ Use instead | Notes |
|---|---|---|
| `has`, `has_any`, `contains` | `==`, `startswith`, `in` | KQL-M only supports exact match, prefix, and set membership |
| Dotted dimension names in bare `where` (e.g. `kepi.dc.name == "X"`) | Use `metrics_read_time_series` with dimension path syntax | KQL-M parser chokes on `.` in identifiers outside `metric()` / `.dimensions()` / `.samplingTypes()` |
| Dotted metric names without quotes | `metric('http.server.requests')` | Must be single-quoted in `metric()` call — but dotted dims in `where` still fail |
