#!/bin/bash

CACHE_FILE="${HOME}/.teams-sender-channels.tsv"

url_decode() {
    python3 - "$1" <<'PY'
import sys, urllib.parse
print(urllib.parse.unquote(sys.argv[1]))
PY
}

parse_channel_url() {
    local url="$1"
    local encoded_channel team_id
    team_id=$(echo "$url" | sed -nE 's/.*[?&]groupId=([^&]+).*/\1/p')
    if [ -z "$team_id" ]; then
        return 1
    fi
    if echo "$url" | grep -q "/l/channel/"; then
        encoded_channel=$(echo "$url" | sed -E 's#.*\/l\/channel\/([^/]+)\/.*#\1#')
        if [ -z "$encoded_channel" ] || [ "$encoded_channel" = "$url" ]; then
            return 1
        fi
        CHANNEL_ID=$(url_decode "$encoded_channel")
    elif echo "$url" | grep -q "/l/message/"; then
        CHANNEL_ID=$(echo "$url" | sed -E 's#.*\/l\/message\/([^/]+)\/.*#\1#')
        if [ -z "$CHANNEL_ID" ] || [ "$CHANNEL_ID" = "$url" ]; then
            return 1
        fi
    else
        return 1
    fi
    TEAM_ID="$team_id"
    return 0
}

upsert_cached_alias() {
    local alias="$1" team_id="$2" channel_id="$3"
    mkdir -p "$(dirname "$CACHE_FILE")"
    touch "$CACHE_FILE"
    awk -F '\t' -v a="$alias" '$1 != a' "$CACHE_FILE" > "${CACHE_FILE}.tmp"
    printf "%s\t%s\t%s\n" "$alias" "$team_id" "$channel_id" >> "${CACHE_FILE}.tmp"
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
}

resolve_cached_alias() {
    local alias="$1"
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi
    local row
    row=$(awk -F '\t' -v a="$alias" '$1 == a {print $0}' "$CACHE_FILE" | tail -n 1)
    if [ -z "$row" ]; then
        return 1
    fi
    TEAM_ID=$(echo "$row" | awk -F '\t' '{print $2}')
    CHANNEL_ID=$(echo "$row" | awk -F '\t' '{print $3}')
    return 0
}

if [ "$1" = "cache-add" ]; then
    ALIAS="$2"
    CHANNEL_URL="$3"
    if [ -z "$ALIAS" ] || [ -z "$CHANNEL_URL" ]; then
        echo "Usage: $0 cache-add <alias> <teams_channel_url>"
        exit 1
    fi
    if ! parse_channel_url "$CHANNEL_URL"; then
        echo "Invalid Teams channel URL."
        exit 1
    fi
    upsert_cached_alias "$ALIAS" "$TEAM_ID" "$CHANNEL_ID"
    echo "Cached alias '$ALIAS' => team '$TEAM_ID', channel '$CHANNEL_ID'."
    exit 0
fi

if [ "$1" = "cache-list" ]; then
    if [ ! -f "$CACHE_FILE" ]; then
        echo "No cached aliases."
        exit 0
    fi
    cat "$CACHE_FILE"
    exit 0
fi

TARGET="$1"
MESSAGE="$2"

