import AppKit
import Foundation

extension Bundle {
    func opodsImage(named name: String) -> NSImage? {
        guard let url = url(forResource: name, withExtension: "png", subdirectory: nil) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
