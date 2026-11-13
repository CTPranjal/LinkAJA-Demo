import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: DeepLinkRouter
    @EnvironmentObject var pe: PEResolver
    @EnvironmentObject var theme: ThemeProvider
    @State private var hideBalance = false
    @AppStorage("ljd_remind_pln") private var remindPLN = true

    private var english: Bool { app.language == "en" }
    private var config: PersonaConfig? { pe.persona }

    // MARK: Quick actions

    private struct Action { let idID: String, en: String, symbol: String, go: () -> Void }

    private func action(_ t: QuickActionToken) -> Action {
        switch t {
        case .kirim: return Action(idID: "Kirim", en: "Send", symbol: "paperplane") { router.sheet = .transfer }
        case .terima: return Action(idID: "Terima", en: "Receive", symbol: "tray.and.arrow.down") { router.sheet = .receive }
        case .qris: return Action(idID: "QRIS", en: "QRIS", symbol: "qrcode") { router.tab = .scan }
        case .topup: return Action(idID: "Top Up", en: "Top Up", symbol: "creditcard") { router.sheet = .topUp }
        case .pulsa: return Action(idID: "Pulsa", en: "Pulsa", symbol: "iphone") { router.sheet = .pulsa }
        case .tagihan: return Action(idID: "Tagihan", en: "Bills", symbol: "doc.text") { router.sheet = .bill }
        case .transport: return Action(idID: "Transport", en: "Transport", symbol: "tram") { router.sheet = .transport }
        case .donasi: return Action(idID: "Donasi", en: "Donate", symbol: "heart") { router.sheet = .donasi }
        }
    }

    // MARK: Body

    var body: some View {
        let p = Theme.persona
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: p.spacing) {
                    ForEach(p.homeModules) { m in module(m).id(m) }
                }
                .padding(.bottom, 24)
            }
            .onAppear {
                // Screenshot harness: scroll down to the promo block.
                guard CommandLine.arguments.contains("-scrolled") else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    proxy.scrollTo(p.compact ? HomeModule.trip : HomeModule.sales, anchor: .top)
                }
            }
        }
        .background(Theme.bg)
        .ignoresSafeArea(edges: .top)
        .refreshable {
            await PEStore.shared.refresh()
            await LoyaltyWallet.shared.refreshBalance()
        }
    }

    @ViewBuilder private func module(_ m: HomeModule) -> some View {
        switch m {
        case .header: header
        case .balance:
            balanceCard.padding(.horizontal, 16).padding(.top, -(Theme.spacing + 44)).zIndex(1)
        case .dueBill: padded(dueBillCard)
        case .quickActions: padded(quickActions)
        case .trip: padded(tripCard)
        case .hero: if pe.heroVisible { padded(heroBanner) }
        case .paydayBanner: if app.local.paydayActive { padded(paydayBanner) }
        case .promoCarousel: promoCarousel
        case .crossSell: if pe.crossVisible { padded(crossSellCard) }
        case .qrisEducation: if pe.qrisEducationTile { padded(qrisEducation) }
        case .activityList: padded(activityList)
        case .scanButton: padded(scanButton)
        case .sales: padded(salesWidget)
        case .verifyCard: if app.str(.kycStatus) == "pending" { padded(verifyCard) }
        case .promoGrid: padded(promoGrid)
        case .streakQris: if pe.streakEnabled { padded(streakCard) }
        case .activityCards: padded(activityCards)
        }
    }

    private func padded<V: View>(_ v: V) -> some View { v.padding(.horizontal, 16) }

    // MARK: Header and balance

    private var header: some View {
        let p = Theme.persona
        return VStack(alignment: .leading, spacing: p.spacing) {
            HStack {
                Image("img_logo_white").resizable().scaledToFit().frame(height: 26)
                Spacer()
                Button { if app.str(.kycStatus) == "pending" { router.sheet = .kyc } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: app.str(.kycStatus) == "completed" ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                        Text(app.str(.kycStatus) == "completed" ? app.t("Terverifikasi", "Verified") : app.t("Belum terverifikasi", "Unverified"))
                    }
                    .font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: Capsule()).foregroundStyle(.white)
                }
            }
            HStack(spacing: 12) {
                if let id = app.persona?.id { PersonaAvatar(personaID: id, size: p.compact ? 44 : 56).overlay(Circle().stroke(.white, lineWidth: 2)) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.t("Hi, \(app.firstName)", "Hi, \(app.firstName)")).font(.system(size: p.compact ? 22 : 28, weight: .bold)).foregroundStyle(.white)
                    if let tag = config?.tagline { Text(tag).font(.caption).foregroundStyle(.white.opacity(0.92)) }
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 64).padding(.bottom, 64)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gradient)
    }

    private var balanceCard: some View {
        let p = Theme.persona
        return VStack(alignment: .leading, spacing: p.compact ? 8 : 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.t("SALDO", "BALANCE")).font(.caption2.weight(.bold)).foregroundStyle(.secondary).tracking(0.8)
                    Text(hideBalance ? "Rp ••••••" : Fmt.rp(app.balance))
                        .font(.system(size: p.balanceFontSize, weight: .bold, design: p.fontDesign))
                }
                Spacer()
                Button { hideBalance.toggle() } label: {
                    Image(systemName: hideBalance ? "eye.slash" : "eye").foregroundStyle(Theme.accent)
                }
            }
            HStack {
                PointsChip()
                Spacer()
                if pe.showTopupCTA {
                    Button { router.sheet = .topUp } label: {
                        Text(pe.topupCTAText).font(.subheadline.bold()).padding(.horizontal, 16).padding(.vertical, p.compact ? 7 : 10)
                            .background(Theme.cta).foregroundStyle(.white).clipShape(Capsule())
                    }
                }
            }
        }
        .card()
    }

    // MARK: Budi modules

    private var dueBillCard: some View {
        let bill = config?.dueBills.first
        return HStack(spacing: 0) {
            Theme.secondary.frame(width: 5)
            VStack(alignment: .leading, spacing: 8) {
                Text(app.t("PERLU DIBAYAR", "DUE SOON")).font(.caption2.weight(.bold)).foregroundStyle(.secondary).tracking(0.8)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill?.title ?? "PLN listrik").font(.headline)
                        Text(app.t("Jatuh tempo \(bill?.dueInDays ?? 3) hari lagi", "Due in \(bill?.dueInDays ?? 3) days"))
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    Text(Fmt.rp(bill?.amount ?? 387_500)).font(.headline)
                }
                HStack {
                    Toggle(app.t("Atur pengingat", "Remind me"), isOn: $remindPLN).font(.caption).toggleStyle(.switch).labelsHidden()
                    Text(app.t("Atur pengingat", "Remind me")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { router.sheet = .bill } label: {
                        Text(app.t("Bayar", "Pay")).font(.subheadline.bold()).padding(.horizontal, 22).padding(.vertical, 7)
                            .background(Theme.cta).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: max(Theme.radius - 4, 4)))
                    }
                }
            }
            .padding(Theme.persona.rowPadding)
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay { if let b = Theme.persona.border { RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(b, lineWidth: 1) } }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .shadow(color: Theme.persona.shadow, radius: Theme.persona.shadowRadius, y: 1)
    }

    private var tripCard: some View {
        let target = pe.streakTarget
        let streak = min(app.int(.streakDays), target)
        return VStack(alignment: .leading, spacing: 10) {
            Button { router.sheet = .streak } label: {
                HStack {
                    Text(app.t("PERJALANAN HARI INI", "TODAY'S TRIPS")).font(.caption2.weight(.bold)).foregroundStyle(.secondary).tracking(0.8)
                    Spacer()
                    Chip(text: "\(streak)/\(target) \(pe.streakChip(english: english))", color: Theme.secondary)
                }
            }
            .buttonStyle(.plain)
            stampRow(streak: streak, target: target)
            Divider()
            HStack(spacing: 10) {
                PIcon(symbol: "tram", size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("KRL Commuter Line").font(.subheadline.weight(.semibold))
                    Text("07.42").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.rp(7_000)).font(.subheadline.weight(.semibold))
            }
            Button {
                app.complete(.transport, amount: 7_000, title: "KRL Commuter Line")
            } label: {
                Label(app.t("Bayar Transport", "Pay Transport"), systemImage: "tram.fill").font(.caption.bold())
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.accent.opacity(0.12)).foregroundStyle(Theme.accent).clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func stampRow(streak: Int, target: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<target, id: \.self) { i in
                StampSlot(earned: i < streak,
                          symbol: StampSets.symbol(set: pe.stampSet, index: i, target: target, finalSymbol: pe.stampFinalSymbol),
                          color: pe.stampColor, label: app.t("H\(i + 1)", "D\(i + 1)"), tilt: i % 2 == 0 ? -6 : 5, animated: false)
            }
        }
    }

    private var promoCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(app.t("Promo untukmu", "Promos for you")).font(.headline)
                Spacer()
                Button(app.t("Lihat semua", "See all")) { router.tab = .promo }.font(.caption.bold())
            }
            .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacing) {
                    ForEach(config?.promoCatalog ?? []) { promoTile($0).frame(width: 210) }
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
            }
        }
    }

    private func promoTile(_ promo: PromoItem) -> some View {
        Button { router.tab = .promo } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PIcon(symbol: promoSymbol(promo.category), tint: promo.category == "qris" ? 0 : 1, size: 34)
                    Spacer()
                    Chip(text: promo.category.uppercased(), color: Theme.secondary)
                }
                Text(promo.title).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                    .frame(minHeight: 36, alignment: .topLeading)
                Text(promo.code).font(.caption.monospaced().bold()).foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading).card()
        }
        .buttonStyle(.plain)
    }

    private func promoSymbol(_ c: String) -> String {
        switch c {
        case "tagihan": return "bolt"
        case "transport": return "tram"
        case "pulsa": return "iphone"
        case "qris": return "qrcode"
        case "transfer": return "paperplane"
        case "topup": return "cart"
        default: return "tag"
        }
    }

    private var activityList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(app.t("AKTIVITAS TERBARU", "RECENT ACTIVITY")).font(.caption2.weight(.bold)).foregroundStyle(.secondary).tracking(0.8)
                .padding(.bottom, 8)
            ForEach(Array(app.local.activity.prefix(4).enumerated()), id: \.element.id) { i, a in
                if i > 0 { Divider() }
                HStack(spacing: 10) {
                    PIcon(symbol: activitySymbol(a.title), size: 32)
                    Text(a.title).font(.subheadline)
                    Spacer()
                    Text((a.amount > 0 ? "+" : "-") + Fmt.rp(abs(a.amount))).font(.subheadline.weight(.semibold))
                        .foregroundStyle(a.amount > 0 ? Theme.good : Color.primary)
                }
                .padding(.vertical, 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private var activityCards: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(app.t("Aktivitas terbaru", "Recent activity")).font(.headline)
            ForEach(Array(app.local.activity.prefix(4).enumerated()), id: \.element.id) { i, a in
                HStack(spacing: 14) {
                    PIcon(symbol: activitySymbol(a.title), tint: i, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.title).font(.subheadline.weight(.semibold))
                        Text(app.t("Hari ini", "Today")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text((a.amount > 0 ? "+" : "-") + Fmt.rp(abs(a.amount))).font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(a.amount > 0 ? Theme.good : Color.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).card()
            }
        }
    }

    private func activitySymbol(_ title: String) -> String {
        let t = title.lowercased()
        if t.contains("pln") { return "bolt" }
        if t.contains("krl") || t.contains("transport") || t.contains("mrt") { return "tram" }
        if t.contains("pulsa") || t.contains("telkomsel") { return "iphone" }
        if t.contains("indihome") { return "wifi" }
        if t.contains("warung") || t.contains("makan") { return "fork.knife" }
        if t.contains("kantin") { return "cup.and.saucer" }
        if t.contains("transfer") || t.contains("kirim") || t.contains("sent") { return "paperplane" }
        if t.contains("top up") { return "plus.circle" }
        if t.contains("qris") { return "qrcode" }
        return "creditcard"
    }

    // MARK: Siti modules

    private var scanButton: some View {
        Button { router.tab = .scan } label: {
            HStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder").font(.system(size: 30, weight: .semibold))
                Text("Scan QRIS").font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 64)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: Theme.persona.shadow, radius: 10, y: 5)
        }
    }

    private var salesWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(app.t("Penjualan hari ini", "Today's sales")).font(.headline)
                Spacer()
                Chip(text: app.t("12 transaksi", "12 transactions"), color: Theme.secondary)
            }
            Text(Fmt.rp(TokoData.todaySales)).font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
            MiniBarChart(values: TokoData.week, labels: TokoData.dayLabels(english: english), color: Theme.accent)
            SecondaryButton(title: app.t("Tampilkan QR Toko", "Show shop QR"), icon: "qrcode") { router.sheet = .receive }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private var verifyCard: some View {
        Button { router.sheet = .kyc } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.t("Verifikasi cuma 2 menit", "Verification takes 2 minutes")).font(.headline)
                    Text(app.t("dapat voucher Rp10.000", "get a Rp10,000 voucher")).font(.subheadline).opacity(0.95)
                }
                Spacer()
                Image(systemName: "chevron.right").fontWeight(.bold)
            }
            .foregroundStyle(.white).padding(Theme.persona.rowPadding)
            .background(Theme.secondary, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: Theme.secondary.opacity(0.35), radius: 10, y: 5)
        }
    }

    private var promoGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(app.t("Promo untukmu", "Promos for you")).font(.headline)
                Spacer()
                Button(app.t("Lihat semua", "See all")) { router.tab = .promo }.font(.caption.bold())
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.spacing, alignment: .top),
                                GridItem(.flexible(), spacing: Theme.spacing, alignment: .top)], spacing: Theme.spacing) {
                ForEach(config?.promoCatalog ?? []) { promoTile($0) }
            }
        }
    }

    private var streakCard: some View {
        let target = pe.streakTarget
        let shown = min(app.int(.streakDays), target)
        return Button { router.sheet = .streak } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(app.t("Streak QRIS", "QRIS Streak")).font(.headline)
                    Spacer()
                    Chip(text: "\(shown)/\(target) \(pe.streakChip(english: english))", color: pe.stampColor)
                }
                stampRow(streak: shown, target: target)
                Text(app.t("Bayar QRIS tiap hari kerja, dapat +\(pe.rewardPoints) \(pe.loyaltyLabel(english: false)) di akhir siklus",
                           "Pay with QRIS every workday, earn +\(pe.rewardPoints) \(pe.loyaltyLabel(english: true)) at the end of the cycle"))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            .foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading).card()
        }
    }

    // MARK: Shared modules

    private var quickActions: some View {
        let p = Theme.persona
        let order = pe.quickActionOrder
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .top), count: 4)
        return LazyVGrid(columns: cols, spacing: p.compact ? 12 : 20) {
            ForEach(Array(order.enumerated()), id: \.element) { index, token in
                let a = action(token)
                let highlighted = pe.quickActionHighlight == token
                Button {
                    app.rec(.quickActionClicked, [.action: token.rawValue, .position: index + 1, .isHighlighted: highlighted])
                    a.go()
                } label: {
                    VStack(spacing: 6) {
                        PIcon(symbol: a.symbol, tint: index, size: p.compact ? 44 : 58)
                            .overlay(alignment: .topTrailing) {
                                if highlighted {
                                    Circle().fill(Theme.cta).frame(width: 12, height: 12).overlay(Circle().stroke(Theme.card, lineWidth: 2))
                                }
                            }
                        Text(app.t(a.idID, a.en)).font(.caption2.weight(highlighted ? .bold : .medium))
                            .foregroundStyle(highlighted ? Theme.accent : .primary).multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, p.compact ? 0 : 6)
        .card()
    }

    private var heroBanner: some View {
        ZStack(alignment: .leading) {
            Theme.gradient
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pe.heroTitle).font(.title3.bold())
                    Text(pe.heroSubtitle).font(.caption).opacity(0.92)
                    Button { tapHero() } label: {
                        Text(pe.heroCTAText).font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 7)
                            .background(.white).foregroundStyle(Theme.accent).clipShape(Capsule())
                    }
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
                HeroImage(source: pe.heroImage).frame(width: 100, height: 110)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .onAppear {
            app.rec(.homeBannerViewed, [.variant: CleverTapManager.shared.experimentVariant, .title: pe.heroTitle, .deeplink: pe.heroDeeplink])
        }
    }

    private func tapHero() {
        app.rec(.homeBannerClicked, [.variant: CleverTapManager.shared.experimentVariant, .title: pe.heroTitle, .deeplink: pe.heroDeeplink])
        if let url = URL(string: pe.heroDeeplink) { router.handle(url) }
    }

    private var crossSellCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pe.crossTitle).font(.headline).foregroundStyle(.primary)
                Spacer()
                Chip(text: pe.crossVariant == "hemat" ? "Hemat" : "Praktis", color: Theme.secondary)
            }
            if pe.crossVariant == "hemat" {
                Label(app.t("Cashback \(Fmt.rp(pe.crossCashback)) di transaksi pertama", "\(Fmt.rp(pe.crossCashback)) cashback on your first transaction"),
                      systemImage: "gift.fill").font(.subheadline).foregroundStyle(Theme.good)
            } else {
                Label(app.t("Bayar langsung dengan 1-tap bayar", "Pay instantly with 1-tap bayar"),
                      systemImage: "hand.tap.fill").font(.subheadline).foregroundStyle(Theme.accent)
            }
            SecondaryButton(title: pe.crossVariant == "praktis" ? "\(pe.crossCTA) (1-tap bayar)" : pe.crossCTA) { tapCrossSell() }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
        .onAppear { app.rec(.crossSellCardViewed, [.category: pe.crossCategory, .variant: pe.crossVariant]) }
    }

    private func tapCrossSell() {
        app.rec(.crossSellCardClicked, [.category: pe.crossCategory, .variant: pe.crossVariant])
        switch pe.crossCategory {
        case "tagihan": router.sheet = .bill
        case "pulsa": router.sheet = .pulsa
        case "transport": router.sheet = .transport
        case "donasi", "zakat": router.sheet = .donasi
        case "qris": router.tab = .scan
        default: router.sheet = .bill
        }
    }

    private var qrisEducation: some View {
        Button { router.tab = .scan } label: {
            HStack(spacing: 12) {
                PIcon(symbol: "qrcode", size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cara bayar QRIS").font(.subheadline.bold())
                    Text(app.t("Scan, cek nominal, bayar. Gampang!", "Scan, check the amount, pay. Easy!")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary).card()
        }
    }

    private var paydayBanner: some View {
        Button { router.tab = .promo } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gajian Deals!").font(.headline)
                    Text(app.t("Pakai kode GAJIAN25, cashback 10%", "Use code GAJIAN25 for 10% cashback")).font(.caption)
                }
                Spacer()
                Chip(text: "GAJIAN25", color: .white)
            }
            .foregroundStyle(.white).padding(16)
            .background(Theme.gradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        }
    }
}

/// Hero image: a remote URL when the variable holds one, otherwise a bundled asset name.
/// Falls back to the default bundled asset when loading fails or the name is unknown.
struct HeroImage: View {
    let source: String
    private var fallbackName: String {
        if case .string(let d) = PEKeys.heroImageURL.defaultValue { return d }
        return "img_banner_home"
    }

    var body: some View {
        if source.lowercased().hasPrefix("http"), let url = URL(string: source) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                case .failure: Image(fallbackName).resizable().scaledToFit()
                default: ProgressView().tint(.white)
                }
            }
        } else if UIImage(named: source) != nil {
            Image(source).resizable().scaledToFit()
        } else {
            Image(fallbackName).resizable().scaledToFit()
        }
    }
}
