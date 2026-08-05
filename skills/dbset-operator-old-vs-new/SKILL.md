---
name: dbset-operator-old-vs-new
description: "Compare the OLD dbset-operator instance (rs-2-data-stage-aks, Flux, Kusto table `data`) against the NEW one (mps-mda-core-k8s-stg-weu-106, Ev2, Kusto table `dbsetoperator`). Categorizes ERROR logs from both with one shared taxonomy and produces a parity report: which errors are NEW-only (regressions to fix), OLD-only (removed/fixed), or BOTH (shared/environmental). Bottom line = we want the NEW instance to behave the same as the OLD one. Use when the user says 'compare old vs new dbset-operator', 'dbset parity', 'what errors are new vs old', 'did the migration regress', or wants an old/new error diff for the dbset-operator migration."
domain: "infrastructure"
confidence: "high"
---

<!--
═══════════════════════════════════════════════════════════════════════════════
  HUMANS: read this top section to use. Everything below the "Agent contract"
  divider is the agent's contract.
═══════════════════════════════════════════════════════════════════════════════
-->

# dbset-operator — OLD vs NEW error parity

The dbset-operator was **migrated** from the standalone data cluster
`rs-2-data-stage-aks` (deployed by **Flux**, from repo `data-flux`) onto the shared
core cluster `mps-mda-core-k8s-stg-weu-106` (deployed by **Ev2/OneBranch**, from repo
`data-dbset-operator`). This is the MMA "consolidated dbset-operator" cutover.

Both ship logs to the **same Geneva account** (`McasDataRSEUW`) on the **same Kusto
cluster/db**, but into **different tables** because they get different routing keys.
That is the whole reason this comparison is tricky — you must query two tables with
two different log shapes.

**Goal of this skill:** produce a side-by-side error comparison and a **parity
verdict** — we want the NEW instance to behave the *same* as the OLD one, so any
error category that appears **NEW-only** is a migration **regression** to fix.

## Install (one command)

```bash
mkdir -p ~/.copilot/skills/dbset-operator-old-vs-new
mv SKILL.md ~/.copilot/skills/dbset-operator-old-vs-new/SKILL.md
```

## Use it

Trigger phrases:

> *"Compare old vs new dbset-operator errors"*
> *"dbset parity check"* / *"did the migration regress?"*
> *"What errors are in the new instance that weren't in the old?"*
> *"Diff the rs-2 flux instance against the 106 Ev2 instance"*

The agent will:
1. Query the **OLD** instance (table `data`, parse the `log` column) and the **NEW**
   instance (table `dbsetoperator`, use `level`/`msg`/`error`) over the chosen window.
2. Categorize both with **one shared taxonomy**.
3. Print a comparison table + a **parity verdict**: NEW-only (🔴 regression),
   OLD-only (🟢 gone), BOTH (🟠 shared/environmental).
4. Optionally export a `dbset_old_vs_new_comparison.txt` to the Desktop.

Prereqs the agent checks: the `GenevaMonitoringMCP-kusto_execute_query` tool (find it
via `tool_search_tool_regex` if not already surfaced) and cached Geneva auth.

## Recommended mode: PINNED-DAY steady-state comparison (preferred)

Do NOT compare the two instances over the same overlapping window — that window
includes the migration cutover churn (rollout restarts, graceful-shutdown
`context canceled`, vcore 409 storms) and is misleading. Instead, pick **one
representative full day for each instance**:

- **OLD** = a day it was in **steady-state pre-cutover** (default `2026-06-20`).
- **NEW** = a **recent day after the migration finished** (migration completed
  ~2026-06-30, so default NEW = `2026-06-30`, or the latest full day available).

Rationale (from the user): "in 30.6 we finished the migration to the new cluster, so
compare the newest NEW against a clean OLD day (20.6) — least-noisy old vs newest new."

Use `PreciseTimeStamp between (datetime(<day>) .. datetime(<day+1>))` for each side.
Ask the user for the two dates; default to OLD=2026-06-20, NEW=2026-06-30.

## Caveat: OLD logs age out

The OLD instance was **scaled to 0 at the cutover (last log 2026-06-25 06:36:57Z)**.
Kusto retention is only ~21 days, so the OLD logs **age out ~mid-July 2026**. If the
OLD pinned day returns 0 rows, its logs are gone — say so and rely on the historical
export (Step 5) if one was saved. Always offer to export so the OLD baseline is
preserved before it disappears.

