---
name: get-approval-link
description: "Fetch approval service links from running Azure DevOps pipelines waiting for approval. Use when a OneBranch production pipeline is paused for approval, user asks to get/retrieve/find the approval link, or when pipeline is waiting for approval in non-STG environments (PRD, FF). The approval is done via SAW (Secured Admin Workstation) approval portal."
domain: "deployment"
confidence: "adopted"
---

# Get Approval Service Link from Running Pipeline

Retrieve the approval service link from Azure DevOps OneBranch pipelines waiting for approval in non-STG environments (PRD, FF). Production deployments require manual approval through the Approval Service portal, accessed via SAW (Secured Admin Workstation).

## When to Use This Skill

- User asks to "get the approval link" or "find the approval URL"
- A pipeline is waiting for approval in PRD or FF environment
- Need to approve a running production deployment
- Following up after `monitor-ado-pipeline` shows a build is paused

## Context

When deploying to production via OneBranch pipelines (Microsoft standard compliant build pipelines), an approval stage is required. The pipeline pauses at an **ApprovalService** job, which logs the approval URL. An approver must approve via the approval portal in SAW.

This applies to both:
- **ConfigGen deployments**: Resources generated via config-gen, built into EV2 files
- **Service deployments**: Docker images packaged with deployment values, deployed via EV2

## Execution Steps

### 1. Get Build ID

If not provided, either:

**Option A: Ask the user directly**

**Option B: Search for recent running builds**
```
mcp_ado-msazure_pipelines_get_builds
- project: MCAS
- definitions: {PIPELINE_DEFINITION_ID}
- statusFilter: inProgress
- top: 10
```

Display the list and let the user select one.

### 2. Find the ApprovalService Job

Get the pipeline run details:

```
mcp_ado-msazure_pipelines_get_run
- pipelineId: {PIPELINE_DEFINITION_ID}
- project: MCAS
- runId: {BUILD_ID}
```

> **Note**: In Azure DevOps, "run" and "build" refer to the same entity and share the same ID.

Look for a stage/job named "ApprovalService" or containing "Approval" in the name.

### 3. Get Build Logs

Retrieve all build logs:

```
mcp_ado-msazure_pipelines_get_build_log
- project: MCAS
- buildId: {BUILD_ID}
```

### 4. Find the Approval Step Log

Look through logs for the one associated with:
- Job name containing "ApprovalService" or "Approval"
- Step name containing "Waiting for Approval"

Note the log `id` from the response.

### 5. Get Log Content

```
mcp_ado-msazure_pipelines_get_build_log_by_id
- project: MCAS
- buildId: {BUILD_ID}
- logId: {LOG_ID}
```

### 6. Extract Approval URL

Search the log content for the line:
```
Please approve release from https://approval.azengsys.com/approvalRequest?id=<approval document id>
```

Extract the full URL matching pattern:
```
https://approval\.azengsys\.com/approvalRequest\?id=[a-zA-Z0-9-]+
```

### 7. Display Results

```
✅ Approval Link Found!

Build ID: {BUILD_ID}
Pipeline: {PIPELINE_NAME}
Environment: {PRD/FF}

🔗 Approval URL: {EXTRACTED_URL}

Open this link in SAW (Secured Admin Workstation) to approve the release.
```

If multiple approval links are found, display all of them.

## Error Handling

### No Running Builds
```
No pipelines are currently running. Provide a specific build ID or trigger a pipeline first.
```

### Build Not Waiting for Approval
```
Build {BUILD_ID} is not currently waiting for approval.
Possible reasons:
- It's running in STG (no approval required)
- The approval step hasn't started yet
- The approval was already processed
```

### Approval Link Not Found in Logs
```
Could not find approval link in the logs.
Possible reasons:
- Pipeline hasn't reached the approval stage yet
- This is a STG deployment (no approval required)
- Log format may have changed

🔗 Build URL: {BUILD_URL}
Please check the pipeline manually.
```

### Authentication Errors
```
Authentication error accessing Azure DevOps.
1. Ensure ADO MCP server is properly configured
2. Verify access to the MCAS project
3. Try running: az login
```

## Important Notes

- **STG Deployments**: STG environment does NOT require approval — this skill won't find links for STG pipelines
- **Timing**: The approval step must have started for the link to appear in logs
- **SAW Required**: The approval URL must be opened in a SAW (Secured Admin Workstation) browser
- **Permissions**: You need read access to the MCAS project and build logs
- **Multiple Approvals**: Some deployments may require multiple approvals for different stages/regions

## Approval Service URL Pattern

```
https://approval.azengsys.com/approvalRequest?id={APPROVAL_DOCUMENT_ID}
```

## Pipeline URL Patterns

- **Pipeline definition**: `https://msazure.visualstudio.com/MCAS/_build?definitionId={DEFINITION_ID}`
- **Specific build**: `https://msazure.visualstudio.com/MCAS/_build/results?buildId={BUILD_ID}`

## Integration with Deployment Workflow

This skill is the final step in the production deployment chain:

```
configgen-development → [generates EV2 files]
       ↓
Pipeline triggered → monitor-ado-pipeline → [build succeeds]
       ↓
[Production env] → get-approval-link → [approve in SAW]
       ↓
monitor-ev2-rollout → [track regional deployment]
```

The approval gate is required for all production (PRD) and fast-forward (FF) deployments via OneBranch pipelines.

## Related Skills

- `monitor-ado-pipeline` — Monitor ADO pipeline runs and detect when approval is needed
- `monitor-ev2-rollout` — Monitor Ev2 deployment progress after approval
- `configgen-development` — ConfigGen workflow that produces EV2 files
- `pull-request-process` — PR lifecycle including build validation
