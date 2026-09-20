#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
cd "${SCRIPT_DIR:h}"
# Keep caches writable and scoped to this checkout, including concurrent worktrees.
CACHE_ROOT="${PWD}/.build/test-support"
mkdir -p "${CACHE_ROOT}"
export CLANG_MODULE_CACHE_PATH="${CACHE_ROOT}/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="${CACHE_ROOT}/swift"
swift test \
    --cache-path "${CACHE_ROOT}/packages" \
    --config-path "${CACHE_ROOT}/config" \
    --security-path "${CACHE_ROOT}/security" \
    --scratch-path "${CACHE_ROOT}/build" \
    "$@"
