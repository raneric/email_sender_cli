#!/usr/bin/env bash

set -euo pipefail

# ==========================
# Paths
# ==========================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATASET_DIR="$SCRIPT_DIR/datasets"
SEND_NO_ATTACH="$SCRIPT_DIR/send_mail.sh"
SEND_WITH_ATTACH="$SCRIPT_DIR/send_mail_attachment.sh"

# ==========================
# Helper: whiptail radiolist menu
# ==========================
whiptail_menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    # args: tag1 item1 tag2 item2 ...
    local -a args=("$@")
    local height=$(( ${#args[@]} / 2 + 8 ))

    whiptail --title "$title" \
             --radiolist "$prompt" \
             "$height" 60 $(( ${#args[@]} / 2 )) \
             "${args[@]}" \
             3>&1 1>&2 2>&3
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
# Step 2: Choose dataset folder
# ==========================
mapfile -t FOLDERS < <(find "$SELECTED_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#FOLDERS[@]} -eq 0 ]]; then
    echo "No datasets found in $SELECTED_DIR"
    exit 1
fi

MENU_ARGS=()
FIRST="ON"
for f in "${FOLDERS[@]}"; do
    NAME="$(basename "$f")"
    MENU_ARGS+=("$NAME" "" "$FIRST")
    FIRST="OFF"
done

DATASET_NAME=$(whiptail_menu \
    "Email Dataset CLI" \
    "Choose dataset:" \
    "${MENU_ARGS[@]}")

if [[ -z "$DATASET_NAME" ]]; then
    echo "Cancelled."
    exit 0
fi

DATASET_PATH="$SELECTED_DIR/$DATASET_NAME"

# ==========================
# Step 3: Validate body.txt
# ==========================
BODY_FILE="$DATASET_PATH/body.txt"

if [[ ! -f "$BODY_FILE" ]]; then
    echo "Missing body.txt in $DATASET_PATH"
    exit 1
fi

# ==========================
# Step 4: Collect attachments (if any)
# ==========================
ATTACHMENTS=()
while IFS= read -r file; do
    ATTACHMENTS+=("$file")
done < <(
    find "$DATASET_PATH" \
        -maxdepth 1 \
        -type f \
        ! -name "body.txt" \
        | sort
)

# ==========================
# Step 5: Summary & confirmation
# ==========================
SUMMARY="Category    : $CATEGORY\nDataset     : $DATASET_NAME\nBody file   : body.txt\n"

if [[ ${#ATTACHMENTS[@]} -gt 0 ]]; then
    SUMMARY+="\nAttachments :\n"
    for a in "${ATTACHMENTS[@]}"; do
        SUMMARY+="  - $(basename "$a")\n"
    done
else
    SUMMARY+="\nAttachments : (none)\n"
fi

if whiptail --title "Confirm" --yesno "$SUMMARY\n\nSend email?" 0 0; then
    :
else
    echo "Cancelled."
    exit 0
fi

# ==========================
# Step 6: Send email
# ==========================
if [[ ${#ATTACHMENTS[@]} -gt 0 ]]; then
    "$SEND_WITH_ATTACH" "$BODY_FILE" "${ATTACHMENTS[@]}"
else
    "$SEND_NO_ATTACH" "$BODY_FILE"
fi