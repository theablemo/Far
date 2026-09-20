# Architecture

Far has two SwiftPM targets: `FarCore` and the `Far` executable. The Xcode app target compiles the same sources into one module, adding bundle metadata and assets. Conditional `canImport(FarCore)` imports support both layouts. SwiftPM owns the test targets; the Xcode scheme builds and runs the application.

## Scheduling core

`BreakEngine.swift` owns the state machine, schedule progress, rest credit, and daily accounting. Callers supply monotonic elapsed time, a wall-clock date, and an `ActivityContext`. The engine returns events and an immutable snapshot; it does not create timers, windows, audio, or persistence effects.

`BreakTypes.swift` defines configuration, stages, events, snapshots, and Codable tracking state. Guided durations are configurable. `BreakKind.duration` represents the fixed away-credit thresholds, which stay independent of guided durations.

`ActivitySignals.swift` contains the input classifier, meeting debounce, and independent session-availability flags. `PanelPlacement.swift` is pure display-coordinate geometry.

## App model and system adapters

`AppModel` samples injected dependencies on a 250 ms timer, advances the engine, publishes snapshots, and checkpoints tracking. Explicit controls update the engine and persist immediately. `TimingSetting` owns the user-facing units, bounds, storage keys, and mapping to engine configuration.

`AppServices.swift` supplies a monotonic clock and local UserDefaults tracking storage. `SystemMonitoring.swift` adapts input counters, Core Audio activity, and availability notifications. `BreakSoundPlayer.swift` wraps named macOS sounds. Tests replace these dependencies with controlled inputs.

Persistence contains only preferences, daily aggregates, and scheduling progress. Unknown or undecodable tracking versions fall back to an empty state. App downtime is not replayed. Existing preference keys and the tracking schema must remain compatible unless a migration is deliberately added.

## Presentation

`FarApp` connects application lifecycle, status menu, reminder, and onboarding controllers. `StatusMenuController` owns the anchored popover and settings window. `ReminderPanelController` owns panel placement and transitions, while `RestDimmingController` manages click-through backdrops on each display.

SwiftUI content lives in `MenuBarView`, `PreferencesView`, and `ReminderPanelView`. Shared colors and button styles live in `ViewStyles.swift`. `BreakPanelSurface` owns native material, clipping, and host bounds. The onboarding window remains self-contained.

`GlassCompatibility.swift` isolates the public AppKit glass bridge used when building with Xcode 16.4. Newer compilers construct the typed glass class; older compilers look it up at runtime on macOS 26. Keep OS-version handling here, and validate both build branches when changing it.

Combine's `@Published` sends before the stored property is updated. Subscribers must use the emitted snapshot for the corresponding frame and content, rather than reading a stale `model.snapshot` during a transition.

## Tests and build metadata

`FarCoreTests` depends only on the core. `FarTests` separates model, menu, reminder, and visual-fixture tests, with shared controlled dependencies in `TestSupport.swift`. The default run skips opt-in visual and physical desktop tests.

The Xcode target's `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `PRODUCT_BUNDLE_IDENTIFIER`, and deployment target populate `Resources/Info.plist` during the build. Update both Debug and Release target configurations when changing version metadata. The shared scheme is checked in; user-specific Xcode state is ignored.
