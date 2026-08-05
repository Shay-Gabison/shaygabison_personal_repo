#!/usr/bin/env bash
#
# sync-skills.sh — Sync local Copilot skills to the GitHub plugin repo
#
# Usage:
#   ./sync-skills.sh                    # sync all skills
#   ./sync-skills.sh --skill kusto      # sync one skill
#   ./sync-skills.sh --dry-run          # preview changes
#   ./sync-skills.sh --no-push          # commit but don't push
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
COPILOT_SKILLS="$HOME/.copilot/skills"
SQUAD_SKILLS="$HOME/.squad/skills"
DRY_RUN=false
NO_PUSH=false
SINGLE_SKILL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)   DRY_RUN=true; shift ;;
    --no-push)   NO_PUSH=true; shift ;;
    --skill)     SINGLE_SKILL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--skill <name>] [--dry-run] [--no-push]"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🔄 Syncing skills to plugin repo..."

# --- Copilot skills ---
if [ -n "$SINGLE_SKILL" ]; then
  skills=("$SINGLE_SKILL")
else
  skills=()
  for d in "$COPILOT_SKILLS"/*/; do
    name=$(basename "$d")
    # Skip backups
    [[ "$name" == *.bak.* ]] && continue
    skills+=("$name")
  done
fi

changed=0
for skill in "${skills[@]}"; do
  src="$COPILOT_SKILLS/$skill"
  dst="$REPO_DIR/skills/$skill"
  if [ ! -d "$src" ]; then
    echo "  ⚠️  $skill not found in $COPILOT_SKILLS, skipping"
    continue
  fi
  if $DRY_RUN; then
    echo "  [dry-run] Would sync: $skill"
    changed=$((changed + 1))
  else
    rm -rf "$dst"
    cp -r "$src" "$dst"
    echo "  ✅ $skill"
    changed=$((changed + 1))
  fi
done

# --- Squad skills ---
if [ -z "$SINGLE_SKILL" ] && [ -d "$SQUAD_SKILLS" ]; then
  for d in "$SQUAD_SKILLS"/*/; do
    name=$(basename "$d")
    src="$SQUAD_SKILLS/$name"
    dst="$REPO_DIR/squad-skills/$name"
    if $DRY_RUN; then
      echo "  [dry-run] Would sync squad skill: $name"
    else
      rm -rf "$dst"
      cp -r "$src" "$dst"
      echo "  ✅ squad/$name"
    fi
    changed=$((changed + 1))
  done
fi

if [ "$changed" -eq 0 ]; then
  echo "Nothing to sync."
  exit 0
fi

$DRY_RUN && { echo "Dry run complete. $changed skills would be synced."; exit 0; }

# --- Bump version ---
cd "$REPO_DIR"
current=$(jq -r .version plugin.json)
IFS='.' read -r major minor patch <<< "$current"
new_version="$major.$minor.$((patch + 1))"
jq --arg v "$new_version" '.version = $v' plugin.json > plugin.json.tmp
mv plugin.json.tmp plugin.json
echo "📦 Version: $current → $new_version"

# --- Git commit & push ---
git add -A
if git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

git commit -m "Sync skills v$new_version

Updated $changed skill(s) from local environment."

if $NO_PUSH; then
  echo "Committed locally (--no-push). Run 'git push' when ready."
else
  git push
  echo "🚀 Pushed v$new_version to origin"
fi

# --- Update local plugin cache ---
PLUGIN_CACHE="$HOME/.copilot/installed-plugins/_direct/https---github-com-gim--home-shaygabison_personal_repo"
if [ -d "$PLUGIN_CACHE" ]; then
  echo "🔄 Updating local plugin cache..."
  cd "$PLUGIN_CACHE"
  git pull --ff-only 2>/dev/null && echo "  ✅ Plugin cache updated" || echo "  ⚠️  Cache update failed — run '/plugin update' manually"
fi

echo "✨ Done! Skills synced and plugin updated."
