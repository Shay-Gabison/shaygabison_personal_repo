#!/usr/bin/env bash
#
# Publish local Copilot skills to the canonical GitHub plugin repository.
#
# Usage:
#   ./sync-skills.sh                         # publish all changed skills
#   ./sync-skills.sh --skill kusto           # publish one skill
#   ./sync-skills.sh --skill kusto --share   # print its npx install command
#   ./sync-skills.sh --dry-run               # preview changes
#   ./sync-skills.sh --no-push               # commit but do not push/update
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
COPILOT_SKILLS="$HOME/.copilot/skills"
SQUAD_SKILLS="$HOME/.squad/skills"
PLUGIN_NAME="shaygabison-personal-skills"
GITHUB_REPO="gim-home/shaygabison_personal_repo"
DRY_RUN=false
NO_PUSH=false
SINGLE_SKILL=""
SHARE_ONLY=false
synced_paths=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --no-push) NO_PUSH=true; shift ;;
    --skill)
      [ $# -ge 2 ] || { echo "ERROR: --skill requires a skill name"; exit 1; }
      SINGLE_SKILL="$2"
      shift 2
      ;;
    --share) SHARE_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--skill <name>] [--share] [--dry-run] [--no-push]"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

share_skill() {
  local skill="$1"
  local relative_path=""

  if [ -f "$REPO_DIR/skills/$skill/SKILL.md" ]; then
    relative_path="skills/$skill"
  elif [ -f "$REPO_DIR/squad-skills/$skill/SKILL.md" ]; then
    relative_path="squad-skills/$skill"
  else
    echo "ERROR: Skill '$skill' is not published in this repository."
    exit 1
  fi

  local url="https://github.com/$GITHUB_REPO/tree/main/$relative_path"
  echo
  echo "Share URL:"
  echo "  $url"
  echo
  echo "One-command install:"
  echo "  npx -y skills@latest add $url --agent github-copilot --global --yes"
}

if $SHARE_ONLY; then
  [ -n "$SINGLE_SKILL" ] || {
    echo "ERROR: --share requires --skill <name>."
    exit 1
  }
  share_skill "$SINGLE_SKILL"
  exit 0
fi

if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
  echo "ERROR: The skill repository has uncommitted changes."
  echo "Commit or stash them before publishing so unrelated work is not included."
  exit 1
fi

sync_skill() {
  local src="$1"
  local destination_root="$2"
  local skill
  local dst

  skill="$(basename "$src")"
  [[ "$skill" == *.bak.* ]] && return
  [ -f "$src/SKILL.md" ] || return

  dst="$REPO_DIR/$destination_root/$skill"
  if [ -d "$dst" ] && diff -qr "$src" "$dst" >/dev/null; then
    return
  fi

  if $DRY_RUN; then
    echo "  [dry-run] Would sync $src -> $destination_root/$skill"
  else
    rm -rf "$dst"
    cp -r "$src" "$dst"
    echo "  Synced $destination_root/$skill"
  fi
  synced_paths+=("$destination_root/$skill")
}

echo "Syncing skills to $GITHUB_REPO..."

if [ -n "$SINGLE_SKILL" ]; then
  found=false
  if [ -d "$COPILOT_SKILLS/$SINGLE_SKILL" ]; then
    sync_skill "$COPILOT_SKILLS/$SINGLE_SKILL" "skills"
    found=true
  fi
  if [ -d "$SQUAD_SKILLS/$SINGLE_SKILL" ]; then
    sync_skill "$SQUAD_SKILLS/$SINGLE_SKILL" "squad-skills"
    found=true
  fi
  if ! $found; then
    echo "ERROR: Skill '$SINGLE_SKILL' was not found in:"
    echo "  $COPILOT_SKILLS"
    echo "  $SQUAD_SKILLS"
    exit 1
  fi
else
  for source_root in "$COPILOT_SKILLS:skills" "$SQUAD_SKILLS:squad-skills"; do
    source_dir="${source_root%%:*}"
    destination_root="${source_root##*:}"
    [ -d "$source_dir" ] || continue
    for skill_dir in "$source_dir"/*/; do
      [ -d "$skill_dir" ] || continue
      sync_skill "${skill_dir%/}" "$destination_root"
    done
  done
fi

if [ "${#synced_paths[@]}" -eq 0 ]; then
  echo "Nothing to publish."
  if [ -n "$SINGLE_SKILL" ]; then
    share_skill "$SINGLE_SKILL"
  fi
  exit 0
fi

if $DRY_RUN; then
  echo "Dry run complete. ${#synced_paths[@]} skill path(s) would be synced."
  exit 0
fi

cd "$REPO_DIR"
current=$(jq -r .version plugin.json)
IFS='.' read -r major minor patch <<< "$current"
new_version="$major.$minor.$((patch + 1))"
jq --arg v "$new_version" '.version = $v' plugin.json > plugin.json.tmp
mv plugin.json.tmp plugin.json
echo "Plugin version: $current -> $new_version"

git add -A
git commit -m "Sync skills v$new_version

Updated ${#synced_paths[@]} skill path(s) from the local skill sources."

if $NO_PUSH; then
  echo "Committed locally (--no-push). Run 'git push' when ready."
else
  git push
  echo "Pushed v$new_version to origin."
  copilot plugin update "$PLUGIN_NAME"
  echo "Updated installed plugin '$PLUGIN_NAME'."
fi

if [ -n "$SINGLE_SKILL" ]; then
  share_skill "$SINGLE_SKILL"
fi
