#!/bin/bash
# Mock whiptail for testing setup.sh menu navigation

# Log arguments to a file for verification
LOG_FILE="${MOCK_WHIPTAIL_LOG:-/tmp/whiptail.log}"
echo "whiptail $@" >> "$LOG_FILE"

# Determine dialog type
dialog_type=""
args=("$@")
for arg in "${args[@]}"; do
    if [[ "$arg" == "--menu" ]]; then
        dialog_type="menu"
        break
    elif [[ "$arg" == "--checklist" ]]; then
        dialog_type="checklist"
        break
    elif [[ "$arg" == "--yesno" ]]; then
        dialog_type="yesno"
        break
    elif [[ "$arg" == "--inputbox" ]]; then
        dialog_type="inputbox"
        break
    fi
done

# Check state file for predefined responses
state_file="${MOCK_WHIPTAIL_STATE:-/tmp/whiptail_state}"
response=""

# Helper to pop response from state file
pop_response() {
    if [[ -f "$state_file" && -s "$state_file" ]]; then
        response=$(head -n 1 "$state_file")
        # Remove the used response (safely)
        # Using a temp file to avoid race conditions or read/write issues
        tmp_state=$(mktemp)
        tail -n +2 "$state_file" > "$tmp_state"
        mv "$tmp_state" "$state_file"
    fi
}

# Logic based on dialog type
if [[ "$dialog_type" == "menu" ]]; then
    # Main menu navigation
    pop_response
    # If no response configured, default to Exit (4) to prevent infinite loops
    [[ -z "$response" ]] && response="4"

elif [[ "$dialog_type" == "checklist" ]]; then
    # Script selection (checklist)
    pop_response
    # Return whatever is popped (e.g., "1 2")

elif [[ "$dialog_type" == "yesno" ]]; then
    # Confirmation dialogs (yesno)
    # Default to Yes (0) unless overridden via env or state?
    # For simplicity, always Yes (0)
    exit 0

elif [[ "$dialog_type" == "inputbox" ]]; then
    # Input box
    pop_response
fi

# Output response to stderr (fd 2) because whiptail writes selection to stderr
# and setup.sh captures it via 3>&1 1>&2 2>&3
if [[ -n "$response" ]]; then
    echo "$response" >&2
fi

exit 0
