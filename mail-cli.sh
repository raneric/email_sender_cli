#!/usr/bin/env bash

set -euo pipefail

# ==========================
# Paths
# ==========================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATASET_DIR="$SCRIPT_DIR/datasets"
SEND_NO_ATTACH="$SCRIPT_DIR/send_mail.sh"
SEND_WITH_ATTACH="$SCRIPT_DIR/send_mail_attachment.sh"

# Optional config override (pass-through to send scripts)
SEND_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            SEND_ARGS+=("--config" "$2")
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# ==========================
# Helper: whiptail radiolist menu
# ==========================
whiptail_menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    local -a args=("$@")
    local height=$(( ${#args[@]} / 2 + 8 ))

    whiptail --title "$title" \
             --radiolist "$prompt" \
             "$height" 60 $(( ${#args[@]} / 2 )) \
             "${args[@]}" \
             3>&1 1>&2 2>&3
}

# ==========================
# Helper: send a single dataset
# ==========================
send_dataset() {
    local dataset_path="$1"
    local body_file="$dataset_path/body.txt"
    local headers_file="$dataset_path/headers.txt"

    if [[ ! -f "$body_file" ]]; then
        echo "  SKIP: Missing body.txt in $dataset_path"
        return 1
    fi

    # Collect attachments
    local -a attachments=()
    while IFS= read -r file; do
        attachments+=("$file")
    done < <(
        find "$dataset_path" \
            -maxdepth 1 \
            -type f \
            ! -name "body.txt" \
            ! -name "headers.txt" \
            | sort
    )

    # Build send args
    local -a send_args=("${SEND_ARGS[@]}")
    if [[ -f "$headers_file" ]]; then
        send_args+=("--headers" "$headers_file")
    fi

    echo "  Sending: $(basename "$dataset_path")"

    if [[ ${#attachments[@]} -gt 0 ]]; then
        "$SEND_WITH_ATTACH" "${send_args[@]}" "$body_file" "${attachments[@]}"
    else
        "$SEND_NO_ATTACH" "${send_args[@]}" "$body_file"
    fi
}

# ==========================
# Step 1: Choose category
# ==========================
CATEGORY=$(whiptail_menu \
    "Email Dataset CLI" \
    "Choose category:" \
    "with_attachment" "Send email with attachment(s)" "ON" \
    "without_attachment" "Send email without attachment" "OFF")

if [[ -z "$CATEGORY" ]]; then
    echo "Cancelled."
    exit 0
fi

SELECTED_DIR="$DATASET_DIR/$CATEGORY"

if [[ ! -d "$SELECTED_DIR" ]]; then
    echo "Category directory not found: $SELECTED_DIR"
    exit 1
fi

# ==========================
# Step 2: Choose dataset folder (or ALL)
# ==========================
mapfile -t FOLDERS < <(find "$SELECTED_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#FOLDERS[@]} -eq 0 ]]; then
    echo "No datasets found in $SELECTED_DIR"
    exit 1
fi

MENU_ARGS=()
# "ALL" is always first and pre-selected
MENU_ARGS+=("__ALL__" "ALL — send every dataset below" "ON")
for f in "${FOLDERS[@]}"; do
    NAME="$(basename "$f")"
    MENU_ARGS+=("$NAME" "" "OFF")
done

DATASET_NAME=$(whiptail_menu \
    "Email Dataset CLI" \
    "Choose dataset (or ALL):" \
    "${MENU_ARGS[@]}")

if [[ -z "$DATASET_NAME" ]]; then
    echo "Cancelled."
    exit 0
fi

# ==========================
# Step 3: Send (single or all)
# ==========================
if [[ "$DATASET_NAME" == "__ALL__" ]]; then
    # --- Send all ---
    TOTAL=${#FOLDERS[@]}
    echo
    echo "========================================="
    echo "  Sending ALL ($TOTAL datasets)"
    echo "  Category: $CATEGORY"
    echo "========================================="
    echo

    if ! whiptail --title "Confirm" --yesno "Send ALL $TOTAL datasets from \"$CATEGORY\"?" 0 0; then
        echo "Cancelled."
        exit 0
    fi

    SUCCESS=0
    FAIL=0
    for f in "${FOLDERS[@]}"; do
        echo "---"
        if send_dataset "$f"; then
            ((SUCCESS++))
        else
            ((FAIL++))
        fi
    done

    echo
    echo "========================================="
    echo "  Done: $SUCCESS sent, $FAIL skipped/failed"
    echo "========================================="
else
    # --- Send single ---
    DATASET_PATH="$SELECTED_DIR/$DATASET_NAME"
    BODY_FILE="$DATASET_PATH/body.txt"

    if [[ ! -f "$BODY_FILE" ]]; then
        echo "Missing body.txt in $DATASET_PATH"
        exit 1
    fi

    # Collect attachments for summary
    ATTACHMENTS=()
    while IFS= read -r file; do
        ATTACHMENTS+=("$file")
    done < <(
        find "$DATASET_PATH" \
            -maxdepth 1 \
            -type f \
            ! -name "body.txt" \
            ! -name "headers.txt" \
            | sort
    )

    HEADERS_FILE="$DATASET_PATH/headers.txt"

    SUMMARY="Category    : $CATEGORY\nDataset     : $DATASET_NAME\nBody file   : body.txt\n"

    if [[ -f "$HEADERS_FILE" ]]; then
        SUMMARY+="\nHeaders     : headers.txt (custom)\n"
    else
        SUMMARY+="\nHeaders     : (defaults from config.sh)\n"
    fi

    if [[ ${#ATTACHMENTS[@]} -gt 0 ]]; then
        SUMMARY+="\nAttachments :\n"
        for a in "${ATTACHMENTS[@]}"; do
            SUMMARY+="  - $(basename "$a")\n"
        done
    else
        SUMMARY+="\nAttachments : (none)\n"
    fi

    if whiptail --title "Confirm" --yesno "$SUMMARY\n\nSend email?" 0 0; then
        send_dataset "$DATASET_PATH"
    else
        echo "Cancelled."
        exit 0
    fi
fi