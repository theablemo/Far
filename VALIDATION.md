# Validation evidence — Far 0.4.0

## First public release review, 2026-09-20

- Reviewed scheduling, interruption, skip/postpone, pause, persistence, meeting suppression, unavailable-session handling, daily accounting, settings changes, and window transitions. No release-blocking logic defect was found; the audit did not change application code.
- Fresh default suite: **49 executed, 45 passed, four opt-in tests skipped, zero failures**. The two native desktop checks were explicitly requested separately and again skipped because the test process has no native display connection. The other two skips are fixture generators.
- Production code and original Soft pause artwork now have the MIT license. The first public download is ad-hoc signed, not Developer ID signed or notarized.
- Fresh Xcode 16.4 Release build and formatting checks passed. The bundle reports version 0.4.0, build 4, macOS 13.0 minimum, and both arm64 and x86_64 slices. Packaging extracted the ZIP and reverified its strict signature, architectures, and SHA-256 checksum.
- Reviewed the public file list and local documentation links. A targeted text scan found no private-key markers, GitHub/AWS key patterns, or absolute user-home paths. Builds, local reviews, historical design studies, and credentials are excluded from source control.
- The README animation uses synthetic native fixtures with opaque surfaces and accelerated timing. It is not a recording of live desktop motion or Liquid Glass.

Earlier entries below record the state at each development milestone; their statements about missing licensing or publication setup are historical. Physical-device checks remain outstanding.

## Open-source preparation, 2026-09-20

- Separated scheduling types and signal classifiers from the engine; extracted settings, sound/storage services, native surfaces, window controllers, and shared styles into focused files. Removed unused UI helpers and optional menu-content storage. The existing behavior and persistence schema are preserved.
- Split core and app test targets, grouped app tests by responsibility, and added teardown for isolated preference suites. All 49 original test methods remain. Baseline and post-extraction default runs each reported 45 passed, four opt-in skips, and zero failures.
- Final run with `FAR_LIVE_PANEL_TEST=1 FAR_PREVIEW_DIR="$PWD/artifacts/previews" ./scripts/test.sh --disable-sandbox`: **49 executed, 47 passed, two physical-desktop checks skipped, zero failures**. Both live checks reported no native display connection. Fixtures were generated; this cleanup did not include a new visual approval of their appearance.
- Xcode 16.4 Release build passed for **arm64 and x86_64**, with strict ad-hoc signature verification and property-list checks. The bundle reports version **0.4.0**, build **4**. Metadata now resolves from Xcode build settings, and the app is staged and verified before replacing the previous local build.
- A second Release build from a clean copy containing only the 57 publishable files passed, including bundle verification. It used no existing build output or local review files.
- Formatting lint, shell syntax, shared-scheme XML, workflow YAML, asset JSON, local Markdown links, and Xcode/SwiftPM source membership checks passed. The public-file manifest excludes builds, caches, local review output, and agent files. A targeted text scan found no private-key markers, GitHub/AWS key patterns, or absolute user-home paths in that manifest; this is not a full historical secret audit.
- GitHub CI is configured for Xcode 16.4 and 26.3. The runner versions were checked against GitHub's published macOS 15 inventory. The workflow itself and the Xcode 26.3 branch have not run here. This folder has no Git repository or remote, and nothing was published.

The source-publication decisions and binary-release requirements are listed in [release preparation](docs/RELEASING.md). License selection and icon provenance were pending at this milestone and have since been resolved. The physical-device checklist below remains outstanding.

## Menu placement correction, 2026-09-20

The user reported that the menu's top extended offscreen after the glass adaptation. The menu previously let `NSHostingController` resolve its size during native presentation. An injected-show regression check observed zero content/frame sizes at the presentation boundary; this demonstrates the implicit sizing dependency, not a reproduction of physical offscreen placement.

The menu now measures its real content before opening, assigns explicit popover and host bounds, and disables automatic native-host sizing. A vertical viewport stays anchored at the top and scrolls when content exceeds the space below the status button on its display. Status changes do not resize the open popover. Screen changes dismiss the old anchor; reopening measures again. Glass control backgrounds explicitly accept only their proposed bounds.

