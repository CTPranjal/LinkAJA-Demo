import Foundation

/// Launch with `-autodemo` to fire every journey's events one by one through the same AppState calls
/// the screens use. Handy for filling the dashboard before a demo.
enum AutoDemo {
    static var enabled: Bool { CommandLine.arguments.contains("-autodemo") }
    static var walletTest: Bool { CommandLine.arguments.contains("-autowallet") }

    /// Headless check of the loyalty wallet flows. Run with `-autowallet -ljd_wallet_mock YES`.
    @MainActor
    static func runWallet(_ app: AppState) async {
        let w = app.wallet
        func show(_ s: String) { print("AUTOWALLET >> \(s) | points=\(w.points) pending=\(w.pendingPoints) saldo=\(app.balance) streak=\(app.int(.streakDays))/\(PEResolver.shared.streakTarget) cycles=\(app.int(.streakCyclesCompleted))") }
        func pause() async { try? await Task.sleep(nanoseconds: 700_000_000) }
        w.clearLocal()
        app.login(.siti); await pause(); show("login Siti (expect 400 points, saldo 120000)")
        print("AUTOWALLET >> hero=\(PEResolver.shared.heroTitle) | set=\(PEResolver.shared.stampSet) | layout=\(PEResolver.shared.promoLayout)")
        app.completeKYC(); await pause(); show("KYC (expect +200)")
        app.completeKYC(); await pause(); show("KYC again (expect no change, once only)")
        app.complete(.topUp, amount: 50_000, title: "Top Up"); await pause(); show("first top up (expect +150)")
        app.complete(.topUp, amount: 50_000, title: "Top Up"); await pause(); show("second top up (expect no points)")
        let q = app.payWithPointsQuote(amount: 100_000)
        print("AUTOWALLET >> quote for 100k: points=\(q?.points ?? 0) discount=\(q?.discount ?? 0)")
        let pid = app.complete(.bill("PLN"), amount: 100_000, title: "PLN", discount: q?.discount ?? 0, pointsUsed: q?.points ?? 0)
        await pause(); show("bill with points (expect +50 bill, -\(q?.points ?? 0) points, +new category 100)")
        let ok = await app.cancelPayment(pid); await pause(); show("cancel payment ok=\(ok)")
        for i in 1...5 { app.complete(.qris, amount: 35_000, title: "QRIS"); await pause(); show("qris stamp \(i)") }
        print("AUTOWALLET >> celebration=\(String(describing: app.celebration?.points))")
        app.complete(.qris, amount: 35_000, title: "QRIS"); await pause(); show("qris new cycle (expect streak 1/5)")
        let r = PersonaRegistry.siti.rewards[0]
        let redeemed = await app.redeemReward(r); show("redeem \(r.points) ok=\(redeemed)")
        let big = PointsReward(id: "big", title: "Big", points: 99_999)
        let denied = await app.redeemReward(big); show("redeem 99999 ok=\(denied) (expect false, no call)")
        print("AUTOWALLET >> failed queue=\(w.failed.count) ledger=\(w.ledger.count)")
        print("AUTOWALLET >> DONE")
    }

