import SwiftUI
import Combine
import CleverTapSDK

/// Product Experiences store. Defines every CleverTap variable once, mirrors live values and
/// publishes changes so SwiftUI re-renders when the dashboard pushes new values.
final class PEStore: ObservableObject {
    static let shared = PEStore()

    /// Bumped on every change. Views observe the store and re-read the accessors below.
    @Published private(set) var revision = 0
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var lastFetchSucceeded: Bool?
    @Published private(set) var overrideCount = 0
    @Published private(set) var defaultsOnly = false

    private var vars: [PEKeys: Var] = [:]
    private var overrides: [PEKeys: Any] = [:]
    private var pending: DispatchWorkItem?
    private var defined = false

    // MARK: Definition and fetching

    /// Called once from CleverTapManager.configure(), right after CleverTap.sharedInstance() exists
    /// and before the first fetch.
    func define() {
        guard !defined else { return }
        defined = true
        let ct = CleverTapManager.shared
        for key in PEKeys.allCases {
            if let v = ct.defineVariable(key, onChange: { [weak self] in self?.scheduleCommit() }) { vars[key] = v }
        }
        ct.onVariablesChanged { [weak self] in self?.scheduleCommit() }
        ct.syncVariableDefinitionsInDebug()
        commit()
    }

    func fetch(completion: ((Bool) -> Void)? = nil) {
        CleverTapManager.shared.fetchVariables { [weak self] ok in
            DispatchQueue.main.async {
                self?.lastFetchSucceeded = ok
                if ok { self?.commit() }
                completion?(ok)
            }
        }
    }

    func refresh() async {
        clearLocalChanges()
        _ = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in fetch { c.resume(returning: $0) } }
    }

    // MARK: Local previews (never sent to CleverTap)

    func setOverride(_ key: PEKeys, _ value: Any) {
        overrides[key] = value
        overrideCount = overrides.count
        commit()
    }

    func resetToDefaults() {
        overrides = [:]
        overrideCount = 0
        defaultsOnly = true
        commit()
    }

    func clearLocalChanges() {
        overrides = [:]
        overrideCount = 0
        defaultsOnly = false
        commit()
    }

    /// True when a local preview value is active for this key.
    func isLocalPreview(_ key: PEKeys) -> Bool { overrides[key] != nil }

    /// True when the live value (dashboard, or a local preview standing in for it) differs from the
    /// variable's defined default. A dashboard value equal to the default is not an override.
    func isOverridden(_ key: PEKeys) -> Bool { effectiveDisplay(key) != key.defaultValue.display }

    // MARK: Change handling

    private func scheduleCommit() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pending?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.commit() }
            self.pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }

    private func commit() {
        lastUpdate = Date()
        ThemeProvider.shared.refresh()
        revision += 1
    }

    // MARK: Raw reads with defensive fallbacks

    /// Value the SDK holds (dashboard value, or the default when none is published).
    func liveValue(_ key: PEKeys) -> Any? { vars[key]?.value }

    /// Value the UI uses: local override, else SDK value, else the default.
    private func raw(_ key: PEKeys) -> Any? {
        if let o = overrides[key] { return o }
        if defaultsOnly { return nil }
        return vars[key]?.value
    }

    func effectiveDisplay(_ key: PEKeys) -> String {
        switch key.defaultValue {
        case .bool: return bool(key) ? "true" : "false"
        case .string: return string(key)
        case .int: return "\(int(key))"
        }
    }

    func bool(_ key: PEKeys) -> Bool {
        guard case .bool(let d) = key.defaultValue else { return false }
        switch raw(key) {
        case let b as Bool: return b
        case let n as NSNumber: return n.boolValue
        case let s as String:
            switch s.trimmingCharacters(in: .whitespaces).lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return d
            }
        default: return d
        }
    }

    func string(_ key: PEKeys) -> String {
        guard case .string(let d) = key.defaultValue else { return "" }
        if let s = raw(key) as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? d : t
        }
        return d
    }

    func int(_ key: PEKeys) -> Int {
        guard case .int(let d) = key.defaultValue else { return 0 }
        switch raw(key) {
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s.trimmingCharacters(in: .whitespaces)) ?? d
        default: return d
        }
    }

    /// Comma separated list: trims spaces, drops empty tokens.
    private func csv(_ key: PEKeys) -> [String] {
        string(key).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
    }

    // MARK: Typed accessors

    // Home
    var heroVisible: Bool { bool(.heroVisible) }
    var heroTitle: String { string(.heroTitle) }
    var heroSubtitle: String { string(.heroSubtitle) }
    var heroImage: String { string(.heroImageURL) }
    var heroCTAText: String { string(.heroCTAText) }
    var heroDeeplink: String { string(.heroDeeplink) }
    var quickActionOrder: [QuickActionToken] {
        var seen = Set<QuickActionToken>()
        let parsed = csv(.quickActionsOrder).compactMap { QuickActionToken(rawValue: $0) }.filter { seen.insert($0).inserted }
        if !parsed.isEmpty { return parsed }
        guard case .string(let d) = PEKeys.quickActionsOrder.defaultValue else { return QuickActionToken.allCases }
        return d.split(separator: ",").compactMap { QuickActionToken(rawValue: String($0)) }
    }
    var quickActionHighlight: QuickActionToken? { QuickActionToken(rawValue: string(.quickActionsHighlight).lowercased()) }
    var showTopupCTA: Bool { bool(.balanceShowTopup) }
    var topupCTAText: String { string(.balanceTopupText) }

    // Top Up
    var topupAmounts: [Int] {
        var seen = Set<Int>()
        let parsed = csv(.topupSuggested).compactMap { Int($0) }.filter { $0 > 0 && seen.insert($0).inserted }
        if !parsed.isEmpty { return parsed }
        return [50_000, 100_000, 200_000, 500_000]
    }
    var topupDefault: Int { max(1, int(.topupDefault)) }
    var bonusEnabled: Bool { bool(.bonusEnabled) }
    var bonusMin: Int { max(0, int(.bonusMin)) }
    var bonusAmount: Int { max(0, int(.bonusAmount)) }
    var bonusBanner: String { string(.bonusBanner) }

    // Promo
    var promoLayout: String { string(.promoLayout).lowercased() == "grid" ? "grid" : "carousel" }
    var promoFeatured: String { string(.promoFeatured).lowercased() }
    var promoCodeVisible: Bool { bool(.promoCodeVisible) }

    // Gamification
    var streakEnabled: Bool { bool(.streakEnabled) }
    var streakTarget: Int { min(max(int(.streakTarget), 1), 14) }
    var streakChip: String { string(.streakChip) }
    var badgeLabel: String { string(.badgeLabel) }
    var progressColor: Color { Color(hex: string(.progressColor)) ?? ThemeProvider.shared.primary }

    // Cross-sell
    var crossVisible: Bool { bool(.crossVisible) }
    var crossTitle: String { string(.crossTitle) }
    var crossCTA: String { string(.crossCTA) }
    var crossCategory: String { string(.crossCategory).lowercased() }
    var crossCashback: Int { max(0, int(.crossCashback)) }
    var crossVariant: String { string(.crossVariant).lowercased() == "praktis" ? "praktis" : "hemat" }

    // Flags
    var qrisEducationTile: Bool { bool(.flagQrisEducation) }
    var oneTapPay: Bool { bool(.flagOneTapPay) }
}
