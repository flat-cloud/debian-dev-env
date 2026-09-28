#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly INSTALLER="$REPO_ROOT/install.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

help_output="$("$INSTALLER" --help)"
[[ "$help_output" == *"-p, --python-tools"* ]] || fail "missing Python tools option"
[[ "$help_output" == *"-n, --node-tools"* ]] || fail "missing Node tools option"
[[ "$help_output" == *"skipped unless their explicit flags"* ]] || \
    fail "help does not explain opt-in behavior"

if "$INSTALLER" --not-a-real-option >/dev/null 2>&1; then
    fail "unknown installer option should fail"
fi

echo "PASS: install option tests"
