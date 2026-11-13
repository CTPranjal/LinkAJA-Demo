import SwiftUI
import Combine

/// Session, mock profile, wallet and all journey logic. Every CleverTap call goes through CleverTapManager.
final class AppState: ObservableObject {
    @Published var persona: Persona?
    @Published var language: String = "id"
    /// Current mock profile, keyed by CT.Prop.rawValue. Mirrors what is pushed to CleverTap.
    @Published var props: [String: Any] = [:]
    @Published var changedKeys: Set<String> = []
    @Published var local = LocalState()
    @Published var optEmail = true
    @Published var optPush = true
    @Published var optWhatsapp = true
    @Published var toast: String?
    @Published var lastScenario: String?
    /// Shown on the Streak screen after a cycle completes.
    @Published var celebration: Celebration?
    /// Persona id while the 1.2 second welcome transition is showing.
    @Published var welcome: String?
    /// Receipts of this session's payments, used by "Batalkan transaksi".
    @Published var payments: [String: PaymentRecord] = [:]

    let wallet = LoyaltyWallet.shared
    private let ct = CleverTapManager.shared
    private let d = UserDefaults.standard

    private var bag = Set<AnyCancellable>()

    init() {
        Self.resetIfNewBuild()
        restore()
        // Keep the active cross-sell variant on the profile so segments can use it.
        PEResolver.shared.$revision
            .map { _ in PEResolver.shared.crossVariant }
            .removeDuplicates()
            .sink { [weak self] v in
                guard let self, self.persona != nil else { return }
                self.set([.peVariantCrossSell: v])
            }
            .store(in: &bag)
        // LinkAJA_loyalty_points always mirrors the wallet balance shown in the UI.
        wallet.$balance
            .dropFirst()
            .map { Int($0.rounded()) }
            .removeDuplicates()
            .sink { [weak self] v in
                guard let self, self.persona != nil else { return }
                self.set([.loyaltyPoints: v])
            }
            .store(in: &bag)
        wallet.onCredited = { [weak self] rule in
            self?.set([.lastIncentiveRule: rule, .lastIncentiveDate: Date()])
        }
    }

    // MARK: Localization

    func t(_ id: String, _ en: String) -> String { language == "en" ? en : id }

    // MARK: Typed access to the profile

    func int(_ p: CT.Prop) -> Int { props[p.rawValue] as? Int ?? 0 }
    func str(_ p: CT.Prop) -> String { props[p.rawValue] as? String ?? "" }
    func bool(_ p: CT.Prop) -> Bool { props[p.rawValue] as? Bool ?? false }
    func date(_ p: CT.Prop) -> Date? { props[p.rawValue] as? Date }
    func list(_ p: CT.Prop) -> [String] { props[p.rawValue] as? [String] ?? [] }

    var balance: Int { int(.walletBalance) }
    var firstName: String { persona?.firstName ?? "" }

    /// Updates the local mirror and pushes the same values to the CleverTap profile.
    func set(_ updates: [CT.Prop: Any], push: Bool = true) {
        updates.forEach { props[$0.key.rawValue] = $0.value; changedKeys.insert($0.key.rawValue) }
        if push { ct.pushProfile(updates) }
        persist()
    }

    func rec(_ e: CT.Event, _ p: [CT.EventProp: Any] = [:]) { ct.record(e, p) }

