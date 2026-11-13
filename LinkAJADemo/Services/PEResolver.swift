import SwiftUI
import Combine

/// Where a resolved value comes from.
enum PESource: String {
    case dashboard = "Dashboard", persona = "Persona", global = "Default"
}

/// Single entry point for views. Resolution order, highest first:
///  1. Dashboard override: the live PEStore value, only when it differs from the variable's defined default.
///  2. Persona value: the hardcoded value for the logged in persona.
///  3. Global default: the default defined in PEStore.
/// Edge case: a dashboard value equal to the global default is not an override, so the persona value wins.
/// For string variables whose default is an empty string, any non-empty dashboard value wins.
final class PEResolver: ObservableObject {
    static let shared = PEResolver()

    /// Bumped when the persona, the persona-defaults toggle or any PEStore value changes.
    @Published private(set) var revision = 0
    @Published var personaDefaults: Bool {
        didSet {
            UserDefaults.standard.set(personaDefaults, forKey: "ljd_persona_defaults")
            bump()
        }
    }

    private let store = PEStore.shared
    private var bag = Set<AnyCancellable>()

    private init() {
        personaDefaults = UserDefaults.standard.object(forKey: "ljd_persona_defaults") as? Bool ?? true
        store.$revision.dropFirst().sink { [weak self] _ in self?.bump() }.store(in: &bag)
        PersonaRegistry.shared.$active.dropFirst().sink { [weak self] _ in self?.bump() }.store(in: &bag)
    }

    private func bump() {
        DispatchQueue.main.async {
            ThemeProvider.shared.refresh()
            self.revision += 1
        }
    }

    /// Resolved value for a specific persona, ignoring who is logged in. Used by Persona Diff and tests.
    func display(_ key: PEKeys, for config: PersonaConfig?) -> String {
        if store.isOverridden(key) { return store.effectiveDisplay(key) }
        if let v = config?.overrides[key] { return v.display }
        return key.defaultValue.display
    }

    var persona: PersonaConfig? { PersonaRegistry.shared.active }

    // MARK: Resolution

    func source(_ key: PEKeys) -> PESource {
        if store.isOverridden(key) { return .dashboard }
        if personaDefaults, persona?.overrides[key] != nil { return .persona }
        return .global
    }

    private func personaValue(_ key: PEKeys) -> PEValue? {
        guard personaDefaults else { return nil }
        return persona?.overrides[key]
    }

    func string(_ key: PEKeys) -> String {
        if source(key) == .persona, let v = personaValue(key) {
            switch v {
            case .string(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines)
            case .int(let i): return "\(i)"
            case .bool(let b): return b ? "true" : "false"
            }
        }
        return store.string(key)
    }

    func int(_ key: PEKeys) -> Int {
        if source(key) == .persona, let v = personaValue(key) {
            switch v {
            case .int(let i): return i
            case .string(let s): return Int(s) ?? store.int(key)
            case .bool(let b): return b ? 1 : 0
            }
        }
        return store.int(key)
    }

    func bool(_ key: PEKeys) -> Bool {
        if source(key) == .persona, let v = personaValue(key) {
            switch v {
            case .bool(let b): return b
            case .int(let i): return i != 0
            case .string(let s): return ["true", "1", "yes"].contains(s.lowercased())
            }
        }
        return store.bool(key)
    }

    /// Comma separated list: trimmed, lowercased, empty tokens dropped.
    func list(_ key: PEKeys) -> [String] {
        string(key).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
    }

    /// Display text of the resolved value, used by the PE Inspector.
    func display(_ key: PEKeys) -> String {
        switch key.defaultValue {
        case .bool: return bool(key) ? "true" : "false"
        case .string: return string(key)
        case .int: return "\(int(key))"
        }
    }

    // MARK: Home

    var heroVisible: Bool { bool(.heroVisible) }
    var heroTitle: String { string(.heroTitle) }
    var heroSubtitle: String { string(.heroSubtitle) }
    var heroImage: String { string(.heroImageURL) }
    var heroCTAText: String { string(.heroCTAText) }
    var heroDeeplink: String { string(.heroDeeplink) }
    var quickActionOrder: [QuickActionToken] {
        var seen = Set<QuickActionToken>()
        let parsed = list(.quickActionsOrder).compactMap { QuickActionToken(rawValue: $0) }.filter { seen.insert($0).inserted }
        return parsed.isEmpty ? QuickActionToken.allCases : parsed
    }
    var quickActionHighlight: QuickActionToken? { QuickActionToken(rawValue: string(.quickActionsHighlight).lowercased()) }
    var showTopupCTA: Bool { bool(.balanceShowTopup) }
    var topupCTAText: String { string(.balanceTopupText) }

