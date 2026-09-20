import AppKit
import SwiftUI

#if canImport(FarCore)
    import FarCore
#endif

/// The popover owns its viewport; long status text scrolls instead of resizing
/// the native window after AppKit has positioned it beneath the menu bar.
struct MenuPopoverView: View {
    let content: MenuBarView
    let size: CGSize

    var body: some View {
        ScrollView(.vertical) {
            content.fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.farOpaqueSurfaces) private var opaquePreview
    var startBreak: () -> Void = {}
    var showSettings: () -> Void = {}
    var postpone: () -> Void = {}
    var skip: () -> Void = {}
    var pause: () -> Void = {}
    var quit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                FarBrandMark().fill(Color.farGreen)
                    .frame(width: 20, height: 23).accessibilityHidden(true)
                Text("Far").font(.system(size: 23, weight: .medium, design: .rounded))
                Spacer()
                Button(action: showSettings) { Image(systemName: "gearshape").frame(width: 32, height: 32) }
                    .buttonStyle(QuietPillButtonStyle()).accessibilityLabel("Settings")
                    .keyboardShortcut(",", modifiers: .command)
            }
            Text(model.menuStatus)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                Text(model.sinceRestLabel).font(.system(size: 12)).foregroundStyle(Color.farSecondary)
                Text(model.sinceRestTime).font(.system(size: 22, weight: .regular, design: .rounded))
                Divider()
                summaryRow("Screen time today", AppModel.formatDuration(model.snapshot.today.screenTime))
                summaryRow("Guided breaks today", "\(model.snapshot.today.guidedBreaks)")
                summaryRow("Away rests today", "\(model.snapshot.today.awayShortRests)")
            }
            .padding(18)
            .background(Color.farGreen.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
            if model.snapshot.stage.offersActions {
                HStack {
                    Button(model.postponeLabel, action: postpone).buttonStyle(SoftPillButtonStyle(glass: true))
                    Button("Skip", action: skip).buttonStyle(QuietPillButtonStyle())
                        .accessibilityLabel("Skip this break")
                }
            } else {
                Button(action: startBreak) {
                    HStack {
                        Spacer()
                        Text("Take a break now")
                        Spacer()
                    }
                }
                .buttonStyle(SoftPillButtonStyle(glass: true))
                .disabled(!model.canStartBreak)
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
            Toggle("Meeting mode", isOn: $model.manualMeetingMode)
                .toggleStyle(.switch).controlSize(.small).tint(.farGreen)
                .font(.system(size: 13))
                .help("Hold reminders until you turn Meeting mode off. Screen time still counts.")
            HStack {
                Button(model.reminderPaused ? "Resume reminders" : model.pauseLabel, action: pause)
                Spacer()
                Button("Quit Far", action: quit)
            }
            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color.farSecondary)
        }
        .padding(22)
        .frame(width: 336)
        .background {
            if reduceTransparency || opaquePreview { Color(nsColor: .windowBackgroundColor) }
            // The native popover owns the material; a second blur obscures its glass.
        }
    }
    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.farSecondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.system(size: 12))
    }
}
