import SwiftUI

enum Fmt {
    /// 1.250 style grouping for plain numbers such as points.
    static func num(_ value: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.numberStyle = .decimal
        f.groupingSize = 3
        f.groupingSeparator = "."
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Rp1.250.000 style, no decimals.
    static func rp(_ value: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.numberStyle = .decimal
        f.groupingSize = 3
        f.secondaryGroupingSize = 3
        f.groupingSeparator = "."
        f.usesGroupingSeparator = true
        return "Rp" + (f.string(from: NSNumber(value: value)) ?? "\(value)")
    }
}

/// Reads every token from the live theme (dashboard, then persona, then default). Views never hardcode colors.
enum Theme {
    private static var t: ThemeProvider { ThemeProvider.shared }
    private static var p: PersonaTheme { ThemeProvider.shared.persona }

    /// Accent color (navy for Budi, teal for Siti, or the dashboard primary).
    static var red: Color { t.primary }
    static var accent: Color { t.primary }
    static var cta: Color { t.cta }
    static var secondary: Color { p.secondary }
    static var highlight: Color { p.highlight }
    static var radius: CGFloat { t.cornerRadius }
    static var spacing: CGFloat { p.spacing }
    static var bg: Color { p.background }
    static var card: Color { p.card }
    static var gradient: LinearGradient { t.headerGradient }
    static var persona: PersonaTheme { p }
    static let positive = Color("Mint")
    static let blue = Color("LinkBlue")
    static let mint = Color("Mint")
    static let redDark = Color("LinkRedDark")
    /// Semantic status colors.
    static let good = Color(red: 0.12, green: 0.62, blue: 0.36)
    static let bad = Color(red: 0.80, green: 0.14, blue: 0.14)
}
