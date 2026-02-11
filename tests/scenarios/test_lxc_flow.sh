#!/bin/bash
# =============================================================================
# Scenario: LXC Environment - Select and Run Script
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
export CS_SKIP_ROOT_CHECK="true"
export CS_FORCE_INTERACTIVE="true"

# Create dummy script
mkdir -p "$TEST_TEMP_DIR/cat1"
cat > "$TEST_TEMP_DIR/cat1/test_script.sh" <<EOF
# Title: Test Script LXC
# Description: Installs something
# Supported: lxc, vm
# Interactive: no
# Network: safe

echo "Running test script..."
apt-get install -y nginx
EOF
chmod +x "$TEST_TEMP_DIR/cat1/test_script.sh"

# Mock Inputs for whiptail
# Sequence:
# 1. Main Menu -> 2 (Select Scripts)
# 2. Checklist -> "0" (Select first item)
# 3. Confirmation -> Yes (default)
# 4. Main Menu -> 4 (Exit)
cat > "$MOCK_INPUT_FILE" <<EOF
2
"0"
yes
4
EOF

# Run setup.sh with overridden SCRIPT_DIR (to scan temp dir)
# We need to hack SCRIPT_DIR or pass it? setup.sh uses its own dir.
# Solution: We source setup.sh functions but run main manually?
# Or we just run setup.sh and let it scan its own directory?
# The registry scan takes a directory. We can patch setup.sh to accept --scan-dir?
# No, registry.sh scans based on SCRIPT_DIR.
# Let's override SCRIPT_DIR by symlinking setup.sh to temp dir.

cp "$ROOT_DIR/setup.sh" "$TEST_TEMP_DIR/"
cp -r "$ROOT_DIR/lib" "$TEST_TEMP_DIR/"
mkdir -p "$TEST_TEMP_DIR/.git"
# Mock sys needs to be sourced inside setup.sh?
# No, we can source it via LD_PRELOAD equivalent or just inject it.
# Simplest: Modify the copied setup.sh to source mock_sys.sh at top.

sed -i '2i source "'"$ROOT_DIR/tests/lib/mock_sys.sh"'"' "$TEST_TEMP_DIR/setup.sh"

# Execute
cd "$TEST_TEMP_DIR" || exit 1
timeout 10 ./setup.sh > "$TEST_TEMP_DIR/output.log" 2>&1

# Assertions
echo "Checking results..."
if grep -q "apt-get install -y nginx" "$MOCK_LOG_FILE"; then
    echo "PASS: apt-get called correctly."
else
    echo "FAIL: apt-get NOT called."
    [[ -f "$MOCK_LOG_FILE" ]] && cat "$MOCK_LOG_FILE"
    echo "--- OUTPUT LOG ---"
    cat "$TEST_TEMP_DIR/output.log"
    exit 1
fi

if grep -q "Test Script LXC" "$TEST_TEMP_DIR/output.log"; then
    echo "PASS: Script title found in output."
else
    echo "FAIL: Script title NOT found in output."
    exit 1
fi

rm -rf "$TEST_TEMP_DIR"
exit 0
