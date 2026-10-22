import SwiftUI

/// Three bundled cuts keep reading and recipe headings consistent without a network font request.
extension Font {
    static func tati(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        custom(kitchenFace(weight: weight, design: design), size: size, relativeTo: .body).weight(weight)
    }

    static func tati(_ style: Font.TextStyle, design: Font.Design = .default, weight: Font.Weight = .regular) -> Font {
        let points: CGFloat
        switch style {
        case .largeTitle: points = 34
        case .title: points = 28
        case .title2: points = 22
        case .title3: points = 20
        case .headline, .body: points = 17
        case .callout: points = 16
        case .subheadline: points = 15
        case .footnote: points = 13
        case .caption: points = 12
        case .caption2: points = 11
        @unknown default: points = 17
        }
        return custom(kitchenFace(weight: weight, design: design), size: points, relativeTo: style).weight(weight)
    }

    private static func kitchenFace(weight: Font.Weight, design: Font.Design) -> String {
        if design == .serif { return "Fraunces-9ptSemiBold" }
        return weight == .semibold || weight == .bold || weight == .heavy || weight == .black
            ? "DMSans-9ptSemiBold" : "DMSans-9pt"
    }
}
