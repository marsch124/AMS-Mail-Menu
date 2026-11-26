import AppKit
import MailMenuCore

/// The drawings in the menu bar that SwiftUI cannot make there itself: the warning mark (an envelope with an
/// orange "!" badge) and the time of the newest new email as two small thin lines ("08:" over "09").
/// A menu bar label only takes one picture and one word, so both are drawn here as pictures.
enum MenuBarArt {
    /// The warning mark (the owner's pick 2 of 3, 26 Nov 2026): the menu bar's envelope with a filled badge
    /// and a white "!" at the top right, all orange — orange is the warning colour of the whole app.
    /// It keeps its colour, so it reads on a light and on a dark menu bar alike.
    static let warningMark: NSImage = {
        let colour = NSColor.systemOrange
        let size = NSSize(width: 23, height: 17)
        let image = NSImage(size: size, flipped: false) { _ in
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                .applying(.init(paletteColors: [colour]))
            if let envelope = NSImage(systemSymbolName: "envelope", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                let e = envelope.size
                envelope.draw(in: NSRect(x: 0, y: (size.height - e.height) / 2 - 1, width: e.width, height: e.height))
            }
            // The badge: a cut-out ring (so it stands apart from the envelope), then the filled circle with "!".
            let badge = NSRect(x: size.width - 10, y: size.height - 10, width: 10, height: 10)
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: badge.insetBy(dx: -1.5, dy: -1.5)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            colour.setFill()
            NSBezierPath(ovalIn: badge).fill()
            let mark = NSAttributedString(string: "!", attributes: [
                .font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: NSColor.white,
            ])
            let m = mark.size()
            mark.draw(at: NSPoint(x: badge.midX - m.width / 2, y: badge.midY - m.height / 2 + 0.3))
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Something is wrong"
        return image
    }()

    /// One piece of the menu bar label.
    enum Part {
        case picture(NSImage)
        case word(String)
        case time(Date)
    }

    /// The whole label as ONE picture: a menu bar label shows only its first picture, so the envelope, the
    /// number and the time are drawn side by side here. When nothing in it has its own colour, the Mac paints
    /// it in the menu bar's colour (a template); otherwise the plain parts are drawn black by day, white at night.
    static func label(_ parts: [Part], dark: Bool) -> NSImage {
        let coloured = parts.contains { if case .picture(let p) = $0 { return !p.isTemplate } else { return false } }
        let ink: NSColor = coloured ? (dark ? .white : .black) : .black
        let pictures: [NSImage] = parts.map { part in
            switch part {
            case .picture(let p): return p
            case .word(let w):
                let text = NSAttributedString(string: w, attributes: [.font: NSFont.menuBarFont(ofSize: 0),
                                                                      .foregroundColor: NSColor.black])
                let s = text.size()
                let i = NSImage(size: NSSize(width: ceil(s.width), height: ceil(s.height)), flipped: false) { _ in
                    text.draw(at: .zero); return true
                }
                i.isTemplate = true
                return i
            case .time(let d): return stackedTime(d)
            }
        }
        let gap: CGFloat = 3
        let height: CGFloat = 18
        let width = pictures.reduce(0) { $0 + $1.size.width } + gap * CGFloat(max(0, pictures.count - 1))
        let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
            var x: CGFloat = 0
            for p in pictures {
                let r = NSRect(x: x, y: ((height - p.size.height) / 2).rounded(), width: p.size.width, height: p.size.height)
                if p.isTemplate && coloured {
                    // A plain part next to a coloured one: paint it in the menu bar's letter colour ourselves.
                    let tinted = NSImage(size: p.size, flipped: false) { b in
                        p.draw(in: b); ink.set(); b.fill(using: .sourceAtop); return true
                    }
                    tinted.draw(in: r)
                } else {
                    p.draw(in: r)
                }
                x += p.size.width + gap
            }
            return true
        }
        image.isTemplate = !coloured
        image.accessibilityDescription = parts.compactMap { part -> String? in
            switch part {
            case .picture(let p): return p.accessibilityDescription
            case .word(let w): return w
            case .time(let d): let l = MenuBarTime.lines(d); return l.top + l.bottom
            }
        }.joined(separator: " ")
        return image
    }

    /// A symbol from the Mac's own set, as the menu bar draws it (a template, 14 points).
    static func symbol(_ name: String, _ description: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = true
        return image
    }

    /// How big the time's digits are (the owner: "much smaller and thinner", then "even smaller").
    static let timePoints: CGFloat = 7.5

    /// The time as two small thin lines: the hour with the colon over the minutes (the owner's pick A).
    /// A template picture, so the Mac paints it in the menu bar's own colour, day and night.
    static func stackedTime(_ date: Date) -> NSImage {
        let lines = MenuBarTime.lines(date)
        let font = NSFont.monospacedDigitSystemFont(ofSize: timePoints, weight: .light)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let top = NSAttributedString(string: lines.top, attributes: attributes)
        let bottom = NSAttributedString(string: lines.bottom, attributes: attributes)
        let lineHeight = timePoints + 1
        // Both lines start at the same left edge, so the digits stand exactly over each other.
        let width = ceil(max(top.size().width, bottom.size().width))
        let height: CGFloat = 18
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let base = (height - 2 * lineHeight) / 2 - font.descender * -1 + 0.5
            bottom.draw(at: NSPoint(x: 0, y: base))
            top.draw(at: NSPoint(x: 0, y: base + lineHeight))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = lines.top + lines.bottom
        return image
    }
}
