import SwiftUI
import UIKit
import XCTest
@testable import KeptoraiOS

/// Checks the design colors against WCAG 2.2 AA (4.5:1 for normal text) in light and dark mode,
/// on plain system backgrounds and on the lightly tinted backgrounds used by secondary buttons.
final class ColorContrastTests: XCTestCase {
    private let styles: [UIUserInterfaceStyle] = [.light, .dark]
    private let backgrounds: [UIColor] = [.systemBackground, .systemGroupedBackground, .secondarySystemGroupedBackground]

    func testTextColorsMeetAAOnSystemAndTintedBackgrounds() {
        let textColors: [(String, Color)] = [
            ("accent", MobileKeptoraDesign.accent),
            ("danger", MobileKeptoraDesign.danger),
            ("success", MobileKeptoraDesign.success),
            ("warning", MobileKeptoraDesign.warning)
        ]
        for style in styles {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for (name, color) in textColors {
                let text = UIColor(color).resolvedColor(with: traits)
                for background in backgrounds {
                    let base = background.resolvedColor(with: traits)
                    // Secondary buttons and chips draw the same color at 9–16 % behind the text.
                    for tint in [0.0, 0.16] {
                        let ratio = Self.contrast(text, Self.blend(text, over: base, alpha: tint))
                        XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) in \(style == .dark ? "dark" : "light") mode, tint \(tint): \(ratio)")
                    }
                }
            }
        }
    }

    func testWhiteLabelsOnFilledButtonsMeetAA() {
        for (name, fill) in [("accentFill", MobileKeptoraDesign.accentFill), ("dangerFill", MobileKeptoraDesign.dangerFill)] {
            for style in styles {
                let resolved = UIColor(fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
                XCTAssertGreaterThanOrEqual(Self.contrast(.white, resolved), 4.5, name)
            }
        }
    }

    private static func components(_ color: UIColor) -> (CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    private static func blend(_ top: UIColor, over bottom: UIColor, alpha: CGFloat) -> UIColor {
        let t = components(top), b = components(bottom)
        return UIColor(red: t.0 * alpha + b.0 * (1 - alpha), green: t.1 * alpha + b.1 * (1 - alpha), blue: t.2 * alpha + b.2 * (1 - alpha), alpha: 1)
    }

    private static func luminance(_ color: UIColor) -> CGFloat {
        func channel(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let c = components(color)
        return 0.2126 * channel(c.0) + 0.7152 * channel(c.1) + 0.0722 * channel(c.2)
    }

    static func contrast(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
