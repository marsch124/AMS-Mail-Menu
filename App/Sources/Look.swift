import SwiftUI

/// The letters of the list panel, in one place: every size there goes through `Look.f`.
/// `choose` switches to a candidate look for the test pictures (`--picture … --look N`).
enum Look {
    static var delta: CGFloat = 0
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
        case 2: delta = -2
        case 3: delta = -2; weight = .light
        case 4: delta = -2; face = "Avenir Next"
        case 5: delta = -2; design = .rounded
        case 6: delta = -1
        default: break
        }
    }
}
