# Far iconography

Far uses the **original Soft pause**, selected by the owner on September 20, 2026: two rounded forms, without an eye. The production source is `Sources/Far/FarBrandMark.swift`; earlier design studies are not part of the distribution.

`Sources/Far/FarBrandMark.swift` is the shared vector geometry for the SwiftUI brand mark, AppKit menu-bar template, and app-icon exporter. The app tile preserves the selected forest background (`#20503e`), pale mark (`#edf7f0`), rounded corners and original spacing. In-app marks use Far's semantic green for light/dark appearances.

## Uses

- App icon, including the icon shown by the welcome window.
- Normal menu-bar state: a monochrome template with a 16-point-tall mark in an 18-point image.
- Menu heading: a 20 × 23 point frame.
- Both rest prompts: a 27 × 32 point frame.

Status changes retain semantic system symbols: timer during countdown, leaf during rest, checkmark on completion, and pause while reminders are held. The tooltip reports the current menu status. Settings, completion and other standard controls retain SF Symbols; the unselected custom control-icon study is not integrated.

## Regenerate assets

From the repository root, with Xcode selected:

```sh
./scripts/generate-icons.sh
./scripts/build-app.sh
```

The exporter compiles against the same path as the native UI, writes all seven PNG sizes from 16 through 1024 pixels into `Assets.xcassets/AppIcon.appiconset`, and replaces `FarIconSource.png` with the 1024-pixel export. No Python package or external image dependency is needed. Xcode packages the PNGs into the app icon resources.

## Provenance

The selected vector paths were authored for this project with AI assistance. No third-party icon paths, SF Symbol outlines, stock imagery or previous raster-icon pixels were incorporated. The PNGs are deterministic Core Graphics renders of those paths. This replaces the older raster icon whose provenance was undocumented. The original artwork is distributed under the project's [MIT license](../LICENSE); this record does not assert exclusivity or trademark clearance.
