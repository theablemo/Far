---
name: Far
description: Strongly rounded native screen-break guidance with room to rest.
colors:
  far-green-light: "rgb(15% 39% 30%)"
  far-green-dark: "rgb(52% 78% 65%)"
  far-secondary-light: "rgb(22% 22% 22%)"
  far-secondary-dark: "rgb(84% 84% 84%)"
  postpone-text-light: "rgb(9% 27% 20%)"
  postpone-text-dark: "rgb(83% 95% 88%)"
typography:
  countdown:
    fontFamily: "system-ui"
    fontSize: "32pt"
    fontWeight: 300
    fontFeature: "tabular-nums"
  rest-timer:
    fontFamily: "system-ui"
    fontSize: "17pt"
    fontWeight: 400
    fontFeature: "tabular-nums"
  notice-title:
    fontFamily: "system-ui"
    fontSize: "19pt"
    fontWeight: 500
  rest-title:
    fontFamily: "system-ui"
    fontSize: "25pt"
    fontWeight: 500
  completion-title:
    fontFamily: "system-ui"
    fontSize: "23pt"
    fontWeight: 500
  menu-status:
    fontFamily: "system-ui"
    fontSize: "16pt"
    fontWeight: 500
  summary-value:
    fontFamily: "system-ui"
    fontSize: "22pt"
    fontWeight: 400
  group-title:
    fontFamily: "system-ui"
    fontSize: "17pt"
    fontWeight: 500
  body:
    fontFamily: "system-ui"
    fontSize: "14pt"
    fontWeight: 400
  label:
    fontFamily: "system-ui"
    fontSize: "13pt"
    fontWeight: 400
  action:
    fontFamily: "system-ui"
    fontSize: "13pt"
    fontWeight: 500
rounded:
  group: "24pt"
  notice: "30pt"
  rest: "36pt"
  completion: "32pt"
spacing:
  menu-inset: "22pt"
  summary-inset: "18pt"
  settings-inset: "26pt"
  group-inset: "20pt"
  notice-text-gap: "5pt"
  notice-stack: "12pt"
  action-gap: "14pt"
  notice-row-gap: "16pt"
  action-horizontal: "17pt"
  notice-horizontal: "26pt"
  rest-horizontal: "28pt"
  completion-inset: "24pt"
components:
  menu-content:
    width: "336pt"
    padding: "{spacing.menu-inset}"
  menu-summary:
    rounded: "{rounded.group}"
    padding: "{spacing.summary-inset}"
  settings-group:
    rounded: "{rounded.group}"
    padding: "{spacing.group-inset}"
  timing-input:
    typography: "{typography.label}"
    width: "58pt"
  settings-navigation:
    width: "100%"
  notice-panel:
    rounded: "{rounded.notice}"
    padding: "22pt 26pt"
    width: "420pt"
    height: "252pt"
  rest-panel:
    rounded: "{rounded.rest}"
    padding: "29pt 28pt 24pt"
    width: "392pt"
    height: "292pt"
  completion-panel:
    rounded: "{rounded.completion}"
    padding: "{spacing.completion-inset}"
    width: "320pt"
    height: "180pt"
  countdown-number:
    typography: "{typography.countdown}"
    width: "66pt"
  rest-timer:
    typography: "{typography.rest-timer}"
  button-postpone:
    typography: "{typography.action}"
    padding: "0pt 17pt"
    height: "36pt"
  button-skip:
    typography: "{typography.label}"
    padding: "0pt 17pt"
    height: "36pt"
---

# Design System: Far

## Overview

**Creative North Star: "Room to rest"**

Far uses strongly rounded native material surfaces, rounded system headings, and restrained green accents to make screen breaks feel soothing and easy to act on. Each overlay is sparse: a little notice, one place to look away, then a short completion message. “Room to rest” names the implemented direction; the break-flow and menu/settings surface contracts guide its application. The menu and Settings extend the same rounded headings, green accents, and capsule actions into everyday controls.

**Key Characteristics:**

- Strongly rounded silhouettes shape the actual native backdrop.
- Instructions lead; the rest timer stays subordinate.
- Soft capsule actions keep Postpone and Skip separate.
- The notice adds two compact daily totals; the rest panel keeps its quiet focus.
- Rounded internal groups sit inside native popover and window chrome.

## Colors

### Primary

**Forest green** and **soft green** are the light/dark `far-green` pair. Use them for the notice countdown, resting symbol, completion checkmark, and existing explicit start actions. The rest timer uses secondary text so it does not compete with the instruction.

### Neutral

The `far-secondary` pair carries measured screen time, supporting instructions, remaining time, and Skip. The `postpone-text` pair provides a distinct green foreground for the filled action. Main text and material surfaces retain native semantic colors.

