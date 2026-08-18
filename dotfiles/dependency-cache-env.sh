#!/usr/bin/env sh
# Disposable dependency caches for storage-constrained Cloud Shell sessions.

_cloudshell_dep_uid="${UID:-$(id -u)}"
_cloudshell_dep_root="${NODETMP_STORE_DIR:-${TMPDIR:-/tmp}/dev_tmp_store/${_cloudshell_dep_uid}}/cache"

export NPM_CONFIG_CACHE="$_cloudshell_dep_root/npm"
export YARN_CACHE_FOLDER="$_cloudshell_dep_root/yarn"
export BUN_INSTALL_CACHE_DIR="$_cloudshell_dep_root/bun"

export PIP_CACHE_DIR="$_cloudshell_dep_root/pip"
export UV_CACHE_DIR="$_cloudshell_dep_root/uv"

export COMPOSER_CACHE_DIR="$_cloudshell_dep_root/composer"

export PLAYWRIGHT_BROWSERS_PATH="$_cloudshell_dep_root/ms-playwright"
export PUPPETEER_CACHE_DIR="$_cloudshell_dep_root/puppeteer"
export CYPRESS_CACHE_FOLDER="$_cloudshell_dep_root/cypress"

unset _cloudshell_dep_root _cloudshell_dep_uid
