# @mda/skills-cli

Install and manage Copilot CLI skills from shared registries.

## Quick Start

```bash
# Install a skill from the team registry
npx @mda/skills-cli add my-work-export

# List available skills
npx @mda/skills-cli list

# See what's installed
npx @mda/skills-cli installed

# Remove a skill
npx @mda/skills-cli remove my-work-export
```

## How It Works

Skills are Markdown files (`SKILL.md`) that teach Copilot CLI how to perform specific tasks. This CLI fetches them from a shared registry (Git repo) and installs them into your `~/.squad/skills/` directory where Copilot CLI picks them up automatically.

## Sources

```bash
# From the team's shared registry (MDA.Platform.Squad.Skills)
skills add my-work-export

# From a specific skill in the registry
skills add kusto-engine-health-snapshot

# Any skill available in the registry
skills list
```

## Default Registry

The default registry is:
```
https://msazure.visualstudio.com/MCAS/_git/MDA.Platform.Squad.Skills
```

Override with `--registry=<url>` or set in `~/.config/mda-skills/config.json`:
```json
{
  "registry": "https://dev.azure.com/myorg/myproject/_git/my-skills-repo"
}
```

## Available Skills

Run `npx @mda/skills-cli list` to see all skills in the registry, or browse the repo directly.

## For Skill Authors

Create a new skill by adding a directory under `.squad/skills/<skill-name>/` with a `SKILL.md` file. See existing skills for the format (YAML frontmatter + Markdown body).
