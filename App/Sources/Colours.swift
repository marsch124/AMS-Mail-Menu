import AppKit
import SwiftUI

extension Color {
    /// The app's own colour: the blue of the envelope. A lighter blue at night, so it reads on dark.
    /// Used for headings, tags and main buttons instead of the Mac's highlight colour.
    static let mailBlue = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.42, green: 0.68, blue: 1.0, alpha: 1)
            : NSColor(red: 0.04, green: 0.36, blue: 0.77, alpha: 1)
    })
}