Postpone uses green at 10% opacity in light appearance and black at 18% in dark appearance; pressing increases those to 18% and 30%. Skip is normally clear and gains primary color at 8% opacity while pressed.

**The Appearance Rule.** Use the matching light or dark foregrounds and let macOS resolve native text and material. A sampled translucent background is not a palette token.

## Typography

Headings and changing numerals use SwiftUI's rounded system design. Body copy and action labels use the standard system design. The frontmatter records native point sizes; sidecar preview pixels are illustrative equivalents.

The notice pairs `notice-title` with a light countdown numeral. Rest gives `rest-title` visual priority and places the much smaller `rest-timer` below the supporting instruction. Completion uses its own compact title role. Countdown and rest time use monospaced digits. The menu uses the completion-title scale for “Far,” menu-status for state, and summary-value for measured time since rest. This summary is not a rest countdown. Settings uses the rest-title scale for its heading and group-title for section labels. Welcome retains its existing native typography.

## Layout

The three stage dimensions and insets are normative in the frontmatter. Notice sits at top center of the chosen display's visible area. Rest and completion sit at center and remain centered on later ticks. The flow retains its display while available; placement is clamped to the chosen visible frame and falls back when a display disappears.

Notice holds one heading, measured time since rest (or since tracking began), a labeled countdown, a segmented bar against the look-away interval, today’s screen/rest totals, and the action row. A two-point inset perimeter stroke recedes over the stable countdown deadline. Rest holds one lightweight symbol, a centered instruction, one supporting line, subordinate remaining time, and actions. Completion is a small centered acknowledgment. The rest and completion stages omit daily totals.

The menu content is fixed-width with a compact heading, status, measured totals, and actions. Its transient, non-detachable `NSPopover` anchors to the status button bounds on `.minY`; AppKit supplies placement and the outer chrome and arrow. It closes before a manual break and on entry into countdown/rest. Reopening during rest shows status and actions without a second countdown.

Settings opens at 560×650 points with a 510×560 minimum, a segmented three-tab selector (Breaks, Behavior, App & privacy), and a scrolling content region. Groups use the shared group radius and inset; menu summaries use their own smaller inset.

AppKit owns the panel frame, material bounds, and hosted content bounds. `NSHostingView.sizingOptions` is empty. Content and geometry use the same emitted immutable snapshot. Cancellable interpolation reapplies the exact destination frame; SwiftUI content updates must not resize or relocate the window.

## Elevation & Depth

On macOS 26+, `NSGlassEffectView` embeds the hosted break content in the system Liquid Glass material. Earlier systems use an active `NSVisualEffectView` with `.hudWindow` material and `.behindWindow` blending. The native panel supplies its own shadow. Reduce Transparency hides the material and uses opaque `windowBackgroundColor`; rest adds a nonactivating, click-through black backdrop at 60% opacity on each display, below the prompt. Backdrops fade in over 0.35 seconds and clear immediately when rest ends or is interrupted. Reduce Motion shows them immediately.

The menu leaves its background to native popover chrome, avoiding a second material layer; Reduce Transparency supplies an opaque semantic background. Settings uses opaque semantic `windowBackgroundColor`; its groups use green at 6% opacity and menu summaries at 7%. Neither internal group adds a shadow. Native popover animation respects Reduce Motion and dismissal before a break is synchronous.

Appearance fades over 0.18 seconds, stage movement/resizing lasts 0.42 seconds, and dismissal fades over 0.15 seconds. Geometry and window opacity use cubic ease-out, `1 − (1 − t)³`. During a stage change, content reveals from 15% to 80% of the transition. Reduce Motion places the final frame and opacity immediately. The panel is nonactivating; physical desktop focus behavior remains unverified.

## Brand mark

The approved identity is the original **Soft pause**, without an eye: two rounded vertical forms. `FarBrandMark.swift` supplies the same vector geometry for SwiftUI, the AppKit menu template and app-icon export. The app tile uses `#20503e` with a `#edf7f0` mark; in-app marks inherit semantic `far-green`. Menu headings use a 20 × 23 point frame and both rest prompts a 27 × 32 point frame. The normal status-item image is an 18-point template with a 16-point-tall mark. Semantic system symbols continue to distinguish countdown, resting, completion and held reminders. See `Resources/ICONOGRAPHY.md` for provenance and regeneration.

## Shapes

Strong rounding is an explicit user requirement. Each stage uses its own radius rather than a shared small corner. A continuous root-layer clip and `NSGlassEffectView.cornerRadius` shape Liquid Glass. The older-system fallback uses a stretchable `NSVisualEffectView.maskImage`; the material layer also carries the stage radius. A SwiftUI-only clip is insufficient for this surface.

Overlay, menu, and Settings actions share `SoftPillButtonStyle` and `QuietPillButtonStyle`, using `Capsule()` for background and hit shape. Their shared height determines the capsule endcaps; keep the roomy horizontal inset. Internal menu summaries and Settings groups use the group radius; native popover chrome remains system-owned. Timing fields, steppers, segmented navigation, and switches retain native affordances. Quiet pause/quit links remain plain.

