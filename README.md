# Shay Gabison's Personal Skills

Canonical repository for Shay's GitHub Copilot CLI plugin and individually
shareable agent skills.

## Install the full Copilot plugin

```bash
copilot plugin install https://github.com/gim-home/shaygabison_personal_repo
```

Update it after new skills are published:

```bash
copilot plugin update shaygabison-personal-skills
```

## Install one skill with npx

Use the skill's direct GitHub directory URL so skills under both `skills/` and
`squad-skills/` can be installed reliably:

```bash
npx -y skills@latest add \
  https://github.com/gim-home/shaygabison_personal_repo/tree/main/squad-skills/configgen-development \
  --agent github-copilot \
  --global \
  --yes
```

Generate the correct command for any published skill:

```bash
./sync-skills.sh --skill configgen-development --share
```

## Publish a skill

Skills are authored in `~/.copilot/skills/` or `~/.squad/skills/`. One command
syncs the selected skill into this repository, bumps `plugin.json`, commits,
pushes `main`, updates the installed plugin, and prints its `npx` share command:

```bash
./sync-skills.sh --skill configgen-development
```

Publish all changed local skills:

```bash
./sync-skills.sh
```

Use `--dry-run` to preview or `--no-push` to create only the local commit.
