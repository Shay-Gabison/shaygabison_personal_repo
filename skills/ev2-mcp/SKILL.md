---
name: ev2-mcp
description: 'Interact with Microsoft EV2 (ExpressV2) deployment system via the Ev2 MCP Server. Monitor rollouts, manage services, register artifacts, control deployments (start/cancel/suspend/resume), query configurations, stage maps, and service presence. Covers the full EV2 deployment lifecycle for MDA and other Azure services.'
---

# EV2 MCP Skill

Use the **Ev2 MCP Server** tools to interact with Microsoft's EV2 (ExpressV2) deployment system — the enterprise deployment orchestration platform for Azure services.

## Prerequisites

- The `ev2-mcp` MCP server must be running (configured in `~/.copilot/mcp-config.json`)
- User must be logged in via `az login` for EV2 API auth
- `ALLOWED_EV2_ENDPOINTS` env var controls which endpoints are accessible (default: `Test,Prod`)

## MDA-Specific Context

For MDA (Microsoft Defender for Cloud Apps) services:
- **Service Tree ID / EV2 Service ID**: `2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d`
- **Secondary Service Tree ID**: `aa7d05ce-5b6c-449f-9f85-1982d2700d79`
- **Tenant ID**: `33e01921-4d64-4f8c-a055-5bdaffd5e33d`
- **ADO Project**: `MCAS`
- **Shell Generator Repo**: `MDA.Ev2.Shell.Generator`

Common MDA service groups include:
- `MDA.Platform.DeleteUnusedPublicIps` — Orphaned public IP cleanup
- Various `MDA.*` service groups for platform operations

### MDA EV2 Shell Generator Pipeline

- **Pipeline name**: `MDA.Ev2.Shell.Generator-Official` (def ID: 375925)
- **ADO project**: `MCAS`
- **Repo**: `MDA.Ev2.Shell.Generator`

## Finding EV2 Rollout Links from Any ADO Pipeline Run

Any ADO pipeline that deploys via EV2 logs the **EV2 portal rollout link** in the deployment job. The link and rollout status always appear in the same format regardless of the pipeline or service group.

### How to extract the EV2 link from a build

**Given a build URL** like `https://msazure.visualstudio.com/{Project}/_build/results?buildId={buildId}`:

1. **List all log entries** for the build:
   ```
   pipelines_get_build_log(project: "<project>", buildId: <buildId>)
   ```

2. **Identify the EV2 deployment log** — it's in the rollout job, typically one of the larger logs. Job names often contain `RolloutJob`, `SHELL_EXTENSION`, or the environment name (e.g., `PROD_PRD_SHELL_EXTENSION_AgentRolloutJob`). When unsure, check the **last few large logs** (sort by `lineCount` descending).

3. **Read the log** and search for `ev2portal`:
   ```
   pipelines_get_build_log_by_id(project: "<project>", buildId: <buildId>, logId: <logId>)
   ```

4. **The EV2 portal link** always appears as this warning line:
   ```
   ##[warning]Ev2 portal link - https://ev2portal.azure.net/#/Rollout/{ServiceGroupName}/{RolloutId}?RolloutInfra={Endpoint}
   ```

5. **Rollout status** is logged repeatedly as the rollout progresses:
   ```
   Rollout Details: Id: <guid> Name: <ServiceGroupName> <version>
   Status: Succeeded|Running|Failed
       Start Time: ..., End Time: ..., Total Duration: ...
       Resource Group: ..., Location: ..., SubscriptionId: ...
           ServiceResource: ..., Action: Shell/..., Status: Succeeded
   ```

### Quick grep patterns

When parsing log output from any EV2 pipeline, search for:
- `ev2portal.azure.net` — the portal link (always present)
- `Rollout Details: Id:` — rollout summary with GUID
- `Status: Succeeded` / `Status: Failed` / `Status: Running` — final status

### Generic workflow

