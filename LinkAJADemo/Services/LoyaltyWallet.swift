import SwiftUI
import Combine

/// Every reason points move. Raw value is the rule key used in metadata, events and the ledger.
enum IncentiveRule: String, CaseIterable, Codable {
    case kycCompleted = "kyc_completed", firstTopup = "first_topup", qrisPayment = "qris_payment"
    case billPayment = "bill_payment", habitThirdPayment = "habit_third_payment", streakCycle = "streak_cycle"
    case promoCodeRedeemed = "promo_code_redeemed", newCategory = "new_category"
    // Debits and tools
    case loyaltyRedeem = "loyalty_redeem", payWithPoints = "pay_with_points", seed = "seed", manual = "manual"

    /// The credit rules that can be fired from Demo Tools.
    static let creditRules: [IncentiveRule] = [.kycCompleted, .firstTopup, .qrisPayment, .billPayment,
                                               .habitThirdPayment, .streakCycle, .promoCodeRedeemed, .newCategory]

    var enabledKey: PEKeys? {
        switch self {
        case .kycCompleted: return .incKycEnabled
        case .firstTopup: return .incTopupEnabled
        case .qrisPayment: return .incQrisEnabled
        case .billPayment: return .incBillEnabled
        case .habitThirdPayment: return .incHabitEnabled
        case .streakCycle: return .incCycleEnabled
        case .promoCodeRedeemed: return .incPromoEnabled
        case .newCategory: return .incNewCatEnabled
        case .payWithPoints: return .incPayEnabled
        default: return nil
        }
    }

    func title(english: Bool) -> String {
        switch self {
        case .kycCompleted: return english ? "KYC completed" : "KYC selesai"
        case .firstTopup: return english ? "First top up" : "Top up pertama"
        case .qrisPayment: return english ? "QRIS payment" : "Pembayaran QRIS"
        case .billPayment: return english ? "Bill payment" : "Pembayaran tagihan"
        case .habitThirdPayment: return english ? "Third payment habit" : "Kebiasaan transaksi ke-3"
        case .streakCycle: return english ? "Streak cycle complete" : "Siklus streak selesai"
        case .promoCodeRedeemed: return english ? "Promo code used" : "Kode promo dipakai"
        case .newCategory: return english ? "New category" : "Kategori baru"
        case .loyaltyRedeem: return english ? "Reward redeemed" : "Tukar poin"
        case .payWithPoints: return english ? "Paid with points" : "Bayar pakai poin"
        case .seed: return english ? "Starting points" : "Poin awal"
        case .manual: return english ? "Manual" : "Manual"
        }
    }
}

/// One wallet request, stored as is when it fails so a manual retry reuses the same orderId.
struct WalletOp: Codable {
    var isCredit: Bool
    var description: String
    var points: Double
    var orderId: String
    var saleAmount: Int?
    var metadata: [String: String]
    var bucket: String?
    var activation: String?
    var expiry: String?
    var rule: String
    var paymentId: String?
}

struct FailedWalletOp: Codable, Identifiable {
    var id = UUID()
    var op: WalletOp
    var date = Date()
    var error: String
}

struct WalletEntry: Codable, Identifiable {
    var id = UUID()
    var txnId: String
    var orderId: String
    var kind: String            // credit, debit, reverse, refund
    var points: Double
    var rule: String
    var paymentId: String?
    var bucket: String?
    var date = Date()
    var balanceAfter: Double
    var mock: Bool
    var reversed = false
}

private struct WalletSnapshot: Codable {
    var balance: Double
    var pending: Double = 0
    var ledger: [WalletEntry] = []
    var failed: [FailedWalletOp] = []
    var once: [String] = []
    var habitCycle = 1
}

struct PointsToast: Equatable, Identifiable {
    enum Kind { case credit, debit, error, info }
    let id = UUID()
    let text: String
    let kind: Kind
}

struct HistoryRow: Identifiable {
    let id: String
    let kind: String            // credit, debit, reverse, refund, expired, pending
    let points: Double
    let rule: String
    let detail: String
    let date: Date
    var runningBalance: Double
    var signed: Double {
        switch kind { case "credit", "refund": return points; case "debit", "reverse", "expired": return -points; default: return 0 }
    }
}

