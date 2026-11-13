import Foundation

struct Scenario: Identifiable {
    let id: Int
    let titleID: String
    let titleEN: String
    let useCase: String
    let entry: String
}

extension AppState {
    static let scenarios: [Scenario] = [
        Scenario(id: 1, titleID: "Baru daftar, KYC pending", titleEN: "Just registered, KYC pending",
                 useCase: "6.1 Onboarding", entry: CT.Event.appInstalled.name + " + " + CT.Event.registered.name),
        Scenario(id: 2, titleID: "KYC selesai, belum transaksi", titleEN: "KYC done, no transaction yet",
                 useCase: "6.2 First transaction", entry: CT.Event.kycCompleted.name),
        Scenario(id: 3, titleID: "2 dari 3 transaksi, tagihan jatuh tempo 3 hari", titleEN: "2 of 3 transactions, bill due in 3 days",
                 useCase: "6.3 Repeat transaction", entry: CT.Event.billReminderViewed.name),
        Scenario(id: 4, titleID: "Streak komuter 3 dari 5 hari", titleEN: "Commuter streak at 3 of 5 days",
                 useCase: "6.4 Retention", entry: CT.Event.streakUpdated.name),
        Scenario(id: 5, titleID: "Risiko churn tinggi, saldo masih ada", titleEN: "High churn risk, balance still present",
                 useCase: "6.5 Churn prevention", entry: "Profile update only (open Promo to fire the offer viewed event)"),
        Scenario(id: 6, titleID: "Dormant 45 hari, saldo Rp75.000", titleEN: "Dormant 45 days, balance Rp75,000",
                 useCase: "6.6 Reactivation", entry: "Profile update only (relaunch app for App Launched)"),
        Scenario(id: 7, titleID: "Pengguna QRIS saja, kategori berikutnya diprediksi", titleEN: "QRIS only user, next best category predicted",
                 useCase: "6.7 Cross-sell", entry: CT.Event.categoryUsed.name + " + " + CT.Event.offerVariantViewed.name),
        Scenario(id: 8, titleID: "Jendela gajian aktif (tgl 25 sampai 1)", titleEN: "Payday window active (25th to 1st)",
                 useCase: "6.8 Campaign", entry: CT.Event.campaignViewed.name)
    ]

