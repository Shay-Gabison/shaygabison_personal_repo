---
name: monitor-ado-pipeline
description: "Monitor and debug Azure DevOps pipeline runs. Use when checking pipeline build status, investigating build failures, retrieving build logs, or extracting Ev2 rollout information from completed builds. Works with OneBranch and standard ADO pipelines across all team repositories."
domain: "deployment"
confidence: "adopted"
---

# Monitor and Debug Azure DevOps Pipelines

Monitor Azure DevOps build pipeline runs and debug failures by retrieving logs and extracting Ev2 rollout information. Works with any ADO pipeline in the MCAS project.

## When to Use This Skill

- Checking the status of a running or completed pipeline build
- Investigating why a pipeline build failed
- Extracting Ev2 rollout information from build logs (rollout ID, service group, environment)
- Bridging from build completion to Ev2 deployment monitoring

## Prerequisites

- ADO MCP server connected (msazure / MCAS project)
- Build ID of the pipeline run to monitor

## Execution Steps

### 1. Get Build ID

If not provided, ask for the build ID. It can be found from:
- The Azure DevOps build URL (the number at the end)
- Output of a previous pipeline trigger
- Recent builds list in Azure DevOps

### 2. Check Pipeline Status

Use the ADO MCP server:

```
mcp_ado-msazure_pipelines_get_build_status
- project: MCAS
- buildId: {BUILD_ID}
```

Key response fields:
- `status`: "inProgress", "completed", "cancelling", "postponed", "notStarted"
- `result`: "succeeded", "failed", "canceled", "partiallySucceeded" (only when completed)
- `_links.web.href`: Link to the build in Azure DevOps
- `startTime` / `finishTime`: Timing information
- `sourceBranch`: The branch being built
- `sourceVersion`: The commit SHA
- `definition.name`: Pipeline name
- `definition.id`: Pipeline definition ID

### 3. Report Current Status

**If In Progress**:
```
🔄 Build {BUILD_ID} is still running
Pipeline: {PIPELINE_NAME}
Status: InProgress
Branch: {BRANCH}
Started: {START_TIME}
Duration: {ELAPSED} (ongoing)

🔗 View build: {BUILD_URL}
```

**If Completed Successfully**:
```
✅ Build {BUILD_ID} completed successfully!
Pipeline: {PIPELINE_NAME}
Result: Succeeded
Branch: {BRANCH}
Duration: {DURATION}

🔗 View build: {BUILD_URL}
```
Then proceed to extract Ev2 information from logs (Step 7).

**If Failed**:
```
❌ Build {BUILD_ID} failed!
Pipeline: {PIPELINE_NAME}
Result: Failed
Branch: {BRANCH}
Duration: {DURATION}

🔗 View build: {BUILD_URL}

Retrieving logs to diagnose the issue...
```
Then proceed to retrieve and analyze logs (Step 4).

### 4. If Pipeline Failed — Retrieve Logs

When result is "failed", automatically retrieve the build logs:

```
mcp_ado-msazure_pipelines_get_build_log
- project: MCAS
- buildId: {BUILD_ID}
```

### 5. Analyze Logs for Errors

Search through logs for:

1. **Build Errors**:
   - `##[error]` — Azure DevOps error marker
   - `ERROR:` or `Error:` — General error messages
   - `FAILED` — Test or task failures
   - `exit code 1` / `returned 1` — Non-zero exit codes

2. **Ev2 Rollout Information** (in tasks named `Ev2: ...`):
   - Rollout ID (GUID format)
   - Service Group name
   - Environment/Infra name
   - Rollout portal URLs

Example log patterns:
```
Rollout submitted to Azure Deployment Manager.
	Rollout ID: 39263ec8-018a-4666-8bce-1cdca4db0ed4
Environment Name: Prod
Service Group: MDA.Platform.QuotaAnalyzer
```

Or:
```
https://ev2portal.azure.net/#/Rollout/{SERVICE_GROUP}/{ROLLOUT_ID}?RolloutInfra={INFRA}
```

