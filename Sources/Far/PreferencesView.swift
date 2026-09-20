import AppKit
import SwiftUI

#if canImport(FarCore)
    import FarCore
#endif

enum PreferencesSection: String, CaseIterable, Identifiable {
    case breaks = "Breaks"
    case behavior = "Behavior"
    case app = "App & privacy"
    var id: String { rawValue }
}

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @State var section: PreferencesSection = .breaks
    var appVersion =
        Bundle.main.bundleIdentifier == "app.far.eyecare"
        ? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
        : "Development"
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Make room for rest.").font(.system(size: 25, weight: .medium, design: .rounded))
                Spacer()
                Text("Far \(appVersion)")
                    .font(.system(size: 12)).foregroundStyle(Color.farSecondary)
            }
            Picker("Settings section", selection: $section) {
                ForEach(PreferencesSection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch section {
                    case .breaks: breaks
                    case .behavior: behavior
                    case .app: app
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(26)
        .frame(minWidth: 510, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.farGreen)
    }
    private var breaks: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("Look away", symbol: "sun.horizon") {
                timing("Remind me every", .focusInterval, context: "Look-away interval")
                timing("Rest for", .focusDuration, context: "Look-away duration")
            }
            settingsGroup("Step away", symbol: "leaf") {
                timing("Remind me every", .recoveryInterval, context: "Recovery interval")
                timing("Rest for", .recoveryDuration, context: "Recovery duration")
            }
            timing("Postpone for", .postponeMinutes, context: "Postpone duration")
                .padding(.horizontal, 18)
            Text(
                "Intervals use counted screen time. If both breaks are due, step-away recovery comes first. Duration changes apply to your next break."
            )
            .font(.system(size: 12)).foregroundStyle(Color.farSecondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Changes save automatically.").font(.system(size: 12)).foregroundStyle(Color.farSecondary)
                Spacer()
                Button("Reset all timings") { model.resetTimings() }.buttonStyle(QuietPillButtonStyle())
            }
        }
    }
    private var behavior: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("A little notice", symbol: "clock") {
                timing("Countdown", .countdown, context: "Countdown duration")
                timing("Typing deferral, up to", .typingDeferral, context: "Maximum typing deferral")
                timing("Interrupt after working for", .interruption, context: "Outside-work interruption duration")
                timing("Menu pause lasts", .pauseMinutes, context: "Reminder pause duration")
            }
            Text(
                "Mouse movement never delays a break. Set typing deferral to 0 to show the countdown as soon as a break is due."
            )
            .font(.system(size: 12)).foregroundStyle(Color.farSecondary)
            .fixedSize(horizontal: false, vertical: true)
            settingsGroup("Meetings", symbol: "person.2") {
                Toggle("Detect likely calls automatically", isOn: $model.automaticMeetingDetection)
                    .toggleStyle(.switch).controlSize(.small)
                Text(model.meetingDetectionDetail).font(.system(size: 12)).foregroundStyle(Color.farSecondary)
                Text(
                    "Use Meeting mode in the menu for undetected calls. Recording and dictation can also hold reminders."
                )
                .font(.system(size: 12)).foregroundStyle(Color.farSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var app: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsGroup("At home on your Mac", symbol: "laptopcomputer") {
                Toggle("Sound when a break ends", isOn: $model.endSoundEnabled)
                HStack(spacing: 12) {
                    Picker("End sound", selection: $model.endSound) {
                        ForEach(BreakEndSound.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Button("Preview") { model.previewEndSound() }
                        .buttonStyle(QuietPillButtonStyle())
                        .accessibilityLabel("Preview \(model.endSound.rawValue) sound")
                }
                if let message = model.soundMessage {
                    Text(message).font(.system(size: 12)).foregroundStyle(Color.farSecondary)
                }
                Toggle(
                    "Launch Far when I log in",
                    isOn: Binding(get: { model.launchAtLoginEnabled }, set: { model.setLaunchAtLogin($0) }))
                if let message = model.launchAtLoginMessage {
                    Text(message).font(.system(size: 12)).foregroundStyle(Color.farSecondary)
                }
            }
            .toggleStyle(.switch).controlSize(.small)
            settingsGroup("Private by design", symbol: "lock") {
                Text(
                    "Far counts awake, unlocked screen time, including reading. An unattended unlocked screen can count too."
                )
                Text(
                    "Input counts, device availability, and audio-input activity stay on your Mac. Far never reads typed characters, records audio, or inspects windows or browser tabs."
                )
                Text(
                    "Only preferences, scheduling progress, and daily totals are saved. Screen saver, lock, or sleep earns away-rest credit after 30 seconds, and recovery credit after five minutes, separately from guided breaks."
                )
                Button("Review welcome & privacy") { model.requestOnboarding() }
                    .buttonStyle(SoftPillButtonStyle(glass: true))
            }
            .font(.system(size: 13))
        }
    }
    private func timing(_ label: String, _ setting: TimingSetting, context: String) -> some View {
        TimingRow(
            label: label, setting: setting,
            value: Binding(
                get: { model.timingValue(setting) }, set: { model.setTiming(setting, to: $0) }), context: context)
    }
    private func settingsGroup<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: symbol)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.farGreen)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.farGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct TimingRow: View {
    let label: String
    let setting: TimingSetting
    @Binding var value: Int
    let context: String
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 13))
            Spacer(minLength: 12)
            TextField(context, value: $value, formatter: Self.formatter)
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                .font(.system(size: 13)).monospacedDigit().frame(width: 58)
                .accessibilityLabel(context).accessibilityValue("\(value) \(setting.unit)")
            Text(setting.unit).font(.system(size: 12)).foregroundStyle(Color.farSecondary).frame(
                width: 25, alignment: .leading)
            Stepper(context, value: $value, in: setting.bounds).labelsHidden().controlSize(.small)
                .fixedSize().accessibilityLabel(context)
        }
        .frame(minHeight: 28)
        .help("\(setting.bounds.lowerBound)–\(setting.bounds.upperBound) \(setting.unit)")
    }
}
