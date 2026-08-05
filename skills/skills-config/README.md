# skills-config

Post-install configuration helper for **MDA AI Tools** skills. Always installed automatically alongside other skills.

Guides the agent through configuring all installed skills by following each skill's own `docs/setup.md`. For every skill, it finds the template files in the skill's `templates/` directory, auto-resolves `{{PLACEHOLDER}}` values from workspace context, MCP tools, and environment, asks the user only for what can't be resolved, and writes the configured files after explicit user approval.

## Triggered automatically

- **Via `install.sh`** — runs `copilot -p "configure my skills"` at the end of every install
- **Via Copilot CLI plugin** — run manually after plugin install: `copilot -p "configure my skills"`

## Also run manually any time

```
"configure my skills"
"set up my ai tools config"
"help me fill in the config files"
```

## Docs

- [Setup guide](docs/setup.md)

