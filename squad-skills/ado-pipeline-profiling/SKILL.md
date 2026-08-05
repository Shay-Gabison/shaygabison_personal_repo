---
name: ado-pipeline-profiling
description: "Profile Azure DevOps pipeline performance to identify bottlenecks and optimization opportunities. Extract timeline data, rank tasks by duration, analyze parallelism, and produce actionable optimization plans."
domain: "devops"
confidence: "adopted"
---

# ADO Pipeline Performance Profiling

Systematically profile Azure DevOps pipelines to identify performance bottlenecks, analyze task durations, assess parallelism opportunities, and develop concrete optimization plans.

## When to Use This Skill

- Pipeline runtime is too long (>10 minutes for typical builds)
- Need to optimize CI/CD for faster developer feedback
- Investigating why a pipeline slowed down over time
- Comparing performance across branches or after changes
- Planning pipeline optimization work with data-driven priorities

## Prerequisites

- ADO MCP server connected (or `az` CLI with ADO extensions)
- Pipeline definition ID (visible in pipeline URL)
- Access to build history and timeline data
- Organization and project names

## Investigation Methodology

### 1. Gather Basic Pipeline Metadata

```bash
# Get pipeline definition
az rest --method get --url "https://dev.azure.com/{org}/{project}/_apis/build/definitions/{definitionId}?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798

# Extract:
- Pipeline name
- YAML file path
- Repository details
- Agent pool (hosted vs. self-hosted)
- Trigger configuration
```

### 2. Analyze Build History

Fetch 10-20 recent builds to understand runtime distribution:

```bash
# Get recent builds on main branch
az rest --method get --url "https://dev.azure.com/{org}/{project}/_apis/build/builds?definitions={definitionId}&branchName=refs/heads/main&\$top=20&api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798
```

**Calculate:**
- Median runtime
- P90 (90th percentile) runtime
- Success rate
- Queue time vs. execution time
- Identify outliers (unusually fast/slow builds)

**Compare across branches:**
- Baseline (main/master)
- Feature branches
- Optimization branches (if any)

### 3. Deep Timeline Analysis

For 2-3 representative builds (latest successful, median, slowest), fetch full timeline:

```bash
# Get timeline for a specific build
az rest --method get --url "https://dev.azure.com/{org}/{project}/_apis/build/builds/{buildId}/timeline?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798
```

**Extract and rank:**
- **Stages:** High-level pipeline phases
- **Jobs:** Units of work (may run in parallel)
- **Tasks:** Individual steps within jobs

**Python script to parse timeline:**
```python
import json
from datetime import datetime

def parse_time(ts):
    if '.' in ts:
        ts = ts.split('.')[0] + 'Z'
    return datetime.fromisoformat(ts.replace('Z', '+00:00'))

def analyze_timeline(timeline_json):
    records = timeline_json.get('records', [])
    tasks = []
    
    for rec in records:
        if rec.get('type') == 'Task' and rec.get('startTime') and rec.get('finishTime'):
            start = parse_time(rec['startTime'])
            finish = parse_time(rec['finishTime'])
            duration = (finish - start).total_seconds()
            tasks.append({
                'name': rec['name'],
                'duration': duration,
                'result': rec.get('result', 'unknown')
            })
    
    tasks.sort(key=lambda x: x['duration'], reverse=True)
    return tasks
```

**Output format:**
```
Rank | Duration | % Total | Task Name                      | Result
-----|----------|---------|--------------------------------|----------
1.   | 7m 30s   | 28.4%   | Build and package              | succeeded
2.   | 6m 06s   | 23.1%   | Deploy to staging              | succeeded
3.   | 4m 45s   | 18.0%   | Security scan                  | succeeded
...
```

### 4. Identify Bottleneck Categories

Classify tasks by type:

| Category | Examples | Optimization Potential |
|----------|----------|------------------------|
| **Package restore/install** | NuGet restore, npm install | HIGH (caching) |
| **Build/compile** | dotnet build, tsc | MEDIUM (incremental, parallelism) |
| **Test execution** | unit tests, integration tests | HIGH (parallel, sharding) |
| **Security scans** | Guardian, SBOM, CodeQL | LOW (policy-required) |
| **Artifact upload/download** | Publish, DownloadArtifact | MEDIUM (caching, compression) |
| **External dependencies** | EV2 deployment, approval gates | LOW (cannot control) |

### 5. Analyze Parallelism

**Job-level parallelism:**
```bash
# Extract job dependencies
jq '.records[] | select(.type == "Job") | {name, startTime, finishTime, dependencies}' timeline.json
```

**Questions to answer:**
- How many jobs run in parallel vs. sequentially?
- Are there dependencies that force sequential execution?
- Can independent work be split into separate jobs?
- Is there a matrix/fan-out strategy in use?

**Stage-level parallelism:**
- Which stages depend on each other?
- Can validation stages run in parallel with build stages?
- Are there unnecessary `dependsOn` constraints?

### 6. Common Slowness Patterns

Check for these typical issues:

**🔴 No caching:**
```yaml
# Bad: Downloads every time
- task: NuGetCommand@2
  inputs:
    command: restore
```
```yaml
# Good: Uses cache
- task: Cache@2
  inputs:
    key: 'nuget | "$(Agent.OS)" | **/packages.lock.json'
    path: $(NUGET_PACKAGES)
- task: NuGetCommand@2
  inputs:
    command: restore
```

**🔴 Sequential processing of parallelizable work:**
```powershell
# Bad: Sequential loop
foreach ($file in $files) {
    Process-File $file
}
```
```powershell
# Good: Parallel processing (PowerShell 7+)
$files | ForEach-Object -Parallel {
    Process-File $_
} -ThrottleLimit 8
```

