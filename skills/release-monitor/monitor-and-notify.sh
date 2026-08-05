#!/bin/bash
set -euo pipefail

# Monitor an ADO pipeline build for approval gates, extract the approval link,
# and send a release-approval notification to Teams.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEAMS_SENDER="${SCRIPT_DIR}/../teams-sender/send-message.sh"

# Defaults
PROJECT="MCAS"
ORG="msazure"
POLL_INTERVAL=30
MAX_WAIT=1800  # 30 minutes
TEAMS_TARGET="release-approval"
TITLE=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") <buildId> [options]

Monitor an ADO pipeline build for approval gates, extract the approval link,
and post a release-approval notification to Teams.

Arguments:
  buildId                 The ADO build ID to monitor

Options:
  --project <name>        ADO project (default: MCAS)
  --org <name>            ADO organization (default: msazure)
  --title <text>          Short title for the notification (default: auto from build name)
  --target <alias>        Teams channel alias (default: release-approval)
  --poll-interval <sec>   Seconds between polls (default: 30)
  --max-wait <sec>        Max seconds to wait (default: 1800)
  --dry-run               Extract link but don't send Teams message
  -h|--help               Show this help

Examples:
  $(basename "$0") 160534110
  $(basename "$0") 160534110 --title "Fix cross-tenant auth trigger"
  $(basename "$0") 160534110 --dry-run
  $(basename "$0") 160534110 --project MCAS --target release-approval
EOF
    exit 0
}

# Parse args
BUILD_ID=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --project) PROJECT="$2"; shift 2 ;;
        --org) ORG="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --target) TEAMS_TARGET="$2"; shift 2 ;;
        --poll-interval) POLL_INTERVAL="$2"; shift 2 ;;
        --max-wait) MAX_WAIT="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *)
            if [[ -z "$BUILD_ID" ]]; then
                BUILD_ID="$1"; shift
            else
                echo "Unknown argument: $1" >&2; exit 1
            fi
            ;;
    esac
done

if [[ -z "$BUILD_ID" ]]; then
    echo "Error: buildId is required." >&2
    usage
fi

ADO_BASE="https://dev.azure.com/${ORG}/${PROJECT}"
ADO_RESOURCE="499b84ac-1321-427f-aa17-267ca6975798"
BUILD_URL="${ADO_BASE}/_build/results?buildId=${BUILD_ID}"

get_token() {
    az account get-access-token --resource "$ADO_RESOURCE" --query accessToken -o tsv
}

ado_get() {
    local url="$1"
    local token
    token=$(get_token)
    curl -sS -H "Authorization: Bearer $token" "$url"
}

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

# --- Step 1: Get build info ---
log "Fetching build info for build #${BUILD_ID}..."
BUILD_JSON=$(ado_get "${ADO_BASE}/_apis/build/builds/${BUILD_ID}?api-version=7.0")
BUILD_NAME=$(echo "$BUILD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('buildNumber',''))")
BUILD_STATUS=$(echo "$BUILD_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','unknown'))")
BUILD_RESULT=$(echo "$BUILD_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result','') or '')")

log "Build: ${BUILD_NAME}"
log "Status: ${BUILD_STATUS} ${BUILD_RESULT}"

if [[ "$BUILD_STATUS" == "completed" ]]; then
    echo "Build already completed (result: ${BUILD_RESULT}). Nothing to monitor."
    exit 0
fi

# --- Step 2: Poll timeline for approval task ---
log "Polling timeline for approval stages (every ${POLL_INTERVAL}s, max ${MAX_WAIT}s)..."

ELAPSED=0
APPROVAL_URL=""
APPROVAL_EXPIRY=""
APPROVAL_STAGE=""

