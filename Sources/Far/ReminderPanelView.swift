import AppKit
import SwiftUI

#if canImport(FarCore)
    import FarCore
#endif

/// Content only: the native surface provides rounded blur in both the app and preview tests.
struct ReminderPanelView: View {
    let snapshot: BreakSnapshot
    let postpone: () -> Void
    let skip: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch snapshot.stage {
            case .countdown(let kind, let remaining): notice(kind, remaining)
            case .resting(let kind, let remaining): rest(kind, remaining)
            case .completion: completion
            default: Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
    private func notice(_ kind: BreakKind, _ remaining: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(kind == .focusReset ? "Time to look far" : "Time to step away")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                    Text(
                        "\(AppModel.formatDuration(snapshot.tracking.screenSinceRest)) \(snapshot.tracking.hasKnownRest ? "since your last rest" : "since tracking began")"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(Color.farSecondary)
                }
                Spacer(minLength: 0)
                VStack(spacing: 1) {
                    Text("Starts in").font(.system(size: 11)).foregroundStyle(Color.farSecondary)
                    Text("\(max(1, Int(ceil(remaining))))s")
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .monospacedDigit().foregroundStyle(Color.farGreen)
                }
                .frame(width: 66)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Break starts in \(max(1, Int(ceil(remaining)))) seconds")
            }
            noticeSummary
            panelActions
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            let outline = RoundedRectangle(cornerRadius: 28, style: .continuous)
            outline.stroke(Color.farGreen.opacity(0.15), lineWidth: 1)
                .overlay {
                    outline.trim(from: 0, to: max(0, min(1, remaining / max(1, snapshot.countdownLength))))
                        .stroke(Color.farGreen.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .animation(reduceMotion ? nil : .linear(duration: 0.25), value: remaining)
                }
                .padding(3)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
    private var noticeSummary: some View {
        let fraction = min(1, snapshot.tracking.screenSinceRest / max(1, snapshot.configuration.focusResetThreshold))
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                ForEach(0..<20) { index in
                    Capsule().fill(Double(index) < fraction * 20 ? Color.farGreen : Color.farGreen.opacity(0.13))
                }
            }
            .frame(height: 5)
            .accessibilityHidden(true)
            HStack {
                Text("\(Int(snapshot.configuration.focusResetThreshold / 60)) min reminder interval")
                Spacer()
                Text("\(snapshot.today.restCount) \(snapshot.today.restCount == 1 ? "rest" : "rests") today")
            }
            .font(.system(size: 11))
            Text("\(AppModel.formatDuration(snapshot.today.screenTime)) of screen time today")
                .font(.system(size: 12))
        }
        .foregroundStyle(Color.farSecondary)
        .accessibilityElement(children: .combine)
        .help(
            "The bar shows counted screen time since rest against your look-away interval. Rests include completed guided breaks and away periods of at least 30 seconds, including screen saver."
        )
    }
    private func rest(_ kind: BreakKind, _ remaining: TimeInterval) -> some View {
        VStack(spacing: 0) {
            FarBrandMark().fill(Color.farGreen)
                .frame(width: 27, height: 32)
                .accessibilityHidden(true)
                .padding(.bottom, 17)
            Text(kind == .focusReset ? "Look a little further." : "Take a little space.")
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
            Text(kind == .focusReset ? "Find a spot across the room." : "Step away from your screens.")
                .font(.system(size: 14))
                .foregroundStyle(Color.farSecondary)
                .padding(.top, 8)
            Text(time(remaining))
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.farSecondary)
                .padding(.top, 18)
                .accessibilityLabel("\(Int(ceil(remaining))) seconds remaining")
            Spacer(minLength: 18)
            panelActions
        }
        .padding(.horizontal, 28)
        .padding(.top, 29)
        .padding(.bottom, 24)
    }
    private var panelActions: some View {
        HStack(spacing: 14) {
            Button("Postpone · \(Int(snapshot.configuration.postponeDuration / 60)) min", action: postpone)
                .buttonStyle(SoftPillButtonStyle())
                .keyboardShortcut(.cancelAction)
                .accessibilityHint("Retry after the configured delay; this attempt will not count as a completed break")
            Button("Skip", action: skip)
                .buttonStyle(QuietPillButtonStyle())
                .accessibilityLabel("Skip this break")
                .accessibilityHint("Start a fresh interval without recording a completed break")
        }
        .frame(maxWidth: .infinity)
    }
    private var completion: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 23, weight: .light))
                .foregroundStyle(Color.farGreen)
                .accessibilityHidden(true)
            Text("You’re all set.")
                .font(.system(size: 23, weight: .medium, design: .rounded))
            Text("Back when you’re ready.")
                .font(.system(size: 14))
                .foregroundStyle(Color.farSecondary)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
    private func time(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(ceil(remaining)))
        return String(format: "%d:%02d remaining", seconds / 60, seconds % 60)
    }
}
