import AppKit
import Combine
import SwiftUI

#if canImport(FarCore)
    import FarCore
#endif

@main
struct FarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView(model: appDelegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    private var panelController: ReminderPanelController?
    private var menuController: StatusMenuController?
    private var onboardingCancellable: AnyCancellable?
    private var screenObserver: NSObjectProtocol?
    private var onboardingController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelController = ReminderPanelController(model: model)
        self.panelController = panelController
        menuController = StatusMenuController(model: model)

        let onboardingController = OnboardingWindowController(model: model)
        self.onboardingController = onboardingController
        onboardingCancellable = model.$onboardingRequestID
            .dropFirst()
            .sink { [weak onboardingController] _ in
                onboardingController?.show()
            }
        if !model.hasCompletedOnboarding {
            onboardingController.show()
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak panelController, weak menuController = self.menuController] _ in
            Task { @MainActor in
                panelController?.repositionIfVisible()
                // A moved/removed display invalidates the popover's anchor and
                // height budget. Reopening measures the current screen again.
                menuController?.dismiss()
            }
        }

    }

    func applicationWillTerminate(_ notification: Notification) {
        menuController?.close()
        panelController?.close()
        model.shutdown()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
}