```
# Given any ADO build URL, extract the project and buildId, then:

# 1. List logs
pipelines_get_build_log(project: "<project>", buildId: <buildId>)
# → Sort by lineCount, pick the rollout job log (largest, late in the pipeline)

# 2. Read that log
pipelines_get_build_log_by_id(project: "<project>", buildId: <buildId>, logId: <logId>)
# → Search output for "ev2portal.azure.net"
# → Extract: ServiceGroupName, RolloutId, RolloutInfra (Prod/Test)

# 3. Use EV2 MCP tools to get full details
get_rollout_summary(
  serviceId: "<serviceId>",
  serviceGroupName: "<from URL>",
  rolloutId: "<from URL>",
  endpoint: "<from URL>"  # Prod or Test
)

# 4. For shell execution logs (stdout/stderr of the deployed script):
get_rollout_details(
  serviceId: "<serviceId>",
  serviceGroupName: "<from URL>",
  rolloutId: "<from URL>",
  endpoint: "<from URL>",
  filterActions: "Shell/*",
  includeStatusMessages: true
)
```

### Parsing the EV2 link from the URL

The portal URL `https://ev2portal.azure.net/#/Rollout/{ServiceGroupName}/{RolloutId}?RolloutInfra={Endpoint}` gives you all three parameters directly. The `serviceId` is the Service Tree ID of the owning service — for MDA this is `2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d`.

## EV2 Portal URL Format

```
https://ev2portal.azure.net/#/Rollout/{ServiceGroupName}/{RolloutId}?RolloutInfra={Endpoint}
```

## Common Workflows

### 1. Check Rollout Status

```
# Get the latest rollout for a service group
get_latest_rollout(
  serviceId: "2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d",
  serviceGroupName: "MDA.Platform.DeleteUnusedPublicIps",
  endpoint: "Prod"
)

# Get details for a specific rollout by ID
get_rollout_details_by_rollout_id(
  serviceId: "2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d",
  serviceGroupName: "MDA.Platform.DeleteUnusedPublicIps",
  rolloutId: "<rollout-guid>",
  endpoint: "Prod"
)

# Get rollout summary (higher-level view)
get_rollout_summary(
  serviceId: "2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d",
  serviceGroupName: "MDA.Platform.DeleteUnusedPublicIps",
  rolloutId: "<rollout-guid>",
  endpoint: "Prod"
)

# List rollout history for a time period (max 30 days)
list_rollout_history_for_custom_time_period(
  serviceId: "...",
  serviceGroupName: "...",
  startTime: "2026-03-01",
  endTime: "2026-03-17",
  endpoint: "Prod"
)
```

### 2. Rollout Management (Start/Stop/Control)

```
# Start a new rollout
start_rollout(
  serviceId: "...",
  serviceGroupName: "...",
  stageMapName: "...",
  selectionScope: "regions(eastus,westus).steps(*).stamps(*).actions(*)",
  endpoint: "Prod"
)

# Start a validation rollout (dry run, no actual deployment)
start_validation_rollout(
  serviceId: "...",
  serviceGroupName: "...",
  stageMapName: "...",
  selectionScope: "regions(eastus).steps(*).stamps(*).actions(*)",
  endpoint: "Test"
)

# Suspend (pause) a running rollout
suspend_rollout(
  serviceId: "...",
  rolloutId: "...",
  serviceGroupName: "...",
  endpoint: "Prod"
)

# Resume a suspended rollout
resume_rollout(
  serviceId: "...",
  rolloutId: "...",
  serviceGroupName: "...",
  endpoint: "Prod"
)

# Cancel a rollout permanently
cancel_rollout(
  rolloutId: "...",
  serviceId: "...",
  serviceGroupName: "...",
  endpoint: "Prod"
)

# Restart a failed rollout (can skip succeeded regions)
restart_rollout(
  rolloutId: "...",
  serviceGroupName: "...",
  endpoint: "Prod"
)

# Approve continuation of a rollout paused at a wait action
approve_rollout_continuation(
  rolloutId: "...",
  serviceGroupName: "...",
  serviceResourceGroup: "...",
  serviceResource: "...",
  action: "...",
  endpoint: "Prod"
)
```

