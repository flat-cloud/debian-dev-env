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

# Recursive enforcement discovers dependency links even without a manifest and
# migrates known legacy ephemeral layouts into the current managed store.
legacy_project="$TEST_ROOT/projects/legacy-link-only"
legacy_target="$TEST_ROOT/old-dependencies/legacy-link-only/node_modules"
mkdir -p -- "$legacy_project" "$legacy_target"
printf 'legacy dependency\n' >"$legacy_target/example"
ln -s -- "$legacy_target" "$legacy_project/node_modules"
legacy_output="$("$NODETMP" enforce "$TEST_ROOT/projects" --no-caches)"
assert_contains "Migrating legacy ephemeral target" "$legacy_output"
assert_symlink "$legacy_project/node_modules"
assert_file "$legacy_project/node_modules/example"
[[ "$(readlink -- "$legacy_project/node_modules")" == "$NODETMP_STORE_DIR/"* ]] || \
    fail "legacy link was not adopted into the managed store"
[[ ! -e "$legacy_target" ]] || fail "legacy ephemeral target should have been moved"

# Missing legacy targets are adopted as empty managed directories rather than
# aborting the rest of a recursive enforcement pass.
broken_legacy_project="$TEST_ROOT/projects/broken-legacy-link-only"
broken_legacy_target="$TEST_ROOT/missing-dependencies/broken-legacy-link-only/node_modules"
mkdir -p -- "$broken_legacy_project"
ln -s -- "$broken_legacy_target" "$broken_legacy_project/node_modules"
broken_legacy_output="$("$NODETMP" enforce "$TEST_ROOT/projects" --no-caches)"
assert_contains "Adopting broken legacy link" "$broken_legacy_output"
assert_symlink "$broken_legacy_project/node_modules"
assert_directory "$broken_legacy_project/node_modules"
[[ "$(readlink -- "$broken_legacy_project/node_modules")" == "$NODETMP_STORE_DIR/"* ]] || \
    fail "broken legacy link was not adopted into the managed store"

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

# Prune: old releases across every Codex package channel are removed; current is kept.
standalone_releases="$HOME/.codex/packages/standalone/releases"
current_release="$standalone_releases/1.0.0-linux"
old_release1="$standalone_releases/0.9.0-linux"
old_release2="$standalone_releases/0.8.0-linux"
daemon_releases="$HOME/.codex/packages/app-server-daemon/releases"
current_daemon_release="$daemon_releases/2.0.0-linux"
old_daemon_release="$daemon_releases/1.0.0-linux"
mkdir -p -- "$current_release" "$old_release1" "$old_release2"
mkdir -p -- "$current_daemon_release" "$old_daemon_release"
mkdir -p -- "$(dirname -- "$HOME/.codex/packages/standalone/current")"
ln -sfn "$current_release" "$HOME/.codex/packages/standalone/current"
ln -sfn "$current_daemon_release" "$HOME/.codex/packages/app-server-daemon/current"
mkdir -p -- "$HOME/.nvm/.cache/bin/example"
printf 'archive\n' >"$HOME/.nvm/.cache/bin/example/node.tar.xz"
"$NODETMP" prune "$HOME" --dry-run >/dev/null
assert_directory "$old_release1"
assert_directory "$old_release2"
assert_directory "$old_daemon_release"
assert_file "$HOME/.nvm/.cache/bin/example/node.tar.xz"
"$NODETMP" prune "$HOME" >/dev/null
[[ ! -d "$old_release1" ]] || fail "old Codex release 0.9.0 should have been removed"
[[ ! -d "$old_release2" ]] || fail "old Codex release 0.8.0 should have been removed"
[[ ! -d "$old_daemon_release" ]] || fail "old app-server daemon release should have been removed"
assert_directory "$current_release"
assert_directory "$current_daemon_release"
[[ ! -d "$HOME/.nvm/.cache" ]] || fail "NVM download cache should have been removed"