### 6. Present Debugging Information

**For Build Failures (Non-Ev2)**:
```
❌ Build failed during: {TASK_NAME}

Error Details:
{RELEVANT_ERROR_MESSAGES}

Common Causes:
- {CAUSE_1}
- {CAUSE_2}

Next Steps:
1. Check full logs at {BUILD_URL}
2. Verify {SPECIFIC_CONFIG}
3. Re-run the pipeline after fixing
```

**For Ev2-Related Failures**:
```
❌ Build completed but may have Ev2 deployment issues

📋 Ev2 Rollout Detected:
Rollout ID: {ROLLOUT_ID}
Service Group: {SERVICE_GROUP}
Environment: {ENVIRONMENT}

🔗 Ev2 Portal: https://ev2portal.azure.net/#/Rollout/{SERVICE_GROUP}/{ROLLOUT_ID}?RolloutInfra={INFRA}

To check Ev2 rollout status: use the monitor-ev2-rollout skill
```

### 7. Extract Ev2 Information (Success or Failure)

For successful builds, retrieve logs to extract Ev2 rollout information:
- **Rollout ID**: GUID format
- **Service Group**: e.g., MDA.Platform.QuotaAnalyzer
- **Rollout Infra**: Usually "Prod", "Int"

**CRITICAL**: When Ev2 information is found, inform the user to use the `monitor-ev2-rollout` skill for deployment tracking.

## Error Handling

### MCP Server Errors

Fallback to Azure CLI:
```bash
az pipelines build show --id {BUILD_ID} --organization https://dev.azure.com/msazure --project MCAS
```

For downloading build logs via CLI:
```bash
az rest --method get --url "https://dev.azure.com/msazure/MCAS/_apis/build/builds/{BUILD_ID}/logs?api-version=7.1"
```
Then fetch a specific log by ID:
```bash
az rest --method get --url "https://dev.azure.com/msazure/MCAS/_apis/build/builds/{BUILD_ID}/logs/{LOG_ID}?api-version=7.1"
```

### Common Issues

| Issue | Resolution |
|-------|-----------|
| Build ID not found | Verify the build ID is correct and from the MCAS project |
| Authentication errors | Check MCP server connection or run `az login` |
| Logs too large | Focus on specific task logs or error patterns |
| No Ev2 information | Not all builds create Ev2 rollouts (e.g., validation-only builds) |

## Pipeline URL Patterns

- **Pipeline definition**: `https://msazure.visualstudio.com/MCAS/_build?definitionId={DEFINITION_ID}`
- **Specific build**: `https://msazure.visualstudio.com/MCAS/_build/results?buildId={BUILD_ID}`

## Integration with Deployment Workflow

This skill connects to the broader deployment workflow:

1. **ConfigGen builds** (see `configgen-development` skill): After `dotnet build && dotnet run` generates EV2 files, a pipeline packages and deploys them
2. **Service deployments**: Docker images packaged with deployment values, deployed via EV2
3. **PR builds** (see `pull-request-process` skill): Monitor validation builds before merge
4. **Production deployments**: OneBranch pipelines that require approval — use `get-approval-link` skill to get the SAW approval URL

```
Pipeline triggered → monitor-ado-pipeline → [extract Ev2 info] → monitor-ev2-rollout
                                           → [if waiting approval] → get-approval-link
```

## Important Notes

- **Separate Concerns**: This skill only monitors ADO pipelines. For Ev2 rollout details, use `monitor-ev2-rollout`
- **Automatic Log Retrieval**: Logs are fetched automatically when: (1) a build fails, or (2) user requests Ev2 rollout info from a successful build
- **Polling**: This skill checks status once per invocation. Call again to refresh
- **Build Duration**: Calculate from startTime and finishTime (or current time if still running)

## Related Skills

- `monitor-ev2-rollout` — Monitor Ev2 deployment progress and status
- `get-approval-link` — Get approval URL for production deployments
- `pull-request-process` — PR lifecycle including build validation
- `configgen-development` — ConfigGen workflow that produces EV2 files