    /// Resets the profile to a clean baseline, applies the scenario, pushes the diff and fires the entry events.
    func applyScenario(_ id: Int) {
        guard let p = persona else { return }
        let now = Date()
        func ago(_ days: Int) -> Date { Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now }
        func ahead(_ days: Int) -> Date { ago(-days) }

        let kycDone = id != 1
        var up = baseline(for: p, kycDone: kycDone)
        var local = LocalState()
        var events: [() -> Void] = []

        switch id {
        case 1:
            up[.registrationDate] = now
            up[.installSource] = "AppsFlyer"
            up[.voucherOnboardingEligible] = true
            up[.walletBalance] = 0
            events = [{ self.rec(.appInstalled, [.installSource: "AppsFlyer"]) }, { self.rec(.registered) }]

        case 2:
            up[.registrationDate] = ago(1); up[.kycStartedAt] = ago(1)
            up[.kycCompletedAt] = now
            up[.voucherOnboardingEligible] = true
            up[.transactionLikelihood] = p.id == Persona.budi.id ? "likely" : "unlikely"
            up[.walletBalance] = 100_000
            local.voucherOnboardingIssued = true
            local.voucher15IssuedAt = ago(1)   // so the card reads "Sisa 6 hari"
            events = [{ self.rec(.kycCompleted, [.durationSeconds: 118, .method: "KTP+selfie"]) }]

        case 3:
            up[.hasTransacted] = true
            up[.txnCount30d] = 2; up[.dominantCategory] = "PLN"
            up[.usualPaymentDay] = Calendar.current.component(.day, from: ahead(3))
            up[.nextBillDueDate] = ahead(3)
            up[.habitProgressCurrent] = 2; up[.habitProgressTarget] = 3
            up[.walletBalance] = 300_000
            wallet.resetHabitCycle()
            events = [{ self.rec(.billReminderViewed, [.category: "PLN", .daysLeft: 3]) }]

        case 4:
            up[.hasTransacted] = true
            up[.streakDays] = 3; up[.lastStreakDate] = now
            up[.holdoutGroup] = false
            up[.dominantCategory] = "transport"; up[.txnCount30d] = 12
            up[.walletBalance] = 200_000
            events = [{ self.rec(.streakUpdated, [.streakDays: 3, .targetDays: PEResolver.shared.streakTarget]) }]

        case 5:
            up[.hasTransacted] = true
            up[.churnPropensity] = "high_risk"
            up[.txnCount90d] = 3; up[.avgTxnValue90d] = 42_500
            up[.unusedPromoCount] = 3
            up[.lastTransactionDate] = ago(21); up[.daysSinceLastTransaction] = 21
            up[.controlGroup] = false
            up[.dominantCategory] = "qris"
            up[.walletBalance] = 180_000

        case 6:
            up[.hasTransacted] = true
            up[.daysSinceLastTransaction] = 45
            up[.lastTransactionDate] = ago(45)
            up[.walletBalance] = 75_000
            up[.sunsetList] = false
            up[.churnPropensity] = "high_risk"
            up[.txnCount90d] = 2
            up[.lastMessageSentAt] = ago(60)
            up[.emailOptIn] = true; up[.pushOptIn] = true; up[.whatsappOptIn] = true

        case 7:
            up[.hasTransacted] = true
            up[.categoriesUsed] = ["qris"]; up[.dominantCategory] = "qris"
            up[.rfmSegment] = "high"; up[.activeDays90d] = 38; up[.txnCount30d] = 9
            up[.nextBestCategory] = "tagihan"
            let variant = p.id == Persona.budi.id ? "praktis" : "hemat"
            up[.abVariant] = variant
            up[.walletBalance] = 220_000
            local.categoryCounts = ["qris": 9]
            events = [{ self.rec(.categoryUsed, [.category: "qris"]) },
                      { self.rec(.offerVariantViewed, [.variant: variant]) }]

        case 8:
            up[.hasTransacted] = true
            up[.paydayWindowActive] = true
            up[.favoriteCategory] = p.favoriteCategory
            up[.rfmSegment] = "high"
            up[.lastCampaignId] = "GAJIAN25"
            up[.campaignMessagesToday] = 0
            up[.redeemedCampaignIds] = [String]()
            up[.walletBalance] = 500_000
            local.paydayActive = true
            events = [{ self.rec(.campaignViewed, [.campaignId: "GAJIAN25"]) }]

        default: return
        }

        // Loyalty fields describe the wallet, not the scenario: carry them over.
        ["last_incentive_rule", "last_incentive_date"].forEach { k in
            if let v = props[k], let prop = CT.Prop(rawValue: k) { up[prop] = v }
        }
        // Drop keys that an earlier scenario set but this one does not, so the profile stays truthful.
        let newKeys = Set(up.keys.map { $0.rawValue })
        let stale = props.keys.filter { !newKeys.contains($0) }.compactMap { CT.Prop(rawValue: $0) }
        CleverTapManager.shared.removeProfileValues(stale)

        let old = props
        props = [:]
        changedKeys = []
        self.local = local
        seedActivityIfEmpty()
        set(up)
        // Highlight only what actually changed versus the previous state.
        changedKeys = Set(up.keys.map { $0.rawValue }.filter { k in
            guard let o = old[k] else { return true }
            return "\(o)" != "\(props[k] ?? "")"
        }).union(stale.map { $0.rawValue })
        optEmail = (up[.emailOptIn] as? Bool) ?? optEmail
        optPush = (up[.pushOptIn] as? Bool) ?? optPush
        optWhatsapp = (up[.whatsappOptIn] as? Bool) ?? optWhatsapp
        lastScenario = "\(id)"
        events.forEach { $0() }
        showToast(t("Skenario \(id) diterapkan", "Scenario \(id) applied"))
    }
}
