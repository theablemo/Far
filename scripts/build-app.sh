#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_DIR="${PROJECT_DIR}/dist/Far.app"
DERIVED_DATA_DIR="${PROJECT_DIR}/.xcode-derived"
BUILT_APP="${DERIVED_DATA_DIR}/Build/Products/Release/Far.app"

cd "${PROJECT_DIR}"
if ! xcodebuild -version >/dev/null 2>&1; then
    print -u2 "Building Far.app requires full Xcode 16.4 or later, selected with xcode-select."
    exit 1
fi
/usr/bin/plutil -lint Resources/Info.plist Far.xcodeproj/project.pbxproj
xcodebuild \
    -project Far.xcodeproj \
    -scheme Far \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGNING_ALLOWED=NO \
    build

if [[ "${APP_DIR}" != "${PROJECT_DIR}/dist/Far.app" ]]; then
    print -u2 "Refusing to replace an unexpected app path."
    exit 1
fi

/bin/mkdir -p "${PROJECT_DIR}/dist"
STAGING_DIR="$(/usr/bin/mktemp -d "${PROJECT_DIR}/dist/.far-build.XXXXXX")"
trap '/bin/rm -rf -- "${STAGING_DIR}"' EXIT
/usr/bin/ditto "${BUILT_APP}" "${STAGING_DIR}/Far.app"
/usr/bin/codesign --force --sign - "${STAGING_DIR}/Far.app"
/usr/bin/codesign --verify --deep --strict "${STAGING_DIR}/Far.app"
/usr/bin/plutil -lint "${STAGING_DIR}/Far.app/Contents/Info.plist"

# Replace the previous local build only after the new bundle passes verification.
/bin/rm -rf -- "${APP_DIR}"
/bin/mv -- "${STAGING_DIR}/Far.app" "${APP_DIR}"

print "Built ${APP_DIR}"
