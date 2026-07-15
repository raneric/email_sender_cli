#!/usr/bin/env bash

set -euo pipefail

# ==========================
# Configuration
# ==========================
SMTP_SERVER="localhost"
SMTP_PORT="587"

USERNAME="test@test.local"
PASSWORD="password123"

FROM_NAME="Test Sender"
FROM="test@test.local"
TO="receiver@test.local"
SUBJECT="Product issue detected"

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <body_file> <attachment1> [attachment2 ...]"
    exit 1
fi

BODY_FILE="$1"
shift

if [[ ! -f "$BODY_FILE" ]]; then
    echo "Body file not found: $BODY_FILE"
    exit 1
fi

ATTACH_ARGS=()

for FILE in "$@"; do
    if [[ ! -f "$FILE" ]]; then
        echo "Attachment not found: $FILE"
        exit 1
    fi

    MIME_TYPE=$(file --mime-type -b "$FILE")
    FILE_NAME=$(basename "$FILE")

    ATTACH_ARGS+=( "--attach-type" "$MIME_TYPE" )
    ATTACH_ARGS+=( "--attach-name" "$FILE_NAME" )
    ATTACH_ARGS+=( "--attach" "@$FILE" )
done

swaks \
    --server "$SMTP_SERVER" \
    --port "$SMTP_PORT" \
    --auth LOGIN \
    --auth-user "$USERNAME" \
    --auth-password "$PASSWORD" \
    --from "$FROM_NAME <$FROM>" \
    --to "$TO" \
    --header "Subject: $SUBJECT" \
    --body "$(cat "$BODY_FILE")" \
    "${ATTACH_ARGS[@]}"

echo "Email sent with $# attachments."