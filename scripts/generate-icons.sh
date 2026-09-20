#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
cd "${SCRIPT_DIR:h}"
mkdir -p .build/icon-export
xcrun swiftc -module-cache-path .build/icon-export/module-cache \
    Sources/Far/FarBrandMark.swift scripts/generate-icons.swift \
    -o .build/icon-export/generate-icons
.build/icon-export/generate-icons
