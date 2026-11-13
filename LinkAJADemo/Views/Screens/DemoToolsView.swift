import SwiftUI

/// Hidden screen: tap the version label in Profile five times.
struct DemoToolsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var ct: CleverTapManager
    @EnvironmentObject var resolver: PEResolver
    @ObservedObject private var wallet = LoyaltyWallet.shared
    @State private var copied = false
    @State private var copiedTxn: String?

    private let groups: [(String, [CT.Event])] = [
        ("6.1 Onboarding", [.appInstalled, .registered, .kycStarted, .kycStepCompleted, .kycCompleted]),
        ("6.2 First transaction", [.topUpCompleted, .qrisPaymentCompleted, .transferCompleted, .voucherViewed, .voucherRedeemed]),
        ("6.3 Repeat", [.billPaymentCompleted, .billReminderViewed]),
        ("6.4 Streak", [.transportPaymentCompleted, .streakUpdated, .streakBroken, .streakRewardEarned]),
        ("6.5 and 6.6 Churn and win-back", [.transactionCompleted, .churnOfferViewed, .churnOfferRedeemed, .winbackOfferRedeemed]),
        ("6.7 Cross-sell", [.categoryUsed, .newCategoryUsed, .offerVariantViewed]),
        ("6.8 Campaign", [.campaignViewed, .promoCodeCopied, .promoCodeApplied, .promoCodeRedeemed]),
        ("Loyalty wallet", [.walletCredited, .walletDebited, .walletReversed, .walletOperationFailed,
                            .payWithPointsUsed, .loyaltyPointsEarned, .loyaltyPointsRedeemed]),
        ("Stamps, badge and promos", [.streakStampEarned, .streakCycleCompleted, .badgeEarned, .promoViewed, .promoClicked]),
        ("Session", [.login, .logout])
    ]

    var body: some View {
        List {
            Section("CleverTap ID") {
                Text(ct.cleverTapID).font(.footnote.monospaced()).textSelection(.enabled)
                Button(copied ? "Copied" : "Copy") {
                    UIPasteboard.general.string = ct.cleverTapID
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }
            }

            Section("Product Experiences") {
                NavigationLink("PE Inspector (LinkAJA.* variables)") { PEInspectorView() }
            }

            Section("Persona") {
                row("Active", resolver.persona.map { "\($0.displayName) (\($0.personaID))" } ?? "none")
                Button("Switch persona (re-login without the login screen)") { app.switchPersona() }
                NavigationLink("Persona Diff (Budi vs Siti)") { PersonaDiffView() }
                Button("Reset demo state (wallet ledger, points, activity)", role: .destructive) { app.resetDemoState() }
            }

            walletSection
            walletOperationsSection
            if !wallet.failed.isEmpty { failedSection }

            Section("Loyalty scenarios") {
                Button("Streak 4/5 (one payment from points)") { app.demoStreakNearComplete() }
                Button("Streak complete: award points") { app.demoCompleteCycle() }
                Button("Points 250 (near redeem)") { app.demoPoints(250) }
                Button("Reset streak cycle") { app.demoResetStreakCycle() }
            }

            Section("Scenario switcher") {
                ForEach(AppState.scenarios) { s in
                    Button { app.applyScenario(s.id) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("\(s.id). " + app.t(s.titleID, s.titleEN)).font(.subheadline.bold()).foregroundStyle(.primary)
                                Spacer()
                                if app.lastScenario == "\(s.id)" { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good) }
                            }
                            Text(s.useCase + "  |  Entry: " + s.entry).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Current profile (changed values in red)") {
                ForEach(app.props.keys.sorted(), id: \.self) { k in
                    HStack(alignment: .top) {
                        Text(CT.prefix + k).font(.caption.monospaced())
                        Spacer(minLength: 8)
                        Text(display(app.props[k])).font(.caption.bold()).multilineTextAlignment(.trailing)
                            .foregroundStyle(app.changedKeys.contains(k) ? Theme.red : .primary)
                    }
                }
            }

            Section("Frequency cap demo") {
                Button("Simulate campaign message (+1 campaign_messages_today)") {
                    app.set([.campaignMessagesToday: app.int(.campaignMessagesToday) + 1, .lastMessageSentAt: Date()])
                }
                Button("Reset campaign_messages_today to 0") { app.set([.campaignMessagesToday: 0]) }
            }

            ForEach(groups, id: \.0) { group in
                Section("Fire events: " + group.0) {
                    ForEach(group.1, id: \.self) { e in
                        Button { app.rec(e, sampleProps(e)) } label: {
                            Text(e.name).font(.caption.monospaced())
                        }
                    }
                }
            }

            Section("CleverTap activity (latest first)") {
                ForEach(Array(ct.activityLog.prefix(20).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(size: 10, design: .monospaced))
                }
            }
        }
        .navigationTitle("Demo Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Wallet

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.subheadline); Spacer(); Text(v).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
    }

    private var walletSection: some View {
        Section("Wallet (Poin Loyalty)") {
            row("Poin Loyalty", "\(wallet.points)")
            row("Pending", "\(wallet.pendingPoints)")
            row("Wallet ID", "\(wallet.walletId)")
            row("Identity", wallet.identity ?? "-")
            row("Credentials", wallet.isConfigured ? "configured" : "missing (use mock)")
            Toggle("Mock wallet (offline)", isOn: $wallet.mockMode)
            Button(wallet.refreshing ? "Refreshing..." : "Refresh balance") { Task { await wallet.refreshBalance() } }
            if let e = wallet.lastError, !wallet.mockMode { Text("Last error: " + e).font(.caption2).foregroundStyle(.secondary) }
            ForEach(IncentiveRule.creditRules, id: \.self) { r in
                Button("Credit: \(r.rawValue) (+\(manualPoints(r)))") { fire(r) }.font(.subheadline)
            }
            Button("Debit 100 points") {
                Task { @MainActor in
                    await wallet.debit(.manual, points: 100, description: "Debit manual", orderId: "manual_debit_\(UUID().uuidString.prefix(6).lowercased())", screen: "demo_tools")
                }
            }
            Button("Seed persona starting points") {
                let target = resolver.persona?.startingPoints ?? 0
                if wallet.balance < Double(target) { app.demoPoints(target) }
                else { wallet.show(PointsToast(text: "Saldo poin sudah cukup", kind: .info)) }
            }
            Button("Refund last payment") {
                Task { @MainActor in
                    if let id = wallet.lastPaymentId { await app.cancelPayment(id) }
                    else { wallet.show(PointsToast(text: "Tidak ada pembayaran untuk dibatalkan", kind: .info)) }
                }
            }
            Button("Reset wallet state on this device", role: .destructive) { wallet.clearLocal() }
        }
    }

    private var walletOperationsSection: some View {
        Section("Last 10 wallet operations") {
            if wallet.ledger.isEmpty { Text("None yet").font(.caption).foregroundStyle(.secondary) }
            ForEach(Array(wallet.ledger.prefix(10))) { e in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(e.kind) \(LoyaltyWallet.fmt(e.points))  \(e.rule)" + (e.mock ? " (mock)" : "") + (e.reversed ? " (reversed)" : ""))
                            .font(.caption.bold())
                        Text(e.txnId).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Spacer()
                    Button(copiedTxn == e.txnId ? "Copied" : "Copy") {
                        UIPasteboard.general.string = e.txnId
                        copiedTxn = e.txnId
                    }
                    .font(.caption).buttonStyle(.borderless)
                }
            }
        }
    }

    private var failedSection: some View {
        Section("Failed wallet operations (manual retry, same orderId)") {
            ForEach(wallet.failed) { f in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(f.op.isCredit ? "credit" : "debit") \(LoyaltyWallet.fmt(f.op.points))  \(f.op.rule)").font(.caption.bold())
                    Text(f.op.orderId).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    Text(f.error).font(.caption2).foregroundStyle(Theme.bad)
                    HStack {
                        Button("Retry") { Task { @MainActor in await wallet.retry(f) } }.buttonStyle(.borderless)
                        Spacer()
                        Button("Discard", role: .destructive) { wallet.discardFailed(f) }.buttonStyle(.borderless)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func manualPoints(_ r: IncentiveRule) -> Int {
        let pe = PEResolver.shared
        switch r {
        case .kycCompleted: return pe.int(.incKycPoints)
        case .firstTopup: return pe.int(.incTopupPoints)
        case .qrisPayment: return min(pe.int(.incQrisMax), (50_000 / 10_000) * pe.int(.incQrisPer10k))
        case .billPayment: return pe.int(.incBillPoints)
        case .habitThirdPayment: return pe.int(.incHabitPoints)
        case .streakCycle: return pe.rewardPoints
        case .promoCodeRedeemed: return pe.int(.incPromoPoints)
        case .newCategory: return pe.int(.incNewCatPoints)
        default: return 0
        }
    }

    /// Fires a credit rule manually. Once-only guards are ignored, the orderId is unique,
    /// but the dashboard on/off switches still apply.
    private func fire(_ r: IncentiveRule) {
        let pts = manualPoints(r)
        let pe = PEResolver.shared
        Task { @MainActor in
            let outcome = await wallet.award(r, points: Double(pts), description: "Manual: \(r.rawValue)",
                                             orderId: "manual_\(r.rawValue)_\(UUID().uuidString.prefix(6).lowercased())",
                                             saleAmount: r == .qrisPayment ? 50_000 : nil, screen: "demo_tools",
                                             bucket: r == .streakCycle ? (pe.string(.incCycleBucket).uppercased() == "PENDING" ? "PENDING" : "ACTIVE") : nil,
                                             activation: pe.string(.incCycleActivation), force: true)
            if case .skipped = outcome { wallet.show(PointsToast(text: "Dilewati: aturan nonaktif atau 0 poin", kind: .info)) }
        }
    }

    private func display(_ v: Any?) -> String {
        switch v {
        case let d as Date: let f = DateFormatter(); f.dateFormat = "d MMM yyyy HH:mm"; return f.string(from: d)
        case let a as [String]: return a.isEmpty ? "[]" : a.joined(separator: ", ")
        case let b as Bool: return b ? "true" : "false"
        case let i as Int: return "\(i)"
        case let s as String: return s.isEmpty ? "(empty)" : s
        default: return "\(v ?? "nil")"
        }
    }

    /// Sample event properties so a manual fire looks like the real thing on the dashboard.
    private func sampleProps(_ e: CT.Event) -> [CT.EventProp: Any] {
        switch e {
        case .login: return [.persona: app.persona?.fullName ?? ""]
        case .appInstalled: return [.installSource: "AppsFlyer"]
        case .kycStepCompleted: return [.step: "ktp"]
        case .kycCompleted: return [.durationSeconds: 120, .method: "KTP+selfie"]
        case .topUpCompleted, .transferCompleted: return [.amount: 100_000, .isFirstTransaction: !app.bool(.hasTransacted)]
        case .qrisPaymentCompleted: return [.amount: 35_000, .isFirstTransaction: !app.bool(.hasTransacted), .isWorkday: AppState.isWorkday()]
        case .voucherViewed, .voucherRedeemed: return [.voucherId: "first_txn_15000"]
        case .billPaymentCompleted: return [.category: "PLN", .amount: 150_000]
        case .billReminderViewed: return [.category: "PLN", .daysLeft: 3]
        case .transportPaymentCompleted: return [.isWorkday: AppState.isWorkday(), .amount: 6_000]
        case .streakUpdated: return [.streakDays: max(1, app.int(.streakDays)), .targetDays: PEResolver.shared.streakTarget]
        case .streakRewardEarned: return [.reward: "loyalty_points", .points: PEResolver.shared.rewardPoints]
        case .walletCredited: return [.points: 50, .rule: "bill_payment", .orderId: "manual", .txnId: "manual_txn", .balanceAfter: wallet.points, .bucket: "ACTIVE"]
        case .walletDebited: return [.points: 100, .rule: "manual", .orderId: "manual", .txnId: "manual_txn", .balanceAfter: wallet.points]
        case .walletReversed: return [.type: "reverse", .txnId: "manual_txn", .rule: "bill_payment"]
        case .walletOperationFailed: return [.operation: "credit", .rule: "bill_payment", .errorCode: 777, .message: "manual"]
        case .payWithPointsUsed: return [.points: 100, .rupiahSaved: 1_000, .billAmount: 150_000]
        case .loyaltyPointsEarned, .loyaltyPointsRedeemed: return [.points: 50, .rule: "manual", .balanceAfter: wallet.points]
        case .streakStampEarned: return [.dayIndex: 1, .stampSymbol: "star.fill", .streakDays: 1, .isFinal: false]
        case .streakCycleCompleted: return [.cycleNumber: 1, .pointsAwarded: PEResolver.shared.rewardPoints]
        case .badgeEarned: return [.badgeLabel: PEResolver.shared.badgeLabel, .cyclesCompleted: PEResolver.shared.badgeCycles]
        case .promoViewed: return [.promoId: "pln_cashback", .category: "tagihan", .position: 1, .source: "persona"]
        case .promoClicked: return [.promoId: "pln_cashback", .category: "tagihan"]
        case .transactionCompleted: return [.amount: 50_000, .category: "qris"]
        case .churnOfferViewed, .churnOfferRedeemed: return [.offerId: "churn_10000"]
        case .winbackOfferRedeemed: return [.offerId: "winback_15000"]
        case .categoryUsed: return [.category: "qris"]
        case .newCategoryUsed: return [.category: "tagihan", .isFirstInCategory: true]
        case .offerVariantViewed: return [.variant: "hemat"]
        case .campaignViewed: return [.campaignId: "GAJIAN25"]
        case .promoCodeCopied: return [.code: "GAJIAN25"]
        case .promoCodeApplied: return [.code: "GAJIAN25", .discountPercent: 10, .maxDiscount: 25_000, .minTransaction: 100_000]
        case .promoCodeRedeemed: return [.code: "GAJIAN25", .amount: 150_000]
        default: return [:]
        }
    }
}
