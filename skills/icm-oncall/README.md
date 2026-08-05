# IcM On-Call

Get the current **on-call Primary Engineers (PE list)** for your configured teams, scraped live
from the IcM portal.

## What it does

- Iterates a configurable registry of teams (team ID + IcM queue, loaded from
  `templates/icm-oncall-config.md`) and opens each team's *current on-call* view in the IcM
  portal.
- Scrapes the Primary (and optionally Backup) engineer per team via Playwright browser
  automation, with an IcM MCP fallback when available.
- Stores results in a local SQL table and prints a clean per-team PE table, flagging teams
  with no configured schedule.

## Supported Agents

Works with any [Agent Skills](https://agentskills.io)-compatible agent that has a Playwright
browser tool available:
- All compliant agents (`.agents/skills/` — recommended cross-agent path)
- GitHub Copilot (`.github/skills/`)
- Cline (`.cline/skills/`)
- Claude (`.claude/skills/`)
- Cursor (`.cursor/skills/`)

## How to use

> *"Who's on call this week?"*
> *"Give me the IcM on-call PE list for all my teams"*
> *"Show the on-call engineers, including backups"*

## Installation

```bash
./.ai-tools/install.sh --skill icm-oncall
```

Requires a Playwright MCP browser, an active Entra session, and a filled-in team registry
config (see [docs/setup.md](docs/setup.md)).

## Configuration

Team-specific values (team IDs, IcM queues, serviceId) are **not** hardcoded — they live in
`templates/icm-oncall-config.md`. Copy it, replace every `{{PLACEHOLDER}}`, and add one row per
team you want on the list. See [docs/setup.md](docs/setup.md) for details.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | AI instructions and scraping workflow |
| `templates/icm-oncall-config.md` | Team registry config (serviceId + per-team rows) — fill the `{{PLACEHOLDER}}` values |
| `docs/setup.md` | Prerequisites (Playwright MCP, IcM auth) and configuration steps |
| `evals/evals.json` | Behavioral evaluations |