if [ -z "$TARGET" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 <target_or_teams_channel_url> <message>"
    echo "Built-in targets: tenant-mgmt, daily, on-call, pr-review, platform-axon-support"
    echo "Cache commands: $0 cache-add <alias> <teams_channel_url> | $0 cache-list"
    exit 1
fi

# Built-in channels
TEAM_ID_MDA_PLATFORM_AXON="829a2297-f598-45a6-bcaa-66a9d8ac3302"
TEAM_ID_DEFENDER_FOR_CLOUD_APPS="7544b4bb-29df-48d3-a90d-eb835f1124a6"
CHANNEL_TAG_NAME=""

case "$TARGET" in
    tenant-mgmt|tenant-management)
        TEAM_ID="$TEAM_ID_MDA_PLATFORM_AXON"
        CHANNEL_ID="19:201a900402b44fa3b94e5aac157c1789@thread.tacv2"
        ;;
    daily)
        TEAM_ID="$TEAM_ID_MDA_PLATFORM_AXON"
        CHANNEL_ID="19:a91f69d2231b4696b692cf7a315e09ba@thread.tacv2"
        ;;
    on-call)
        TEAM_ID="$TEAM_ID_MDA_PLATFORM_AXON"
        CHANNEL_ID="19:18bf13ccaeb2480db5034adcda0c41e6@thread.tacv2"
        ;;
    pr-review|pr-reviewers)
        TEAM_ID="$TEAM_ID_MDA_PLATFORM_AXON"
        CHANNEL_ID="19:27a43689b9694916b088c63503925e9b@thread.tacv2"
        ;;
    platform-axon-support|defender-axon-support)
        TEAM_ID="$TEAM_ID_DEFENDER_FOR_CLOUD_APPS"
        CHANNEL_ID="19:65b1762b40a544d1950e856550173436@thread.skype"
        ;;
    release-approval|release-approvals)
        TEAM_ID="$TEAM_ID_MDA_PLATFORM_AXON"
        CHANNEL_ID="19:8f0745dd34694e20b26ea7f108937c10@thread.tacv2"
        CHANNEL_TAG_NAME="Release approvals"
        ;;
    https://teams.microsoft.com/l/channel/*|https://teams.microsoft.com/l/message/*)
        if ! parse_channel_url "$TARGET"; then
            echo "Could not parse Teams channel/message URL."
            exit 1
        fi
        ;;
    *)
        if ! resolve_cached_alias "$TARGET"; then
            echo "Unknown target: $TARGET"
            echo "Use a Teams channel URL directly, or cache one first:"
            echo "  $0 cache-add <alias> <teams_channel_url>"
            echo "Tip: use WorkIQ to find a channel deep-link, then cache it."
            exit 1
        fi
        ;;
esac

URI="https://graph.microsoft.com/v1.0/teams/$TEAM_ID/channels/$CHANNEL_ID/messages"
FORMATTED_HTML=$(python3 - "$MESSAGE" <<'PY'
import html
import re
import sys

message = sys.argv[1]
contains_html = any(tag in message for tag in ("<at ", "<a ", "<div", "<br", "<p", "<span"))

if contains_html:
    content = message
else:
    content = html.escape(message)
    content = re.sub(r'(https?://[^\s<]+)', r'<a href="\1">\1</a>', content)
    content = content.replace('\n', '<br/>')

if re.match(r'^\s*<div>', content):
    content = re.sub(r'^\s*<div>', '<div>🤖 ', content, count=1)
else:
    content = f"<div>🤖 {content}</div>"

print(content)
PY
)

REQUEST_BODY=$(python3 - "$FORMATTED_HTML" "$CHANNEL_ID" "$CHANNEL_TAG_NAME" <<'PY'
import json
import sys

content = sys.argv[1]
channel_id = sys.argv[2] if len(sys.argv) > 2 else ""
channel_name = sys.argv[3] if len(sys.argv) > 3 else ""

payload = {"body": {"contentType": "html", "content": content}}

if channel_name:
    # Prepend channel @mention tag to the message
    mention_html = f'<at id="0">{channel_name}</at> '
    payload["body"]["content"] = mention_html + content
    payload["mentions"] = [{
        "id": 0,
        "mentionText": channel_name,
        "mentioned": {
            "conversation": {
                "id": channel_id,
                "displayName": channel_name,
                "conversationIdentityType": "channel"
            }
        }
    }]

print(json.dumps(payload))
PY
)

echo "Sending message to '$TARGET' (team: $TEAM_ID, channel: $CHANNEL_ID)..."

OUTPUT=$(az rest --method POST \
  --uri "$URI" \
  --headers "Content-Type=application/json" \
  --body "$REQUEST_BODY" \
  --resource "https://graph.microsoft.com/" 2>&1)

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "Message sent successfully."
else
    echo "Failed to send message."
    echo "Error details:"
    echo "$OUTPUT"
    if [[ "$OUTPUT" == *"Forbidden"* ]] || [[ "$OUTPUT" == *"Missing scope permissions"* ]]; then
        echo ""
        echo "Missing Graph channel message permissions; run:"
        echo "  az login --allow-no-subscriptions"
    fi
    exit 1
fi
