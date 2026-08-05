---
name: monitor-ev2-rollout
description: "Monitor and debug Ev2 (Express v2) rollout deployments. Use when checking Ev2 deployment status, investigating rollout failures, or tracking deployment progress across regions. Requires ev2 CLI to be installed and authenticated. Typically invoked after extracting rollout info from ADO pipeline logs."
domain: "deployment"
confidence: "adopted"
---

# Monitor and Debug Ev2 Rollouts

Monitor and debug Ev2 (Express v2) rollout deployments using the ev2 CLI and Ev2 portal. Typically used after extracting rollout information from ADO pipeline build logs.

## When to Use This Skill

- Checking the status of an Ev2 deployment rollout
- Investigating why a rollout failed in a specific region
- Tracking deployment progress across region groups
- Following up after `monitor-ado-pipeline` extracts rollout info

## Prerequisites

- **ev2 CLI**: Must be installed and authenticated (`ev2 login`)
- **Rollout Information**: Rollout ID, Service Group, and Rollout Infra — typically extracted from ADO build logs via `monitor-ado-pipeline`

## Collecting Rollout Information

If not provided, you need:

- **Rollout ID**: GUID format (e.g., `39263ec8-018a-4666-8bce-1cdca4db0ed4`)
- **Service Group**: The service group name (e.g., `MDA.Platform.QuotaAnalyzer`)
- **Rollout Infra**: The infrastructure/environment name (e.g., `Prod`, `Int`)

**Where to find this**:
- Output from `monitor-ado-pipeline` skill (extracted from build logs)
- Ev2 Portal URL: `https://ev2portal.azure.net/#/Rollout/{ServiceGroup}/{RolloutID}?RolloutInfra={Infra}`
- Azure DevOps build logs (Ev2 task output)

## Execution Steps

### 1. Check ev2 CLI Installation

```bash
which ev2
```

If not found:
```
The ev2 CLI is not installed. To install:

Windows:  winget install Microsoft.ExpressV2
Linux/Mac: Follow instructions at https://aka.ms/ev2/cli

After installation, authenticate with: ev2 login
```

### 2. Get Rollout Status

```bash
ev2 rollout get \
  --rolloutid '{ROLLOUT_ID}' \
  --servicegroup '{SERVICE_GROUP}' \
  --rolloutinfra '{ROLLOUT_INFRA}' \
  --embeddetails
```

**Important**: Use single quotes around parameters to prevent shell interpretation issues.

### 3. Parse Rollout Status

The ev2 CLI returns JSON. Key fields:

**Rollout-level**:
- `Status`: InProgress, Completed, Failed, Canceled
- `CurrentStepIndex` / `TotalSteps`
- `PercentComplete`
- `StartTime` / `EndTime`

**Step-level** (from `Steps` array):
- `Name`: Deployment step name
- `Status`: NotStarted, InProgress, Succeeded, Failed, Skipped
- `StartTime` / `EndTime`
- `ErrorMessage`: Error details if failed
- `Regions`: Array of regions in this step

**Error information** (if failed):
- `ErrorCode`, `ErrorMessage`, `FailedStep`, `FailedStepDetails`

### 4. Present Rollout Status

**In Progress**:
```
🔄 Rollout is in progress

Rollout ID: {ROLLOUT_ID}
Service Group: {SERVICE_GROUP}
Environment: {INFRA}
Progress: Step {N} of {TOTAL} ({PERCENT}% complete)
Current Step: {STEP_NAME}
  Regions: {REGION_LIST}

Completed Steps:
✅ Step 1: {NAME} ({REGIONS}) — {DURATION}

Upcoming Steps:
⏳ Step 3: {NAME} ({REGIONS})

🔗 Ev2 Portal: https://ev2portal.azure.net/#/Rollout/{SERVICE_GROUP}/{ROLLOUT_ID}?RolloutInfra={INFRA}
```

**Completed Successfully**:
```
✅ Rollout completed successfully!

Rollout ID: {ROLLOUT_ID}
Service Group: {SERVICE_GROUP}
Environment: {INFRA}
Total Duration: {DURATION}
All Steps: {N} of {N} completed

Deployment Summary:
✅ Step 1: {NAME} ({DURATION})
✅ Step 2: {NAME} ({DURATION})
...

🔗 Ev2 Portal: {PORTAL_URL}
```

