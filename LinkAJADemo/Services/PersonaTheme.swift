import SwiftUI

/// Home screen building blocks. Each persona has its own ordered list (PersonaHomeLayout).
enum HomeModule: String, CaseIterable, Identifiable {
    case header, balance
    // Budi
    case dueBill, quickActions, trip, hero, paydayBanner, promoCarousel, crossSell, qrisEducation, activityList
    // Siti
    case scanButton, sales, verifyCard, promoGrid, streakQris, activityCards

    var id: String { rawValue }
}

/// Two separate, data driven module lists.
enum PersonaHomeLayout {
    static let budi: [HomeModule] = [.header, .balance, .dueBill, .quickActions, .trip, .hero, .paydayBanner,
                                     .promoCarousel, .crossSell, .qrisEducation, .activityList]
    static let siti: [HomeModule] = [.header, .balance, .scanButton, .sales, .quickActions, .verifyCard, .hero,
                                     .paydayBanner, .promoGrid, .streakQris, .crossSell, .activityCards]
}

/// Persona design tokens. Persona-only, not CleverTap variables. Colors are stored as hex so two
/// themes can be compared and shown in Persona Diff. Dashboard theme variables still win (see ThemeProvider).
struct PersonaTheme: Equatable {
    let name: String
    let headerStartHex: String, headerEndHex: String
    let backgroundHex: String, cardHex: String
    let borderHex: String?
    let shadowHex: String
    let shadowRadius: CGFloat
    let accentHex: String, secondaryHex: String, ctaHex: String
    /// Highlight used for stamps, streak and progress (amber for Budi, coral for Siti).
    let highlightHex: String
    let iconTintHexes: [String]
    let radius: CGFloat
    let fontDesign: Font.Design
    let spacing: CGFloat
    let rowPadding: CGFloat
    let compact: Bool
    let squareIcons: Bool
    let balanceFontSize: CGFloat
    let tabs: [AppTab]
    let homeModules: [HomeModule]
    let welcomeID: String, welcomeEN: String, modeID: String, modeEN: String

    static func color(_ hex: String) -> Color { Color(hex: hex) ?? .gray }

    var headerStart: Color { Self.color(headerStartHex) }
    var headerEnd: Color { Self.color(headerEndHex) }
    var background: Color { Self.color(backgroundHex) }
    var card: Color { Self.color(cardHex) }
    var border: Color? { borderHex.map(Self.color) }
    var shadow: Color { Self.color(shadowHex) }
    var accent: Color { Self.color(accentHex) }
    var secondary: Color { Self.color(secondaryHex) }
    var cta: Color { Self.color(ctaHex) }
    var highlight: Color { Self.color(highlightHex) }
    var iconTints: [Color] { iconTintHexes.map(Self.color) }
    var headerGradient: LinearGradient {
        LinearGradient(colors: [headerStart, headerEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let brandRed = "#E4002B"

    /// Komuter Mode: professional, calm, dense, list based.
    static let budi = PersonaTheme(
        name: "Komuter Mode",
        headerStartHex: "#12294D", headerEndHex: "#2F4B7C",
        backgroundHex: "#EEF1F6", cardHex: "#FFFFFF", borderHex: "#D9DFEA",
        shadowHex: "#12294D14", shadowRadius: 2,
        accentHex: "#1F3A68", secondaryHex: "#F2A900", ctaHex: brandRed, highlightHex: "#F2A900",
        iconTintHexes: ["#1F3A68"],
        radius: 12, fontDesign: .default, spacing: 12, rowPadding: 12, compact: true, squareIcons: true,
        balanceFontSize: 26,
        tabs: [.home, .bills, .scan, .inbox, .profile], homeModules: PersonaHomeLayout.budi,
        welcomeID: "Selamat pagi, Budi", welcomeEN: "Good morning, Budi", modeID: "Mode Komuter", modeEN: "Commuter Mode")

    /// Mode Toko: vibrant, friendly, card based.
    static let siti = PersonaTheme(
        name: "Mode Toko",
        headerStartHex: "#0E9F8E", headerEndHex: "#6C4BD6",
        backgroundHex: "#FFF7EE", cardHex: "#FFFFFF", borderHex: nil,
        shadowHex: "#6C4BD633", shadowRadius: 12,
        accentHex: "#0E9F8E", secondaryHex: "#FF6B5A", ctaHex: brandRed, highlightHex: "#FF6B5A",
        iconTintHexes: ["#0E9F8E", "#FF6B5A", "#6C4BD6"],
        radius: 24, fontDesign: .rounded, spacing: 16, rowPadding: 18, compact: false, squareIcons: false,
        balanceFontSize: 38,
        tabs: [.home, .promo, .scan, .shop, .profile], homeModules: PersonaHomeLayout.siti,
        welcomeID: "Halo Siti", welcomeEN: "Hi Siti", modeID: "Mode Toko", modeEN: "Shop Mode")

    /// Before login: the original brand look.
    static let neutral = PersonaTheme(
        name: "LinkAja",
        headerStartHex: brandRed, headerEndHex: "#B00020",
        backgroundHex: "#F2F2F7", cardHex: "#FFFFFF", borderHex: nil,
        shadowHex: "#0000000D", shadowRadius: 6,
        accentHex: brandRed, secondaryHex: "#F2A900", ctaHex: brandRed, highlightHex: brandRed,
        iconTintHexes: [brandRed],
        radius: 16, fontDesign: .default, spacing: 14, rowPadding: 16, compact: false, squareIcons: false,
        balanceFontSize: 30,
        tabs: [.home, .promo, .scan, .inbox, .profile], homeModules: PersonaHomeLayout.budi,
        welcomeID: "Selamat datang", welcomeEN: "Welcome", modeID: "", modeEN: "")

    static func theme(for personaID: String?) -> PersonaTheme {
        switch personaID {
        case Persona.budi.id: return .budi
        case Persona.siti.id: return .siti
        default: return .neutral
        }
    }
}
