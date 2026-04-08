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
CMDP_SH="$SCRIPT_DIR/src/cmdp.sh"
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

# --- UNC path integrity (echo vs printf regression) ---
echo ""
echo "--- UNC path integrity ---"

# cmdp must use printf, not echo — echo in zsh interprets \U, \f, \c in UNC paths
result=$(cmdp "$HOME" 2>/dev/null)
# Check the path starts with \\ and contains the distro name intact
if [[ "$result" == \\\\wsl.localhost\\* ]] && [[ "$result" == *"$USER"* ]]; then
    pass "UNC path preserved (no echo backslash corruption)"
else
    fail "UNC path preserved" "Got: [$result] (may be echo corruption)"
fi

# --- Flags ---
echo ""
echo "--- Flags ---"

# No argument → usage
output=$(cmdp 2>&1) && rc=$? || rc=$?
if [[ $rc -ne 0 ]] && echo "$output" | grep -qi "usage"; then
    pass "No argument → usage + exit 1"
else
    fail "No argument" "Exit code: $rc, Output: $output"
fi

# --help
output=$(cmdp --help 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Options"; then
    pass "--help shows full help"
else
    fail "--help" "Exit code: $rc, Output: $output"
fi

# -h
output=$(cmdp -h 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "Options"; then
    pass "-h shows full help"
else
    fail "-h" "Exit code: $rc, Output: $output"
fi

# --version
output=$(cmdp --version 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -qE "cmdp [0-9]+\.[0-9]+"; then
    pass "--version shows version"
else
    fail "--version" "Exit code: $rc, Output: $output"
fi

# -q / --quiet produces no output
result=$(cmdp -q /mnt/c/Users 2>&1)
if [[ -z "$result" ]]; then
    pass "-q produces no output"
else
    fail "-q produces no output" "Got: [$result]"
fi

# Normal mode shows status message
output=$(cmdp /mnt/c/Users 2>&1) && rc=$? || rc=$?
if echo "$output" | grep -q "Windows path copied to clipboard"; then
    pass "Normal mode shows status message"
else
    fail "Normal mode shows status message" "Got: [$output]"
fi

# Path found indicator — existing path
output=$(cmdp /mnt/c 2>&1) && rc=$? || rc=$?
if echo "$output" | grep -q "path found"; then
    pass "Existing path shows (path found)"
else
    fail "Existing path shows (path found)" "Got: [$output]"
fi

# Path not found indicator — non-existing path
output=$(cmdp /mnt/c/this/does/not/exist 2>&1) && rc=$? || rc=$?
if echo "$output" | grep -q "path not found"; then
    pass "Non-existing path shows (path not found)"
else
    fail "Non-existing path shows (path not found)" "Got: [$output]"
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
