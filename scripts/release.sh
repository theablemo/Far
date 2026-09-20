#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DIST_DIR="${PROJECT_DIR}/dist"
APP_DIR="${DIST_DIR}/Far.app"

usage() {
    print -u2 "Usage: scripts/release.sh VERSION [--skip-build]"
    print -u2 "Example: scripts/release.sh 0.4.0"
    exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
RELEASE_VERSION="$1"
[[ "${RELEASE_VERSION}" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || usage
[[ $# -eq 1 || "$2" == "--skip-build" ]] || usage

cd "${PROJECT_DIR}"
if [[ "${2:-}" != "--skip-build" ]]; then
    ./scripts/build-app.sh
fi

PLIST="${APP_DIR}/Contents/Info.plist"
[[ -f "${PLIST}" ]] || { print -u2 "Missing Far.app; run scripts/build-app.sh first."; exit 1; }
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST}")"
MINIMUM_SYSTEM="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${PLIST}")"
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${PLIST}")"
if [[ "${ACTUAL_VERSION}" != "${RELEASE_VERSION}" ]]; then
    print -u2 "Release version ${RELEASE_VERSION} does not match bundle version ${ACTUAL_VERSION}."
    exit 1
fi
if [[ "${MINIMUM_SYSTEM}" != "13.0" || "${EXECUTABLE}" != "Far" ]]; then
    print -u2 "Unexpected app metadata: minimum macOS ${MINIMUM_SYSTEM}, executable ${EXECUTABLE}."
    exit 1
fi

/usr/bin/lipo "${APP_DIR}/Contents/MacOS/Far" -verify_arch arm64 x86_64
/usr/bin/codesign --verify --deep --strict "${APP_DIR}"
/usr/bin/plutil -lint "${PLIST}"

ARCHIVE_NAME="Far-${RELEASE_VERSION}-macOS-universal.zip"
STAGING_DIR="$(/usr/bin/mktemp -d "${DIST_DIR}/.far-release.XXXXXX")"
trap '/bin/rm -rf -- "${STAGING_DIR}"' EXIT

# Preserve the application bundle and macOS metadata in the distributable ZIP.
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${STAGING_DIR}/${ARCHIVE_NAME}"
/usr/bin/ditto -x -k "${STAGING_DIR}/${ARCHIVE_NAME}" "${STAGING_DIR}/unpacked"
/usr/bin/codesign --verify --deep --strict "${STAGING_DIR}/unpacked/Far.app"
/usr/bin/lipo "${STAGING_DIR}/unpacked/Far.app/Contents/MacOS/Far" -verify_arch arm64 x86_64

(
    cd "${STAGING_DIR}"
    /usr/bin/shasum -a 256 "${ARCHIVE_NAME}" > SHA256SUMS.txt
    /usr/bin/shasum -a 256 -c SHA256SUMS.txt
)

# Publish local artifacts only after archive extraction and verification succeed.
/bin/mv -f -- "${STAGING_DIR}/${ARCHIVE_NAME}" "${DIST_DIR}/${ARCHIVE_NAME}"
/bin/mv -f -- "${STAGING_DIR}/SHA256SUMS.txt" "${DIST_DIR}/SHA256SUMS.txt"
print "Packaged ${DIST_DIR}/${ARCHIVE_NAME}"
print "Checksums: ${DIST_DIR}/SHA256SUMS.txt"
print "Signing: the build script uses an ad-hoc signature; this package is not notarized."
