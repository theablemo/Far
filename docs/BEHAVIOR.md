# Scheduling, settings, and privacy

## Configurable timing

Settings saves changes automatically and provides **Reset all timings**. Fields accept whole numbers; steppers and typed values use the same bounds.

| Setting | Default | Range |
| --- | --- | --- |
| Look-away interval | 20 min | 1–180 min |
| Look-away rest | 30 sec | 5–600 sec |
| Step-away interval | 60 min | 1–480 min |
| Step-away rest | 5 min | 1–60 min |
| Postpone | 5 min | 1–60 min |
| Countdown | 15 sec | 5–60 sec |
| Maximum typing deferral | 120 sec | 0–120 sec |
| Work before interrupting rest | 3 sec | 1–15 sec |
| Menu pause | 60 min | 1–240 min |

Intervals are independent and use counted screen time. Changing an interval preserves counted progress; a newly due break can start on the next tick. Changing a duration does not alter an active countdown or rest deadline. The next attempt uses the new duration. Away-rest credit remains fixed at 30 seconds and five minutes, separate from customizable guided rests.

## How breaks work with the defaults

- A 30-second distant-focus break becomes due after 20 counted minutes; five-minute recovery becomes due after 60. Recovery takes priority when both are due.
- Sustained typing can delay a due notice by at most two additional eligible minutes. Ten key-down events within five seconds establishes typing; three seconds without typing releases the delay. Mouse movement never dismisses the notice, and the countdown starts the break automatically.
- **Postpone** retries after five counted minutes by default. Change this to 1–60 minutes in Settings.
- **Skip this break** starts a fresh interval for that break type. Another due break type can still appear. Neither action earns completion credit or changes the true time since your last rest.
- During a break, three seconds of sustained keyboard, click, scroll, or drag activity outside Far interrupts the break and postpones it. Pointer movement alone does nothing. Both controls remain available throughout.
- A completed break shows a brief confirmation and optionally plays one sound. Short breaks preserve progress toward the longer recovery break.

## What the time means

Far counts awake, unlocked screen time, including reading and meetings. It cannot determine whether you are looking at the screen: an unattended unlocked Mac can count too. App downtime is never inferred as screen time or rest.

Lock, sleep, screen saver, inactive login sessions, and all displays being off stop counting. Thirty continuous seconds in those states earns short-rest credit, and five minutes earns recovery credit. Away credit is separate from guided completion counts. Ordinary keyboard/mouse inactivity earns no rest credit.

Far saves preferences, scheduling progress, and local daily totals in UserDefaults. Daily totals split at local midnight. Input contents and activity histories are not saved. Normal quits save immediately; an abrupt termination can lose up to five seconds since the last checkpoint. Counts from the previous prototype cannot be reconstructed. The old reminder-style presets are replaced by the bounded two-minute policy; sound and launch-at-login preferences are preserved.

## Meetings and privacy

Automatic detection uses Core Audio input activity as a likely-call signal. macOS 14.2+ uses process-level input state; older supported systems use running input-capable devices. Detection settles for two seconds before suppressing reminders, and waits 15 seconds after the signal ends before releasing them. The older device-level fallback can also react to playback on a duplex device.

This is best-effort detection, not a universal meeting API. Recording or dictation may hold reminders; some muted or listen-only calls may be missed. Use **Meeting mode** in the menu for those calls, and turn it off afterward. Turn automatic detection off in Settings if unrelated microphone use keeps reminders held. The menu shows the suppression reason; detector errors are surfaced in Settings. Ordinary full-screen windows do not suppress reminders.

Far does not record audio, read typed characters, use a camera, inspect window contents, read browser tabs, or send activity anywhere. Lock/screen-saver detection includes macOS distributed-notification conventions, isolated in the system adapter; these require verification when supporting new OS versions.