<!--
═══════════════════════════════════════════════════════════════════════════════
                              AGENT CONTRACT
═══════════════════════════════════════════════════════════════════════════════
-->

---

## Constants (verified 2026-07-01)

```
KUSTO_CLUSTER = https://mcasge00euw1pxynv.westeurope.kusto.windows.net
DATABASE      = data
GENEVA_ACCT   = McasDataRSEUW  (moniker mcasdatarseuwdiagweu)  [same for both]

OLD  (pre-migration, being retired)
  instance     = rs-2-data-stage-aks
  deployed_by  = Flux (helm.toolkit.fluxcd.io) — repo `data-flux`
  container    = manager        namespace = data / default
  nodes        = aks-usernpfips-*
  TABLE        = data           <-- generic catch-all container-log table
  LOG SHAPE    = console/tab text inside the `log` column.
                 level/msg/error columns are EMPTY. Parse `log`.
  MSI objid    = 04a0e466-8571-4940-885b-0cf307d7b1e8  (client 29f1fa3e-64a4-47f2-9a0c-56a9b625578b)
  image        = mcasdatacr.azurecr.io/data-dbset-operator (chart 1.4.x)
  status       = SCALED TO 0 at cutover; last log ~2026-06-25 06:36:57Z

NEW  (consolidated, live)
  instance     = mps-mda-core-k8s-stg-weu-106
  deployed_by  = Ev2 / OneBranch — repo `data-dbset-operator`
  container    = wdatp-service  namespace = mda-data-services
  nodes        = aks-weu106*
  TABLE        = dbsetoperator
  LOG SHAPE    = structured JSON -> use tostring(msg) and tostring(error).
                 (message column is usually EMPTY; the detail is in msg + error.)
  MSI objid    = da6217e1-8af7-47e5-beef-7aba9bcae4c7  (client f17e723c-b828-4e7f-9902-66c4ba342036)
  status       = LIVE

Both PodNames start with "dbset-operator-controller-manager-" — do NOT use PodName to
distinguish them; use the TABLE (and namespace/nodes) instead.
```

## Shared error taxonomy

Apply the SAME `case()` to both instances. The only difference is the source text:
- OLD:  `text = tostring(log)`
- NEW:  `text = strcat(tostring(msg), " || ", tostring(error))`

```
category                     match (case-insensitive substrings, first match wins)
---------------------------  ---------------------------------------------------------
A_fail_to_find_cluster       "fail to find cluster" or "Cluster_0 not found" or "cluster ... not found"
B_vcore_update_in_progress   "already in progress"
C_403_listConnectionStrings  "listConnectionStrings" and ("403" or "AuthorizationFailed")
D_mongo_ctx_deadline         "context deadline exceeded" (connection pool checkout)
E_mongo_server_selection     "server selection error" or "server selection"
F_vcore_nil                  "vCoreProperties" (cannot be nil)
G_no_documents               "no documents"
H_json_unmarshal             "invalid character" or "unmarshal"
R_redis_secret               "failed to create redis secret" or "redis ARM"
M_mapping_update             "failed to update mapping entries" or "collectionmappingentry"
X_reconciler_error           "Reconciler error"  (generic requeue wrapper)
L_leader_election            "leader election" or "stop sequence was engaged"
Z_other                      everything else (bucket first ~70 chars for triage)
```

Notes:
- Filter to ERROR only:
  - OLD:  `where tostring(log) has "ERROR"` then `body = split(log,"ERROR")[1]`
  - NEW:  `where tostring(level) has "error" or isnotempty(tostring(error))`
- Many OLD errors come from **deliberately-bad TEST CRs** (`redisentry-bad-cluster`,
  `redisentry-bad-tm-not-found`, `mma-tester`, `round5-*-cm-error-*`,
  `bogus-source-not-in-kv`). Flag these as test-fixtures, not real problems.

## Step 1 — OLD instance categorization (table `data`)

Preferred: pin to a clean pre-cutover day (default 2026-06-20). Replace the `between`
line with `| where PreciseTimeStamp > ago(21d)` only if you deliberately want the whole
window.