enum WalletOutcome {
    case success(WalletEntry)
    case insufficient(missing: Double)
    case failed(WalletError)
    case skipped
}

/// Poin Loyalty: the CleverTap Promo Wallet balance and everything that moves it.
/// Not the Rupiah saldo, which lives in AppState (LinkAJA_wallet_balance).
/// Mutating async methods are @MainActor so state changes always land on the main thread.
final class LoyaltyWallet: ObservableObject {
    static let shared = LoyaltyWallet()

    @Published private(set) var balance: Double = 0
    /// Points that are promised but not active yet (PENDING bucket).
    @Published private(set) var pending: Double = 0
    @Published private(set) var ledger: [WalletEntry] = []
    @Published private(set) var failed: [FailedWalletOp] = []
    @Published private(set) var history: [HistoryRow] = []
    @Published private(set) var loadingHistory = false
    @Published private(set) var refreshing = false
    @Published private(set) var lastError: String?
    @Published var toast: PointsToast?
    @Published var mockMode: Bool {
        didSet {
            UserDefaults.standard.set(mockMode, forKey: "ljd_wallet_mock")
            guard oldValue != mockMode, identity != nil else { return }
            load()
            if !mockMode { Task { await refreshBalance() } }
        }
    }

    /// Called after every successful credit so the app can stamp the profile.
    var onCredited: ((String) -> Void)?

    private(set) var identity: String?
    private var config: PersonaConfig?
    private var once = Set<String>()
    private var habitCycle = 1
    private let service = PromoWalletService()

    var walletId: Int { service.config.walletId }
    var isConfigured: Bool { service.config.isConfigured }
    var points: Int { Int(balance.rounded()) }
    var pendingPoints: Int { Int(pending.rounded()) }

    private init() {
        mockMode = UserDefaults.standard.bool(forKey: "ljd_wallet_mock")
    }

    // MARK: Session

    func activate(identity: String, config: PersonaConfig?, freshStart: Bool) {
        self.identity = identity
        self.config = config
        if freshStart { UserDefaults.standard.removeObject(forKey: key) }
        load()
        if !mockMode { Task { await refreshBalance() } }
    }

    func deactivate() {
        identity = nil; config = nil
        balance = 0; pending = 0; ledger = []; failed = []; history = []; once = []
    }

