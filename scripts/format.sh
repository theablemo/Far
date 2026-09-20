#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "${SCRIPT_DIR:h}"

case "${1:-}" in
    --check)
        xcrun swift-format lint --strict --recursive Sources Tests Package.swift
        ;;
    "")
        xcrun swift-format format --in-place --recursive Sources Tests Package.swift
        ;;
    *)
        print -u2 "Usage: $0 [--check]"
        exit 2
        ;;
esac