    // MARK: Top Up

    var topupAmounts: [Int] {
        var seen = Set<Int>()
        let parsed = list(.topupSuggested).compactMap { Int($0) }.filter { $0 > 0 && seen.insert($0).inserted }
        return parsed.isEmpty ? [50_000, 100_000, 200_000, 500_000] : parsed
    }
    var topupDefault: Int { max(1, int(.topupDefault)) }
    var topupMethods: [String] {
        let known = ["bank_va", "atm", "debit_card", "minimarket"]
        var seen = Set<String>()
        let parsed = list(.methodsOrder).filter { known.contains($0) && seen.insert($0).inserted }
        return parsed.isEmpty ? known : parsed
    }
    var topupMethodHighlight: String { string(.methodsHighlight).lowercased() }
    var bonusEnabled: Bool { bool(.bonusEnabled) }
    var bonusMin: Int { max(0, int(.bonusMin)) }
    var bonusAmount: Int { max(0, int(.bonusAmount)) }
    var bonusBanner: String { string(.bonusBanner) }

    // MARK: Promo

    var promoLayout: String { string(.promoLayout).lowercased() == "grid" ? "grid" : "carousel" }
    var promoFeatured: String { string(.promoFeatured).lowercased() }
    var promoCodeVisible: Bool { bool(.promoCodeVisible) }
    var promoFeaturedVisible: Bool { bool(.promoFeaturedVisible) }
    var promoListOrder: [String] { list(.promoListOrder) }

    // MARK: Gamification

    var streakEnabled: Bool { bool(.streakEnabled) }
    var streakTarget: Int { min(max(int(.streakTarget), 1), 14) }
    var streakChip: String { string(.streakChip) }
    var rewardPoints: Int { max(0, int(.streakRewardPoints)) }
    var badgeLabel: String { string(.badgeLabel) }
    var badgeCycles: Int { max(1, int(.badgeCycles)) }
    var stampSet: String {
        let s = string(.stampSet).lowercased()
        return StampSets.names.contains(s) ? s : "classic"
    }
    var stampFinalSymbol: String { StampSets.valid(string(.stampFinalSymbol)) }
    var stampColor: Color { Color(hex: string(.stampColor)) ?? ThemeProvider.shared.primary }
    var stampAnimation: Bool { bool(.stampAnimation) }
    var loyaltyEnabled: Bool { bool(.loyaltyEnabled) }
    var loyaltyCatalogVisible: Bool { bool(.loyaltyCatalogVisible) }
    var progressColor: Color { Color(hex: string(.progressColor)) ?? ThemeProvider.shared.primary }

    /// Poin Loyalty label. The default Indonesian label is translated when the app is in English.
    func loyaltyLabel(english: Bool) -> String {
        let l = string(.loyaltyLabel)
        return english && l == "Poin Loyalty" ? "Loyalty Points" : l
    }

    /// The streak chip suffix, translated for the known built-in values.
    func streakChip(english: Bool) -> String {
        let c = streakChip
        guard english else { return c }
        switch c {
        case "hari beruntun": return "day streak"
        case "hari kerja beruntun": return "workday streak"
        case "hari QRIS beruntun": return "QRIS day streak"
        default: return c
        }
    }

    // MARK: Cross-sell

    var crossVisible: Bool { bool(.crossVisible) }
    var crossTitle: String { string(.crossTitle) }
    var crossCTA: String { string(.crossCTA) }
    var crossCategory: String { string(.crossCategory).lowercased() }
    var crossCashback: Int { max(0, int(.crossCashback)) }
    var crossVariant: String { string(.crossVariant).lowercased() == "praktis" ? "praktis" : "hemat" }

    // MARK: Flags

    var qrisEducationTile: Bool { bool(.flagQrisEducation) }
    var oneTapPay: Bool { bool(.flagOneTapPay) }

    // MARK: Incentives

    var incentivesEnabled: Bool { bool(.incEnabled) }
    var expiryDuration: String { string(.incExpiry) }
}
