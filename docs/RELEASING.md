# Releasing Far

Far's first public release is **0.4.0**. Downloads are universal macOS apps for Apple silicon and Intel, targeting macOS 13 or later. The build is ad-hoc signed and **not notarized**. It does not have a Developer ID signature; macOS may block the first launch.

## Prepare a version

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both target configurations in `Far.xcodeproj/project.pbxproj`. Record the changes under the same version in `CHANGELOG.md`.
2. Run `./scripts/format.sh --check` and `./scripts/test.sh` with full Xcode 16.4 or later selected. If the local environment cannot start SwiftPM's nested sandbox, use `./scripts/test.sh --disable-sandbox` and record that choice.
3. Follow the optional native tests in [CONTRIBUTING.md](../CONTRIBUTING.md) and the physical-device checklist in [VALIDATION.md](../VALIDATION.md). Record actual passes and skips. Hosted CI and offscreen checks do not establish desktop behavior across macOS versions.
4. Review the files being committed. Keep build products, signing material, credentials, and local design reviews outside Git. Review [icon provenance](../Resources/ICONOGRAPHY.md) when artwork changes.
5. Commit the reviewed source and wait for CI before tagging it.

CI checks both Xcode 16.4 and 26.3 on `macos-15`. These versions are listed in the [GitHub runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md); update the workflow when the runner image retires them. The release workflow builds with Xcode 26.3 to include the macOS 26 material implementation while preserving the macOS 13 deployment target.

## Package locally

```sh
./scripts/release.sh 0.4.0
```

If a fresh Release bundle has already been built with `./scripts/build-app.sh`:

```sh
./scripts/release.sh 0.4.0 --skip-build
```

The script checks the requested version against the bundle, the macOS deployment target, both `arm64` and `x86_64` slices, and the code signature. It creates a ZIP with `ditto`, extracts it into a temporary directory, verifies the extracted signature and architectures, and writes:

```text
dist/Far-0.4.0-macOS-universal.zip
dist/SHA256SUMS.txt
```

Both files belong on the GitHub Release, not in Git history. A valid ad-hoc signature checks bundle integrity; it does not identify a Developer ID publisher or satisfy notarization.

## Publish on GitHub

After the source commit passes CI:

```sh
git tag -a v0.4.0 -m "Far 0.4.0"
git push origin v0.4.0
```

The tag-triggered **Release** workflow runs formatting and tests, builds and verifies the universal archive, then publishes it with checksums and the matching changelog entry. Only the final publish job has permission to write repository contents. An existing release is left unchanged so rerunning a workflow cannot silently replace a downloaded binary. Failed runs can be rerun in GitHub Actions; if a release already exists but needs corrected assets, review and manage those assets explicitly.

For a manually prepared release, create it against the reviewed tag with the same ZIP and checksum files. Include the unnotarized status and first-launch instructions below. Do not describe a local or hosted build as notarized without completing the signing process.

## Installation and verification

Download the versioned ZIP from this repository's Releases page, extract it, and drag **Far.app** into **Applications**. Launch it from Applications; Far lives in the menu bar.

If macOS blocks it because the developer cannot be verified, review the source and download location first. If you choose to proceed, open **System Settings → Privacy & Security**, find the notice for Far, and choose **Open Anyway** after the blocked launch. Follow [Apple's instructions for opening an app from an unidentified developer](https://support.apple.com/en-ca/102445). Do not disable Gatekeeper globally. Managed Macs may restrict this choice.

To check a download, place the ZIP and `SHA256SUMS.txt` in the same folder and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

The checksum detects a damaged or mismatched download; it is not a substitute for a trusted publisher signature. Test the actual downloaded archive on a separate Mac before claiming a verified installation experience.

## Future Developer ID releases

For a notarized release, use an Apple Developer ID Application certificate, sign the app with hardened runtime and a secure timestamp, submit the archive using `xcrun notarytool`, then staple the accepted ticket to the app with `xcrun stapler`. Repackage the stapled app and regenerate checksums. Verify with `codesign`, `stapler validate`, and `spctl`, then test a quarantined download on another Mac.

The current build script deliberately uses an ad-hoc signature. Change that pipeline as part of introducing Developer ID; notarization cannot be added by uploading the existing ad-hoc ZIP alone. Keep certificates and notarization credentials in protected CI secrets or local signing storage, never in the repository. Follow [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
