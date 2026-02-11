#!/bin/bash
# tests/repro_gitlab_hang.sh

MOCK_BIN=$(mktemp -d)
trap 'rm -rf "$MOCK_BIN"' EXIT

# Mock grep
cat > "$MOCK_BIN/grep" <<'EOF'
#!/bin/bash
if [[ "$*" == *"/proc/meminfo"* ]]; then
    echo "MemTotal: 3000000 kB"
else
    /usr/bin/grep "$@"
fi
EOF
chmod +x "$MOCK_BIN/grep"

# Mock apt-get
cat > "$MOCK_BIN/apt-get" <<'EOF'
#!/bin/bash
echo "MOCK apt-get $*"
EOF
chmod +x "$MOCK_BIN/apt-get"

# Mock curl
cat > "$MOCK_BIN/curl" <<'EOF'
#!/bin/bash
echo "MOCK curl $*"
EOF
chmod +x "$MOCK_BIN/curl"

export PATH="$MOCK_BIN:$PATH"
export CS_DRY_RUN=true

# Mock setup.sh-like script preparation
cp automation/gitlab-install.sh "$MOCK_BIN/test_gitlab.sh"
# Bypass root check
sed -i 's/if \[ "$EUID" -ne 0 \]; then/if false; then/' "$MOCK_BIN/test_gitlab.sh"

echo "Starting gitlab-install.sh with open stdin (expected to pass instantly)..."

# Run with a pipe that stays open but sends no data
# If it prompts, it will hang and timeout
timeout 5s bash "$MOCK_BIN/test_gitlab.sh" < <(sleep 10)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "PASS: Script finished successfully (no hang)."
elif [[ $EXIT_CODE -eq 124 ]]; then
    echo "FAIL: Script timed out (hang)."
else
    echo "FAIL: Script exited with code $EXIT_CODE."
fi
