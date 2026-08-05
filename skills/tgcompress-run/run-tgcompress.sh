#!/bin/bash
# tgcompress-run: thin wrapper around the ADO REST API to queue an Official Build
# (when needed) and an Official Release for TGCompress.
#
# Does NOT post the approval ASK or run the Kusto validation — those steps need
# the agent's reasoning. The script prints the build IDs to stdout and exits.
#
# Usage:
#   run-tgcompress.sh <action> <environment> [--skip-build] [--branch refs/heads/main]
#
# Examples:
#   run-tgcompress.sh full-orphans-dry-run PROD-3
#   run-tgcompress.sh full-orphans-dry-run PROD-4 --skip-build
#   run-tgcompress.sh "Backup + Plan + Compress" PROD-2

set -euo pipefail

ORG="msazure"
PROJECT="MCAS"
BUILD_PIPELINE_ID=429493     # TGCompress.Job.Official.Build
RELEASE_PIPELINE_ID=433104   # TGCompress.Job.Official.Release
BRANCH="refs/heads/main"
SKIP_BUILD=0

ALLOWED_ACTIONS=(
  "Backup + Plan"
  "Plan + Validate"
  "Recover"
  "Backup + Plan + Compress"
  "dry-run"
  "full-orphans-dry-run"
  "full-orphans"
  "contoso-full-orphans-dry-run"
  "contoso-full-orphans"
  "sync_groups_tenants_counts"
  "Sleep"
)
ALLOWED_ENVS=("RS" "GCCM" "GPRD" "PROD-1" "PROD-2" "PROD-3" "PROD-4" "PROD-5")

usage() {
  echo "Usage: $0 <action> <environment> [--skip-build] [--branch <refs/heads/...>]"
  echo ""
  echo "Allowed actions:"
  printf "  - %s\n" "${ALLOWED_ACTIONS[@]}"
  echo ""
  echo "Allowed environments:"
  printf "  - %s\n" "${ALLOWED_ENVS[@]}"
  exit 1
}

contains() {
  local needle="$1"; shift
  local hay
  for hay in "$@"; do
    [ "$hay" = "$needle" ] && return 0
  done
  return 1
}

if [ $# -lt 2 ]; then
  usage
fi

ACTION="$1"
ENVIRONMENT="$2"
shift 2

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --branch) BRANCH="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown flag: $1"; usage ;;
  esac
  shift
done

if ! contains "$ACTION" "${ALLOWED_ACTIONS[@]}"; then
  echo "❌ Invalid action: '$ACTION'"; usage
fi
if ! contains "$ENVIRONMENT" "${ALLOWED_ENVS[@]}"; then
  echo "❌ Invalid environment: '$ENVIRONMENT'"; usage
fi

# Fetch AAD token for ADO REST API
TOKEN=$(az account get-access-token \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --query accessToken -o tsv)
if [ -z "$TOKEN" ]; then
  echo "❌ Could not get AAD token. Run 'az login' first."
  exit 1
fi
AUTH_HEADER=("Authorization: Bearer $TOKEN")

ADO_BASE="https://dev.azure.com/$ORG/$PROJECT/_apis"

queue_pipeline() {
  local pipeline_id="$1" body="$2"
  curl -sf -X POST \
    -H "Content-Type: application/json" \
    -H "${AUTH_HEADER[0]}" \
    --data "$body" \
    "$ADO_BASE/pipelines/$pipeline_id/runs?api-version=7.0"
}

latest_official_build() {
  curl -sf \
    -H "${AUTH_HEADER[0]}" \
    "$ADO_BASE/build/builds?definitions=$BUILD_PIPELINE_ID&branchName=$BRANCH&statusFilter=completed&resultFilter=succeeded&\$top=1&api-version=7.0"
}

# ---- Step 1: build (or reuse) ----
BUILD_ID=""
BUILD_NUMBER=""

if [ "$SKIP_BUILD" -eq 1 ]; then
  echo "→ --skip-build set; finding latest successful official build on $BRANCH..."
  resp=$(latest_official_build)
  BUILD_ID=$(echo "$resp" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["value"][0]["id"]) if d["value"] else ""')
  BUILD_NUMBER=$(echo "$resp" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["value"][0]["buildNumber"]) if d["value"] else ""')
  if [ -z "$BUILD_ID" ]; then
    echo "❌ No successful official build found on $BRANCH. Re-run without --skip-build."
    exit 1
  fi
  echo "✓ Reusing build $BUILD_NUMBER (id=$BUILD_ID)"
else
  echo "→ Triggering new Official Build on $BRANCH..."
  body=$(python3 -c "import json;print(json.dumps({'resources':{'repositories':{'self':{'refName':'$BRANCH'}}}}))")
  resp=$(queue_pipeline "$BUILD_PIPELINE_ID" "$body")
  BUILD_ID=$(echo "$resp" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
  BUILD_NUMBER=$(echo "$resp" | python3 -c 'import json,sys;print(json.load(sys.stdin)["name"])')
  echo "✓ Queued build $BUILD_NUMBER (id=$BUILD_ID)"
  echo "   URL: https://dev.azure.com/$ORG/$PROJECT/_build/results?buildId=$BUILD_ID"
  echo ""
  echo "⏳ Wait for it to finish (~30 min) before queueing the release."
  echo "   The release pipeline auto-picks the latest successful Official Build."
  echo ""
  echo "Exit (skipping release). Re-run with --skip-build once the build succeeds."
  echo ""
  printf 'BUILD_ID=%s\nBUILD_NUMBER=%s\n' "$BUILD_ID" "$BUILD_NUMBER"
  exit 0
fi

# ---- Step 2: queue release ----
echo ""
echo "→ Queueing Official Release: action='$ACTION', environment='$ENVIRONMENT'..."
release_body=$(python3 -c "
import json
print(json.dumps({
  'resources': {'repositories': {'self': {'refName': '$BRANCH'}}},
  'templateParameters': {
    'action': '$ACTION',
    'environment': '$ENVIRONMENT',
    'debug': 'false'
  }
}))
")
resp=$(queue_pipeline "$RELEASE_PIPELINE_ID" "$release_body")
RELEASE_ID=$(echo "$resp" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
RELEASE_NUMBER=$(echo "$resp" | python3 -c 'import json,sys;print(json.load(sys.stdin)["name"])')
echo "✓ Queued release $RELEASE_NUMBER (id=$RELEASE_ID)"
echo "   URL: https://dev.azure.com/$ORG/$PROJECT/_build/results?buildId=$RELEASE_ID"

# ---- Output ----
echo ""
echo "==== Summary ===="
printf 'BUILD_ID=%s\n'           "$BUILD_ID"
printf 'BUILD_NUMBER=%s\n'       "$BUILD_NUMBER"
printf 'RELEASE_ID=%s\n'         "$RELEASE_ID"
printf 'RELEASE_NUMBER=%s\n'     "$RELEASE_NUMBER"
printf 'ACTION=%s\n'             "$ACTION"
printf 'ENVIRONMENT=%s\n'        "$ENVIRONMENT"
echo ""
echo "Next steps for the agent:"
echo "  1. Wait for the *_APPROVAL stage on release $RELEASE_ID"
echo "  2. Extract the approval URL (use release-monitor skill or read the approval stage log)"
echo "  3. Compose the SDP ASK using release-approval-template skill"
echo "  4. Send via: ~/.copilot/skills/teams-sender/send-message.sh release-approval \"<ASK>\""
echo "  5. After approval clears, poll Kusto (orchestration DB, tgcompress table) for planner logs"