```kusto
database('data').['data']
| where PreciseTimeStamp between (datetime(2026-06-20) .. datetime(2026-06-21))  // OLD pinned day
| where PodName has "dbset-operator-controller-manager"
| extend L = tostring(log)
| where L has "ERROR"
| extend body = tostring(split(L, "ERROR")[1])
| extend cat = case(
    body has "fail to find cluster" or body has "not found" and body has "cluster", "A_fail_to_find_cluster",
    body has "already in progress", "B_vcore_update_in_progress",
    body has "listConnectionStrings" and (body has "403" or body has "AuthorizationFailed"), "C_403_listConnectionStrings",
    body has "context deadline exceeded", "D_mongo_ctx_deadline",
    body has "server selection", "E_mongo_server_selection",
    body has "vCoreProperties", "F_vcore_nil",
    body has "no documents", "G_no_documents",
    body has "invalid character" or body has "unmarshal", "H_json_unmarshal",
    body has "failed to create redis secret" or body has "redis ARM", "R_redis_secret",
    body has "failed to update mapping entries" or body has "collectionmappingentry", "M_mapping_update",
    body has "Reconciler error", "X_reconciler_error",
    body has "leader election" or body has "stop sequence was engaged", "L_leader_election",
    "Z_other")
| summarize cnt=count(), firstSeen=min(PreciseTimeStamp), lastSeen=max(PreciseTimeStamp) by cat
| order by cnt desc
```

## Step 2 — NEW instance categorization (table `dbsetoperator`)

Preferred: pin to a recent post-migration day (default 2026-06-30 or latest full day).

```kusto
database('data').table('dbsetoperator')
| where PreciseTimeStamp between (datetime(2026-06-30) .. datetime(2026-07-01))  // NEW pinned day
| extend m = tostring(msg), e = tostring(error)
| where tostring(level) has "error" or isnotempty(e)
| extend body = strcat(m, " || ", e)
| extend cat = case(
    body has "fail to find cluster" or (body has "not found" and body has "cluster"), "A_fail_to_find_cluster",
    body has "already in progress", "B_vcore_update_in_progress",
    body has "listConnectionStrings" and (body has "403" or body has "AuthorizationFailed"), "C_403_listConnectionStrings",
    body has "context deadline exceeded", "D_mongo_ctx_deadline",
    body has "server selection", "E_mongo_server_selection",
    body has "vCoreProperties", "F_vcore_nil",
    body has "no documents", "G_no_documents",
    body has "invalid character" or body has "unmarshal", "H_json_unmarshal",
    body has "failed to create redis secret" or body has "redis ARM", "R_redis_secret",
    body has "failed to update mapping entries" or body has "collectionmappingentry", "M_mapping_update",
    body has "Reconciler error", "X_reconciler_error",
    body has "leader election" or body has "stop sequence was engaged", "L_leader_election",
    "Z_other")
| summarize cnt=count(), firstSeen=min(PreciseTimeStamp), lastSeen=max(PreciseTimeStamp) by cat
| order by cnt desc
```

## Step 3 — per-category drill-down (run for any category of interest)

Get a representative sample line + the driving CRs / targets. Example for the 403 gap:

```kusto
// NEW (table dbsetoperator)
database('data').table('dbsetoperator')
| where PreciseTimeStamp > ago(21d)
| extend e = tostring(error)
| where e has "listConnectionStrings" and e has "403"
| extend acct = extract(@"databaseAccounts/([a-z0-9-]+)/listConnectionStrings", 1, e)
| extend rg   = extract(@"resourceGroups/([A-Za-z0-9-]+)/providers", 1, e)
| extend objid= extract(@"object id '([0-9a-f-]+)'", 1, e)
| extend cr   = tostring(CosmosTargetEntry)
| summarize cnt=count(), lastSeen=max(PreciseTimeStamp) by cr, acct, rg, objid
| order by cnt desc
```
For OLD, use table `data`, `extend L=tostring(log)` and the same regexes against `L`.

## Step 4 — diff + parity verdict

Build the union of category keys from Step 1 and Step 2, then classify each:

```
NEW-only  (cnt_old == 0 && cnt_new > 0)   -> 🔴 REGRESSION  (introduced by the new build)
OLD-only  (cnt_old > 0  && cnt_new == 0)  -> 🟢 GONE        (removed/fixed, or test-only)
BOTH      (both > 0)                      -> 🟠 SHARED      (environmental / RBAC / backend)
```

