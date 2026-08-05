---
name: tgcompress-run
description: End-to-end workflow for running TGCompress in any prod ring. Covers triggering the Official Build (or reusing a recent one), queueing the Official Release with a chosen action + environment, posting the SDP release-approval ASK to Teams, and monitoring the planner output in Kusto. Use whenever the user says "run TGCompress on PROD-X", "trigger orphans cleanup", "kick off TGCompress dry-run", "compress PROD-2", or any variant that combines an action (full-orphans / contoso-full-orphans / Backup+Plan+Compress / Recover / etc.) with a target environment.
---

# TGCompress Run Skill

Owns the full lifecycle of a TGCompress invocation:

```
[optional] Official Build  →  Official Release (action + env)  →  Approval ASK  →  Kusto validation
```

## When to use

Trigger phrases:
- "run TGCompress on PROD-X"
- "trigger orphans cleanup / dry-run on PROD-Y"
- "kick off TGCompress <action> on <env>"
- "compress PROD-Z"
- "run contoso-full-orphans on prod-3"

Do NOT use for:
- Buddy builds (use ADO portal directly — buddy is per-branch and not standardized)
- Code changes to TGCompress (use normal PR flow + the `pr-review-template` skill)
- Engine health / right-sizing (use the kusto-* skills)

## Hard-coded IDs (verified working 2026-06-15)

ADO:
- **Organization:** `msazure`
- **Project:** `MCAS`
- **Repository:** `TenantService`
- **Official Build pipeline:** `429493` (`TGCompress.Job.Official.Build`)
- **Official Release pipeline:** `433104` (`TGCompress.Job.Official.Release`)
- **Default branch:** `refs/heads/main`

Teams:
- **Release-approval channel alias:** `release-approval`
  (team `MDA Platform Axon`, channel `19:8f0745dd34694e20b26ea7f108937c10@thread.tacv2`)
- Sender: `~/.copilot/skills/teams-sender/send-message.sh`
- Approval ASK template: `~/.copilot/skills/release-approval-template/SKILL.md`

Kusto (orchestration DB, `tgcompress` table — same shape on every cluster):

| Env | Region | Cluster URL |
|---|---|---|
| RS Primary | WEU | `https://mcasge00euw1pxynv.westeurope.kusto.windows.net` |
| RS DR | NEU | `https://mdasupportstgneu.northeurope.kusto.windows.net` |
| PROD-3 | WUS *(pipeline deploys to EUS2 cluster, logs route here)* | `https://mcasge00usw1pxrni.westus.kusto.windows.net` |
| PROD-4 | UKS | `https://mcasge00uks1pxnci.uksouth.kusto.windows.net` |
| PROD-2 | WEU | `https://mcasge00euw1pxcqv.westeurope.kusto.windows.net` |
| PROD-1 | — | *(ask user — not yet captured)* |
| PROD-5 / GOV / GCCM / GPRD | — | *(ask user — not yet captured)* |

## Release pipeline parameters (from `TGCompress/.pipelines/OneBranch.Job.Official.Release.yml`)

```yaml
parameters:
  - name: debug         # boolean, default false
  - name: action        # see list below
  - name: environment   # RS | GCCM | GPRD | PROD-1 | PROD-2 | PROD-3 | PROD-4 | PROD-5
```

### Allowed `action` values

| Action | Destructive? | Notes |
|---|---|---|
| `Backup + Plan` | No | Backup + generate plan, no compress |
| `Plan + Validate` | No | Generate + validate plan only (default) |
| `Recover` | **Yes** | Restore from prior backup |
| `Backup + Plan + Compress` | **Yes** | Full compress run — writes to prod |
| `dry-run` | No | Generic dry-run |
| `full-orphans-dry-run` | No | Plan orphan-cleanup moves only |
| `full-orphans` | **Yes** | Execute orphan-cleanup moves |
| `contoso-full-orphans-dry-run` | No | Contoso-tenant orphan plan only |
| `contoso-full-orphans` | **Yes** | Execute Contoso orphan moves |
| `sync_groups_tenants_counts` | **Yes** | Sync count metadata in CosmosDB |
| `Sleep` | No | Idle (smoke-test the pipeline) |

