import SwiftUI

/// Single place that holds the live theme. Colors and radius resolve in this order:
/// dashboard LinkAJA.theme.* value (when overridden), then the persona theme, then the global default.
final class ThemeProvider: ObservableObject {
    static let shared = ThemeProvider()
    static let defaultPrimary = Color(red: 228 / 255, green: 0, blue: 43 / 255)

    /// The accent: dashboard primary color if overridden, else the persona accent.
    @Published var primary: Color = ThemeProvider.defaultPrimary
    @Published var cornerRadius: CGFloat = 16
    @Published var persona: PersonaTheme = .neutral
    /// Set only when the dashboard overrides LinkAJA.theme.primary_color_hex.
    @Published var dashboardPrimary: Color?

    /// Button color: the dashboard primary if overridden, else the persona CTA (brand red).
    var cta: Color { dashboardPrimary ?? persona.cta }

    var headerGradient: LinearGradient {
        if let p = dashboardPrimary {
            return LinearGradient(colors: [p, p.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return persona.headerGradient
    }

    func refresh() {
        let store = PEStore.shared
        let r = PEResolver.shared
        persona = PersonaTheme.theme(for: r.persona?.personaID)
        dashboardPrimary = store.isOverridden(.themePrimary) ? Color(hex: store.string(.themePrimary)) : nil
        primary = dashboardPrimary ?? persona.accent
        let dashRadius = store.isOverridden(.themeRadius)
        cornerRadius = CGFloat(min(max(dashRadius ? store.int(.themeRadius) : Int(persona.radius), 0), 32))
    }
}

extension Color {
    /// Parses "#RRGGBB", "#RRGGBBAA" or without the hash. Returns nil for anything else.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
        } else {
            self.init(red: Double((v >> 24) & 0xFF) / 255, green: Double((v >> 16) & 0xFF) / 255,
                      blue: Double((v >> 8) & 0xFF) / 255, opacity: Double(v & 0xFF) / 255)
        }
    }
}
