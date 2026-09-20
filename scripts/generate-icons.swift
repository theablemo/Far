import AppKit

/// Compile alongside FarBrandMark.swift so exports and native UI use identical curves.
@main enum GenerateIcons {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let catalog = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let context = CGContext(
                data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            // Match the approved 512-unit tile and top-left SVG coordinates exactly.
            context.translateBy(x: 0, y: CGFloat(size))
            context.scaleBy(x: CGFloat(size) / 512, y: -CGFloat(size) / 512)
            context.setFillColor(CGColor(srgbRed: 32 / 255, green: 80 / 255, blue: 62 / 255, alpha: 1))
            context.addPath(
                CGPath(
                    roundedRect: CGRect(x: 16, y: 16, width: 480, height: 480),
                    cornerWidth: 108, cornerHeight: 108, transform: nil))
            context.fillPath()
            context.translateBy(x: 49.6, y: 49.6)
            context.scaleBy(x: 4.128, y: 4.128)
            context.setFillColor(CGColor(srgbRed: 237 / 255, green: 247 / 255, blue: 240 / 255, alpha: 1))
            context.addPath(FarBrand.designPath)
            context.fillPath()
            let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
            let data = bitmap.representation(using: .png, properties: [:])!
            try data.write(to: catalog.appendingPathComponent("AppIcon-\(size).png"))
            if size == 1024 {
                try data.write(to: root.appendingPathComponent("Resources/FarIconSource.png"))
            }
        }
        print("Exported Soft pause at all seven app-icon sizes.")
    }
}
