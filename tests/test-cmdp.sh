#!/usr/bin/env bash
# test-cmdp.sh — Automated test suite for cmdp (WSL side).
#
# Usage (from WSL):
#   bash tests/test-cmdp.sh
#
# Requires: cmdp.sh sourced, clip.exe available in PATH.

# No set -e: test functions are expected to handle failures

PASSED=0
FAILED=0

# Source cmdp if not already loaded
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CMDP_SH="$SCRIPT_DIR/scripts/cmdp.sh"
if ! command -v cmdp > /dev/null 2>&1; then
    if [[ -f "$CMDP_SH" ]]; then
        source "$CMDP_SH"
    else
        echo "FATAL: cmdp not found. Source cmdp.sh first or run from project root." >&2
        exit 1
    fi
fi

pass() { echo "  PASS  $1"; ((PASSED++)); }
fail() { echo "  FAIL  $1"; shift; [[ -n "${1:-}" ]] && echo "        $1"; ((FAILED++)); }

# Run a test: test_cmdp <name> <input_path> <expected_output>
test_cmdp() {
    local name="$1" input="$2" expected="$3"
    local result
    result=$(cmdp "$input" 2>/dev/null)
    if [[ "$result" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "Expected: [$expected]  Got: [$result]"
    fi
}

echo ""
echo "=== cmdp Test Suite ==="
echo ""

# --- Basic /mnt paths ---
test_cmdp "Simple /mnt/c path" \
    "/mnt/c/Users/janot" \
    'C:\Users\janot'

test_cmdp "Drive root /mnt/c/" \
    "/mnt/c/" \
    'C:\'

test_cmdp "File path with spaces" \
    "/mnt/c/Program Files/Common Files" \
    'C:\Program Files\Common Files'

test_cmdp "Path with accents" \
    "/mnt/d/Bibliothèque calibre" \
    'D:\Bibliothèque calibre'

# --- WSL-internal paths (pattern match, exact UNC depends on distro name) ---
echo ""
echo "--- WSL-internal paths (pattern match) ---"

result=$(cmdp "$HOME" 2>/dev/null)
if [[ "$result" == \\\\wsl* ]]; then
    pass "Home → UNC path"
else
    fail "Home → UNC path" "Expected \\\\wsl... Got: [$result]"
fi

result=$(cmdp "/etc/hosts" 2>/dev/null)
if [[ "$result" == \\\\wsl* ]]; then
    pass "/etc/hosts → UNC path"
else
    fail "/etc/hosts → UNC path" "Expected \\\\wsl... Got: [$result]"
fi

# --- Error handling ---
echo ""
echo "--- Error handling ---"

output=$(cmdp 2>&1) && rc=$? || rc=$?
if [[ $rc -ne 0 ]] && echo "$output" | grep -qi "usage"; then
    pass "No argument → usage + exit 1"
else
    fail "No argument" "Exit code: $rc, Output: $output"
fi

# --- Summary ---
echo ""
TOTAL=$((PASSED + FAILED))
if [[ $FAILED -eq 0 ]]; then
    echo "=== Results: $PASSED passed, $FAILED failed ==="
else
    echo "=== Results: $PASSED passed, $FAILED failed ==="
fi

exit $FAILED
