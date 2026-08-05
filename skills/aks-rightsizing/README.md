# AKS Rightsizing

Analyzes MDA AKS workloads using Geneva Monitoring data and Eng Hub rightsizing guidance so an agent can recommend safer CPU, memory, and scaling settings, compare clusters, and optionally turn those findings into PRs or ADO follow-up work.

## What it does

Reads the team-local rightsizing config plus the shipped methodology guides, queries Geneva for utilization and scaling signals, and turns those signals into structured rightsizing recommendations for MDA services.

## Key features

- CPU and memory request analysis
- CPU throttling and tight-limit detection
- HPA / KEDA optimization guidance
- JVM heap-to-container memory alignment
- Cross-cluster comparison and drift detection
- PR generation handoff via `pr-generator`
- ADO work item tracking for follow-up actions

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## When to use

> *"Analyze the rightsizing potential for service X"*
> *"Check whether this AKS service is over-provisioned on CPU or memory"*
> *"Should we lower HPA min replicas for this worker?"*
> *"Generate a rightsizing PR for this service"*

Use this skill for MDA AKS pod rightsizing, CPU / memory request and limit analysis, HPA / KEDA tuning guidance, JVM alignment, and cluster-by-cluster comparison.

## When NOT to use

- Direct Kusto / ADX log queries — use the `kusto` skill
- General Geneva monitoring asks that are not about rightsizing — use `geneva-monitoring`
- Non-MDA cluster analysis

## Installation

```bash
./.ai-tools/install.sh --skill aks-rightsizing
```

Then follow the configuration prompts, or ask your agent: *"configure aks-rightsizing"*

## Dependencies

- A Geneva MCP server with access to `WCDProduction` / `WCDPRDInfraSystem`
- The `pr-generator` skill for PR creation workflows
- Optional ADO MCP connectivity for tracking User Stories

## Setup

See [docs/setup.md](docs/setup.md) for prerequisites, template configuration, verification, and dependency setup.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions |
| `docs/setup.md` | Configuration reference |
| `assets/report-template.html` | HTML/CSS template for generated reports |
| `templates/aks-rightsizing-config.md` | Project config template |
| `library/geneva-dashboard-guide.md` | Metric discovery and Geneva query guidance |
| `library/rightsizing-rules.md` | Thresholds and recommendation rules |
| `library/analysis-methodology.md` | Confidence, savings, and reporting methodology |
| `library/mda-cluster-inventory.md` | Complete MDA cluster inventory (Core + Inline) |
| `library/pr-generation-guide.md` | PR and config-edit workflow guidance |
| `library/html-report-guide.md` | Report generation structure and conventions |
| `library/java-memory-guide.md` | JVM memory sizing guidance for Java services |
| `evals/evals.json` | Manual eval test cases |
