# Setup: skills-config

This skill has no config file of its own — it *is* the configuration helper for all **MDA AI Tools** skills.

## How to Invoke

After installing any MDA AI skills (via submodule or Copilot CLI plugin), simply tell your AI agent:

> "Configure my installed skills"

or

> "Help me fill in the config files for the AI tools"

The agent will detect which skills are installed, find the template files in each skill's `templates/` directory, auto-resolve `{{PLACEHOLDER}}` values from workspace context and MCP tools, ask you only for values it can't determine, and write each file only after you approve it.

## What It Configures

Template files that were copied to each skill's `templates/` directory during installation. Each skill's `docs/setup.md` describes what the templates are and where the configured files should be placed.

## Re-running

You can run this skill at any time. If a template is already fully configured (no `{{` patterns remain), the agent will offer to review and update it or skip it.

## Skill Discovery

See [`reference/skill-discovery.md`](../reference/skill-discovery.md) for the full list of paths to search when skills cannot be found at the path provided by the prompt.
