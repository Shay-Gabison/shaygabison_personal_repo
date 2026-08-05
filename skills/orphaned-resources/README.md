# Orphaned Resources

Find **orphaned, unused, or idle Azure network resources** across MDA subscriptions using
Kusto queries against IPAM and Azure Resource Graph.

## What it does

Covers 16 resource types: Public IP Prefixes, Unassociated Public IPs, AppGW Public IPs,
Application Gateways, Load Balancers, VNETs, Subnets, NAT Gateways, Bastion Hosts, NICs,
NSGs, Private Endpoints, Private Link Services, Deallocated VMs, and IPAM IP lookup.

It queries via a Kusto MCP and cross-references:
- **IPAM** (`IpamReport`) — subscription discovery and IP lookups
- **Azure Resource Graph** — resource state across regions

It also encodes the cross-cluster workaround for `GetSubscriptionsAssociatedWith()` (which
fails in cross-cluster calls) by deriving subscriptions from IPAM instead.

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## How to use

> *"Find orphaned public IPs across our subscriptions"*
> *"List unused load balancers and NAT gateways"*
> *"Which VNETs/subnets are empty?"*
> *"Look up which resource owns this IP in IPAM"*

## Installation

```bash
./.ai-tools/install.sh --skill orphaned-resources
```

Requires a configured Kusto/ADX MCP and VPN + `az login` (see [docs/setup.md](docs/setup.md)).

## Credits

Created and led by **Amit Cohen**, who built the underlying orphaned-resources dashboards and is driving this cleanup effort. This skill packages that work into a reusable Agent Skill.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions and the 16 orphan-detection queries |
| `docs/setup.md` | Prerequisites and Kusto MCP configuration |
| `evals/evals.json` | Behavioral evaluations |