- Full suite after the core correction: 48 tests, 46 passed, two desktop checks skipped, zero failures. Four focused menu checks passed again after adding dismissal on display changes.
- An additional native scroll-view test passed: a 260-point menu can scroll to its bottom controls without changing the host bounds, with glass enabled.
- Both small-screen viewport captures show the complete header at the top in light/dark appearances. The normal menu retains its existing content and arrangement. Captures are in `.impeccable/review/menu-sizing-fix/` and use the documented opaque preview environment.
- Native desktop placement was requested outside the sandbox as well; the process still reported no native display connection. Physical placement is unverified. The live check now asserts all screen bounds, not just proximity to the status button.
- Release build and strict bundle signature verification passed.

## Liquid Glass adaptation, 2026-09-20

- Final run: **46 tests executed, 44 passed, two physical-desktop tests skipped, zero failures**. Live checks were explicitly requested with `FAR_LIVE_PANEL_TEST=1`; both reported no native display connection.
- The new integration test verifies that macOS 26 instantiates the public glass class, applies the stage radius, and preserves the hosted content and its bounds when repeatedly switching between glass and opaque surfaces. Decorative button backgrounds do not capture input.
- Xcode Release build and ad-hoc signing succeeded using the installed macOS 15.5 SDK. The runtime bridge uses only documented public `NSGlassEffectView` properties. The typed Xcode 26 branch and execution on macOS 13–15 have not been run here.
- Native-host opaque captures live in `.impeccable/review/liquid-glass/`. Inspected light/dark menu, light privacy settings, dark break settings, light countdown and dark rest layouts; no clipping observed at those sizes. The explicit preview environment disables composited control backgrounds; it does not simulate the OS accessibility preference itself.
- `cacheDisplay` cannot capture the glass compositor reliably: material captures were blank and control captures omitted composited regions. Those initial images are diagnostic only, not design previews or passing visual evidence. Actual desktop glass, contrast, hover and focus remain unverified.
- The app keeps the existing workflow and geometry; no scheduling or monitoring changes. Quit an older Far process before opening the rebuilt `dist/Far.app`.

Reproduce: `FAR_LIVE_PANEL_TEST=1 FAR_PREVIEW_DIR="$PWD/.impeccable/review/liquid-glass" ./scripts/test.sh --disable-sandbox`, then `./scripts/build-app.sh`.

## Earlier 0.4.0 result, 2026-09-20

- Baseline before refinement: 37 tests, 33 passed, four opt-in tests skipped, zero failures.
- Final full run with visual fixtures and live desktop checks requested: **45 tests executed, 43 passed, two physical-desktop tests skipped, zero failures**.
- Xcode Release build succeeded. `codesign --verify --deep --strict dist/Far.app` passed. Resource and Xcode project property lists passed `plutil -lint`. The built bundle reports version 0.4.0, build 4.
- Reviewed 23 native-host captures in `.impeccable/review/refinement-2026-09-20/`. Light/dark notice, halfway countdown, short/recovery rest, completion, material variants, menu states, and all Settings tabs are covered. The notice border was moved to the panel's actual perimeter after the first visual inspection. No clipping was observed at the captured sizes.

## Functional checks