## Components

- **Notice panel:** Compact top-center promise of the upcoming break. Its countdown says “Starts in” with an explicit seconds suffix. The progress border is decorative for accessibility; the numeral supplies the remaining time.
- **Rest panel:** The Soft pause mark supports one instruction. The timer includes “remaining” and stays quiet; it is not a hero numeral.
- **Completion panel:** Checkmark, acknowledgment, and return message without daily accounting.
- **Postpone:** Soft filled capsule showing the configured delay, with Escape as its cancel shortcut.
- **Skip:** Quiet capsule labeled “Skip,” with the full accessibility label “Skip this break.” Pressed treatment makes its response visible.

- **Shared capsule actions:** Soft fill for break/start/review actions, quiet treatment for secondary actions and Settings. Soft capsules use 45% opacity when disabled. The same styles appear in prompts, menu, and Settings.
- **Timing row:** A labeled, right-aligned whole-number field, visible unit, and native stepper. Bounds are supplied by `TimingSetting` and exposed in help text; accessibility labels identify each schedule. Edits save locally; changing durations preserves an active countdown/rest deadline. Reset all timings preserves measured totals.
- **Settings navigation:** Native segmented selection keeps the three sections visible; the selected section scrolls within the resizable window.
- **Rounded groups:** A restrained green tint groups related settings and measured menu totals without competing with their headings.

The older sidecar supplies historical web approximations; the native source and 0.4.0 review fixtures define the current notice and dimming behavior. Browser focus/hover treatments and opaque preview backgrounds are documentation aids, not evidence of native rendering. Synthesized tonal ramps are swatch aids, not shipping palette values.

Pre-glass offscreen captures are in `.impeccable/review/refinement-2026-09-20/`: 23 views covering both themes, notice start/halfway, menu states, Settings, rest, recovery, completion, and material appearances. The countdown border was corrected to follow the native panel edge after inspection. The subsequent Soft pause integration regenerated the shipping app-icon rasters; updated native offscreen fixtures are in `.impeccable/review/soft-pause/`. See VALIDATION.md for functional evidence and the physical-desktop limitations.

## Do's and Don'ts

### Do:

- Do preserve the distinct notice, rest, and completion dimensions and strongly rounded shapes.
- Do mask the native material and let AppKit own window and hosted-view geometry.
- Do keep the rest instruction prominent and its timer subordinate.
- Do keep Postpone and Skip adjacent, distinct, and readable.
- Do honor Reduce Motion and Reduce Transparency.
- Do share capsule actions and rounded group styling across prompts, menu, and Settings.
- Do leave popover placement, outer chrome, and arrow to AppKit.

### Don't:

- Don't duplicate the rest countdown in the menu.
- Keep notice statistics compact and omit them during rest.
- Don't substitute a SwiftUI-only clip for the native backdrop mask.
- Don't let timer ticks move a centered rest or completion panel.
- Dim every display during rest without taking focus or blocking desktop input.
- Don't treat native-host review fixtures as shipping artwork or proof of physical desktop behavior.

## Liquid Glass adaptation — 2026-09-20

Preserve the existing composition, typography, green accent, stage geometry, countdown, dimming and actions. Glass belongs to the floating break surface and selected primary controls in the menu, privacy settings and welcome. The break panel's own actions keep their soft fills to avoid glass inside glass. Settings groups and measured totals stay flat and readable; no decorative refractive layers or additional animation.

`FarGlass` isolates the public AppKit API. Xcode 26+ instantiates the typed class; the installed Xcode 16.4 build resolves the public Objective-C class and checks its documented setters at runtime. macOS 13–15 retain the original HUD material and capsule fills. Reduce Transparency hides glass, reparents the hosted content to the opaque root, and removes glass control backgrounds. Increased Contrast also removes the control glass backgrounds. SwiftUI owns button focus, input and accessibility; decorative AppKit backgrounds never hit-test.

Opaque fixtures are in `.impeccable/review/liquid-glass/*-opaque.png`. Native glass cannot be verified by `cacheDisplay`: those captures may omit composited content. Actual refraction, desktop contrast, hover and live focus still require desktop-connected review. Do not present offscreen material captures as the glass design.

## Menu viewport ownership

The native popover keeps its status-item anchor and arrow. Before showing, a measurement host determines the content height; a plain NSViewController and a hosting view with sizingOptions disabled receive explicit bounds. The viewport is capped to the space below the anchor in that screen's visible frame, leaving 24 points for chrome and margins. Content aligns to the top and scrolls on short displays. SwiftUI and native glass subviews cannot enlarge or reposition the open menu. Display changes dismiss stale placement.
