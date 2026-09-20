# Contributing to Far

Far is a small native macOS app. Keep changes focused, local-first, and consistent with [PRODUCT.md](PRODUCT.md) and [DESIGN.md](DESIGN.md). For scheduling changes, read the [behavior guide](docs/BEHAVIOR.md) first.

## Set up and verify

Use full Xcode 16.4 or later and Swift 6. The [README](README.md#build-and-run) describes building and launching the app. There are no external package dependencies.

Before submitting a change, run:

```sh
./scripts/format.sh
./scripts/format.sh --check
./scripts/test.sh
./scripts/build-app.sh
```

The formatter is Apple's `swift-format` bundled with Xcode. The optional [CI template](docs/automation/ci.yml) checks formatting with Xcode 16.4 and runs tests and builds with both Xcode 16.4 and 26.3. See the [automation setup](docs/RELEASING.md#enable-github-actions) to enable it. The first public release was verified locally and published manually.

## Make a change

- Keep scheduling and accounting in `FarCore`; inject system effects into `AppModel` through its existing protocols.
- Add new source files to both SwiftPM's source folders and the Xcode project's Sources build phase. Both build paths must pass.
- Preserve independent Postpone and Skip behavior, stable active deadlines, and the distinction between measured totals and reminder schedules.
- Add regression tests for behavioral fixes. Use controlled clocks and synthetic preferences rather than real user data. App tests inherit `FarTestCase`, which removes each test's preference suite during teardown.
- For UI changes, exercise the native controllers and inspect the relevant screen on a physical desktop. Keep the existing accessibility and reduced-motion behavior.
- Do not commit generated builds, local review screenshots, agent files, signing material, or personal paths. Curated documentation images belong in `docs/media/` with provenance and synthetic-data labels. `.gitignore` excludes the usual local output.

## Optional visual and desktop checks

```sh
FAR_PREVIEW_DIR="$PWD/artifacts/previews" ./scripts/test.sh
FAR_LIVE_PANEL_TEST=1 ./scripts/test.sh
```

Previews use synthetic state and are written to an ignored directory. Live tests require a desktop-connected session and can show windows. A skipped test is not a passing desktop check. See [VALIDATION.md](VALIDATION.md) for the manual checklist and evidence limits.

For a pull request, explain the problem, the resulting behavior, the checks you ran, and any remaining device checks. For a bug report, include macOS and Xcode/app versions, relevant timing settings, reproduction steps, and expected versus observed behavior. Review logs and screenshots for personal information before attaching them.