- A real `SystemClock` and scheduled 250 ms timer drive an accelerated countdown → rest → completion flow. The test observes both intermediate stages, one completed break, and exactly one completion-sound request. Other time-sensitive cases use a controlled clock for deterministic boundaries.
- Countdown defaults to 15 seconds; saved three-second defaults migrate once. Other custom choices remain within the new 5–60 second bounds. Settings changes preserve the deadline and original progress-border denominator of an active countdown.
- Native controller tests exercise real NSPanel/NSHostingView objects with injected display coordinates: top-to-center movement, stable positioning, removed displays, Reduce Motion/Transparency, rapid hide/show, controls, and completion.
- Dimming tests cover two displays (including negative coordinates), window levels, full display frames, non-key behavior, click-through input, removal of a display, and cleanup on completion, Postpone, Skip, screen saver, Meeting mode, and close. Cancelling a fade cannot revive a dismissed backdrop. Click-through backdrops are excluded from Far's own-input classifier.
- Notification-adapter tests send screen-saver start, will-stop, lock, and unlock notifications through isolated notification centers into the real system adapter and app model. They verify counting stops, one continuous absence earns credit once, returning resumes counting, independent lock remains effective, and stopped observers no longer receive events. These are simulated notification deliveries, not an observed physical screen-saver session.
- Away credit remains fixed at 30 seconds / five minutes when custom guided durations are shorter. The new rest total combines guided breaks and short away credits; a recovery upgrade does not double-count a continuous absence.
- Sound tests verify selection persistence, explicit Preview, exactly-once completion requests, mute, Skip, failure feedback, and successful loading of all six named macOS sounds. Audio output has not been verified by listening on a physical device.
- Existing regression coverage includes typing deferral, Postpone/Skip semantics, sustained-work interruption, recovery priority, meeting suppression, persistence, local midnight splitting, clock changes, unavailable-device overlaps, settings/reset behavior, and no invented activity across app downtime.
- The menu/Settings fixture test now creates its output directory before writing, so a fresh review folder works independently of test execution order.

## Reproduce

```sh
FAR_LIVE_PANEL_TEST=1 FAR_PREVIEW_DIR="$PWD/.impeccable/review/refinement-2026-09-20" ./scripts/test.sh
./scripts/build-app.sh
codesign --verify --deep --strict dist/Far.app
```

Append `--disable-sandbox` to the test command only in environments that cannot start SwiftPM's nested sandbox. Tests use synthetic preferences and tracking state, not the user's real Far totals.

## Soft pause icon integration — September 20, 2026

The selected original Soft pause now supplies the bundled app-icon PNGs, normal menu-bar template, menu heading and both rest prompts. The existing test suite with `FAR_PREVIEW_DIR="$PWD/.impeccable/review/soft-pause"` and `--disable-sandbox` completed 49 tests: 47 passed and the two opt-in physical-desktop tests were skipped, with zero failures. Light/dark menu and rest fixtures were visually inspected; the app-icon source export was also inspected. Formatting, the Release bundle build and strict code-signature verification passed. These results do not establish live menu-bar contrast, compositing or icon-cache refresh on the desktop.

## Physical-device boundary

The physical panel-focus and status-popover tests reported no native display connection, including a retry outside the restricted sandbox. They remain skipped, not passed. Offscreen captures and AppKit object tests cannot establish actual desktop compositing, focus, Space behavior, or OS notification delivery. The first public release includes this validation limitation.

For physical-device validation, run the live tests from a desktop-connected terminal and check:

1. Watch the full warning, transition, and dimming on a real desktop. Use Postpone/Skip, move the pointer, and type steadily in another app. Verify focus is preserved and working through the dimming interrupts the rest.
2. Check multiple monitors, a full-screen editor, another Space, and display unplugging. Every display should dim only during rest; no backdrop should remain after exit.
3. Enter screen saver without locking for over 30 seconds, return, and check the away-rest count and screen total. Repeat for over five minutes and for lock → display sleep → wake while locked. Also check system sleep and fast user switching.
4. Preview each sound and listen for the selected sound at completion; verify the automatic-sound toggle.
5. Check VoiceOver, keyboard navigation, Reduce Motion/Transparency, and light/dark desktop contrast. Exercise normal 20/60-minute schedules in addition to accelerated tests.
6. Check real calls, muted/listen-only calls, microphone changes, dictation, and manual Meeting mode. Core Audio detection remains best effort.

Lock/screen-saver notification names are macOS conventions, not a guaranteed public screen-saver-state API. They require real-device regression checks on supported macOS versions. The older Core Audio device fallback can react to playback on duplex devices.
