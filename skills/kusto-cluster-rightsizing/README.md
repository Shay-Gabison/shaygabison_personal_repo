# Kusto Cluster Right-Sizing

End-to-end **ADX/Kusto cluster right-sizing** — snapshot 30-day Engine Health metrics for a
fleet of clusters, then generate Hold / Scale-in / SKU-change recommendations back into the
same spreadsheet.

## What it does

A single self-contained skill that runs both phases in one shot:

1. **Snapshot** — fetches 30-day Engine Health metrics (77 of them) for every Kusto cluster in
   your fleet from Geneva MDM and appends them as `<Metric> 30dAvg` / `<Metric> 30dMax`
   columns into an xlsx.
2. **Analyze** — applies a decision tree per cluster, writes `Recommendation` and `Why`
   columns, regenerates the `Summary` tab, and colors each data row with a traffic-light
   palette by recommendation. Existing dashboard hyperlinks are preserved.

The Python analyzer is **embedded inside `SKILL.md`** — no external `.py` ships; the agent
writes it to your working directory at runtime (also as `./analyze.py` for transparency).

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## How to use

> *"Right-size these Kusto clusters: <paste names>"*
> *"Snapshot + analyze the fleet in `compute-details.xlsx`"*
> *"Analyze this existing right-sizing xlsx"* — skip the fetch, analyze only
> *"Re-run analysis with the colors"*

## Installation

```bash
./.ai-tools/install.sh --skill kusto-cluster-rightsizing
```

Requires the Geneva monitoring MCP, `dotnet` SDK, and `python3 + openpyxl`
(see [docs/setup.md](docs/setup.md)).

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions + embedded snapshot/analyze pipeline |
| `docs/setup.md` | Prerequisites (Geneva MCP, auth, python deps) |
| `evals/evals.json` | Behavioral evaluations |
