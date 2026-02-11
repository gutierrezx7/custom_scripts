#!/bin/bash
# =============================================================================
# Scenario: Incompatible Scripts
# =============================================================================

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_TEMP_DIR="$(mktemp -d)"
MOCK_LOG_FILE="$TEST_TEMP_DIR/mock.log"
MOCK_INPUT_FILE="$TEST_TEMP_DIR/input.txt"

# Export for mock sys
export MOCK_LOG_FILE
export MOCK_INPUT_FILE
export CS_DRY_RUN="false"
export CS_VERBOSE="true"
export CS_ENV_TYPE="LXC"
export CS_INSTALL_DIR="$TEST_TEMP_DIR/install"
export CS_LOG_FILE="$TEST_TEMP_DIR/app.log"
export CS_STATE_DIR="$TEST_TEMP_DIR/state"
export CS_VIRT_TYPE="lxc"
export CS_OS="ubuntu"

# Create dummy script (VM only)
mkdir -p "$TEST_TEMP_DIR/cat1"
cat > "$TEST_TEMP_DIR/cat1/vm_script.sh" <<EOF
# Title: Only For VM
# Description: Installs something for VM
# Supported: vm
# Interactive: no
# Network: safe

echo "Running VM script..."
apt-get install -y vm-tools
EOF
chmod +x "$TEST_TEMP_DIR/cat1/vm_script.sh"

# Mock Inputs for whiptail
# Sequence:
# 1. Main Menu -> 3 (List Scripts)
# 2. (List output is stdout, no interaction needed usually, but show_banner might detect)
# 3. Main Menu -> 4 (Exit)
cat > "$MOCK_INPUT_FILE" <<EOF
3
4
EOF

cp "$ROOT_DIR/setup.sh" "$TEST_TEMP_DIR/"
cp -r "$ROOT_DIR/lib" "$TEST_TEMP_DIR/"
mkdir -p "$TEST_TEMP_DIR/.git"
sed -i '2i source "'"$ROOT_DIR/tests/lib/mock_sys.sh"'"' "$TEST_TEMP_DIR/setup.sh"

# Execute
cd "$TEST_TEMP_DIR"
./setup.sh --list > "$TEST_TEMP_DIR/output.log" 2>&1

# Assertions
echo "Checking results..."
# Since CS_VIRT_TYPE=lxc, "Only For VM" should NOT be in the output.
if grep -q "Only For VM" "$TEST_TEMP_DIR/output.log"; then
    echo "FAIL: Incompatible script found in list!"
    cat "$TEST_TEMP_DIR/output.log"
    exit 1
else
    echo "PASS: Incompatible script correctly filtered out."
fi

rm -rf "$TEST_TEMP_DIR"
exit 0
