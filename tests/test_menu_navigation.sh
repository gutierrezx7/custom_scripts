#!/bin/bash
# Test for setup.sh menu navigation using mocked whiptail

set -euo pipefail

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Create a temporary directory for mocked binaries
MOCK_BIN_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_BIN_DIR"' EXIT

# Symlink mock_whiptail.sh to whiptail
ln -s "$SCRIPT_DIR/mock_whiptail.sh" "$MOCK_BIN_DIR/whiptail"
chmod +x "$SCRIPT_DIR/mock_whiptail.sh"

# Setup Mock Environment
export PATH="$MOCK_BIN_DIR:$PATH"
export MOCK_WHIPTAIL_LOG="/tmp/whiptail_log"
export MOCK_WHIPTAIL_STATE="/tmp/whiptail_state"
export CS_ENV_TYPE="LXC"
export CS_DISTRO="debian"
export CS_DISTRO_VERSION="12"
export CS_DISTRO_PRETTY="Debian GNU/Linux 12 (bookworm)"
export CS_DRY_RUN="true"
export CS_SKIP_ROOT_CHECK="true"
export CS_RUN_LOG="/tmp/custom_scripts_summary.log"
export CS_LOG_FILE="/tmp/custom_scripts.log"
export CS_STATE_DIR="/tmp/custom_scripts_state"
export CS_RESUME_SERVICE_FILE="/tmp/custom-scripts-resume.service"
mkdir -p "$CS_STATE_DIR"
export TERM=xterm # To satisfy tput

# Function to run setup.sh and check result
run_test() {
    local test_name="$1"
    local input_sequence="$2"

    echo "---------------------------------------------------"
    echo "Running Test: $test_name"

    # Clean state
    rm -f "$MOCK_WHIPTAIL_LOG" "$MOCK_WHIPTAIL_STATE"

    # Prepare input (whiptail mock reads line by line)
    # Use printf to ensure newlines
    printf "$input_sequence" > "$MOCK_WHIPTAIL_STATE"

    # Run setup.sh
    # We expect success (exit 0)
    # Use timeout to prevent infinite loops
    if timeout 5s bash "$PROJECT_ROOT/setup.sh" >/tmp/setup_output 2>&1; then
        echo "  [PASS] setup.sh executed successfully."
    else
        echo "  [FAIL] setup.sh returned error or timed out."
        cat /tmp/setup_output
        return 1
    fi

    # Verify whiptail was called
    if [[ -f "$MOCK_WHIPTAIL_LOG" ]]; then
        echo "  [PASS] whiptail was called."
    else
        echo "  [FAIL] whiptail was NOT called."
        return 1
    fi
}

# Scenario 1: Main Menu -> List -> Exit
# Sequence:
# 1. Main Menu (Choice 3: List)
# 2. (List shown)
# 3. Main Menu (Choice 4: Exit)
# Note: Confirmation dialogs default to "Yes" in mock.
run_test "Scenario 1 (List -> Exit)" "3\n4\n"

# Scenario 2: Main Menu -> Select Script -> Confirm -> Exit
# Sequence:
# 1. Main Menu (Choice 2: Select)
# 2. Checklist (Select "0" -> First script)
# 3. (Confirm Execution -> Yes implicitly)
# 4. (Execution logs...)
# 5. Main Menu (Choice 4: Exit)
# Note: Confirmation dialogs default to "Yes" in mock.
run_test "Scenario 2 (Select -> Exec -> Exit)" "2\n0\n4\n"

# Verify output of Scenario 2 contains "Scripts selecionados"
if grep -q "Scripts selecionados" /tmp/setup_output; then
    echo "  [PASS] Script selection confirmed in output."
else
    echo "  [FAIL] 'Scripts selecionados' not found in output."
    cat /tmp/setup_output
    exit 1
fi

echo ""
echo "All menu navigation tests passed! 🎉"
rm -f /tmp/setup_output "$MOCK_WHIPTAIL_LOG" "$MOCK_WHIPTAIL_STATE"
