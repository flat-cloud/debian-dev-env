#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly NODETMP="$REPO_ROOT/bin/nodetmp"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/nodetmp-test.XXXXXX")"
readonly TEST_ROOT
export NODETMP_STORE_DIR="$TEST_ROOT/store"
export HOME="$TEST_ROOT/home"
mkdir -p -- "$HOME" "$TEST_ROOT/bin" "$TEST_ROOT/projects"

cleanup() {
    case "$TEST_ROOT" in
        "${TMPDIR:-/tmp}"/nodetmp-test.*) rm -rf -- "$TEST_ROOT" ;;
        *) echo "Refusing to clean unexpected test path: $TEST_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file() {
    [[ -f "$1" ]] || fail "expected file: $1"
}

assert_directory() {
    [[ -d "$1" ]] || fail "expected directory: $1"
}

assert_symlink() {
    [[ -L "$1" ]] || fail "expected symlink: $1"
}

assert_not_symlink() {
    [[ ! -L "$1" ]] || fail "expected a real path, not a symlink: $1"
}

assert_contains() {
    local expected="$1"
    local actual="$2"
    [[ "$actual" == *"$expected"* ]] || fail "expected output to contain '$expected'"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    [[ "$actual" == "$expected" ]] || fail "expected '$expected', got '$actual'"
}

# The help text used to execute its backticked `npm install` example.
cat >"$TEST_ROOT/bin/npm" <<'EOF'
#!/usr/bin/env bash
printf 'called\n' >>"$TEST_ROOT/npm-calls"
EOF
chmod +x "$TEST_ROOT/bin/npm"
export TEST_ROOT
export PATH="$TEST_ROOT/bin:$PATH"
"$NODETMP" help >/dev/null
[[ ! -e "$TEST_ROOT/npm-calls" ]] || fail "help executed npm"

# Existing contents, including dotfiles, survive the move to temp storage.
project="$TEST_ROOT/projects/project with spaces"
mkdir -p -- "$project/node_modules/.bin"
printf '{}\n' >"$project/package.json"
printf 'binary\n' >"$project/node_modules/.bin/tool"
printf 'package\n' >"$project/node_modules/file with spaces"
"$NODETMP" link "$project" >/dev/null
assert_symlink "$project/node_modules"
assert_file "$project/node_modules/.bin/tool"
assert_file "$project/node_modules/file with spaces"

status_output="$(cd -- "$project" && "$NODETMP" status)"
assert_contains "Status for $project" "$status_output"
assert_contains "Symlinked" "$status_output"

# A broken managed symlink is recreated and migrated into the configured store.
managed_target="$(readlink -- "$project/node_modules")"
rm -f -- "$managed_target/.bin/tool" "$managed_target/file with spaces"
rmdir -- "$managed_target/.bin"
rmdir -- "$managed_target"
"$NODETMP" enforce "$TEST_ROOT/projects" --dry-run --no-caches >/dev/null
assert_symlink "$project/node_modules"
"$NODETMP" fix "$TEST_ROOT/projects" >/dev/null
assert_directory "$project/node_modules"
assert_file "$TEST_ROOT/npm-calls"

# Recursive enforcement handles Composer, Node, and known caches in one pass.
enforced_project="$HOME/enforced-project"
mkdir -p -- "$enforced_project/node_modules" "$enforced_project/vendor" "$HOME/.npm"
printf '{}\n' >"$enforced_project/package.json"
printf '{}\n' >"$enforced_project/composer.json"
printf 'node dependency\n' >"$enforced_project/node_modules/example"
printf 'composer dependency\n' >"$enforced_project/vendor/example"
printf 'cache\n' >"$HOME/.npm/example"
"$NODETMP" enforce "$HOME" --dry-run >/dev/null
assert_not_symlink "$enforced_project/node_modules"
assert_not_symlink "$enforced_project/vendor"
"$NODETMP" enforce "$HOME" >/dev/null
assert_symlink "$enforced_project/node_modules"
assert_symlink "$enforced_project/vendor"
assert_symlink "$HOME/.npm"
assert_file "$enforced_project/node_modules/example"
assert_file "$enforced_project/vendor/example"
assert_file "$HOME/.npm/example"

# A later enforcement pass recreates broken links after ephemeral storage resets.
enforced_node_target="$(readlink -- "$enforced_project/node_modules")"
enforced_cache_target="$(readlink -- "$HOME/.npm")"
rm -rf -- "$enforced_node_target" "$enforced_cache_target"
"$NODETMP" enforce "$HOME" >/dev/null
assert_symlink "$enforced_project/node_modules"
assert_directory "$enforced_project/node_modules"
assert_symlink "$HOME/.npm"
assert_directory "$HOME/.npm"

# Links owned by another tool or the user are never overwritten or cleaned up.
external="$TEST_ROOT/external-venv"
python_project="$TEST_ROOT/projects/python-project"
mkdir -p -- "$external" "$python_project"
printf '[project]\nname = "example"\nversion = "0.1.0"\n' >"$python_project/pyproject.toml"
ln -s -- "$external" "$python_project/.venv"
if "$NODETMP" link "$python_project" >/dev/null 2>&1; then
    fail "link replaced an unmanaged symlink"
fi
assert_symlink "$python_project/.venv"
[[ "$(readlink -- "$python_project/.venv")" == "$external" ]] || fail "unmanaged link target changed"
(cd -- "$python_project" && "$NODETMP" clean >/dev/null 2>&1)
assert_symlink "$python_project/.venv"
assert_directory "$external"

# Login-shell cache variables use the same per-user ephemeral store.
unset NPM_CONFIG_CACHE YARN_CACHE_FOLDER BUN_INSTALL_CACHE_DIR
unset PIP_CACHE_DIR UV_CACHE_DIR COMPOSER_CACHE_DIR
unset PLAYWRIGHT_BROWSERS_PATH PUPPETEER_CACHE_DIR CYPRESS_CACHE_FOLDER
. "$REPO_ROOT/dotfiles/dependency-cache-env.sh"
assert_equals "$NODETMP_STORE_DIR/cache/npm" "$NPM_CONFIG_CACHE"
assert_equals "$NODETMP_STORE_DIR/cache/yarn" "$YARN_CACHE_FOLDER"
assert_equals "$NODETMP_STORE_DIR/cache/bun" "$BUN_INSTALL_CACHE_DIR"
assert_equals "$NODETMP_STORE_DIR/cache/pip" "$PIP_CACHE_DIR"
assert_equals "$NODETMP_STORE_DIR/cache/uv" "$UV_CACHE_DIR"
assert_equals "$NODETMP_STORE_DIR/cache/composer" "$COMPOSER_CACHE_DIR"
assert_equals "$NODETMP_STORE_DIR/cache/ms-playwright" "$PLAYWRIGHT_BROWSERS_PATH"
assert_equals "$NODETMP_STORE_DIR/cache/puppeteer" "$PUPPETEER_CACHE_DIR"
assert_equals "$NODETMP_STORE_DIR/cache/cypress" "$CYPRESS_CACHE_FOLDER"

echo "PASS: nodetmp regression tests"
