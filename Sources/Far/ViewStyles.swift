import AppKit
import SwiftUI

struct SoftPillButtonStyle: ButtonStyle {
    var glass = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.farOpaqueSurfaces) private var opaquePreview
    @Environment(\.colorSchemeContrast) private var contrast
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(
                scheme == .dark
                    ? Color(red: 0.83, green: 0.95, blue: 0.88)
                    : Color(red: 0.09, green: 0.27, blue: 0.20)
            )
            .padding(.horizontal, 17)
            .frame(height: 36)
            .background(
                scheme == .dark
                    ? Color.black.opacity(configuration.isPressed ? 0.30 : 0.18)
                    : Color.farGreen.opacity(configuration.isPressed ? 0.18 : 0.10), in: Capsule()
            )
            .background {
                if glass && !reduceTransparency && !opaquePreview && contrast != .increased {
                    GlassPillBackground().allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.45)
    }
}
struct QuietPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(Color.farSecondary)
            .padding(.horizontal, 17)
            .frame(height: 36)
            .background(Color.primary.opacity(configuration.isPressed ? 0.08 : 0), in: Capsule())
            .contentShape(Capsule())
    }
}

extension Color {
    static let farSecondary = Color(
        light: NSColor(white: 0.22, alpha: 1),
        dark: NSColor(white: 0.84, alpha: 1))
    static let farGreen = Color(
        light: NSColor(red: 0.15, green: 0.39, blue: 0.30, alpha: 1),
        dark: NSColor(red: 0.52, green: 0.78, blue: 0.65, alpha: 1))
    private init(light: NSColor, dark: NSColor) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            })
    }
}
