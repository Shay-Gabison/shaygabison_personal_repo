# gru flags

Queries against the gru / compliance event stream that lives in the
`compliance` database on the four MDA clusters (`prod-us`, `prod-eu`,
`prod-uk`, `staging-eu` — see
[`../well-known-clusters.md`](../well-known-clusters.md)).

`mhash == "881a5ba6"` filters for "Preparing to write" gru events. The
`message` field is text — flag name, tenant, ring, and value are extracted
with `extract(...)` regexes against it.

---

### `Find values of a gru flag per environment / tenant / ring`
**Cluster(s):** `prod-us`, `prod-eu`, `prod-uk`, `staging-eu`
**Database:** `compliance`

```kusto
union
    cluster("https://mcasge00euw1pxynv.westeurope.kusto.windows.net").database("compliance").compliance,
    cluster("https://mcasge00usw1pxrni.westus.kusto.windows.net").database("compliance").compliance,
    cluster("https://mcasge00euw1pxcqv.westeurope.kusto.windows.net").database("compliance").compliance,
    cluster("https://mcasge00uks1pxnci.uksouth.kusto.windows.net").database("compliance").compliance
| where PreciseTimeStamp > ago(1d)
| where mhash == "881a5ba6"
| where message contains "adallom.shared.cosmosdb.domains.enabled"
| extend key = extract("key=(.+)\\[", 1, message, typeof(string))
| extend tenantId = extract("tenantId=([0-9.]+)", 1, message, typeof(int))
| extend ring = extract("ring=([0-9.]+)", 1, message, typeof(int))
| extend lastUpdate = unixtime_milliseconds_todatetime(tolong(lastUpdateTime))
| distinct env, key, tenantId, ring, value, comment, lastUpdate
| order by env asc, tenantId asc, ring asc
```
