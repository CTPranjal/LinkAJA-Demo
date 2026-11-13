import SwiftUI

struct Celebration: Identifiable {
    let id = UUID()
    let cycle: Int
    let points: Int
    /// "Poin menunggu aktif dalam 1 hari" when the credit went to the PENDING bucket.
    let note: String?
    /// True when the credit failed and sits in the retry queue.
    let queued: Bool
}

struct PaymentRecord {
    let title: String
    let signedAmount: Int      // Rupiah, negative for spend
    var cancelled = false
}

struct PointsQuote {
    let points: Int
    let discount: Int
}

/// Incentive rules that are not part of the payment flow itself, plus the debit and reversal flows.
extension AppState {

    // MARK: KYC and promo codes

    func awardKYC() {
        let pe = PEResolver.shared
        let identity = persona?.id ?? ""
        Task { @MainActor in
            await wallet.award(.kycCompleted, points: Double(pe.int(.incKycPoints)), description: "KYC selesai",
                               orderId: "kyc_\(identity)", screen: "kyc", onceKey: "kyc_completed")
        }
    }

    func awardPromoRedeemed(code: String, promoId: String) {
        let pe = PEResolver.shared
        let identity = persona?.id ?? ""
        Task { @MainActor in
            await wallet.award(.promoCodeRedeemed, points: Double(pe.int(.incPromoPoints)), description: "Kode promo \(code)",
                               orderId: "promo_\(identity)_\(code)", metadata: ["code": code, "promo_id": promoId],
                               screen: "promo", onceKey: "promo_\(code)")
        }
    }

    // MARK: Pay with points

    /// Points and Rupiah discount for a bill, or nil when the feature is off or there are no points.
    /// Discount = points x points_to_rupiah, capped at max_percent_of_bill of the bill.
    func payWithPointsQuote(amount: Int) -> PointsQuote? {
        let pe = PEResolver.shared
        guard pe.incentivesEnabled, pe.loyaltyEnabled, pe.bool(.incPayEnabled) else { return nil }
        let rate = max(1, pe.int(.incPayRate))
        let percent = min(100, max(0, pe.int(.incPayMaxPercent)))
        let cap = amount * percent / 100
        let pts = min(Int(wallet.balance), cap / rate)
        guard pts > 0 else { return nil }
        return PointsQuote(points: pts, discount: pts * rate)
    }

    @MainActor func settlePointsDebit(paymentId: String, points: Int, discount: Int, bill: Int, screen: String) async {
        let outcome = await wallet.debit(.payWithPoints, points: Double(points), description: "Bayar pakai poin",
                                         orderId: paymentId, saleAmount: bill, screen: screen, paymentId: paymentId)
        if case .success = outcome {
            rec(.payWithPointsUsed, [.points: points, .rupiahSaved: discount, .billAmount: bill])
        }
    }

    // MARK: Reversal ("Batalkan transaksi")

    /// Mock refund of a payment: reverses the earn credit and refunds the points debit (up to two wallet
    /// calls, using the stored txnIds), then restores the Rupiah saldo.
    @MainActor @discardableResult
    func cancelPayment(_ paymentId: String) async -> Bool {
        var ok = true
        for e in wallet.reversibleEntries(paymentId: paymentId) { ok = await wallet.reverse(e) && ok }
        if var p = payments[paymentId], !p.cancelled {
            p.cancelled = true
            payments[paymentId] = p
            set([.walletBalance: max(0, balance - p.signedAmount)])
            local.activity.insert(ActivityItem(title: t("Dibatalkan: ", "Cancelled: ") + p.title, amount: -p.signedAmount, date: Date()), at: 0)
            local.activity = Array(local.activity.prefix(6))
            showToast(t("Transaksi dibatalkan", "Transaction cancelled"))
        }
        return ok
    }

    // MARK: Loyalty catalog (Tukar poin)

    @MainActor func redeemReward(_ r: PointsReward) async -> Bool {
        let outcome = await wallet.debit(.loyaltyRedeem, points: Double(r.points), description: "Tukar poin: \(r.title)",
                                         orderId: "redeem_\(r.id)_\(UUID().uuidString.prefix(6).lowercased())",
                                         metadata: ["reward_id": r.id], screen: "promo")
        if case .success = outcome { return true }
        return false
    }

    // MARK: Demo scenarios

    /// One payment away from the cycle reward.
    func demoStreakNearComplete() {
        let target = PEResolver.shared.streakTarget
        celebration = nil
        set([.streakDays: max(0, target - 1)])
        rec(.streakUpdated, [.streakDays: max(0, target - 1), .targetDays: target])
    }

    /// Fills the last stamp and runs the cycle credit, without moving any money.
    func demoCompleteCycle() {
        let target = PEResolver.shared.streakTarget
        var up: [CT.Prop: Any] = [.streakDays: target, .lastStreakDate: Date()]
        var awards: [() async -> Void] = []
        let symbol = StampSets.symbol(set: PEResolver.shared.stampSet, index: target - 1, target: target,
                                      finalSymbol: PEResolver.shared.stampFinalSymbol)
        rec(.streakUpdated, [.streakDays: target, .targetDays: target])
        rec(.streakStampEarned, [.dayIndex: target, .stampSymbol: symbol, .streakDays: target, .isFinal: true])
        completeCycle(&up, awards: &awards)
        set(up)
        let list = awards
        Task { @MainActor in for a in list { await a() } }
    }

    func demoResetStreakCycle() {
        celebration = nil
        set([.streakDays: 0])
    }

    func demoPoints(_ target: Int) {
        Task { @MainActor in await wallet.setBalance(to: Double(target)) }
    }

    // MARK: Activity seeds and demo reset

    /// Recent activity is never empty: each persona starts with a few sample rows.
    func seedActivityIfEmpty() {
        guard local.activity.isEmpty, let p = persona, let cfg = PersonaRegistry.config(for: p.id) else { return }
        local.activity = cfg.seedActivity.enumerated().map { i, row in
            ActivityItem(title: row.0, amount: row.1, date: Date().addingTimeInterval(-Double(i + 1) * 3_600))
        }
    }

    /// Clears the persisted wallet ledger, once-only flags and failed queue for every Identity,
    /// then restarts the current persona so Budi has 1.250 points and Siti 400.
    func resetDemoState() {
        wallet.resetAll()
        if let p = persona { login(p, welcome: false) }
    }

    /// Runs automatically on the first launch of a new build.
    static func resetIfNewBuild() {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let d = UserDefaults.standard
        guard d.string(forKey: "ljd_build_marker") != build else { return }
        LoyaltyWallet.shared.resetAll()
        d.set(build, forKey: "ljd_build_marker")
    }

    /// Re-logs in as the other persona without the login screen.
    func switchPersona() {
        guard let current = persona else { return }
        let other = Persona.all.first { $0.id != current.id } ?? current
        logout()
        login(other)
    }
}