Emit a table sorted with 🔴 first (they are the parity gap), then 🟠, then 🟢:

```
| category | OLD cnt | NEW cnt | first/last (new) | verdict |
```

Then a **BOTTOM LINE — PARITY** block:
- List every 🔴 NEW-only category as an explicit regression the migration introduced,
  with its top driving CR(s) from Step 3.
- List 🟠 shared items as pre-existing environmental issues (not caused by migration)
  — note different MSIs mean RBAC grants must be re-applied to the NEW identity
  (`da6217e1-…`) even for shared 403s.
- State the goal plainly: *to reach parity, the NEW instance should show only the 🟠
  shared set (or fewer); every 🔴 must be driven to zero.*

### Known baseline — PINNED DAYS (OLD 2026-06-20 vs NEW 2026-06-30) — sanity check

```
category                       OLD 20.6   NEW 30.6    verdict
A_fail_to_find_cluster             20        783       🟠 shared, 39x WORSE (Cluster_0: dbset-1-mongodb-files/venturi/dataops-venturi)
D_mongo_ctx_deadline              134        265       🟠 shared, 2x worse (mongo pool)
C_403_listConnectionStrings        23        108       🟠 shared, ~5x worse (RBAC, NEW MSI da6217e1)
R_redis_secret                     22          0       🟢 improved / gone on NEW
G_no_documents                      0         88       🔴 NEW-only regression  ┐
M_mapping_update                    0         88       🔴 NEW-only regression  │ same cascade:
X_reconciler_error                  0         88       🔴 NEW-only regression  │ missing dbset entry
"failed to find dbset entry"        0         88       🔴 NEW-only regression  ┘ (e.g. dbset-1-pgmongo2)
F_vcore_nil                         0         81       🔴 NEW-only regression (vCore KV secret)
H_json_unmarshal                    0          4       🔴 NEW-only regression (bad JSON secret)
empty error-level rows              0        265       🔴 NEW-only noise
TOTAL errors/day                 ~199      ~1858       ~9x MORE on NEW
OLD still running?                 n/a (scaled to 0 at cutover 2026-06-25)
```
Interpretation: OLD steady-state was ~200 err/day across 4 benign categories. NEW is
~9x noisier across 9+ categories, with 6 brand-new categories AND the shared ones
2-39x worse. Parity = drive the 🔴 set to zero and bring A/D/C back to the OLD baseline.

### Verdict classification (note the third bucket)

```
NEW-only  (cnt_old == 0 && cnt_new > 0)              -> 🔴 REGRESSION (migration introduced it)
OLD-only  (cnt_old > 0  && cnt_new == 0)             -> 🟢 GONE (fixed/removed)
BOTH, NEW much higher (cnt_new >= 2x cnt_old)        -> 🟠 SHARED-WORSE (regressed in VOLUME)
BOTH, similar                                        -> 🟠 SHARED (environmental / RBAC / backend)
```

## Step 5 — export (optional, if user asked)

Write `~/Desktop/dbset_old_vs_new_comparison.txt` containing: the constants block, both
category tables, the diff table, per-🔴-category sample line + driving CRs, and the
PARITY bottom line. Keep it plain text (this user collects these on the Desktop).

## Gotchas / lessons baked in

- **Wrong table = empty result.** OLD logs are in `data`, NOT `dbsetoperator`.
- **Wrong field = empty result.** OLD detail is in `log` (console/tab); NEW detail is in
  `msg`+`error` (NOT `message`, which is empty).
- **`< ago(Nd)` returns OLDER-than-N**, i.e. usually nothing. Use `> ago(Nd)`.
- **Retention ~21 days.** OLD instance stopped 2026-06-25; it will fully age out ~mid-July
  2026. After that, OLD returns 0 and only a historical export (Step 5) preserves it —
  encourage the user to keep the txt.
- **Different MSIs.** OLD obj `04a0e466-…`, NEW obj `da6217e1-…`. Shared 403s need the
  grant applied to the NEW identity; the old grant does not carry over.
- **Tool discovery.** If `GenevaMonitoringMCP-kusto_execute_query` isn't visible, find it
  with `tool_search_tool_regex` pattern `kusto_execute_query` first.
- **Large outputs** from the MCP get saved to a temp file — parse with python3/grep.
