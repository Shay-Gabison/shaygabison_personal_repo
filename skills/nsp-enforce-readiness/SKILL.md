---
name: nsp-enforce-readiness
description: Use this skill when the user wants to know whether a Network Security Perimeter (NSP) resource association can be safely moved from Transition (Learning) mode to Enforced mode without blocking any service — e.g. when they say "enforce", "enforced mode", "transition mode", "learning mode", "NSP readiness", "NS2.2.1", or "can I enforce this NSP". It implements the SFI NS2.2.1 pre-flight checks from the official NSP TSG (https://aka.ms/ns221tsg) using equivalent logic to the Traffic Analysis Tool: by default against the aggregated `AccessLogsWithSTag` table (all RPs pre-unioned, 90-day retention), with per-RP raw logs (Storage / Cosmos / SQL / Key Vault) as a live-site/fresh fallback. Do NOT use it for creating NSPs, associating resources, or rule authoring — those are separate flows.
---

# NSP Enforce-Readiness Skill (Kusto-only)

## Goal

Given an NSP ARM ID, produce a **PASS / FAIL verdict per resource** answering: *"If I flip this resource's association from Transition → Enforced right now, will any traffic be denied?"*

**Scope constraint:** This skill operates **purely from NSP access logs in Kusto**. It does NOT call ARM, `az rest`, or any management plane API — assume the operator has no `Microsoft.Network/networkSecurityPerimeters/*/read` permissions. Everything is inferred from the logs the Traffic Analysis Tool already consumes.

Reference docs:
- TSG overview: https://aka.ms/ns221tsg
- Enforced mode: https://aka.ms/ns221enforced
- Logging: https://aka.ms/ns221logging
- Traffic Analysis Tool: https://aka.ms/NSPTrafficAnalysis (dashboard `0799d844-3039-4736-9d1a-9daab2aff826`)

---

## The single rule that matters

> **Any traffic currently allowed by the underlying PaaS resource rules (Storage firewall / KV firewall / SQL firewall / Cosmos firewall) will be DENIED the moment the association flips to Enforced — unless an equivalent NSP access rule exists.**

A resource is **NOT safe** to enforce if its access logs in the lookup window contain ANY events with category:
- `NspPublicInboundResourceRulesAllowed` *(inbound traffic only the PaaS firewall is currently allowing)*
- `NspPublicOutboundResourceRulesAllowed` *(outbound traffic only the PaaS firewall is currently allowing)*

Every other category is informational. If those two are empty across a window **fully covered by retention** (≥7 days recommended; see the retention table before going beyond it), the resource shows **no blockers in the available logs** — which is the readiness signal, subject to the caveats section.

---

## Required inputs

| Input | Example | Notes |
|---|---|---|
| **NSP ARM ID** | `/subscriptions/40d8…/resourceGroups/…/providers/Microsoft.Network/networkSecurityPerimeters/<name>` | Required. Lower-cased before comparison. |
| **Lookup window** | `7d` (default). Longer windows (`30d`/`90d`) MUST use the aggregated `AccessLogsWithSTag` table — see retention table. | KQL `timespan`. |

If the user only provides a Traffic Analysis dashboard URL, parse `p-_nspArmId` from the query string.

---

## Data source: aggregated table (primary) vs per-RP raw (fresh/live-site)

This skill has **two** data-source modes. Choose based on how recent the traffic of interest is:

| Mode | Source | When to use |
|---|---|---|
| **Aggregated (default)** | Table `AccessLogsWithSTag` — cluster `nsp-logs-summary.eastus`, db `NspAggregatedLogs` | Default for all windows, especially `>7d`. All 4 RPs pre-unioned; **90-day retention**; ships `ServiceTagMatches` + `GetServiceTagPriority` built in (no manual Service-Tag lookup / Step 6 needed). Trade-off: ~9h ingestion delay. |
| **Per-RP raw (fallback)** | The per-RP clusters in the routing table below | Live-site / "did it stop in the last few hours" checks where the ~9h aggregation delay is unacceptable. **Subject to per-RP retention limits — see the retention table.** |

Because `AccessLogsWithSTag` is a single pre-unioned table, the aggregated path lets you drop the KV 3-cluster union, the Storage inbound/outbound union, the `SourceIP`/`SourceIp` coalesce, and all of Step 6. Substitute `cluster('nsp-logs-summary.eastus').database('NspAggregatedLogs').AccessLogsWithSTag` for `<RP_LOG_SOURCE>` in the workflow queries below and drop the per-RP fan-out.

> **The "equivalent logic" claim, precisely:** the verdict rule (Step 2) and the dashboard tile mapping are the same as the Traffic Analysis Tool. The canonical tool queries run against `AccessLogsWithSTag`; the per-RP raw queries below reproduce the same logic against the raw logs and are **not** byte-identical to the tool's KQL.

---

## Per-RP cluster routing

Run via an **MCP-compatible Kusto/ADX query tool**. Database connection can be **any** cluster the user has access to (e.g., `Geneva`) — all queries use **explicit cross-cluster references** so they work regardless of the connected database.

| RP | Cluster(s) | Database | Table | SourceIP column |
|---|---|---|---|---|
| `Microsoft.KeyVault/vaults` | `nsp-access-logs-eus.eastus`, `nsp-access-logs-sea.southeastasia`, `nsp-access-logs-weu.westeurope` *(union all 3)* | `NspAccessLogs` | `KeyVaultNspAccessLogsNspAuditLogsKeyVault` | `SourceIp` |
| `Microsoft.Storage/storageAccounts` | `argwusarrone.westus.kusto.windows.net` *(or 17 azcore* regions)* | `XStore` | `ShoeboxNetworkSecurityPerimeterInboundEvent` **and** `ShoeboxNetworkSecurityPerimeterOutboundEvent` *(union both — see Storage note)* | `SourceIP` |
| `Microsoft.DocumentDB/databaseAccounts` | `cdbsecurity.eastus2.kusto.windows.net` | `NspAccessLogs` | `NspAccessLogs` | `SourceIP` |
| `Microsoft.Sql/servers` | `sqlazuresecurity.westus3.kusto.windows.net` | `sqlsecurity` | `NspAccessLogs` | `SourceIP` |

> **Storage note:** `ShoeboxNetworkSecurityPerimeterInboundEvent` only carries inbound flows. Outbound blockers (`NspPublicOutboundResourceRulesAllowed`) and outbound `DestinationFQDN` coverage live in `ShoeboxNetworkSecurityPerimeterOutboundEvent`. For Storage, set `<RP_LOG_SOURCE>` to a `union isfuzzy=true` of the inbound + outbound tables — querying inbound alone can produce a false ✅ READY verdict for outbound traffic.

> **Column-name note:** Query templates below assume a `SourceIP` column. KeyVault logs use `SourceIp` (lowercase `p`). Every template normalizes this with `coalesce(column_ifexists("SourceIP",""), column_ifexists("SourceIp",""))` so the shared queries work across all 4 RPs.

**Out of scope (no Traffic Analysis support):** EventHub, Synapse, AKS, App Service, etc. If logs show those resource types associated, list them under "Cannot evaluate — no log coverage" and tell the user to verify them manually.

### ⚠️ Per-RP raw retention — window must not exceed retention

Raw per-RP logs have **different retention**. A window longer than a RP's retention **silently returns truncated data**, turning "no blockers" into a **false ✅ PASS**:

| RP | Raw retention |
|---|---|
| `Microsoft.DocumentDB/databaseAccounts` (Cosmos) | **7 days** |
| `Microsoft.KeyVault/vaults` | 30 days |
| `Microsoft.Storage/storageAccounts` | 60 days |
| `Microsoft.Sql/servers` | 365 days |
| **Aggregated `AccessLogsWithSTag`** | **90 days** |

Rules:
- If `window > RP raw retention`, either (a) run that RP on the aggregated `AccessLogsWithSTag` table (90d), or (b) clamp the window to the RP's retention **and report the truncation explicitly** in the output (never present a truncated result as a clean PASS).
- **Cosmos on raw logs is capped at 7d.** Any window `>7d` for Cosmos MUST use the aggregated table; otherwise flag Cosmos as "Unevaluated — window exceeds 7d raw retention".

---

## Workflow

### Step 0 — Initial sniff (always run first)

For each of the 4 RPs, run this `count() by LogCategory` filtered by `tolower(ResourceId) == _nspArmId` over the window (substitute `<RP_LOG_SOURCE>` per the routing table, or the aggregated table):

```kql
let _nspArmId = tolower("<NSP_ARM_ID>");
let _startTime = ago(<WINDOW>);
let _endTime = now();
<RP_LOG_SOURCE>
| where TimeGenerated between (_startTime .. _endTime)
| where tolower(ResourceId) == _nspArmId
| summarize Events=count(), LastSeen=max(TimeGenerated) by LogCategory
| order by Events desc
```

Three outcomes per RP:

| Result | Meaning | Action |
|---|---|---|
| Query fails (cluster/db/table not found, or access denied) | RP could **not** be evaluated (query unavailable) — does **NOT** imply the RP has no associations | Mark the RP as "Unevaluated / query unavailable" in the report; do not assume readiness for it |
| 0 rows | Either no associations of this RP, OR no traffic, OR logging not enabled for this RP | Note "No data" |
| ≥1 row | Logging is enabled and traffic was observed | Continue with deep queries |

This single query proves logging is enabled (per-RP) without needing ARM access.

> **KeyVault caveat:** KV access logs are emitted **even when NSP logging is disabled**, across all categories (`ns22TrafficAnalysisTool.md`). So for `Microsoft.KeyVault/vaults` the generic "0 rows = logging off OR no traffic" interpretation does **not** hold — a KV RP with rows does not prove NSP logging is on, and the absence of `…ResourceRulesAllowed` for KV must be read together with the perimeter categories. Do not infer KV logging state from this sniff.

### Step 1 — Discover associated resources from logs

For each RP that returned data, derive the set of associated PaaS resources:

```kql
let _nspArmId = tolower("<NSP_ARM_ID>");
let _startTime = ago(<WINDOW>);
let _endTime = now();
<RP_LOG_SOURCE>
| where TimeGenerated between (_startTime .. _endTime)
| where tolower(ResourceId) == _nspArmId
| summarize Hits=count(), LastSeen=max(TimeGenerated), Categories=make_set(LogCategory) by PaaSResourceId
| order by Hits desc
```

This is your "what's actually associated and active" inventory — derived purely from logs.

> Note: A resource that has been silent for the whole window will not appear here. Combine with the user-stated context if needed; otherwise call this out in the report ("evaluation only covers resources with traffic in the window").

### Step 2 — The blocker query (Query #1, MUST return 0 rows per resource)

```kql
let _nspArmId = tolower("<NSP_ARM_ID>");
let _startTime = ago(<WINDOW>);
let _endTime = now();
let resourceRulesCategories = dynamic([
    "NspPublicInboundResourceRulesAllowed",
    "NspPublicOutboundResourceRulesAllowed"
]);
<RP_LOG_SOURCE>
| where TimeGenerated between (_startTime .. _endTime)
| where tolower(ResourceId) == _nspArmId
| extend SourceIP = coalesce(tostring(column_ifexists("SourceIP", "")), tostring(column_ifexists("SourceIp", "")))
| where LogCategory in (resourceRulesCategories)
| summarize Hits=count(), LastSeen=max(TimeGenerated)
    by SourceIP, PaaSResourceId, LogCategory, MatchedRuleName, NspProfile
| order by Hits desc
```

- **0 rows for a resource** → ✅ no traffic depends on PaaS-firewall fallthrough; safe to enforce that resource.
- **Non-zero for a resource** → ❌ **DO NOT ENFORCE**. Each row is traffic that will start being blocked. Group by `PaaSResourceId` and `SourceIP` to size the impact.

### Step 3 — Already-denied perimeter traffic (informational)

```kql
let _nspArmId = tolower("<NSP_ARM_ID>");
let _startTime = ago(<WINDOW>);
let _endTime = now();
let denyCategories = dynamic([
    "NspPublicInboundPerimeterRulesDenied",
    "NspPublicOutboundPerimeterRulesDenied",
    "NspPublicInboundResourceRulesDenied",
    "NspPublicOutboundResourceRulesDenied"
]);
<RP_LOG_SOURCE>
| where TimeGenerated between (_startTime .. _endTime)
| where tolower(ResourceId) == _nspArmId
| extend SourceIP = coalesce(tostring(column_ifexists("SourceIP", "")), tostring(column_ifexists("SourceIp", "")))
| where LogCategory in (denyCategories)
| summarize Hits=count(), LastSeen=max(TimeGenerated)
    by SourceIP, DestinationFQDN, PaaSResourceId, LogCategory, MatchedRuleName
| order by Hits desc
```

These are already being denied today — surface for triage, but **do not block enforcement on them**.

### Step 4 — Service Endpoint / SNAT-bypass detection

Rows with `SourceParameters contains "ServiceEndpoint"` (broad token — matches `ServiceEndpointIP` and related SE flows) and no matchable `SourceIP` cannot be matched by IP. **Critical:** SE traffic is only a problem if it's NOT yet covered by an NSP rule. Always group by `LogCategory` to distinguish:

| LogCategory of SE flow | Meaning | Action |
|---|---|---|
| `NspPublicInboundPerimeterRulesAllowed` | Already matched by an NSP rule (typically `MicrosoftPublicIPSpace` Service Tag). | ✅ Safe — no action. |
| `NspPublicInboundResourceRulesAllowed` | Only the PaaS firewall is letting it through. | ❌ **Will be denied** in Enforced. **Primary fix:** configure **Network Identifier** on the source per https://aka.ms/ns221serviceendpoint (Service Endpoint TSG). The `MicrosoftPublicIPSpace` Service Tag is **NON-COMPLIANT** (too broad) — offer it only as an explicit exception requiring Security sign-off, never as the default. |
| `NspPublicInboundPerimeterRulesDenied` / `…ResourceRulesDenied` | Already denied today. | Informational; not a blocker. |

```kql
let _nspArmId = tolower("<NSP_ARM_ID>");
let _startTime = ago(<WINDOW>);
let _endTime = now();
<RP_LOG_SOURCE>
| where TimeGenerated between (_startTime .. _endTime)
| where tolower(ResourceId) == _nspArmId
| extend SourceIP = coalesce(tostring(column_ifexists("SourceIP", "")), tostring(column_ifexists("SourceIp", "")))
| where SourceParameters contains "ServiceEndpoint"
| extend isSEVIP = iff(SourceIP == "", true, false)
| summarize SECount=count() by LogCategory, isSEVIP, MatchedRuleName, NspProfile, SourceResourceId, PaaSResourceId
| order by SECount desc
```

Only flag PaaSResourceIds where SE flows show up under `NspPublicInboundResourceRulesAllowed`. SE flows under `NspPublicInboundPerimeterRulesAllowed` are **already covered**.

### Step 5 — Outbound FQDN inventory (sizing)

```kql
let _nspArmId = tolower("<NSP_ARM_ID>");
let _startTime = ago(<WINDOW>);
let _endTime = now();
<RP_LOG_SOURCE>
| where TimeGenerated between (_startTime .. _endTime)
| where tolower(ResourceId) == _nspArmId
| where LogCategory has "Outbound"
| where DestinationFQDN != ""
| summarize FQDNs = make_set(trim_end("/", DestinationFQDN)), Hits=count() by NspProfile, PaaSResourceId
| extend FQDNCount = array_length(FQDNs),
         Recommendation = iff(array_length(FQDNs) > 200, "Use '*' rule (>200 distinct FQDNs)", "Allowlist these FQDNs explicitly")
```

Useful when the user is preparing outbound rules.

> **Storage:** `<RP_LOG_SOURCE>` must include `ShoeboxNetworkSecurityPerimeterOutboundEvent` (see the Storage note in the routing table) — the inbound-only table carries no `DestinationFQDN`, so querying it alone yields empty outbound coverage rather than an evaluated result.

### Step 6 — Service Tag suggestion (only when Step 2 returned blockers)

For every distinct `SourceIP` from Step 2, look up Service Tags. `ServiceTagsMapping` lives in the same per-RP NSP access-log database — use the **same cluster(s)** you used for that RP in Step 2. For KeyVault, that means a `union` across all three regional clusters (matching the routing table), not a single cluster:

```kql
let blockerIPs = dynamic([<comma-separated-IPs-from-Step-2>]);
// Single-cluster RPs (Storage / Cosmos / SQL):
cluster('<RP_CLUSTER>').database('<RP_DB>').ServiceTagsMapping
| where IPAddress in (blockerIPs)
| summarize Tags = make_set(TagName) by IPAddress
```

```kql
// KeyVault — union the same 3 regional ServiceTagsMapping tables used in Step 2:
let blockerIPs = dynamic([<comma-separated-IPs-from-Step-2>]);
union
    cluster('nsp-access-logs-eus.eastus').database('NspAccessLogs').ServiceTagsMapping,
    cluster('nsp-access-logs-sea.southeastasia').database('NspAccessLogs').ServiceTagsMapping,
    cluster('nsp-access-logs-weu.westeurope').database('NspAccessLogs').ServiceTagsMapping
| where IPAddress in (blockerIPs)
| summarize Tags = make_set(TagName) by IPAddress
```

- IP matched to a Service Tag → recommend an inbound `serviceTags` rule with that tag.
- IP matched to a Service Tag → recommend an inbound `serviceTags` rule with that specific (narrow) tag.
- IP has no Service Tag → recommend Security review.
- **`MicrosoftPublicIPSpace` and other broad AzureCloud-prefixed tags are NON-COMPLIANT** — do NOT recommend them as a normal fix. Prefer **Network Identifier** (Service Endpoint TSG, https://aka.ms/ns221serviceendpoint) as the primary remediation; surface the broad tag only as an explicit exception that requires Security sign-off.
- IP-prefix and subscription rules are flagged non-compliant unless an exception exists.

---

## SQL-specific guardrails (when `Microsoft.Sql/servers` resources exist)

These are well-known outage scenarios from the TSG. Surface them as **⚠️ MUST verify** even if the resource shows 0 blockers from Step 2:

1. **Outbound `*` FQDN rule is mandatory.** ARM SQL DB Copy / Geo-Replication / GeoRestore / LTR Restore / Import-Export / Fabric Mirroring lack NSP coverage. An FQDN-only outbound rule will break these.
2. **Inbound `Sql` and `SqlManagement` service tags are mandatory.**
3. **Geo-DR**: rules must exist on **both** primary and secondary NSP profiles.

You cannot verify the rules from logs alone — **explicitly tell the user to confirm these themselves** before enforcing any SQL resource.

---

## Output format (always produce this)

```
NSP Enforce-Readiness Report (Kusto-only)
==========================================
NSP: <armId>
Window: <window>
Generated: <UTC timestamp>
Method: NSP access logs only — no ARM/management-plane queries

Logging signal (Step 0)
-----------------------
| RP        | Logs in window? | Categories observed                                  |
|-----------|-----------------|------------------------------------------------------|
| KeyVault  | Yes (N events)  | NspPublicInboundPerimeterRulesAllowed, …             |
| Storage   | No data         | (logging may be off, no traffic, or no associations) |
| Cosmos    | …               | …                                                    |
| SQL       | …               | …                                                    |

Resources observed in window (Step 1)
-------------------------------------
| PaaSResourceId | RP | Hits | LastSeen | Categories observed |
| …              | …  | …    | …        | …                   |

Per-resource verdict
--------------------
| PaaSResourceId | Blocker rows (Step 2) | SE traffic (Step 4) | Verdict                              |
|----------------|-----------------------|---------------------|--------------------------------------|
| <kv-A>         | 0                     | 0                   | ✅ READY (subject to SQL caveats)    |
| <kv-B>         | 12                    | 0                   | ❌ NOT READY — see blocker table     |
| <storage-X>    | 0                     | 5                   | ⚠️ NEEDS Network Identifier          |

Blockers (Step 2 — would be denied in Enforced mode)
----------------------------------------------------
| PaaSResource | SourceIP       | Hits | LastSeen | LogCategory | Suggested rule (Step 6)              |
| …            | …              | …    | …        | …           | ServiceTag: <Tag> / Investigate IP    |

Already-denied (Step 3 — informational)
---------------------------------------
| PaaSResource | SourceIP | LogCategory | Hits | LastSeen |
| …            | …        | …           | …    | …        |

Outbound FQDN coverage (Step 5)
-------------------------------
| PaaSResource | FQDNCount | Recommendation |
| …            | …         | …              |

Caveats / things this report cannot verify
------------------------------------------
- Resources with zero traffic in the window will not appear at all. If you know a resource is associated and silent, exercise it before enforcing.
- Verdicts mean "no blockers observed in available logs," not an unconditional guarantee — valid only when logging is enabled, the query succeeded, and retention fully covers the window. Any RP whose window exceeded raw retention (esp. Cosmos >7d on raw) is reported as truncated/Unevaluated, never as a clean PASS.
- Profile access rules are NOT inspected (no ARM access). Verify ServiceTag inbound and FQDN outbound rules cover what Step 5 / Step 6 recommend.
- For SQL resources: confirm outbound `*` FQDN rule, inbound `Sql` + `SqlManagement` tags, and Geo-DR primary+secondary parity.
- EventHub / Synapse / AKS / App Service associations are out of Traffic Analysis Tool scope.

Recommended next steps
----------------------
1. <e.g., Add inbound ServiceTag rule for AzureMonitor on profile <…>>
2. <e.g., Add Network Identifier for storage-X>
3. Re-run this skill after rules are deployed and ≥24h of fresh logs accumulate.
4. Promote via R2D — see Change Management in https://aka.ms/ns221enforced.
```

---

## Operating workflow (what the agent does)

1. Parse inputs — NSP ARM ID, window (default `7d`).
2. **Step 0** sniff: run `count() by LogCategory` against all 4 RP clusters in parallel via the configured Kusto/ADX query tool. Use any database the agent is connected to (e.g., `Geneva`); the queries themselves use cross-cluster `cluster('…').database('…').<Table>` references.
3. For RPs with data, run **Step 1** (discover resources) and **Step 2** (blockers) in parallel.
4. For RPs whose Step 2 returned blockers, run **Step 6** (Service Tag suggestion) for the unique source IPs (chunk at 1000 IPs).
5. Run **Step 3** (already-denied) and **Step 4** (SE traffic) and **Step 5** (FQDN inventory) for context.
6. If any resource is `Microsoft.Sql/servers`, append the **SQL guardrails** block.
7. Assemble the report. **Always** include the caveats section and the link to https://aka.ms/ns221enforced.

---

## Things to NOT do

- **Do not** call `az rest` / ARM at all. The skill operates entirely from Kusto. If the user wants ARM-side validation (current accessMode, profile rule contents), tell them to run the queries themselves or use the dashboard UI.
- **Do not** flip the association mode. Promotion is gated by R2D / SDP — say so in the report.
- **Do not** suggest IP-prefix or subscription-based inbound rules as the default. ServiceTag is the only compliant default.
- **Do not** pull from Azure Monitor diagnostic settings — Traffic Analysis Tool only consumes 1P Kusto logs.

---

## Reference: dashboard tile → query mapping

If the user opens the Traffic Analysis dashboard, these are the tiles whose verdicts this skill replicates:

- *"Traffic allowed by Resource rules"* → **Step 2** (THE blocker)
- *"Traffic Denied by NSP"* / *"Traffic Denied by Resource rules"* → **Step 3**
- *"[Inbound] Microsoft Traffic - Service Tag Recommendation"* → **Step 6**
- *"Analysis of Service Endpoint Traffic"* → **Step 4**
- *"Outbound Traffic Recommendation"* → **Step 5**

**Dashboard raw-KQL source-of-truth:** the canonical dashboard KQL can be inspected
manually — see [docs/reference.md](docs/reference.md). That doc holds the (ARM/management-plane)
download command, kept out of this skill body so the agent never runs it.