    func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            if self?.toast == text { self?.toast = nil }
        }
    }

    // MARK: Login and logout

    func login(_ p: Persona, welcome showWelcome: Bool = true) {
        persona = p
        if showWelcome { withAnimation { welcome = p.id } }
        local = LocalState()
        props = [:]
        changedKeys = []
        optEmail = true; optPush = true; optWhatsapp = true

        let cfg = PersonaRegistry.config(for: p.id)
        PersonaRegistry.shared.activate(p.id)
        ThemeProvider.shared.refresh()
        wallet.activate(identity: p.id, config: cfg, freshStart: false)
        celebration = nil
        payments = [:]

        let base = baseline(for: p, kycDone: p.initialKYCStatus == "completed")
        var custom = base
        custom[.kycStatus] = p.initialKYCStatus
        custom[.kycTier] = p.initialKYCTier
        // Persona profile data, so the profile matches what the UI shows.
        cfg?.profileData().forEach { custom[$0.key] = $0.value }
        custom[.whatsappOptIn] = true; custom[.emailOptIn] = true; custom[.pushOptIn] = true

        ct.onUserLogin(
            reserved: [.identity: p.id, .name: p.fullName, .email: p.email, .phone: p.phone, .gender: p.gender],
            custom: custom)
        ct.setOptIns(email: true, push: true, whatsapp: true)
        custom.forEach { props[$0.key.rawValue] = $0.value }
        seedActivityIfEmpty()
        persist()
        rec(.login, [.persona: p.fullName])
        set([.peVariantCrossSell: PEStore.shared.crossVariant])
        PEStore.shared.fetch()
        AppDelegate.registerForPush()
    }

    func logout() {
        rec(.logout)
        persona = nil
        PersonaRegistry.shared.activate(nil)
        ThemeProvider.shared.refresh()
        welcome = nil
        wallet.deactivate()
        celebration = nil
        props = [:]
        local = LocalState()
        lastScenario = nil
        ["session", "props", "local", "opt"].forEach { d.removeObject(forKey: "ljd_\($0)") }
    }

    /// Profile every persona starts from. Scenarios start from this too, then override.
    func baseline(for p: Persona, kycDone: Bool) -> [CT.Prop: Any] {
        [
            .firstName: p.firstName, .city: p.city, .personaType: p.personaType,
            .kycStatus: kycDone ? "completed" : "pending", .kycTier: kycDone ? "full" : "basic",
            .walletBalance: PersonaRegistry.config(for: p.id)?.walletBalance ?? p.initialBalance, .preferredLanguage: language,
            .abVariant: p.abVariant, .hasTransacted: false,
            .streakDays: 0, .streakCyclesCompleted: 0, .badgeEarned: false,
            .loyaltyPoints: wallet.points, .loyaltyWalletId: "\(wallet.walletId)",
            .holdoutGroup: false, .controlGroup: false,
            .habitProgressCurrent: 0, .habitProgressTarget: 3,
            .categoriesUsed: [String](), .churnPropensity: "low",
            .whatsappOptIn: optWhatsapp, .emailOptIn: optEmail, .pushOptIn: optPush
        ]
    }

    // MARK: Profile settings

    func setLanguage(_ code: String) {
        language = code
        if persona != nil { set([.preferredLanguage: code]) } else { persist() }
    }

    func updateOptIns() {
        ct.setOptIns(email: optEmail, push: optPush, whatsapp: optWhatsapp)
        [(CT.Prop.emailOptIn, optEmail), (.pushOptIn, optPush), (.whatsappOptIn, optWhatsapp)]
            .forEach { props[$0.0.rawValue] = $0.1; changedKeys.insert($0.0.rawValue) }
        persist()
        if optPush { AppDelegate.registerForPush() }
    }

    // MARK: KYC (6.1)

    func startKYC() {
        local.kycStartTime = Date()
        rec(.kycStarted)
        set([.kycStartedAt: Date()])
    }

    func completeKYCStep(_ step: String) {
        rec(.kycStepCompleted, [.step: step])
    }

    func completeKYC() {
        let start = local.kycStartTime ?? Date()
        let seconds = max(1, Int(Date().timeIntervalSince(start)))
        rec(.kycCompleted, [.durationSeconds: seconds, .method: "KTP+selfie"])
        local.voucherOnboardingIssued = true
        local.voucher15IssuedAt = Date()
        set([.kycStatus: "completed", .kycTier: "full", .kycCompletedAt: Date(),
             .voucherOnboardingEligible: true, .transactionLikelihood: "likely"])
        awardKYC()
    }

    // MARK: Transactions (6.2 to 6.7)

    /// Central place where a payment updates the wallet, profile and fires every related event.
    /// `amount` is the bill. `discount` is the Rupiah saved by paying with points, `pointsUsed` the points debited.
    /// Returns the payment id, which is also the wallet orderId for this payment.
    @discardableResult
    func complete(_ kind: TxnKind, amount: Int, title: String? = nil, paymentId: String = AppState.newPaymentId(),
                  discount: Int = 0, pointsUsed: Int = 0) -> String {
        let isFirst = !bool(.hasTransacted)
        let workday = Self.isWorkday()
        var up: [CT.Prop: Any] = [:]
        var awards: [() async -> Void] = []
        let identity = persona?.id ?? ""

        // Wallet (Rupiah saldo, not Poin Loyalty)
        var newBalance = balance
        let charged = max(0, amount - discount)
        if case .topUp = kind { newBalance += amount } else { newBalance = max(0, newBalance - charged) }
        up[.walletBalance] = newBalance
        let signed: Int = { if case .topUp = kind { return amount } else { return -charged } }()
        payments[paymentId] = PaymentRecord(title: title ?? kind.label, signedAmount: signed)
        local.activity.insert(ActivityItem(title: title ?? kind.label, amount: signed, date: Date()), at: 0)
        local.activity = Array(local.activity.prefix(6))

        // Specific event
        switch kind {
        case .topUp: rec(.topUpCompleted, [.amount: amount, .isFirstTransaction: isFirst])
        case .qris: rec(.qrisPaymentCompleted, [.amount: amount, .isFirstTransaction: isFirst, .isWorkday: workday])
        case .transfer: rec(.transferCompleted, [.amount: amount, .isFirstTransaction: isFirst])
        case .bill(let b): rec(.billPaymentCompleted, [.category: b, .amount: amount])
        case .transport: rec(.transportPaymentCompleted, [.amount: amount, .isWorkday: workday])
        case .donasi, .zakat: break
        }
        rec(.transactionCompleted, [.amount: amount, .category: kind.category ?? kind.label.lowercased()])

        // Frequency, recency, churn state
        if isFirst { up[.hasTransacted] = true; up[.firstTransactionDate] = Date() }
        up[.txnCount30d] = int(.txnCount30d) + 1
        up[.txnCount90d] = int(.txnCount90d) + 1
        up[.lastTransactionDate] = Date()
        up[.daysSinceLastTransaction] = 0
        up[.sunsetList] = false
        if str(.churnPropensity) == "high_risk" { up[.churnPropensity] = "medium" }
        up[.activeDays90d] = int(.activeDays90d) + 1

        // Categories and cross-sell
        if let cat = kind.category {
            rec(.categoryUsed, [.category: cat])
            var used = list(.categoriesUsed)
            let isNew = !used.contains(cat)
            if isNew {
                used.append(cat)
                up[.categoriesUsed] = used
                rec(.newCategoryUsed, [.category: cat, .isFirstInCategory: true])
                awards.append { [self] in
                    await self.wallet.award(.newCategory, points: Double(PEResolver.shared.int(.incNewCatPoints)),
                                            description: "Kategori baru: \(cat)", orderId: "newcat_\(identity)_\(cat)",
                                            metadata: ["category": cat], screen: "payment", onceKey: "newcat_\(cat)")
                }
                if used.count > 1 { let cb = PEStore.shared.crossCashback
                    credit(cb, "Cashback kategori baru \(Fmt.rp(cb))", "New category cashback \(Fmt.rp(cb))", into: &up) }
            }
            local.categoryCounts[cat, default: 0] += 1
            up[.dominantCategory] = local.categoryCounts.max { $0.value < $1.value }?.key ?? cat
            if str(.nextBestCategory) == cat { up[.nextBestCategory] = "" }
        }

        // Habit builder (bill payments only)
        if case .bill(let b) = kind {
            let target = max(3, int(.habitProgressTarget))
            let current = min(target, int(.habitProgressCurrent) + 1)
            up[.habitProgressCurrent] = current
            up[.habitProgressTarget] = target
            up[.dominantCategory] = b
            up[.nextBillDueDate] = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            up[.usualPaymentDay] = Calendar.current.component(.day, from: Date())
            if current >= target && !local.habitCashbackGranted {
                local.habitCashbackGranted = true
                credit(10_000, "Cashback Rp10.000 transaksi ke-3", "Rp10,000 cashback for the 3rd transaction", into: &up)
            }
            if current >= 3 {
                awards.append { [self] in
                    await self.wallet.award(.habitThirdPayment, points: Double(PEResolver.shared.int(.incHabitPoints)),
                                            description: "Transaksi ke-3 (kebiasaan)", orderId: "habit_\(identity)_\(self.wallet.habitKey)",
                                            saleAmount: amount, metadata: ["category": b], screen: "bill_payment",
                                            onceKey: self.wallet.habitKey)
                }
            }
        }

        // Earn rules that depend on the kind of payment
        let pe = PEResolver.shared
        switch kind {
        case .topUp:
            awards.append { [self] in
                await self.wallet.award(.firstTopup, points: Double(pe.int(.incTopupPoints)), description: "Top up pertama",
                                        orderId: "first_topup_\(identity)", saleAmount: amount, screen: "top_up",
                                        onceKey: "first_topup", paymentId: paymentId)
            }
        case .qris:
            let pts = min(pe.int(.incQrisMax), (amount / 10_000) * pe.int(.incQrisPer10k))
            if pts > 0 {
                awards.append { [self] in
                    await self.wallet.award(.qrisPayment, points: Double(pts), description: "Pembayaran QRIS", orderId: paymentId,
                                            saleAmount: amount, screen: "qris", paymentId: paymentId)
                }
            }
        case .bill(let b):
            awards.append { [self] in
                await self.wallet.award(.billPayment, points: Double(pe.int(.incBillPoints)), description: "Pembayaran tagihan \(b)",
                                        orderId: paymentId, saleAmount: amount, metadata: ["category": b], screen: "bill_payment",
                                        paymentId: paymentId)
            }
        default: break
        }

        // Streak (transport and QRIS)
        switch kind {
        case .transport, .qris: applyStreak(&up, awards: &awards)
        default: break
        }

        // Points spent on this payment
        if pointsUsed > 0 {
            awards.append { [self] in
                await self.settlePointsDebit(paymentId: paymentId, points: pointsUsed, discount: discount, bill: amount,
                                             screen: { if case .qris = kind { return "qris" }; return "bill_payment" }())
            }
        }

        // First-transaction voucher is consumed by the first QRIS payment while valid
        if case .qris = kind, voucher15DaysLeft > 0, !local.voucher15Redeemed {
            local.voucher15Redeemed = true
            rec(.voucherRedeemed, [.voucherId: "first_txn_15000"])
            credit(15_000, "Voucher Rp15.000 terpakai", "Rp15,000 voucher redeemed", into: &up)
        }
        set(up)
        if !awards.isEmpty {
            let list = awards
            Task { @MainActor in for a in list { await a() } }
        }
        return paymentId
    }

    static func newPaymentId() -> String { "txn_" + UUID().uuidString.prefix(8).lowercased() }

    /// Adds mock cashback to the balance being built in `up`.
    private func credit(_ amount: Int, _ id: String, _ en: String, into up: inout [CT.Prop: Any]) {
        up[.walletBalance] = (up[.walletBalance] as? Int ?? balance) + amount
        showToast(t(id, en))
    }

    // MARK: Streak (6.4)

    /// Demo mode: every qualifying payment is one stamp. A cycle is `target_days` stamps.
    /// After the last stamp the next qualifying payment starts a new cycle at 1.
    private func applyStreak(_ up: inout [CT.Prop: Any], awards: inout [() async -> Void]) {
        let pe = PEResolver.shared
        guard pe.streakEnabled else { return }
        let target = pe.streakTarget
        var current = int(.streakDays)
        if current >= target { current = 0 }
        let days = current + 1
        up[.streakDays] = days
        up[.lastStreakDate] = Date()
        local.streakNudge = false
        rec(.streakUpdated, [.streakDays: days, .targetDays: target])
        let symbol = StampSets.symbol(set: pe.stampSet, index: days - 1, target: target, finalSymbol: pe.stampFinalSymbol)
        rec(.streakStampEarned, [.dayIndex: days, .stampSymbol: symbol, .streakDays: days, .isFinal: days == target])
        if days == target { completeCycle(&up, awards: &awards) }
    }

    /// Last stamp of a cycle: events, badge check and the points credit.
    func completeCycle(_ up: inout [CT.Prop: Any], awards: inout [() async -> Void]) {
        let pe = PEResolver.shared
        let cycles = int(.streakCyclesCompleted) + 1
        let pts = pe.rewardPoints
        up[.streakCyclesCompleted] = cycles
        rec(.streakCycleCompleted, [.cycleNumber: cycles, .pointsAwarded: pts])
        rec(.streakRewardEarned, [.reward: "loyalty_points", .points: pts])
        if cycles >= pe.badgeCycles && !bool(.badgeEarned) {
            up[.badgeEarned] = true
            rec(.badgeEarned, [.badgeLabel: pe.badgeLabel, .cyclesCompleted: cycles])
            showToast(t("Badge \(pe.badgeLabel) didapat!", "\(pe.badgeLabel) badge earned!"))
        }
        awards.append { [self] in await self.runCycleAward(cycle: cycles, points: pts) }
    }

    @MainActor func runCycleAward(cycle: Int, points: Int) async {
        let pe = PEResolver.shared
        let identity = persona?.id ?? ""
        let pendingBucket = pe.string(.incCycleBucket).uppercased() == "PENDING"
        let activation = pe.string(.incCycleActivation)
        var note: String?
        if pendingBucket {
            note = t("Poin menunggu aktif dalam \(Self.humanDuration(activation, english: false))",
                     "Points active in \(Self.humanDuration(activation, english: true))")
        }
        guard points > 0 else { celebration = Celebration(cycle: cycle, points: 0, note: nil, queued: false); return }
        let outcome = await wallet.award(.streakCycle, points: Double(points), description: "Siklus streak selesai",
                                         orderId: "cycle_\(identity)_\(cycle)", metadata: ["cycle": "\(cycle)"], screen: "streak",
                                         onceKey: "streak_cycle_\(cycle)", bucket: pendingBucket ? "PENDING" : "ACTIVE",
                                         activation: activation)
        switch outcome {
        case .success: celebration = Celebration(cycle: cycle, points: points, note: note, queued: false)
        case .skipped: celebration = Celebration(cycle: cycle, points: 0, note: nil, queued: false)
        default: celebration = Celebration(cycle: cycle, points: points, note: nil, queued: true)
        }
    }

    func breakStreak() {
        rec(.streakBroken)
        local.streakNudge = true
        set([.streakDays: 0, .streakBrokenAt: Date()])
    }

    /// "1d" becomes "1 hari"; "1w 2d" becomes "1 minggu 2 hari".
    static func humanDuration(_ s: String, english: Bool) -> String {
        let units: [Character: (String, String)] = ["y": ("tahun", "year"), "w": ("minggu", "week"), "d": ("hari", "day"),
                                                    "h": ("jam", "hour"), "m": ("menit", "minute")]
        let parts = s.split(separator: " ").compactMap { tok -> String? in
            guard let u = tok.last, let n = Int(tok.dropLast()), let name = units[u] else { return nil }
            return english ? "\(n) \(name.1)\(n == 1 ? "" : "s")" : "\(n) \(name.0)"
        }
        return parts.isEmpty ? s : parts.joined(separator: " ")
    }

    static func isWorkday(_ date: Date = Date()) -> Bool {
        !Calendar.current.isDateInWeekend(date)
    }

    // MARK: Vouchers and offers

    var voucher15DaysLeft: Int {
        guard let issued = local.voucher15IssuedAt else { return 0 }
        let used = Calendar.current.dateComponents([.day], from: issued, to: Date()).day ?? 0
        return max(0, 7 - used)
    }

    func viewVoucher(_ id: String) {
        rec(.voucherViewed, [.voucherId: id, .daysLeft: voucher15DaysLeft])
    }

    /// Onboarding voucher: Rp10.000 after a Rp50.000 top-up.
    func redeemOnboardingVoucher() {
        complete(.topUp, amount: 50_000, title: "Top Up")
        local.voucherOnboardingRedeemed = true
        rec(.voucherRedeemed, [.voucherId: "onboarding_10000"])
        set([.walletBalance: balance + 10_000, .voucherOnboardingEligible: false])
        showToast(t("Voucher Rp10.000 masuk ke saldo", "Rp10,000 voucher added to balance"))
    }

    var showChurnOffer: Bool { str(.churnPropensity) == "high_risk" && int(.daysSinceLastTransaction) < 30 }
    var showWinbackOffer: Bool { int(.daysSinceLastTransaction) >= 30 && balance > 0 }

    func viewChurnOffer() { rec(.churnOfferViewed, [.offerId: "churn_10000"]) }

    func redeemChurnOffer() {
        complete(.qris, amount: 25_000, title: "QRIS")
        rec(.churnOfferRedeemed, [.offerId: "churn_10000"])
        set([.walletBalance: balance + 10_000, .churnPropensity: "low", .unusedPromoCount: max(0, int(.unusedPromoCount) - 1)])
        showToast(t("Cashback Rp10.000 diterima", "Rp10,000 cashback received"))
    }

    func redeemWinback() {
        complete(.qris, amount: 25_000, title: "QRIS")
        rec(.winbackOfferRedeemed, [.offerId: "winback_15000"])
        set([.walletBalance: balance + 15_000, .sunsetList: false, .churnPropensity: "low"])
        showToast(t("Cashback Rp15.000 diterima", "Rp15,000 cashback received"))
    }

    // MARK: Campaign (6.8)

    func setLastCampaign(_ id: String) {
        set([.lastCampaignId: id])
    }

    // MARK: Persistence

    private func persist() {
        guard let p = persona else { return }
        d.set(p.id, forKey: "ljd_session")
        d.set(props, forKey: "ljd_props")
        d.set(language, forKey: "ljd_lang")
        d.set([optEmail, optPush, optWhatsapp], forKey: "ljd_opt")
        if let data = try? JSONEncoder().encode(local) { d.set(data, forKey: "ljd_local") }
    }

    private func restore() {
        language = d.string(forKey: "ljd_lang") ?? "id"
        guard let id = d.string(forKey: "ljd_session"), let p = Persona.all.first(where: { $0.id == id }) else { return }
        persona = p
        PersonaRegistry.shared.activate(p.id)
        ThemeProvider.shared.refresh()
        wallet.activate(identity: p.id, config: PersonaRegistry.config(for: p.id), freshStart: false)
        props = d.dictionary(forKey: "ljd_props") ?? [:]
        if let data = d.data(forKey: "ljd_local"), let l = try? JSONDecoder().decode(LocalState.self, from: data) { local = l }
        seedActivityIfEmpty()
        if let o = d.array(forKey: "ljd_opt") as? [Bool], o.count == 3 { optEmail = o[0]; optPush = o[1]; optWhatsapp = o[2] }
    }
}
