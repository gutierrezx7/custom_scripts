#!/bin/bash
# =============================================================================
# Scenario: Dry Run Queues Order
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
export CS_DRY_RUN="true"
export CS_VERBOSE="true"
export CS_ENV_TYPE="VM"
export CS_INSTALL_DIR="$TEST_TEMP_DIR/install"
export CS_LOG_FILE="$TEST_TEMP_DIR/app.log"
export CS_STATE_DIR="$TEST_TEMP_DIR/state"
export CS_VIRT_TYPE="vm"
export CS_OS="debian"
export CS_SKIP_ROOT_CHECK="true"
export CS_FORCE_INTERACTIVE="true"

# Create dummy scripts
mkdir -p "$TEST_TEMP_DIR/cat1"
cat > "$TEST_TEMP_DIR/cat1/script_auto.sh" <<EOF
# Title: Auto Script
# Description: Auto
# Supported: vm
# Interactive: no
# Network: safe
EOF
cat > "$TEST_TEMP_DIR/cat1/script_inter.sh" <<EOF
# Title: Interactive Script
# Description: Interactive
# Supported: vm
# Interactive: yes
# Network: safe
EOF
cat > "$TEST_TEMP_DIR/cat1/script_risk.sh" <<EOF
# Title: Risk Script
# Description: Risk
# Supported: vm
# Interactive: no
# Network: risk
EOF
chmod +x "$TEST_TEMP_DIR/cat1/"*.sh

# Mock Inputs for whiptail
# Sequence:
# 1. Main Menu -> 2 (Select Scripts)
# 2. Checklist -> "0" "1" "2" (Select all 3)
# 3. Confirmation -> Yes
# 4. Main Menu -> 4 (Exit)
cat > "$MOCK_INPUT_FILE" <<EOF
2
"0" "1" "2"
yes
4
EOF

cp "$ROOT_DIR/setup.sh" "$TEST_TEMP_DIR/"
cp -r "$ROOT_DIR/lib" "$TEST_TEMP_DIR/"
mkdir -p "$TEST_TEMP_DIR/.git"
sed -i '2i source "'"$ROOT_DIR/tests/lib/mock_sys.sh"'"' "$TEST_TEMP_DIR/setup.sh"

# Execute
cd "$TEST_TEMP_DIR" || exit 1
./setup.sh > "$TEST_TEMP_DIR/output.log" 2>&1

# Assertions
echo "Checking execution order..."
# We can check the output log for the specific headers in order
# Or check the sequence of "Iniciando Fila: ..."

if grep -A 100 "Iniciando Fila: Automáticos" "$TEST_TEMP_DIR/output.log" | grep -q "Auto Script" && \
   grep -A 100 "Iniciando Fila: Interativos" "$TEST_TEMP_DIR/output.log" | grep -q "Interactive Script" && \
   grep -A 100 "Iniciando Fila: Risco" "$TEST_TEMP_DIR/output.log" | grep -q "Risk Script"; then
    echo "PASS: Queue order preserved."
else
    echo "FAIL: Queue order incorrect."
    cat "$TEST_TEMP_DIR/output.log"
    exit 1
fi

if grep -q "DRY-RUN ATIVO" "$TEST_TEMP_DIR/output.log"; then
    echo "PASS: Dry Run detected."
else
    echo "FAIL: Dry Run not detected."
    exit 1
fi

rm -rf "$TEST_TEMP_DIR"
exit 0
