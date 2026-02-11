#!/bin/bash
# =============================================================================
# Custom Scripts - Test Runner (Impeccable Suite)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$SCRIPT_DIR/scenarios"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "    Running Test Scenarios"
echo "=========================================="
echo ""

PASSED=0
FAILED=0
FAILED_TESTS=()

# Find scenarios
if [[ ! -d "$SCENARIO_DIR" ]]; then
    echo "No scenarios directory found!"
    exit 1
fi

for test_script in "$SCENARIO_DIR"/*.sh; do
    [[ -e "$test_script" ]] || continue

    test_name=$(basename "$test_script")
    echo -n "Running $test_name... "

    # Run test in a subshell, capturing output only on failure?
    # Or streaming it? Streaming is better for CI logs.

    # We use a temp file for output capture to keep line clean
    OUT=$(mktemp)

    if bash "$test_script" > "$OUT" 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        echo "------------------------------------------"
        cat "$OUT"
        echo "------------------------------------------"
        ((FAILED++))
        FAILED_TESTS+=("$test_name")
    fi
    rm -f "$OUT"
done

echo ""
echo "=========================================="
echo "    Summary"
echo "=========================================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Failed Tests:"
    for t in "${FAILED_TESTS[@]}"; do
        echo " - $t"
    done
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
