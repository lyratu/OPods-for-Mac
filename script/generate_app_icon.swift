import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "script/icon-sources/Untitled2.icon/Assets/AppIcon.png", relativeTo: root)
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst(2).first ?? "Sources/OPodsMac/Resources/AppIcon.icns", relativeTo: root)
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("opods-app-icon.iconset", isDirectory: true)

let entries = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

guard let image = NSImage(contentsOf: source) else {
    fputs("Cannot read icon source: \(source.path)\n", stderr)
    exit(1)
}

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for entry in entries {
    let pixels = entry.0 * entry.1
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("Cannot create \(entry.2)\n", stderr)
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Cannot encode \(entry.2)\n", stderr)
        exit(1)
    }
    try png.write(to: iconset.appendingPathComponent(entry.2))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", "-o", output.path, iconset.path]
try iconutil.run()
iconutil.waitUntilExit()

if iconutil.terminationStatus != 0 {
    exit(iconutil.terminationStatus)
}