    private var key: String { "ljd_wallet_\(identity ?? "none")_\(mockMode ? "mock" : "live")" }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(WalletSnapshot.self, from: data) {
            balance = s.balance; pending = s.pending; ledger = s.ledger; failed = s.failed
            once = Set(s.once); habitCycle = s.habitCycle
        } else {
            // First run for this identity and mode: the persona's starting points are the offline fallback.
            balance = Double(config?.startingPoints ?? 0); pending = 0; ledger = []; failed = []
            once = []; habitCycle = 1
        }
        history = []
    }

    private func persist() {
        let s = WalletSnapshot(balance: balance, pending: pending, ledger: Array(ledger.prefix(60)), failed: failed,
                               once: Array(once), habitCycle: habitCycle)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }

    // MARK: Once-only guards

    func onceDone(_ k: String) -> Bool { once.contains(k) }
    var habitKey: String { "habit_\(habitCycle)" }
    func resetHabitCycle() { habitCycle += 1; persist() }

    // MARK: Refresh

    @MainActor func refreshBalance() async {
        guard let identity, !mockMode else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let s = try await service.walletDetails(identity: identity)
            balance = s.activePoints
            pending = s.promisedPoints
            lastError = nil
            persist()
        } catch let e as WalletError {
            // Offline or not configured: keep the last known balance.
            lastError = e.detail
        } catch { lastError = error.localizedDescription }
    }

    // MARK: Credit rules

    /// Awards points for an incentive rule. Skips when the rule or the whole program is switched off,
    /// and enforces once-only keys (persisted per Identity). Pass `force` to ignore the once-only key.
    @MainActor @discardableResult
    func award(_ rule: IncentiveRule, points: Double, description: String, orderId: String, saleAmount: Int? = nil,
               metadata: [String: String] = [:], screen: String, onceKey: String? = nil, bucket: String? = nil,
               activation: String? = nil, paymentId: String? = nil, force: Bool = false) async -> WalletOutcome {
        let pe = PEResolver.shared
        guard pe.incentivesEnabled, rule.enabledKey.map({ pe.bool($0) }) ?? true, points > 0 else { return .skipped }
        if let onceKey, !force {
            if once.contains(onceKey) { return .skipped }
            once.insert(onceKey)
            persist()
        }
        let op = WalletOp(isCredit: true, description: description, points: points, orderId: orderId, saleAmount: saleAmount,
                          metadata: standardMetadata(rule: rule, screen: screen, extra: metadata),
                          bucket: bucket ?? "ACTIVE", activation: bucket == "PENDING" ? activation : nil,
                          expiry: pe.expiryDuration.isEmpty ? nil : pe.expiryDuration,
                          rule: rule.rawValue, paymentId: paymentId)
        return await execute(op)
    }

    /// Debits points. Checked against the local balance first: an oversized debit is never sent.
    @MainActor @discardableResult
    func debit(_ rule: IncentiveRule, points: Double, description: String, orderId: String, saleAmount: Int? = nil,
               metadata: [String: String] = [:], screen: String, paymentId: String? = nil) async -> WalletOutcome {
        guard points > 0 else { return .skipped }
        let op = WalletOp(isCredit: false, description: description, points: points, orderId: orderId, saleAmount: saleAmount,
                          metadata: standardMetadata(rule: rule, screen: screen, extra: metadata),
                          bucket: nil, activation: nil, expiry: nil, rule: rule.rawValue, paymentId: paymentId)
        return await execute(op)
    }

    @MainActor @discardableResult
    func retry(_ f: FailedWalletOp) async -> WalletOutcome { await execute(f.op, retryID: f.id) }

    func discardFailed(_ f: FailedWalletOp) { failed.removeAll { $0.id == f.id }; persist() }

    private func standardMetadata(rule: IncentiveRule, screen: String, extra: [String: String]) -> [String: String] {
        var m = extra
        m["rule"] = rule.rawValue
        m["persona"] = config?.displayName ?? identity ?? ""
        m["screen"] = screen
        m["app_version"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return m
    }

    // MARK: Core

    @MainActor private func execute(_ op: WalletOp, retryID: UUID? = nil) async -> WalletOutcome {
        guard let identity else { return .failed(.notConfigured) }
        let mock = mockMode

        if !op.isCredit, op.points > balance + 0.0001 {
            let missing = op.points - balance
            show(PointsToast(text: "Poin tidak cukup, kurang \(Self.fmt(missing))", kind: .error))
            return .insufficient(missing: missing)
        }

        let req = CreditDebitRequest(identity: identity, description: op.description, points: op.points, isCredit: op.isCredit,
                                     orderId: op.orderId, saleAmount: op.saleAmount, metadata: op.metadata,
                                     bucket: op.bucket, activationDuration: op.activation, expiryDuration: op.expiry)
        do {
            let result: CreditDebitResult
            if mock {
                result = mockApply(req)
            } else {
                result = try await service.creditDebit(req)
                balance = result.activePoints
                if op.bucket == "PENDING", op.isCredit { pending += op.points }
            }
            let entry = WalletEntry(txnId: result.txnId, orderId: op.orderId, kind: op.isCredit ? "credit" : "debit",
                                    points: op.points, rule: op.rule, paymentId: op.paymentId, bucket: op.bucket,
                                    balanceAfter: balance, mock: mock)
            ledger.insert(entry, at: 0)
            if let retryID { failed.removeAll { $0.id == retryID } }
            persist()
            recordSuccess(entry, op: op)
            return .success(entry)
        } catch {
            let err = (error as? WalletError) ?? .network(error.localizedDescription)
            handleFailure(err, op: op, retryID: retryID)
            return .failed(err)
        }
    }

    private func mockApply(_ r: CreditDebitRequest) -> CreditDebitResult {
        if r.isCredit {
            if r.bucket == "PENDING" { pending += r.points } else { balance += r.points }
        } else {
            balance = max(0, balance - r.points)
        }
        return CreditDebitResult(txnId: "mock_" + UUID().uuidString.prefix(8).lowercased(), activePoints: balance, points: r.points)
    }

    private func recordSuccess(_ e: WalletEntry, op: WalletOp) {
        let ct = CleverTapManager.shared
        let bucket = op.bucket ?? "ACTIVE"
        if op.isCredit {
            ct.record(.walletCredited, [.points: op.points, .rule: op.rule, .orderId: op.orderId, .txnId: e.txnId,
                                         .balanceAfter: e.balanceAfter, .bucket: bucket])
            ct.record(.loyaltyPointsEarned, [.points: op.points, .rule: op.rule, .balanceAfter: e.balanceAfter])
            onCredited?(op.rule)
            let text = bucket == "PENDING" ? "+\(Self.fmt(op.points)) Poin menunggu aktif" : "+\(Self.fmt(op.points)) Poin Loyalty"
            show(PointsToast(text: text, kind: .credit))
        } else {
            ct.record(.walletDebited, [.points: op.points, .rule: op.rule, .orderId: op.orderId, .txnId: e.txnId,
                                        .balanceAfter: e.balanceAfter])
            ct.record(.loyaltyPointsRedeemed, [.points: op.points, .rule: op.rule, .balanceAfter: e.balanceAfter])
            show(PointsToast(text: "-\(Self.fmt(op.points)) Poin Loyalty", kind: .debit))
        }
    }

    private func handleFailure(_ err: WalletError, op: WalletOp, retryID: UUID?) {
        lastError = err.detail
        CleverTapManager.shared.note("wallet \(op.isCredit ? "credit" : "debit") failed rule=\(op.rule) \(err.detail)")
        CleverTapManager.shared.record(.walletOperationFailed, [
            .operation: op.isCredit ? "credit" : "debit", .rule: op.rule,
            .errorCode: err.code ?? 0, .message: err.detail])
        if let retryID, let i = failed.firstIndex(where: { $0.id == retryID }) {
            failed[i].error = err.detail
        } else {
            failed.insert(FailedWalletOp(op: op, error: err.detail), at: 0)
        }
        persist()
        var text = op.isCredit ? "Poin gagal ditambahkan" : "Poin gagal dipakai"
        if case .notConfigured = err { text += " (wallet belum dikonfigurasi)" }
        else if case .api(let c, _) = err, c == 708 || c == 702 { text = err.friendly }
        show(PointsToast(text: text, kind: .error))
    }

    // MARK: Reversal

    /// Reverses a credit or refunds a debit (Reverse/Refund Points API). No automatic retry.
    @MainActor @discardableResult
    func reverse(_ entry: WalletEntry) async -> Bool {
        guard let identity, !entry.reversed, !entry.txnId.isEmpty else { return false }
        let isCredit = entry.kind == "credit"
        let type = isCredit ? "reverse" : "refund"
        var newTxn = "mock_" + UUID().uuidString.prefix(8).lowercased()
        if mockMode {
            if isCredit {
                if entry.bucket == "PENDING" { pending = max(0, pending - entry.points) } else { balance = max(0, balance - entry.points) }
            } else { balance += entry.points }
        } else {
            do {
                let r = try await service.adjust(identity: identity, txnId: entry.txnId,
                                                 description: isCredit ? "Transaksi dibatalkan" : "Poin dikembalikan")
                if !r.txnId.isEmpty { newTxn = r.txnId }
                await refreshBalance()
            } catch {
                let err = (error as? WalletError) ?? .network(error.localizedDescription)
                CleverTapManager.shared.record(.walletOperationFailed, [.operation: "reverse", .rule: entry.rule,
                                                                         .errorCode: err.code ?? 0, .message: err.detail])
                show(PointsToast(text: "Pembatalan poin gagal", kind: .error))
                return false
            }
        }
        if let i = ledger.firstIndex(where: { $0.id == entry.id }) { ledger[i].reversed = true }
        ledger.insert(WalletEntry(txnId: newTxn, orderId: entry.orderId, kind: type, points: entry.points, rule: entry.rule,
                                  paymentId: entry.paymentId, balanceAfter: balance, mock: mockMode), at: 0)
        persist()
        CleverTapManager.shared.record(.walletReversed, [.type: type, .txnId: entry.txnId, .rule: entry.rule])
        show(PointsToast(text: (isCredit ? "-" : "+") + "\(Self.fmt(entry.points)) Poin Loyalty", kind: isCredit ? .debit : .credit))
        return true
    }

    /// Credit and debit entries of one payment that can still be reversed.
    func reversibleEntries(paymentId: String) -> [WalletEntry] {
        ledger.filter { $0.paymentId == paymentId && !$0.reversed && ($0.kind == "credit" || $0.kind == "debit") }
    }

    var lastPaymentId: String? {
        ledger.first(where: { $0.paymentId != nil && !$0.reversed && ($0.kind == "credit" || $0.kind == "debit") })?.paymentId
    }

    // MARK: History (Riwayat Poin)

    @MainActor func loadHistory() async {
        guard let identity else { return }
        loadingHistory = true
        defer { loadingHistory = false }
        let english = false
        var rows: [HistoryRow] = []
        if mockMode {
            rows = ledger.map { HistoryRow(id: $0.id.uuidString, kind: $0.bucket == "PENDING" && $0.kind == "credit" ? "pending" : $0.kind,
                                           points: $0.points, rule: $0.rule, detail: $0.orderId, date: $0.date, runningBalance: $0.balanceAfter) }
        } else {
            do {
                let page = try await service.transactions(identity: identity)
                pending = page.promisedPoints
                rows = page.items.map { t in
                    let rule = t.metadata["rule"] ?? ledger.first(where: { $0.txnId == t.id })?.rule ?? ""
                    return HistoryRow(id: t.id, kind: t.type.lowercased(), points: t.points, rule: rule,
                                      detail: t.description, date: t.timestamp, runningBalance: 0)
                }
            } catch {
                lastError = (error as? WalletError)?.detail ?? error.localizedDescription
                // Offline: fall back to what this device recorded.
                rows = ledger.map { HistoryRow(id: $0.id.uuidString, kind: $0.kind, points: $0.points, rule: $0.rule,
                                               detail: $0.orderId, date: $0.date, runningBalance: $0.balanceAfter) }
            }
        }
        _ = english
        rows.sort { $0.date > $1.date }
        if !mockMode {
            // Running balance, newest first: step back by each row's effect.
            var running = balance
            for i in rows.indices { rows[i].runningBalance = running; running -= rows[i].signed }
        }
        history = rows
    }

    // MARK: Demo helpers

    /// Sets the active balance to `target` using a credit or debit. Used by scenarios.
    @MainActor func setBalance(to target: Double, screen: String = "demo_tools") async {
        let diff = target - balance
        if diff > 0.0001 {
            await award(.seed, points: diff, description: "Poin awal demo", orderId: "seed_\(UUID().uuidString.prefix(8))",
                        screen: screen, force: true)
        } else if diff < -0.0001 {
            await debit(.manual, points: -diff, description: "Penyesuaian demo", orderId: "adj_\(UUID().uuidString.prefix(8))", screen: screen)
        }
    }

    /// Removes every persisted wallet snapshot (all identities, live and mock).
    func resetAll() {
        let d = UserDefaults.standard
        for k in d.dictionaryRepresentation().keys where k.hasPrefix("ljd_wallet_") && k.contains(".demo_") { d.removeObject(forKey: k) }
        if identity != nil { load() }
    }

    func clearLocal() {
        UserDefaults.standard.removeObject(forKey: key)
        load()
    }

    // MARK: Toast

    func show(_ t: PointsToast) {
        var t = t
        if mockMode && t.kind != .info { t = PointsToast(text: t.text + " (mock)", kind: t.kind) }
        toast = t
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let id = t.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            if self?.toast?.id == id { self?.toast = nil }
        }
    }

    static func fmt(_ v: Double) -> String {
        let n = Int(v.rounded())
        return abs(v - Double(n)) < 0.005 ? "\(n)" : String(format: "%.1f", v)
    }
}
