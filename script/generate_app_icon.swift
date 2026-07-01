import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "script/icon-sources/Untitled1-iOS-Default-1024@1x.png", relativeTo: root)
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst(2).first ?? "Sources/OPodsMac/Resources/AppIcon.icns", relativeTo: root)

let entries = [
    (16, "icp4"),
    (32, "icp5"),
    (32, "ic11"),
    (64, "icp6"),
    (64, "ic12"),
    (128, "ic07"),
    (256, "ic08"),
    (256, "ic13"),
    (512, "ic09"),
    (512, "ic14"),
    (1024, "ic10")
]

guard let image = NSImage(contentsOf: source) else {
    fputs("Cannot read icon source: \(source.path)\n", stderr)
    exit(1)
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { data.append(contentsOf: $0) }
}

func pngData(size pixels: Int) -> Data? {
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
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    return bitmap.representation(using: .png, properties: [:])
}

var blocks = Data()

for entry in entries {
    guard let type = entry.1.data(using: .ascii), let png = pngData(size: entry.0) else {
        fputs("Cannot encode \(entry.1)\n", stderr)
        exit(1)
    }
    blocks.append(type)
    appendUInt32(UInt32(png.count + 8), to: &blocks)
    blocks.append(png)
}

var icns = Data("icns".utf8)
appendUInt32(UInt32(blocks.count + 8), to: &icns)
icns.append(blocks)
try icns.write(to: output)
