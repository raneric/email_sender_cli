#!/usr/bin/env bash

set -euo pipefail

# ==========================
# Parse arguments
# ==========================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
HEADERS_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --headers)
            HEADERS_FILE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# ==========================
# Load configuration
# ==========================
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# ==========================
# Load per-dataset headers (overrides defaults)
# ==========================
if [[ -n "$HEADERS_FILE" ]]; then
    if [[ ! -f "$HEADERS_FILE" ]]; then
        echo "Headers file not found: $HEADERS_FILE"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$HEADERS_FILE"
fi

# ==========================
# Validate arguments
# ==========================
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [-c|--config <file>] [--headers <file>] <body_file> <attachment1> [attachment2 ...]"
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