while [[ $ELAPSED -lt $MAX_WAIT ]]; do
    TIMELINE_JSON=$(ado_get "${ADO_BASE}/_apis/build/builds/${BUILD_ID}/timeline?api-version=7.0")

    # Use python to find approval stages and their "Waiting for Approval" tasks
    RESULT=$(python3 - "$TIMELINE_JSON" <<'PYEOF'
import json, sys

data = json.loads(sys.argv[1])
records = data.get("records", [])

# Build parent lookup
by_id = {r["id"]: r for r in records}

# Find stages with APPROVAL in the name
approval_stages = [r for r in records if r.get("type") == "Stage" and "APPROVAL" in r.get("name", "").upper()]

if not approval_stages:
    print("NO_APPROVAL_STAGE")
    sys.exit(0)

for stage in approval_stages:
    stage_id = stage["id"]
    stage_name = stage["name"]
    stage_state = stage.get("state", "")

    # Find all descendants of this stage
    def get_descendants(parent_id):
        children = [r for r in records if r.get("parentId") == parent_id]
        result = list(children)
        for c in children:
            result.extend(get_descendants(c["id"]))
        return result

    descendants = get_descendants(stage_id)

    # Look for "Waiting for Approval" task
    for d in descendants:
        name = d.get("name", "")
        if "waiting for approval" in name.lower():
            state = d.get("state", "")
            log_id = d.get("log", {}).get("id") if d.get("log") else None
            if state == "completed" and log_id:
                print(f"FOUND|{stage_name}|{log_id}")
                sys.exit(0)
            elif state == "inProgress" and log_id:
                print(f"FOUND|{stage_name}|{log_id}")
                sys.exit(0)
            else:
                print(f"PENDING|{stage_name}|{state}")
                sys.exit(0)

# Approval stage exists but no "Waiting for Approval" task yet
print(f"WAITING|{approval_stages[0]['name']}|{approval_stages[0].get('state','')}")
PYEOF
    )

    case "$RESULT" in
        FOUND\|*)
            APPROVAL_STAGE=$(echo "$RESULT" | cut -d'|' -f2)
            LOG_ID=$(echo "$RESULT" | cut -d'|' -f3)
            log "✅ Found approval task in stage '${APPROVAL_STAGE}' (logId=${LOG_ID})"
            break
            ;;
        PENDING\|*)
            APPROVAL_STAGE=$(echo "$RESULT" | cut -d'|' -f2)
            TASK_STATE=$(echo "$RESULT" | cut -d'|' -f3)
            log "⏳ Approval task in '${APPROVAL_STAGE}' is ${TASK_STATE}..."
            ;;
        WAITING\|*)
            APPROVAL_STAGE=$(echo "$RESULT" | cut -d'|' -f2)
            STAGE_STATE=$(echo "$RESULT" | cut -d'|' -f3)
            log "⏳ Approval stage '${APPROVAL_STAGE}' is ${STAGE_STATE}, waiting for approval task..."
            ;;
        NO_APPROVAL_STAGE)
            log "⏳ No approval stage found yet, waiting..."
            ;;
        *)
            log "⏳ Unexpected result: ${RESULT}"
            ;;
    esac

    # Check if build failed/cancelled
    BUILD_CHECK=$(ado_get "${ADO_BASE}/_apis/build/builds/${BUILD_ID}?api-version=7.0")
    CHECK_STATUS=$(echo "$BUILD_CHECK" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
    CHECK_RESULT=$(echo "$BUILD_CHECK" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result','') or '')")
    if [[ "$CHECK_STATUS" == "completed" ]]; then
        log "❌ Build completed with result: ${CHECK_RESULT}. Aborting."
        exit 1
    fi

    sleep "$POLL_INTERVAL"
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

if [[ -z "${LOG_ID:-}" ]]; then
    log "❌ Timed out waiting for approval task after ${MAX_WAIT}s."
    exit 1
fi

# --- Step 3: Read the approval log ---
log "Reading approval log (logId=${LOG_ID})..."
LOG_CONTENT=$(ado_get "${ADO_BASE}/_apis/build/builds/${BUILD_ID}/logs/${LOG_ID}?api-version=7.0")

# Extract approval URL and expiry
APPROVAL_URL=$(echo "$LOG_CONTENT" | grep -oE 'https://approval\.azengsys\.com/approvalRequest\?id=[A-Za-z0-9]+' | head -1)
APPROVAL_EXPIRY=$(echo "$LOG_CONTENT" | sed -n 's/.*expire on \([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z\).*/\1/p' | head -1)

if [[ -z "$APPROVAL_URL" ]]; then
    log "❌ Could not extract approval URL from log."
    echo "Log content:"
    echo "$LOG_CONTENT"
    exit 1
fi

log "✅ Approval URL: ${APPROVAL_URL}"
log "⏰ Expires: ${APPROVAL_EXPIRY:-unknown}"

# --- Step 4: Determine environment from stage name ---
ENV_TAG=""
case "$APPROVAL_STAGE" in
    *FAIRFAX*|*FF*) ENV_TAG="FF" ;;
    *STAGING*|*STG*) ENV_TAG="STG" ;;
    *PRODUCTION*|*PRD*) ENV_TAG="PRD" ;;
    *MOONCAKE*|*MC*) ENV_TAG="MC" ;;
    *) ENV_TAG=$(echo "$APPROVAL_STAGE" | sed 's/_APPROVAL$//' | head -c 10) ;;
esac

# Auto-generate title from build name if not provided
if [[ -z "$TITLE" ]]; then
    # Convert build name like platform_delete_s360_ns221_resources_20260415.1 → delete-s360-ns221-resources
    TITLE=$(echo "$BUILD_NAME" | sed -E 's/_[0-9]{8}\.[0-9]+$//' | sed 's/^platform_//' | tr '_' '-')
fi

# --- Step 5: Send Teams message ---
MESSAGE="🚀 ${TITLE} ${ENV_TAG} Release Approval

Build: ${BUILD_NAME}
🔗 Build: ${BUILD_URL}
👉 Approve Here: ${APPROVAL_URL}
⏰ Approval expires: ${APPROVAL_EXPIRY:-unknown}"

echo ""
echo "═══════════════════════════════════════════"
echo "$MESSAGE"
echo "═══════════════════════════════════════════"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    log "Dry run — not sending to Teams."
    echo ""
    echo "APPROVAL_URL=${APPROVAL_URL}"
    echo "APPROVAL_EXPIRY=${APPROVAL_EXPIRY:-unknown}"
    echo "BUILD_URL=${BUILD_URL}"
    exit 0
fi

if [[ ! -x "$TEAMS_SENDER" ]]; then
    log "⚠️  Teams sender not found at ${TEAMS_SENDER}. Printing message only."
    exit 0
fi

log "Sending to '${TEAMS_TARGET}' channel..."
bash "$TEAMS_SENDER" "$TEAMS_TARGET" "$MESSAGE"
log "✅ Done!"
