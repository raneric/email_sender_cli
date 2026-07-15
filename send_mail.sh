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

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <body_file>"
    exit 1
fi

BODY_FILE="$1"

if [[ ! -f "$BODY_FILE" ]]; then
    echo "Body file not found: $BODY_FILE"
    exit 1
fi

swaks \
    --server "$SMTP_SERVER" \
    --port "$SMTP_PORT" \
    --auth LOGIN \
    --auth-user "$USERNAME" \
    --auth-password "$PASSWORD" \
    --from "$FROM_NAME <$FROM>" \
    --to "$TO" \
    --header "Subject: $SUBJECT" \
    --body "$(cat "$BODY_FILE")"

echo "Email sent using $BODY_FILE"