# Prune: stale zcompdump files from other hostnames are removed; current host kept.
touch "$HOME/.zcompdump-othermachine-5.9"
touch "$HOME/.zcompdump-othermachine-5.9.zwc"
current_host="$(hostname 2>/dev/null || echo 'testhost')"
touch "$HOME/.zcompdump-${current_host}-5.9"
"$NODETMP" prune "$HOME" >/dev/null
[[ ! -f "$HOME/.zcompdump-othermachine-5.9" ]] || fail "stale zcompdump for othermachine should be removed"
[[ ! -f "$HOME/.zcompdump-othermachine-5.9.zwc" ]] || fail "stale zcompdump .zwc for othermachine should be removed"
assert_file "$HOME/.zcompdump-${current_host}-5.9"

# Prune: leaked dev_tmp_store under ~/tmp on persistent disk is removed.
mkdir -p "$HOME/tmp/dev_tmp_store"
"$NODETMP" prune "$HOME" >/dev/null
[[ ! -d "$HOME/tmp/dev_tmp_store" ]] || fail "leaked ~/tmp/dev_tmp_store should have been removed"
[[ ! -d "$HOME/tmp" ]] || fail "empty ~/tmp should have been removed"

# Prune: recursively remove dist only when Git confirms it is ignored.
ignored_dist_repo="$HOME/projects/ignored-dist-project"
kept_dist_repo="$HOME/projects/kept-dist-project"
mkdir -p -- "$ignored_dist_repo/dist" "$kept_dist_repo/dist"
git -C "$ignored_dist_repo" init -q
git -C "$kept_dist_repo" init -q
printf 'dist/\n' >"$ignored_dist_repo/.gitignore"
printf 'generated\n' >"$ignored_dist_repo/dist/output.js"
printf 'release\n' >"$kept_dist_repo/dist/release.js"
"$NODETMP" prune "$HOME" --dry-run >/dev/null
assert_directory "$ignored_dist_repo/dist"
assert_directory "$kept_dist_repo/dist"
"$NODETMP" prune "$HOME" >/dev/null
[[ ! -d "$ignored_dist_repo/dist" ]] || fail "ignored dist should have been removed"
assert_file "$kept_dist_repo/dist/release.js"

# Prune: real dependency directories are offloaded and tagged orphan stores are removed.
prune_project="$HOME/projects/prune-dependency-project"
orphan_store="$NODETMP_STORE_DIR/orphaned-project_deadbeef0000"
mkdir -p -- "$prune_project/node_modules" "$orphan_store/node_modules"
printf '{}\n' >"$prune_project/package.json"
printf 'dependency\n' >"$prune_project/node_modules/example"
printf '%s\n' "$HOME/projects/missing-project" >"$orphan_store/.nodetmp-project"
"$NODETMP" prune "$HOME" --dry-run --no-docker --no-binaries >/dev/null
assert_not_symlink "$prune_project/node_modules"
assert_directory "$orphan_store"
"$NODETMP" prune "$HOME" --no-docker --no-binaries >/dev/null
assert_symlink "$prune_project/node_modules"
assert_file "$prune_project/node_modules/example"
[[ ! -d "$orphan_store" ]] || fail "tagged orphan dependency store should have been removed"

# Prune: Docker dry-run reports usage; a real run prunes only unused images and build cache.
cat >"$TEST_ROOT/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_ROOT/docker-calls"
case "$*" in
    info) exit 0 ;;
    "system df") printf 'TYPE TOTAL ACTIVE SIZE RECLAIMABLE\n'; exit 0 ;;
    "image prune --all --force") exit 0 ;;
    "builder prune --all --force") exit 0 ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/docker"
"$NODETMP" prune "$HOME" --dry-run --no-deps --no-binaries >/dev/null
docker_dry_calls="$(<"$TEST_ROOT/docker-calls")"
assert_contains "system df" "$docker_dry_calls"
[[ "$docker_dry_calls" != *"image prune"* ]] || fail "Docker dry-run pruned images"
: >"$TEST_ROOT/docker-calls"
"$NODETMP" prune "$HOME" --no-deps --no-binaries >/dev/null
docker_prune_calls="$(<"$TEST_ROOT/docker-calls")"
assert_contains "image prune --all --force" "$docker_prune_calls"
assert_contains "builder prune --all --force" "$docker_prune_calls"

echo "PASS: nodetmp regression tests"
