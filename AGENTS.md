# Personal Skill Publishing

This GitHub repository is the canonical source for Shay Gabison's personal
Copilot plugin and shared skills.

When creating or updating a personal skill:

1. Author the skill under `~/.copilot/skills/<name>/` or
   `~/.squad/skills/<name>/`.
2. Run `./sync-skills.sh --skill <name>` from this repository.
3. Do not consider the task complete until the script pushes the change and
   successfully runs `copilot plugin update shaygabison-personal-skills`.
4. Return the generated `npx skills@latest add ...` command so the individual
   skill can be shared independently.

Do not edit files in the installed plugin cache manually. Publish through the
script so the GitHub repository, plugin version, and active installation remain
in sync.
