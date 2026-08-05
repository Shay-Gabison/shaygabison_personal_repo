# Reference — NSP Traffic Analysis dashboard

## Canonical KQL source-of-truth (manual/human use only)

The verdict logic in `SKILL.md` replicates the tiles of the public **NSP Traffic
Analysis** dashboard (https://aka.ms/NSPTrafficAnalysis). If you want to inspect the
dashboard's canonical KQL directly, a human can download its definition with the
command below.

> **⚠️ Management-plane call — outside the skill's Kusto-only contract.**
> This is an ARM/management-plane request. The skill itself must **never** run it;
> it is provided here, in docs, purely so a human can inspect the dashboard's raw KQL.

```bash
az rest --method GET \
  --url "https://dashboards.kusto.windows.net/dashboards/0799d844-3039-4736-9d1a-9daab2aff826" \
  --resource "35e917a9-4d95-4062-9d97-5781291353b9" \
  --output-file "/tmp/nsp-traffic-analysis-dashboard.json"
```

The dashboard ID (`0799d844-…`) is the single, public, canonical NSP Traffic Analysis
dashboard — the same for every Microsoft team, not an environment-specific value.
