import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Far"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(
            rootView: OnboardingView(
                model: model,
                finish: { [weak self] in
                    self?.model.completeOnboarding()
                    self?.window?.close()
                }
            ))
        window.delegate = self
        return window
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text("Look far. Stay in flow.")
                    .font(.largeTitle.weight(.semibold))
                Text("A little notice. A real break. Room to stay in control.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                OnboardingFeatureRow(
                    symbol: "pause.circle",
                    title: "A clear countdown",
                    detail:
                        "Choose your break intervals and durations in Settings. Far gives you a countdown before each break. Postpone or skip whenever you need."
                )
                OnboardingFeatureRow(
                    symbol: "hand.raised.fill",
                    title: "Your activity stays private",
                    detail:
                        "Far uses input counts, device state, and audio-input activity. No typed characters, audio recordings, window contents, or browser tabs."
                )
                OnboardingFeatureRow(
                    symbol: reduceMotion ? "circle.dotted" : "sparkles",
                    title: "Comfortable by default",
                    detail:
                        "Locked and sleeping time counts as rest. Likely calls hold reminders; Meeting mode covers missed calls. Only daily totals are saved."
                )
            }

            VStack(spacing: 12) {
                Toggle("Play one gentle sound when a break ends", isOn: $model.endSoundEnabled)
                    .toggleStyle(.switch)
            }

            Button("Start using Far") {
                finish()
            }
            .buttonStyle(SoftPillButtonStyle(glass: true))
            .controlSize(.large)
            .tint(.farGreen)
            .keyboardShortcut(.defaultAction)
            .accessibilityHint("Closes this welcome window and starts quiet break tracking")
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 30)
        .frame(width: 560, height: 580)
        .background {
            if reduceTransparency { Color(nsColor: .windowBackgroundColor) } else { Rectangle().fill(.regularMaterial) }
        }
    }
}

private struct OnboardingFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.farGreen)
                .frame(width: 30, height: 30)
                .background(Color.farGreen.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
