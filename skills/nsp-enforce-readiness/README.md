# NSP Enforce-Readiness

## Purpose

Decide whether a **Network Security Perimeter (NSP)** resource association can be safely
flipped from **Transition (Learning)** mode to **Enforced** mode without blocking any live
traffic — the SFI **NS2.2.1** pre-flight check.

## What it does

- Takes an **NSP ARM ID** and a lookup window (default `7d`).
- Runs the same KQL the [NSP Traffic Analysis Tool](https://aka.ms/NSPTrafficAnalysis) uses,
  against the per-RP NSP access-log clusters (Storage / Cosmos / SQL / Key Vault).
- Returns a **PASS / FAIL verdict per resource**: *"If I enforce this association now, will any
  currently-allowed traffic be denied?"*
- Works **purely from access logs** — no ARM / management-plane calls, so it runs even without
  `Microsoft.Network/networkSecurityPerimeters/*/read` permissions.

A resource is flagged **NOT safe** if its logs contain `NspPublicInboundResourceRulesAllowed`
or `NspPublicOutboundResourceRulesAllowed` events in the window — traffic only the PaaS
firewall is currently allowing, which Enforced mode would deny.

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## How to use

> *"Can I enforce this NSP? /subscriptions/…/networkSecurityPerimeters/my-nsp"*
> *"Is this resource ready for enforced mode? Check the last 30 days."*
> *"Run the NS2.2.1 pre-flight on my NSP association."*

## Installation

Install into the canonical cross-agent path (`.agents/skills/`) via the repo helper:

```bash
./.ai-tools/install.sh --skill nsp-enforce-readiness
```

The **Supported Agents** paths above are where the helper links the skill for each agent — you don't copy them manually. See [docs/setup.md](docs/setup.md) for the MCP/VPN prerequisites.

Requires a configured Kusto/ADX MCP and VPN + `az login` (see [docs/setup.md](docs/setup.md)).

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions (verdict logic + KQL) |
| `docs/setup.md` | Prerequisites and Kusto MCP configuration |
| `evals/evals.json` | Behavioral evaluations |