> **Destructive actions require explicit user confirmation in the chat before queueing** (see user memory: "Never trigger deployments, pipeline runs, releases, or merges without explicit user permission first").

## Workflow

### 1. Gather inputs

Ask the user (use `ask_user` form with enums):
- `action` — pick from the table above
- `environment` — `RS | PROD-1..5 | GCCM | GPRD | GOV`
- `headline` — one-line description for the approval ASK (auto-default to the action name + reason if user provides PR context)

### 2. Decide whether to rebuild

Query latest official build on `main`:

```python
ado-pipelines_build action=list project=MCAS definitions=[429493] top=5
# filter: sourceBranch == "refs/heads/main" AND status == "Completed" AND result == "Succeeded"
```

- If a successful build exists on `main` **within the last 24h** AND no new merges since → **reuse** that buildNumber, skip to step 4.
- Otherwise → **trigger** a new official build (step 3).

### 3. Trigger Official Build (when needed)

```python
ado-pipelines_write action=run_pipeline project=MCAS pipelineId=429493 \
  resources='{"repositories": {"self": {"refName": "refs/heads/main"}}}'
```

Save the returned `id` as `BUILD_ID`. Poll `ado-pipelines_build action=list buildIds=[BUILD_ID]` every 5 min via `manage_schedule` until `status=Completed`.

- If `result=Succeeded` → proceed to step 4.
- If `result=Failed/Canceled` → report to user, **stop**.

Typical official build duration: **~30 min** (1.0.x version bump per run).

### 4. Queue the Release

For dry-run actions, no extra confirmation needed. **For destructive actions, re-confirm with the user via `ask_user` before this step.**

```python
ado-pipelines_write action=run_pipeline project=MCAS pipelineId=433104 \
  resources='{"repositories": {"self": {"refName": "refs/heads/main"}}}' \
  templateParameters='{"action": "<action>", "environment": "<env>", "debug": "false"}'
```

The release pipeline automatically picks the **latest successful** official build as its `bd` pipeline resource — no need to pass build id.

Save the returned `id` as `RELEASE_BUILD_ID`. The release pipeline runs:
1. PolicyValidation + sdl_sources (fast, ~5 min)
2. ACR upload (~5 min)
3. **`PROD_<ENV>_APPROVAL` gate** — pipeline pauses here. Approval link appears in this stage's log.
4. AgentRolloutJob (EV2 deploy of Job spec to AKS)
5. Monitoring stage

### 5. Extract approval link → post ASK to Teams

When release stage reaches `*_APPROVAL`, use:

```bash
~/.copilot/skills/release-monitor/monitor-and-notify.sh <RELEASE_BUILD_ID>
```

…OR extract the `https://approval.azengsys.com/Home/PendingRelease?...approvalRequestPanelApprovalRequestId=<GUID>` URL manually from the approval stage log.

Then compose the SDP ASK **strictly** using `~/.copilot/skills/release-approval-template/SKILL.md` (all 9 checklist headings required) and send:

```bash
~/.copilot/skills/teams-sender/send-message.sh release-approval "<full ASK body>"
```

Always preview the message to the user before sending.

For the standard PR 16082977-era helm config (`enabled_group_size=480`, `disabled_group_size=25000`), the validation section should claim the expected planner log lines:

```
Using config value for enabled_group_size: 480
Using config value for disabled_group_size: 25000
Planned … (target size: 25000) — disabled
Planned … (target size: 480)   — enabled
```

### 6. Validate in Kusto after approval clears

Once the user reports the approval has been granted (or the planner pod starts emitting logs), use `manage_schedule` to poll every 10 min:

```kql
tgcompress
| where TIMESTAMP > datetime(<release queue time>)
| where message has_any (
    "Using config value for enabled_group_size",
    "Using config value for disabled_group_size",
    "target size",
    "Missing required config",
    "Planned "
  )
| project TIMESTAMP, levelname, build_id, message
| order by TIMESTAMP asc
| take 60
```

