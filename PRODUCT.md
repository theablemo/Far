# Far

Far is a native macOS menu-bar app for people doing sustained screen work. Its job is to make short screen breaks actionable while keeping the desktop usable. The app is local-only and supports macOS 13 and later.

## Agreed priority behavior

By default, after 20 counted screen minutes, offer a 30-second break. After 60 counted minutes, offer five-minute recovery, taking priority over a simultaneously due short break. Settings lets the user change both intervals and durations while preserving separate scheduling progress. Defer sustained typing for no more than two extra eligible minutes. Give a visible countdown (15 seconds by default, adjustable from 5–60) that survives mouse movement before starting automatically.

The countdown appears at top center and transitions into a centered, nonblocking rest panel. Following user feedback, overlays use strongly rounded shapes, sparse instructions, and a small timer. The notice includes a compact current-stretch bar, today’s screen time, and recorded rest count. Detailed guided/away counts remain in the menu. Blur stays within the panel; click-through backdrops dim every display during rest. Never steal keyboard focus on appearance. Postpone and Skip remain separate actions in both states. Postpone defaults to five counted minutes and is configurable from 1–60. Skip resets only that break's reminder interval and never counts as completed rest. Sustained work during rest interrupts and postpones; incidental pointer movement does nothing.

## Counting and privacy

Count awake, unlocked device use, including reading and meetings. Exclude guided rest and unavailable-device time. An unattended unlocked screen can overcount; no gaze measurement is claimed. Continuous lock/sleep/screen-saver/display-off time earns short-rest credit at 30 seconds and recovery at 5 minutes, separately from guided completions. Ordinary input inactivity earns no rest credit.

Persist only local preferences, daily aggregate totals, and scheduling progress. Preserve true counted time since rest independently of skip/postpone schedules. Do not infer screen activity or rest across app downtime. No keystroke contents, audio recording, camera, window-content inspection, browser-tab inspection, analytics, or network transmission.

## Meetings

Native audio-input activity is a best-effort likely-call signal. Manual Meeting mode covers undetected calls. Audio capture by unrelated software can suppress reminders; muted/listen-only meetings can be missed. Automatic detection can be disabled. Full-screen ordinary work does not suppress reminders.

## Delivery boundary

The first public version is distributed through GitHub Releases as a universal, ad-hoc-signed app. App Store distribution and Developer ID signing/notarization are not included in this release. Meeting detection remains best effort. Automated and offscreen evidence must be distinguished from live device validation.

## Menu and Settings

The menu attaches to its status icon using a transient, non-detachable native popover. Close it before starting a manual break and when an automatic countdown begins. Reopening it during rest shows status and controls without a second timer. Settings shares the prompts' rounded typography, green accent, and capsule controls, with Breaks, Behavior, and App & privacy tabs. Six system completion sounds are selectable with an explicit Preview action. All visible schedule and control timings are editable, bounded, and saved locally; active countdown/rest deadlines remain stable when durations change. Resetting timings never resets measured statistics.
