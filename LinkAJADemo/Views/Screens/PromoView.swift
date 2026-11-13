import SwiftUI

struct PromoView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: DeepLinkRouter
    @EnvironmentObject var pe: PEResolver
    @ObservedObject private var wallet = LoyaltyWallet.shared
    @State private var code = ""
    @State private var amount = 150_000
    @State private var applied: PromoItem?
    @State private var error: String?
    @State private var voucher: PointsReward?
    @State private var redeeming: String?
    @State private var viewed = Set<String>()
    @State private var filter: String?

    private var english: Bool { app.language == "en" }
    private var config: PersonaConfig? { app.persona.flatMap { PersonaRegistry.config(for: $0.id) } }
    private var catalog: [PromoItem] { config?.promoCatalog ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    pointsHeader
                    if pe.promoCodeVisible { codeField }
                    if let p = applied { checkoutCard(p) }
                    if let f = featured { featuredCard(f) }
                    offerCards
                    promoList
                    pointsRewards
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Promo")
        }
        .onAppear {
            consumePrefill()
            viewed = []
            app.rec(.promoLayoutViewed, [.layout: pe.promoLayout])
            if app.local.paydayActive { app.rec(.campaignViewed, [.campaignId: "GAJIAN25"]) }
        }
        .onChange(of: router.promoCode) { _ in consumePrefill() }
    }

    private func consumePrefill() {
        if let c = router.promoCode { code = c; applied = nil; error = nil; router.promoCode = nil }
    }

    // MARK: Featured promo (persona value, replaced field by field from the dashboard)

    private struct Featured {
        let promo: PromoItem
        let title: String
        let subtitle: String
        let code: String
        let badge: String
        let deeplink: String?
        let source: String
    }

    private var featured: Featured? {
        guard pe.promoFeaturedVisible else { return nil }
        let t = pe.string(.promoFeaturedTitle), s = pe.string(.promoFeaturedSubtitle), c = pe.string(.promoFeaturedCode)
        let b = pe.string(.promoFeaturedBadge), d = pe.string(.promoFeaturedDeeplink)
        guard let base = catalog.first ?? (t.isEmpty ? nil : PromoItem(id: "featured", title: t, code: c, category: "qris")) else { return nil }
        let useCode = c.isEmpty ? base.code : c.uppercased()
        let fromDash = [t, s, c, b, d].contains { !$0.isEmpty }
        var promo = base
        if !c.isEmpty && c.uppercased() != base.code {
            promo = PromoItem(id: "featured_dashboard", title: t.isEmpty ? base.title : t, code: useCode, category: base.category,
                              maxDiscount: 25_000, percent: 10, image: base.image, fromDashboard: true)
        }
        return Featured(promo: promo, title: t.isEmpty ? base.title : t,
                        subtitle: s.isEmpty ? base.benefit(!english) : s, code: useCode,
                        badge: b.isEmpty ? app.t("Pilihan utama", "Top pick") : b,
                        deeplink: d.isEmpty ? nil : d, source: fromDash ? "dashboard" : "persona")
    }

    // MARK: List order

    private var orderedPromos: [PromoItem] {
        let order = pe.promoListOrder
        if !order.isEmpty {
            var seen = Set<String>()
            return order.compactMap { id in catalog.first { $0.id == id } }.filter { seen.insert($0.id).inserted }
        }
        let rest = catalog.filter { $0.id != catalog.first?.id }
        let first = rest.filter { $0.category == pe.promoFeatured }
        return first + rest.filter { $0.category != pe.promoFeatured }
    }

    private var listSource: String { pe.promoListOrder.isEmpty ? "persona" : "dashboard" }

    // MARK: Points header and rewards

    @ViewBuilder private var pointsHeader: some View {
        if pe.loyaltyEnabled {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pe.loyaltyLabel(english: english)).font(.caption).foregroundStyle(.secondary)
                    Text(Fmt.num(wallet.points)).font(.title.bold())
                    if wallet.pendingPoints > 0 {
                        Text(app.t("\(wallet.pendingPoints) menunggu aktif", "\(wallet.pendingPoints) pending")).font(.caption2).foregroundStyle(Theme.secondary)
                    }
                }
                Spacer()
                PointsChip()
            }
            .card()
        }
    }

    @ViewBuilder private var pointsRewards: some View {
        if pe.loyaltyEnabled, pe.loyaltyCatalogVisible, let rewards = config?.rewards, !rewards.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(app.t("Tukar \(pe.loyaltyLabel(english: false))", "Redeem \(pe.loyaltyLabel(english: true))")).font(.headline)
                if let v = voucher { voucherCard(v) }
                ForEach(rewards) { r in
                    let missing = r.points - wallet.points
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.title).font(.subheadline.bold())
                            Text("\(r.points) " + pe.loyaltyLabel(english: english)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            redeeming = r.id
                            Task { @MainActor in
                                if await app.redeemReward(r) { voucher = r }
                                redeeming = nil
                            }
                        } label: {
                            Text(missing > 0 ? app.t("Kurang \(missing)", "\(missing) short") : app.t("Tukar", "Redeem"))
                                .font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 7)
                                .background(missing > 0 ? Color.gray.opacity(0.3) : Theme.red)
                                .foregroundStyle(missing > 0 ? Color.secondary : Color.white).clipShape(Capsule())
                        }
                        .disabled(missing > 0 || redeeming != nil)
                    }
                    .card(padding: 12)
                }
            }
        }
    }

    private func voucherCard(_ r: PointsReward) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "ticket.fill").font(.title).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.title).font(.subheadline.bold())
                Text(app.t("Voucher aktif. Kode: ", "Voucher active. Code: ") + "LJ" + String(r.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 100000 }))
                    .font(.caption.monospaced())
            }
            Spacer()
            Button { voucher = nil } label: { Image(systemName: "xmark.circle.fill") }
        }
        .foregroundStyle(.white).padding(14)
        .background(LinearGradient(colors: [.green, Color(red: 0.1, green: 0.5, blue: 0.3)], startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    // MARK: Promo code

    private var codeField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(app.t("Punya kode promo?", "Have a promo code?")).font(.headline)
            HStack {
                TextField(app.t("Masukkan kode", "Enter code"), text: $code)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .padding(12).background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 10))
                Button(app.t("Terapkan", "Apply")) { apply(code) }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.cta).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(code.isEmpty)
            }
            if let error { Text(error).font(.caption).foregroundStyle(Theme.bad) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func promo(forCode c: String) -> PromoItem? {
        let up = c.trimmingCharacters(in: .whitespaces).uppercased()
        if let p = catalog.first(where: { $0.code == up }) { return p }
        if let f = featured, f.code == up { return f.promo }
        return nil
    }

    private func apply(_ c: String) {
        error = nil
        guard let p = promo(forCode: c) else {
            applied = nil
            error = app.t("Kode tidak valid", "Invalid code"); return
        }
        applied = p
        code = p.code
        app.rec(.promoCodeApplied, [.code: p.code, .discountPercent: p.percent ?? 0, .maxDiscount: p.maxDiscount ?? 0,
                                    .minTransaction: p.minTransaction])
    }

    /// Mock checkout for the applied promo. Validates the minimum transaction and the maximum discount.
    private func checkoutCard(_ p: PromoItem) -> some View {
        let cashback = p.cashback(for: amount)
        return VStack(alignment: .leading, spacing: 8) {
            Text(app.t("Simulasi checkout: ", "Checkout simulation: ") + p.code).font(.subheadline.bold())
            AmountChips(amount: $amount, options: [75_000, 150_000, 300_000])
            Text(amount < p.minTransaction
                 ? app.t("Min. transaksi \(Fmt.rp(p.minTransaction))", "Min transaction \(Fmt.rp(p.minTransaction))")
                 : app.t("Cashback kamu: ", "Your cashback: ") + Fmt.rp(cashback))
                .font(.footnote).foregroundStyle(amount < p.minTransaction ? .red : .green)
            PrimaryButton(title: app.t("Bayar dengan kode", "Pay with code"),
                          enabled: amount >= p.minTransaction && amount <= app.balance) { redeem(p) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func txnKind(_ p: PromoItem) -> TxnKind {
        switch p.category {
        case "tagihan": return .bill("PLN")
        case "pulsa": return .bill("pulsa")
        case "transport": return .transport
        case "transfer": return .transfer
        case "topup": return .topUp
        default: return .qris
        }
    }

    private func redeem(_ p: PromoItem) {
        let cashback = p.cashback(for: amount)
        app.complete(txnKind(p), amount: amount, title: "\(txnKind(p).label) + \(p.code)")
        app.rec(.promoCodeRedeemed, [.code: p.code, .amount: amount, .campaignId: p.code])
        var ids = app.list(.redeemedCampaignIds)
        if !ids.contains(p.code) { ids.append(p.code) }
        app.set([.walletBalance: app.balance + cashback, .redeemedCampaignIds: ids, .lastCampaignId: p.code])
        app.awardPromoRedeemed(code: p.code, promoId: p.id)
        app.showToast(app.t("Cashback \(Fmt.rp(cashback)) diterima", "\(Fmt.rp(cashback)) cashback received"))
        applied = nil; code = ""
    }

    // MARK: Promo cards

    private func expiry(_ p: PromoItem) -> String {
        let d = p.daysLeft()
        return app.t("Sisa \(d) hari", "\(d) days left")
    }

    private func copy(_ p: PromoItem, code c: String) {
        UIPasteboard.general.string = c
        app.rec(.promoCodeCopied, [.code: c])
        app.showToast(app.t("Kode disalin", "Code copied"))
    }

    private func use(_ p: PromoItem, code c: String, deeplink: String? = nil) {
        app.rec(.promoClicked, [.promoId: p.id, .category: p.category])
        if let d = deeplink, let url = URL(string: d) { router.handle(url); return }
        apply(c)
    }

    private func promoImage(_ name: String) -> some View {
        Group {
            if UIImage(named: name) != nil { Image(name).resizable().scaledToFit() }
            else { Image(systemName: "tag.fill").resizable().scaledToFit().padding(20).foregroundStyle(.white.opacity(0.8)) }
        }
    }

    private func featuredCard(_ f: Featured) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(f.title).font(.title3.bold())
                Spacer()
                Chip(text: f.badge, color: .white)
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(f.subtitle).font(.caption)
                    Text(expiry(f.promo)).font(.caption2).opacity(0.9)
                }
                Spacer()
                PIcon(symbol: f.promo.category == "tagihan" ? "bolt" : (f.promo.category == "qris" ? "qrcode" : "tag"), size: 52)
            }
            HStack {
                Text(f.code).font(.title3.monospaced().bold()).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
                Button { copy(f.promo, code: f.code) } label: { Label(app.t("Salin", "Copy"), systemImage: "doc.on.doc").font(.subheadline.bold()) }
                Button(app.t("Pakai", "Use")) { use(f.promo, code: f.code, deeplink: f.deeplink) }
                    .font(.subheadline.bold()).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.white).foregroundStyle(Theme.red).clipShape(Capsule())
            }
        }
        .foregroundStyle(.white).padding(16)
        .background(Theme.gradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .onAppear { logViewed(f.promo.id, f.promo.category, 1, f.source) }
    }

    private func logViewed(_ id: String, _ category: String, _ position: Int, _ source: String) {
        guard viewed.insert(id).inserted else { return }
        app.rec(.promoViewed, [.promoId: id, .category: category, .position: position, .source: source])
    }

    private func promoCard(_ p: PromoItem, position: Int, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Theme.gradient
                promoImage(p.image).padding(6)
            }
            .frame(height: compact ? 70 : 90)
            .clipShape(RoundedRectangle(cornerRadius: max(Theme.radius - 6, 6)))
            Text(p.title).font(.subheadline.bold()).lineLimit(2).frame(minHeight: 36, alignment: .topLeading)
            Text(p.benefit(!english)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 6) {
                Text(p.code).font(.caption.monospaced().bold()).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.red.opacity(0.1)).foregroundStyle(Theme.red).clipShape(RoundedRectangle(cornerRadius: 6))
                Button { copy(p, code: p.code) } label: { Image(systemName: "doc.on.doc").font(.caption) }
            }
            HStack {
                Text(expiry(p)).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button(app.t("Pakai", "Use")) { use(p, code: p.code) }
                    .font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.cta).foregroundStyle(.white).clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card(padding: 12)
        .onAppear { logViewed(p.id, p.category, position, listSource) }
    }

    private var filterChips: some View {
        let cats = ["tagihan", "transport", "pulsa"].filter { c in catalog.contains { $0.category == c } }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, app.t("Semua", "All"))
                ForEach(cats, id: \.self) { c in chip(c, c.capitalized) }
            }
        }
    }

    private func chip(_ value: String?, _ title: String) -> some View {
        Button { filter = value } label: {
            Text(title).font(.caption.bold()).padding(.horizontal, 14).padding(.vertical, 7)
                .background(filter == value ? Theme.accent : Theme.accent.opacity(0.10), in: Capsule())
                .foregroundStyle(filter == value ? Color.white : Theme.accent)
        }
    }

    private var merchantStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(app.t("Merchant favorit", "Favorite merchants")).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(["Warung Bu Tini", "Kopi Kenangan", "Indomaret", "Kantin Kampus"].enumerated()), id: \.offset) { i, m in
                        VStack(spacing: 6) {
                            PIcon(symbol: "storefront", tint: i, size: 54)
                            Text(m).font(.caption2.weight(.semibold)).lineLimit(1)
                        }
                        .frame(width: 78)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var promoList: some View {
        let promos = orderedPromos.filter { filter == nil || $0.category == filter }
        return VStack(alignment: .leading, spacing: Theme.spacing) {
            if pe.promoLayout == "grid" {
                merchantStrip
                Text(app.t("Promo untukmu", "Promos for you")).font(.headline)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)], spacing: 10) {
                    ForEach(Array(promos.enumerated()), id: \.element.id) { i, p in promoCard(p, position: i + 2, compact: true) }
                }
            } else {
                // "carousel" renders as a vertical list with category filters on this tab.
                Text(app.t("Promo untukmu", "Promos for you")).font(.headline)
                filterChips
                ForEach(Array(promos.enumerated()), id: \.element.id) { i, p in promoRow(p, position: i + 2) }
            }
        }
    }

    private func promoRow(_ p: PromoItem, position: Int) -> some View {
        HStack(spacing: 12) {
            PIcon(symbol: p.category == "tagihan" ? "bolt" : (p.category == "transport" ? "tram" : (p.category == "pulsa" ? "iphone" : "tag")), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(p.benefit(!english)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    Text(p.code).font(.caption.monospaced().bold()).foregroundStyle(Theme.accent)
                    Button { copy(p, code: p.code) } label: { Image(systemName: "doc.on.doc").font(.caption2) }
                    Text(expiry(p)).font(.caption2).foregroundStyle(Theme.secondary)
                }
            }
            Spacer(minLength: 4)
            Button(app.t("Pakai", "Use")) { use(p, code: p.code) }
                .font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.cta).foregroundStyle(.white).clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
        .onAppear { logViewed(p.id, p.category, position, listSource) }
    }

    // MARK: Other offers

    @ViewBuilder private var offerCards: some View {
        if app.local.voucherOnboardingIssued && !app.local.voucherOnboardingRedeemed {
            offer(title: app.t("Voucher Verifikasi Rp10.000", "Verification Voucher Rp10,000"),
                  body: app.t("Saldo Rp10.000 setelah top-up min. Rp50.000. Berlaku 7 hari.", "Rp10,000 balance after a min Rp50,000 top-up. Valid 7 days."),
                  badge: "Voucher", cta: app.t("Klaim", "Claim")) { app.redeemOnboardingVoucher() }
                .onAppear { app.viewVoucher("onboarding_10000") }
        }
        if app.local.voucher15IssuedAt != nil && !app.local.voucher15Redeemed && app.voucher15DaysLeft > 0 {
            offer(title: app.t("Voucher Transaksi Pertama Rp15.000", "First Transaction Voucher Rp15,000"),
                  body: app.t("Bayar QRIS pertamamu dan dapat Rp15.000.", "Make your first QRIS payment and get Rp15,000."),
                  badge: app.t("Sisa \(app.voucher15DaysLeft) hari", "\(app.voucher15DaysLeft) days left"),
                  cta: app.t("Pakai Sekarang", "Use Now")) { router.tab = .scan }
                .onAppear { app.viewVoucher("first_txn_15000") }
        }
        if app.int(.habitProgressCurrent) > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text(app.t("Cashback Rp10.000 di transaksi ke-3", "Rp10,000 cashback on the 3rd transaction")).font(.headline)
                ProgressBar(value: Double(app.int(.habitProgressCurrent)) / Double(max(1, app.int(.habitProgressTarget))))
                Text("\(app.int(.habitProgressCurrent)) " + app.t("dari", "of") + " \(app.int(.habitProgressTarget)) " + app.t("transaksi dalam 30 hari", "transactions in 30 days"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).card()
        }
        if pe.streakEnabled {
            let target = pe.streakTarget
            offer(title: app.t("Streak Komuter", "Commuter Streak"),
                  body: app.t("\(target) hari kerja: +\(pe.rewardPoints) \(pe.loyaltyLabel(english: false)). \(pe.badgeCycles) siklus: badge \(pe.badgeLabel) plus bonus.",
                              "\(target) workdays: +\(pe.rewardPoints) \(pe.loyaltyLabel(english: true)). \(pe.badgeCycles) cycles: \(pe.badgeLabel) badge plus bonus."),
                  badge: "\(min(app.int(.streakDays), target))/\(target)", cta: app.t("Lihat Progres", "View Progress")) { router.sheet = .streak }
        }
        if app.showChurnOffer {
            offer(title: app.t("Kami kangen kamu", "We miss you"),
                  body: app.t("Cashback Rp10.000 untuk 1 transaksi dalam 7 hari.", "Rp10,000 cashback for 1 transaction within 7 days."),
                  badge: "Churn", cta: app.t("Gunakan (simulasi)", "Redeem (simulated)")) { app.redeemChurnOffer() }
                .onAppear { app.viewChurnOffer() }
        }
        if app.showWinbackOffer {
            offer(title: app.t("Saldo \(Fmt.rp(app.balance)) masih nunggu", "Your \(Fmt.rp(app.balance)) balance is waiting"),
                  body: app.t("Cashback Rp15.000 jika transaksi dalam 7 hari.", "Rp15,000 cashback if you transact within 7 days."),
                  badge: "Win-back", cta: app.t("Gunakan (simulasi)", "Redeem (simulated)")) { app.redeemWinback() }
        }
    }

    private func offer(title: String, body: String, badge: String, cta: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.headline); Spacer(); Chip(text: badge) }
            Text(body).font(.subheadline).foregroundStyle(.secondary)
            SecondaryButton(title: cta, action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }
}
