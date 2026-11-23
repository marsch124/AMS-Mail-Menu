import AppKit
import SwiftUI

extension Color {
    private static func dayNight(_ day: NSColor, _ night: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? night : day })
    }

    /// The colour of an iCloud account: violet.
    static let accountViolet = dayNight(NSColor(red: 0.49, green: 0.30, blue: 0.82, alpha: 1),
                                        NSColor(red: 0.70, green: 0.56, blue: 1.0, alpha: 1))
    /// The colour of a Gmail account: green.
    static let accountGreen = dayNight(NSColor(red: 0.13, green: 0.55, blue: 0.30, alpha: 1),
                                       NSColor(red: 0.36, green: 0.80, blue: 0.50, alpha: 1))

    /// The app's own colour: the blue of the envelope. A lighter blue at night, so it reads on dark.
    /// Used for headings, tags and main buttons instead of the Mac's highlight colour.
    static let mailBlue = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.42, green: 0.68, blue: 1.0, alpha: 1)
            : NSColor(red: 0.04, green: 0.36, blue: 0.77, alpha: 1)
    })
}