Run against the env's Kusto cluster (table above), database `orchestration`.

**Ingestion lag is typically 15–20 min** — yesterday: planner emitted at 08:15Z, ingested by 08:32Z. Don't declare "no logs" until at least 30 min after the planner pod's expected start time.

#### Interpretation

| Pattern in `message` | Verdict |
|---|---|
| `Using config value for disabled_group_size: 25000` + matching helm value for enabled | ✅ FIX CONFIRMED (config loaded correctly) |
| `Planned … target size: 25000` (disabled) AND `target size: 480` (enabled) | ✅ Planner respecting helm values |
| `using default … of 600` OR `target size: 12000` | ❌ REGRESSION — PR 16082977 fix not in effect |
| `ValueError: Missing required config 'enabled_group_size'` | ❌ Configmap not loaded — alert user immediately |
| 0 rows after >30 min of release completion | ⚠️ Planner pod didn't start OR Geneva ingestion broken — check pipeline timeline + other tables on same cluster |

### 7. Report to user

Once both targets (if multiple envs were queued) show ✅ fix-confirmed lines, summarize for the user:
- Build / release IDs
- Approval status
- Actual planner log lines (paste them, with timestamps)
- Before-vs-after comparison vs the prior run if available

## Helper script

`run-tgcompress.sh` (this folder) is a thin wrapper around steps 2–4. It does **not** handle the approval ASK or Kusto validation — those need the agent's reasoning (template fill-out, log interpretation). Use it as:

```bash
~/.copilot/skills/tgcompress-run/run-tgcompress.sh <action> <environment> [--skip-build] [--branch refs/heads/main]
```

It prints the build IDs to stdout and exits — the agent picks up from step 5.

## Pre-flight checks (the agent must do these every time)

- [ ] Confirmed `action` and `environment` with the user via `ask_user`
- [ ] For destructive actions, got a second explicit "yes, proceed" from the user
- [ ] Decided rebuild vs reuse based on latest build age
- [ ] Captured both `BUILD_ID` (if new) and `RELEASE_BUILD_ID`
- [ ] Approval ASK previewed to user before send
- [ ] Approval ASK posted via the `release-approval` alias (auto-mentions channel)
- [ ] Kusto cluster URL matches the chosen env (re-check the table above — PROD-3 uses WestUS Kusto despite deploying to EUS2!)
- [ ] Watcher schedule armed; will report after first ingestion window

## Notes & gotchas

- **PROD-3 region split:** The release pipeline's AgentRolloutJob deploys to AKS in EUS2 (cluster 106), but Geneva routes the planner logs to the **WestUS** Kusto cluster. Don't query EUS2 — it has no `tgcompress` table.
- **Build artifact reuse:** The release pipeline auto-picks the latest successful Official Build via the `bd` pipeline resource. You almost never need to specify a build artifact explicitly.
- **Per-env approval gates:** Each env (PROD-3, PROD-4, etc.) has its own approval URL. Send a separate Teams ASK for each — never batch.
- **Soak ladder for non-dry-run actions:** Destructive actions (`full-orphans`, `contoso-full-orphans`, `Backup + Plan + Compress`, `sync_groups_tenants_counts`) need ≥ 1 day on RS → PROD-3 → public prods → GOV per SDP. Reflect this in the approval ASK soak-compliance section. Dry-run actions are exempt from the soak ladder.
- **Reply with results:** Optionally, once Kusto confirms fix-confirmed lines, reply in-thread to the approval message so approvers see evidence inline. Use direct Graph call `POST /teams/{team}/channels/{channel}/messages/{parentId}/replies` since `send-message.sh` only posts top-level messages.

## Related skills

- `release-monitor` — extracts the approval URL from a running build's timeline
- `release-approval-template` — strict SDP ASK template for the Teams post
- `teams-sender` — the `release-approval` alias used to post
- `pr-review-template` — peer template for PR Review channel (different DNA)
- `geneva-monitoring-mcp` — the underlying Kusto MCP tool used in step 6