### 3. Service & Registration

```
# Get service info
get_service_info(serviceId: "2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d")

# Get service group registration (list all if no serviceGroup specified)
get_service_group_registration(
  serviceIdentifier: "2fa7ba65-93e0-46c6-98b0-1df0c4e8a74d",
  serviceGroup: "MDA.Platform.DeleteUnusedPublicIps",
  endpoint: "Prod"
)

# Get service presence (regions where service operates)
get_service_presence(
  serviceId: "...",
  serviceGroupName: "...",
  endpoint: "Prod"
)
```

### 4. Artifacts

```
# List artifact versions
get_artifacts(serviceId: "...", serviceGroup: "...", endpoint: "Prod")

# Get specific artifact version details
get_artifacts_for_version(serviceId: "...", serviceGroup: "...", artifactsVersion: "1.0.0.0")

# Register new artifacts
register_region_agnostic_artifacts(
  serviceGroupRoot: "/path/to/ev2",
  rolloutSpecPath: "/path/to/RolloutSpec.json"
)

# Validate artifacts locally (no auth needed)
validate_region_agnostic_artifacts(
  serviceGroupRoot: "/path/to/ev2",
  rolloutSpecPath: "/path/to/RolloutSpec.json",
  selectionScope: "regions(eastus).steps(*).stamps(*).actions(*)"
)
```

### 5. Configuration

```
# Get registered configuration
get_registered_configuration(
  serviceId: "...",
  serviceGroup: "...",
  regionName: "eastus",
  endpoint: "Prod"
)

# Set configuration (wholistic replace)
set_registered_configuration(
  serviceId: "...",
  configSpecFilePath: "/path/to/config.json"
)

# Partial update configuration
partial_update_configuration(
  serviceId: "...",
  configSpecFilePath: "/path/to/config-patch.json"
)

# Get EV2 central configuration
get_ev2_central_configuration(
  geographyName: "Public",
  regionName: "eastus"
)
```

### 6. Stage Maps

```
# List stage maps
get_or_list_stage_maps(serviceId: "...", serviceGroup: "...")

# Get latest stage map
get_latest_stage_map(serviceId: "...", serviceGroup: "...")

# Get EV2 standard stage map
get_ev2_standard_stage_map()
```

### 7. Knowledge & Schema

```
# Search EV2 documentation and knowledge base
ev2_knowledge_search(query: "how to configure shell extensions")

# Get EV2 best practices
get_ev2_best_practices()

# Get EV2 schema
get_schema_ev2()

# Get valid geographies and regions
get_valid_geography_and_regions()
```

## EV2 Endpoint Values

| Endpoint | Base URL | Resource ID |
|----------|----------|-------------|
| **Test** | `https://test.azureservicedeploy.msft.net/api` | `https://test.azureservicedeploy.msft.net` |
| **Prod** | `https://azureservicedeploy.msft.net/api` | `https://azureservicedeploy.msft.net` |
| Fairfax | `https://prod.azureservicedeploy.usgovcloudapi.net/api` | Gov cloud |
| Mooncake | `https://prod.azureservicedeploy.chinacloudapi.cn/api` | China cloud |

## EV2 REST API (Fallback)

If the ev2-mcp server is down, you can query the EV2 API directly via curl:

```bash
# Get access token
TOKEN=$(az account get-access-token --resource "https://azureservicedeploy.msft.net" --query accessToken -o tsv)

# Get rollout details (embed-detail=true for full logs)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://azureservicedeploy.msft.net/api/services/{serviceId}/serviceGroups/{serviceGroupName}/rollouts/{rolloutId}?api-version=2024-02-01&embed-detail=true&embed-artifacts=false&embed-actionretries=true"

# List rollouts in time range
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://azureservicedeploy.msft.net/api/rollouts?servicegroupname={sgName}&startTimeFrom={start}&startTimeTo={end}&api-version=2016-07-01&serviceidentifier={serviceId}"

# Get service group registration
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://azureservicedeploy.msft.net/api/services/{serviceId}/serviceGroups/{serviceGroupName}?api-version=2023-06-01"
```

