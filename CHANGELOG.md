# Changelog

## 0.4.0 — 2026-09-20

First public release. Universal download for Apple Silicon and Intel, targeting macOS 13 or later. The app is ad-hoc signed and not notarized by Apple.

- Adopt the original Soft pause app icon, normal menu-bar mark, menu heading and rest-prompt artwork. Share native vector geometry with a repeatable icon exporter.
- Separate scheduling types, system services, window controllers, views, and shared styles into focused files.
- Separate core and app test targets; clean up isolated test preferences after each test.
- Add contributor documentation, formatting checks, a shared Xcode scheme, and CI.
- Verify staged application bundles before replacing the previous local build.
- Add an MIT license, illustrated README, issue templates, release packaging, and SHA-256 checksums.

- A 15-second warning, adjustable from 5–60 seconds, with a steady border showing the time remaining. Reduce Motion disables interpolation. Existing three-second defaults upgrade to 15 seconds; other saved values are preserved within the new bounds.
- A compact screen-time bar compares the current stretch with the look-away interval. The notice also shows today's counted screen time and recorded rests. A long away period counts once, even when it also earns recovery credit. These are measured totals, not health scores or a fabricated activity history.
- All displays dim during guided rest. The centered prompt stays above the dimming, and the desktop still accepts clicks. Completing, postponing, skipping, interrupting, or leaving the available session clears the dimming.
- Screen-saver notifications feed the same away-rest tracking as lock and sleep. Away thresholds are fixed at 30 seconds and five minutes, independent of custom guided durations. Screen-saver stop never clears an independent lock/sleep condition.
- Choose Glass, Tink, Pop, Purr, Ping, or Submarine in **Settings → App & privacy → End sound**, and use **Preview** to listen. Preview works even when automatic completion audio is off.
- Native Liquid Glass on macOS 26, with material and opaque fallbacks on older systems or when transparency is reduced.
- The status menu measures its content before opening and scrolls on smaller displays.