**🔴 Large artifact uploads:**
- Check artifact sizes (should be <100MB)
- Use compression
- Exclude unnecessary files (.pdb, source code)

**🔴 Shallow clone disabled:**
```yaml
# Bad: Full history
- checkout: self
```
```yaml
# Good: Shallow clone
- checkout: self
  fetchDepth: 1
```

**🔴 Agent pool saturation:**
- Check queue time vs. execution time
- If queue time > 2 min regularly, pool is saturated
- Consider self-hosted agents or more parallelism

### 7. Calculate Irreducible Work

Identify tasks that **cannot be optimized:**
- Policy-injected security scans
- External deployments (EV2, Kubernetes rollouts)
- Approval gates
- Artifact registry operations

**Formula:**
```
Realistic floor = Irreducible work + Minimal optimizable work
```

Example:
- Job initialization: 1.5 min (irreducible)
- Security scans: 1.0 min (irreducible, policy-required)
- Deployment execution: 4.0 min (irreducible, external)
- Artifact operations: 0.5 min (optimizable to ~0.5 min)
= **7 minutes realistic floor**

### 8. Develop Optimization Plan

Categorize optimizations by effort and impact:

**🟢 Quick Wins (hours of work):**
- Enable artifact caching
- Increase parallelism limits
- Shallow clone
- Remove redundant tasks

**🟡 Medium Optimizations (days of work):**
- Split jobs for parallelism
- Implement incremental builds
- Test sharding
- Optimize artifact sizes

**🔴 Structural Changes (weeks of work):**
- Self-hosted agents
- Change build system
- Skip stages conditionally
- Rewrite slow tasks

**Output format:**
```markdown
## Optimization Plan

### Phase 1: Quick Wins (1 week, 3-5 min savings)
1. Enable NuGet package caching
   - Expected savings: 2 min
   - Effort: 1 hour
   - Risk: Low

2. Parallelize test execution
   - Expected savings: 3 min
   - Effort: 4 hours
   - Risk: Low

### Phase 2: Medium Optimizations (3-4 weeks, 5-8 min savings)
...
```

### 9. Set Realistic Targets

**Formula:**
```
Achievable target = Irreducible work + Optimized work + Safety margin

Safety margin = 10-15% of (Irreducible + Optimized)
```

Example:
- Irreducible: 7 min
- Optimized work (best case): 2 min
- Safety margin: 1 min
= **10-minute realistic target**

**Red flags:**
- Target < Irreducible work → NOT ACHIEVABLE
- Target < Irreducible + 20% → HIGH RISK (no margin for variance)

## Tools and Scripts

### Compare Builds Script

```bash
#!/bin/bash
# compare_builds.sh - Compare runtimes across multiple builds

BUILDS=(123456 123457 123458)

for BUILD_ID in "${BUILDS[@]}"; do
  az rest --method get \
    --url "https://dev.azure.com/{org}/{project}/_apis/build/builds/${BUILD_ID}?api-version=7.1" \
    --resource 499b84ac-1321-427f-aa17-267ca6975798 \
    | jq -r '"\(.id) | \(.result) | \(.sourceBranch) | \(.startTime) | \(.finishTime)"'
done
```

### Task Duration Extraction

```bash
# Extract top 15 tasks by duration
az rest --method get \
  --url "https://dev.azure.com/{org}/{project}/_apis/build/builds/{buildId}/timeline?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  | jq -r '.records[] | select(.type == "Task" and .startTime != null and .finishTime != null) | 
    (.startTime | fromdateiso8601) as $st | 
    (.finishTime | fromdateiso8601) as $ft | 
    "\($ft - $st)|\(.name)|\(.result)"' \
  | sort -rn | head -15
```

## Example Output: Profiling Report

```markdown
# Pipeline 440977 Performance Profile

## Current State
- Baseline runtime: 28 minutes (median)
- P90 runtime: 35 minutes
- Success rate: 85%
- Agent pool: Azure Pipelines (hosted)

## Top Bottlenecks
1. Build and package: 7m 30s (27% of runtime)
   → Processing 2,252 files sequentially
2. Security scan: 4m 45s (17% of runtime)
   → Policy-required, cannot remove
3. Deploy to staging: 6m 06s (22% of runtime)
   → External EV2 dependency

## Optimization Plan
### Phase 1: Quick Wins (~13 min target)
- Add artifact caching: saves 2 min
- Parallelize file processing: saves 6 min
- Projected runtime: 13 minutes

### Phase 2: Medium (6-11 min target)
- Split jobs for parallel security scans: saves 3 min
- Incremental builds: saves 5-8 min on small PRs
- Projected runtime: 6-11 minutes

## Feasibility
- Requested target: 5 minutes → NOT REALISTIC
- Irreducible work: 8 minutes
- Realistic target: 10 minutes
```

## Integration with Squad Workflow

When completing a pipeline profiling task:

1. **Update history:** `.squad/agents/frank/history.md`
   - Key findings, bottleneck identification, tools used

2. **Decision document:** `.squad/decisions/inbox/frank-{pipeline-name}-optimization.md`
   - Recommended plan, phases, risks, action items

3. **Update this skill:** If you discover new profiling techniques

## Related Skills

- `monitor-ado-pipeline` — Check status and logs of running builds
- `release-monitor` — Extract approval links from OneBranch builds
- `configgen-development` — ConfigGen-specific build patterns

## References

- [ADO Build Timeline API](https://learn.microsoft.com/en-us/rest/api/azure/devops/build/timeline)
- [Pipeline caching](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/caching)
- [Parallel jobs](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/phases?view=azure-devops&tabs=yaml#parallelism)