    @MainActor
    static func run(_ app: AppState, pause: Double = 2.0) async {
        func step(_ title: String, _ action: () -> Void) async {
            print("AUTODEMO >> \(title)")
            action()
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
        }
        let budi = Persona.budi

        await step("Login Budi") { app.login(budi) }

        await step("6.1 Scenario 1: App_Installed, Registered") { app.applyScenario(1) }
        await step("KYC_Started") { app.startKYC() }
        await step("KYC_Step_Completed ktp") { app.completeKYCStep("ktp") }
        await step("KYC_Step_Completed selfie") { app.completeKYCStep("selfie") }
        await step("KYC_Completed") { app.completeKYC() }

        await step("6.2 Voucher_Viewed (onboarding)") { app.viewVoucher("onboarding_10000") }
        await step("Top_Up_Completed + Voucher_Redeemed") { app.redeemOnboardingVoucher() }
        await step("Voucher_Viewed (first txn)") { app.viewVoucher("first_txn_15000") }
        await step("QRIS_Payment_Completed (first txn, voucher redeemed)") { app.complete(.qris, amount: 35_000, title: "QRIS Warung Bu Tini") }
        await step("Transfer_Completed") { app.complete(.transfer, amount: 50_000, title: "Transfer") }

        await step("6.3 Scenario 3: Bill_Reminder_Viewed") { app.applyScenario(3) }
        await step("Bill_Payment_Completed PLN (habit 3 of 3)") { app.complete(.bill("PLN"), amount: 150_000, title: "PLN") }

        await step("6.4 Scenario 4: Streak_Updated 3") { app.applyScenario(4) }
        await step("Transport_Payment_Completed (streak 4)") { app.complete(.transport, amount: 6_000, title: "KRL") }
        await step("Transport_Payment_Completed (streak 5, reward)") { app.complete(.transport, amount: 6_000, title: "KRL") }
        await step("Streak_Broken") { app.breakStreak() }

        await step("6.5 Scenario 5: high churn risk") { app.applyScenario(5) }
        await step("Churn_Offer_Viewed") { app.viewChurnOffer() }
        await step("Churn_Offer_Redeemed + Transaction_Completed") { app.redeemChurnOffer() }

        await step("6.6 Scenario 6: dormant 45 days") { app.applyScenario(6) }
        await step("Winback_Offer_Redeemed") { app.redeemWinback() }

        await step("6.7 Scenario 7: Category_Used, Offer_Variant_Viewed") { app.applyScenario(7) }
        await step("Bill payment in new category: New_Category_Used") { app.complete(.bill("pulsa"), amount: 50_000, title: "Pulsa") }
        await step("Donasi: Category_Used donasi") { app.complete(.donasi, amount: 20_000, title: "Donasi") }

        await step("6.8 Scenario 8: Campaign_Viewed") { app.applyScenario(8) }
        await step("Promo_Code_Copied") { app.rec(.promoCodeCopied, [.code: "GAJIAN25"]) }
        await step("Promo_Code_Applied") {
            app.rec(.promoCodeApplied, [.code: "GAJIAN25", .discountPercent: 10, .maxDiscount: 25_000, .minTransaction: 100_000])
        }
        await step("Promo_Code_Redeemed") {
            app.complete(.qris, amount: 150_000, title: "QRIS + GAJIAN25")
            app.rec(.promoCodeRedeemed, [.code: "GAJIAN25", .amount: 150_000, .campaignId: "GAJIAN25"])
            app.set([.walletBalance: app.balance + 15_000, .redeemedCampaignIds: ["GAJIAN25"], .lastCampaignId: "GAJIAN25"])
        }

        await step("Logout") { app.logout() }
        await step("Login Siti (ready for live demo)") { app.login(.siti) }
        print("AUTODEMO >> DONE")
    }
}


/// Opens a screen directly from launch arguments, so screenshots need no taps and no "Open in..." prompt.
/// Example: -screen home -persona siti -scrolled. Screens: login, welcome, home, topup, promo, streak,
/// inbox, profile, hub (Bill Hub for Budi, Toko for Siti).
enum ScreenshotMode {
    static func value(_ flag: String) -> String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: flag), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    static var active: Bool { value("-screen") != nil }

    @MainActor
    static func run(_ app: AppState, _ router: DeepLinkRouter) async {
        guard let screen = value("-screen") else { return }
        app.language = "id"
        if screen == "login" { app.logout(); return }
        let persona: Persona = value("-persona") == "siti" ? .siti : .budi
        app.wallet.resetAll()
        app.login(persona, welcome: screen == "welcome")
        if screen == "welcome" { return }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        let budi = persona.id == Persona.budi.id
        switch screen {
        case "topup": router.sheet = .topUp
        case "promo": if budi { router.sheet = .promo } else { router.tab = .promo }
        case "streak": router.sheet = .streak
        case "inbox": if budi { router.tab = .inbox } else { router.sheet = .inbox }
        case "profile": router.tab = .profile
        case "hub": router.tab = budi ? .bills : .shop
        default: router.tab = .home
        }
    }
}