**Failed**:
```
❌ Rollout failed!

Rollout ID: {ROLLOUT_ID}
Service Group: {SERVICE_GROUP}
Environment: {INFRA}
Failed at: Step {N} of {TOTAL} ({STEP_NAME})
Progress: {PERCENT}% complete

Failed Step Details:
Regions: {FAILED_REGIONS}
Error Code: {ERROR_CODE}
Error Message: {ERROR_MESSAGE}

Common Causes:
- Managed identity lacks access to target subscription
- Subscription ID incorrect or doesn't exist in this region
- Wrong tenant configuration
- Regional service principal permissions not configured

Next Steps:
1. Verify managed identity permissions in failed regions
2. Check subscription accessibility
3. Review service model configuration
4. Check Ev2 portal for detailed execution logs

🔗 Ev2 Portal: {PORTAL_URL}
```

### 5. Detailed Logs (On Failure)

For more details on failures:

```bash
ev2 rollout get \
  --rolloutid '{ROLLOUT_ID}' \
  --servicegroup '{SERVICE_GROUP}' \
  --rolloutinfra '{ROLLOUT_INFRA}' \
  --embeddetails --verbose
```

Also guide users to:
- **Ev2 Portal**: Click failed step for detailed logs
- **Region-specific logs**: Each region has individual execution logs
- **Script output**: stdout/stderr from script execution

## Common Rollout Failure Patterns

| Pattern | Common Cause | Resolution |
|---------|-------------|------------|
| Script exit code 1 | General script failure | Check script logs |
| Timeout | Script exceeded time limit | Optimize or increase timeout |
| Permission denied | Managed identity lacks access | Grant required roles |
| Resource already exists | Previous partial rollout | Check resource state |
| Quota exceeded | Subscription/region limits | Request quota increase |
| InvalidAuthenticationTokenTenant | Wrong issuer for access token | Check managed identity tenant config |
| DNS resolution failed | Network misconfiguration | Verify DNS settings |

## Environment Mappings

Common ADO pipeline → Ev2 Infra mappings:

| ADO Environment | Ev2 Rollout Infra |
|----------------|-------------------|
| STG | Int or Prod |
| PRD | Prod |
| FF | FF or Prod |

> The exact mapping depends on service group configuration. Check the ServiceModel or build logs to confirm.

## Ev2 Portal Features

The portal at `https://ev2portal.azure.net` provides:
- **Real-time progress** as the rollout progresses
- **Step-by-step view** of each deployment step
- **Region-specific logs** for each region
- **Manual intervention**: Pause, resume, or cancel rollouts (with permissions)
- **Historical rollouts** for comparison

## Troubleshooting Checklist

When investigating failed rollouts, check:

1. **Authentication**: Is the managed identity properly configured?
2. **Permissions**: Does the identity have all required roles? (Subscription, resource group, specific resources)
3. **Configuration**: Are all parameters in the values file correct? (Subscription IDs, resource names, region availability)
4. **Resources**: Do target resources exist and are they accessible?
5. **Network**: Any network restrictions blocking access?
6. **Quotas**: Subscription or regional quotas exceeded?
7. **Dependencies**: All dependent services available?
8. **Script Logic**: Does the script handle all edge cases?

## Integration with Deployment Workflow

This skill fits into the deployment chain:

```
configgen-development → [generates EV2 files]
       ↓
Pipeline triggered → monitor-ado-pipeline → [extracts Ev2 info]
       ↓
monitor-ev2-rollout → [tracks regional deployment]
       ↓
[if approval needed] → get-approval-link
```

Both ConfigGen-generated resources and service deployments (Docker + deployment values) follow this pattern.

## Important Notes

- **Read-Only**: This skill only monitors rollouts — it cannot trigger or modify them
- **CLI Dependency**: Requires `ev2` CLI installed and authenticated
- **Real-Time**: Status reflects the state at query time — call again to refresh
- **Regional Deployment**: Ev2 deploys in stages across regions; partial completion is normal
- **Built-in Retry**: Ev2 has retry logic for transient failures
- **Rollback**: Failed rollouts may require manual rollback or a new rollout

## Related Skills

- `monitor-ado-pipeline` — Monitor ADO pipeline runs and extract Ev2 rollout info
- `get-approval-link` — Get approval URL for production deployments
- `configgen-development` — ConfigGen workflow that produces EV2 files