### Key API Patterns

```
# Service operations
GET  api/services/{serviceId}?api-version=2017-04-01
POST api/services/{serviceId}?api-version=2022-07-11

# Service group operations
GET  api/services/{serviceId}/serviceGroups/{sgName}?api-version=2023-06-01

# Rollout operations
GET  api/services/{serviceId}/serviceGroups/{sgName}/rollouts/{rolloutId}?api-version=2024-02-01&embed-detail={bool}
POST api/services/{serviceId}/serviceGroups/{sgName}/rollouts?api-version=2021-09-01  (start rollout)
POST api/services/{serviceId}/serviceGroups/{sgName}/rollouts/{rolloutId}/cancel?api-version=2021-09-01
POST api/services/{serviceId}/serviceGroups/{sgName}/rollouts/{rolloutId}/suspend?api-version=2021-09-01
POST api/services/{serviceId}/serviceGroups/{sgName}/rollouts/{rolloutId}/resume?api-version=2021-09-01
POST api/rollouts/{rolloutId}/restart?servicegroupname={sgName}&api-version=2016-07-01

# Stage maps
GET  api/services/{serviceId}/serviceGroups/{sgName}/stageMaps?api-version=2021-09-01

# Artifacts
GET  api/services/{serviceId}/serviceGroups/{sgName}?api-version=2022-08-01
```

### Parsing Rollout Response

The rollout JSON from `embed-detail=true` has this structure:

```json
{
  "RolloutId": "guid",
  "RolloutName": "ServiceGroup version",
  "Status": "Succeeded|Failed|Running|Cancelled",
  "TotalRetryAttempts": 0,
  "RolloutDetails": {
    "ServiceIdentifier": "guid",
    "ServiceGroup": "name",
    "Environment": "Prod",
    "BuildVersion": "1.0.0.0",
    "Submitter": "user@microsoft.com"
  },
  "ResourceGroups": [{
    "Name": "rg-name",
    "Location": "region",
    "SubscriptionId": "guid",
    "Resources": [{
      "Name": "service-resource-name",
      "Actions": [{
        "Name": "Shell/action-name",
        "Status": "Succeeded",
        "ActionOperationInfo": {
          "StartTime": "...",
          "EndTime": "...",
          "ErrorInfo": null
        },
        "ResourceOperations": [{
          "StatusMessage": "{JSON string with shell output}",
          "ProvisioningState": "Succeeded"
        }]
      }]
    }]
  }]
}
```

For shell extensions, `StatusMessage` is a JSON string containing:
```json
{
  "ShellProvisioningState": "Succeeded",
  "Shells": [{
    "Name": "shellname",
    "Properties": {
      "ExecutionView": {
        "ExitCode": 0,
        "State": "Terminated",
        "StartTime": "...",
        "FinishTime": "..."
      }
    },
    "Log": "timestamped execution log output..."
  }]
}
```

## Troubleshooting

### MCP Server Not Connecting
- Verify `ev2-mcp` entry exists in `~/.copilot/mcp-config.json`
- Check the binary path: `/Users/shaygabison/.dotnet/tools/ev2-mcp-server`
- Restart the Copilot CLI session after config changes
- Do NOT kill the MCP server process — the CLI cannot auto-restart it

### Prod Endpoint Blocked
- Check `ALLOWED_EV2_ENDPOINTS` in config — must include `Prod`
- Config changes require CLI restart to take effect

### Auth Failures
- Run `az login` to refresh tokens
- For MDA services, ensure you're in the correct tenant (`33e01921-4d64-4f8c-a055-5bdaffd5e33d`)
- The EV2 MCP uses `DefaultAzureCredential` — Azure CLI is the most common credential source
