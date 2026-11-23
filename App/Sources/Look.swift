import SwiftUI

/// The letters of the whole app, in one place: every size goes through `Look.f`.
/// The sizes written in the screens are the ones of 0.5; `delta` makes them smaller. The owner chose
/// option 2 of six on 23 Nov 2026 ("another smaller and not so intrusive font"): 2 points smaller, the Mac's
/// own letters, regular weight. `choose` switches to another candidate for the test pictures (`--look N`).
enum Look {
    /// How wide the list panel is.
    static var panelWidth: CGFloat = 400
    static var delta: CGFloat = -2
    static var design: Font.Design = .default
    static var weight: Font.Weight = .regular
    static var face: String?

    static func f(_ size: CGFloat, _ own: Font.Weight? = nil) -> Font {
        let points = max(9, size + delta)
        if let face { return .custom(face, fixedSize: points).weight(own ?? weight) }
        return .system(size: points, weight: own ?? weight, design: design)
    }

    static func choose(_ number: Int) {
        switch number {
        case 1: delta = 0
        case 2: delta = -2
        case 3: delta = -2; weight = .light
        case 4: delta = -2; face = "Avenir Next"
        case 5: delta = -2; design = .rounded
        case 6: delta = -1
        default: break
        }
    }
}
