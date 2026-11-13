import SwiftUI

// MARK: Top Up

struct TopUpView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var pe: PEResolver
    @State private var amount = PEResolver.shared.topupDefault
    @State private var done = false
    @State private var method = ""
    @State private var paymentId: String?

    private var selected: String {
        if !method.isEmpty { return method }
        let list = pe.topupMethods
        return list.contains(pe.topupMethodHighlight) ? pe.topupMethodHighlight : (list.first ?? "bank_va")
    }

    private func methodName(_ m: String) -> String {
        switch m {
        case "bank_va": return app.t("Transfer Bank (Virtual Account)", "Bank Transfer (Virtual Account)")
        case "atm": return "ATM"
        case "debit_card": return app.t("Kartu Debit", "Debit Card")
        default: return app.t("Minimarket (Indomaret, Alfamart)", "Convenience Store (Indomaret, Alfamart)")
        }
    }

    private func methodIcon(_ m: String) -> String {
        switch m {
        case "bank_va": return "building.columns.fill"
        case "atm": return "creditcard.and.123"
        case "debit_card": return "creditcard.fill"
        default: return "cart.fill"
        }
    }

    private var bonusApplies: Bool { pe.bonusEnabled && amount >= pe.bonusMin }

    var body: some View {
        ScreenContainer(title: "Top Up") {
            Form {
                if pe.bonusEnabled {
                    Section {
                        Label(pe.bonusBanner, systemImage: "gift.fill").font(.subheadline.bold()).foregroundStyle(Theme.red)
                    }
                }
                Section(app.t("Nominal", "Amount")) {
                    AmountChips(amount: $amount, options: pe.topupAmounts) { v in
                        app.rec(.topUpAmountSelected, [.amount: v, .isSuggested: true,
                                                       .bonusApplied: pe.bonusEnabled && v >= pe.bonusMin])
                    }
                    if bonusApplies {
                        Text(app.t("Bonus \(Fmt.rp(pe.bonusAmount)) akan ditambahkan", "A bonus of \(Fmt.rp(pe.bonusAmount)) will be added"))
                            .font(.footnote).foregroundStyle(Theme.good)
                    }
                }
                Section(app.t("Metode", "Method")) {
                    if Theme.persona.compact {
                        ForEach(pe.topupMethods, id: \.self) { m in
                            Button { method = m } label: {
                                HStack(spacing: 10) {
                                    PIcon(symbol: methodIcon(m), size: 32)
                                    Text(methodName(m)).foregroundStyle(.primary).fontWeight(pe.topupMethodHighlight == m ? .bold : .regular)
                                    if pe.topupMethodHighlight == m { Chip(text: app.t("Disarankan", "Suggested")) }
                                    Spacer()
                                    if selected == m { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                                }
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(Array(pe.topupMethods.enumerated()), id: \.element) { i, m in
                                Button { method = m } label: {
                                    VStack(spacing: 8) {
                                        PIcon(symbol: methodIcon(m), tint: i, size: 52)
                                        Text(methodName(m).components(separatedBy: " (").first ?? "").font(.footnote.weight(.semibold)).foregroundStyle(.primary)
                                            .multilineTextAlignment(.center).lineLimit(2)
                                        if pe.topupMethodHighlight == m { Chip(text: app.t("Disarankan", "Suggested"), color: Theme.secondary) }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 120).padding(8)
                                    .background(selected == m ? Theme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.radius))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(selected == m ? Theme.accent : Color.secondary.opacity(0.2), lineWidth: selected == m ? 2 : 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if selected == "minimarket" {
                        Button { app.showToast(app.t("Mencari minimarket terdekat (simulasi)", "Looking for nearby stores (simulated)")) } label: {
                            Label(app.t("Cari minimarket terdekat", "Find nearest store"), systemImage: "location.fill")
                                .font(.footnote.bold()).padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Theme.secondary.opacity(0.15), in: Capsule()).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                Section { PrimaryButton(title: "Top Up \(Fmt.rp(amount))") {
                    let bonus = bonusApplies
                    paymentId = app.complete(.topUp, amount: amount, title: "Top Up " + methodName(selected).components(separatedBy: " (").first!)
                    if bonus {
                        app.set([.walletBalance: app.balance + pe.bonusAmount])
                        app.showToast(app.t("Bonus \(Fmt.rp(pe.bonusAmount)) masuk ke saldo", "\(Fmt.rp(pe.bonusAmount)) bonus added to balance"))
                    }
                    done = true
                } }
                .listRowBackground(Color.clear)
            }
            .sheet(isPresented: $done) {
                SuccessView(message: app.t("Saldo bertambah \(Fmt.rp(amount))", "Balance increased by \(Fmt.rp(amount))"), paymentId: paymentId)
            }
        }
    }
}

/// "Pakai Poin" toggle for the Bill and QRIS confirmation screens.
struct PayWithPointsRow: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var pe: PEResolver
    @ObservedObject private var wallet = LoyaltyWallet.shared
    let amount: Int
    @Binding var use: Bool

    var body: some View {
        if let q = app.payWithPointsQuote(amount: amount) {
            Section {
                Toggle(isOn: $use) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.t("Pakai Poin", "Use Points")).font(.subheadline.bold())
                        Text(app.t("Tersedia \(wallet.points) \(pe.loyaltyLabel(english: false))", "\(wallet.points) \(pe.loyaltyLabel(english: true)) available"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if use {
                    Label(app.t("Hemat \(Fmt.rp(q.discount)) dengan \(q.points) poin", "Save \(Fmt.rp(q.discount)) with \(q.points) points"),
                          systemImage: "star.circle.fill").font(.footnote.bold()).foregroundStyle(Theme.good)
                }
            }
        }
    }
}

extension AppState {
    /// Saving line shown on the success screen when points were used.
    func savingLine(_ q: PointsQuote?) -> String? {
        q.map { t("Hemat \(Fmt.rp($0.discount)) dengan \($0.points) poin", "Saved \(Fmt.rp($0.discount)) with \($0.points) points") }
    }
}

// MARK: Bills

struct BillPaymentView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var pe: PEResolver
    @State var category: String
    @State private var amount = 150_000
    @State private var done = false
    @State private var usePoints = false
    @State private var paymentId: String?
    @State private var saving: String?

    private var quote: PointsQuote? { usePoints ? app.payWithPointsQuote(amount: amount) : nil }

    private func pay(_ suffix: String = "") {
        let q = quote
        guard amount - (q?.discount ?? 0) <= app.balance else { return }
        paymentId = app.complete(.bill(category), amount: amount, title: label(category) + suffix,
                                 discount: q?.discount ?? 0, pointsUsed: q?.points ?? 0)
        saving = app.savingLine(q)
        done = true
    }
    private let cats = ["PLN", "pulsa", "internet"]

    init(initial: String) {
        _category = State(initialValue: initial)
        // Start from the persona's due bill when there is one (Budi: PLN Rp387.500).
        if let b = PersonaRegistry.shared.active?.dueBills.first(where: { $0.category == initial }) { _amount = State(initialValue: b.amount) }
    }

    private func label(_ c: String) -> String {
        switch c { case "PLN": return "PLN"; case "pulsa": return app.t("Pulsa", "Pulsa"); default: return "Internet" }
    }

    var body: some View {
        ScreenContainer(title: app.t("Tagihan", "Bills")) {
            Form {
                Section {
                    Picker("", selection: $category) { ForEach(cats, id: \.self) { Text(label($0)).tag($0) } }
                        .pickerStyle(.segmented)
                }
                Section(app.t("Pelanggan", "Customer")) {
                    Text(category == "PLN" ? "ID Pelanggan 5321 0987 6543" : category == "pulsa" ? app.t("Nomor", "Number") + " " + (app.persona?.phone ?? "") : "IndiHome 1234 5678")
                }
                Section(app.t("Nominal", "Amount")) {
                    AmountChips(amount: $amount, options: category == "pulsa" ? [25_000, 50_000, 100_000] : [100_000, 150_000, 300_000])
                }
                PayWithPointsRow(amount: amount, use: $usePoints)
                Section { PrimaryButton(title: app.t("Bayar", "Pay") + " \(Fmt.rp(amount - (quote?.discount ?? 0)))",
                                        enabled: amount - (quote?.discount ?? 0) <= app.balance) { pay() } }
                .listRowBackground(Color.clear)
                if pe.oneTapPay {
                    Section {
                        SecondaryButton(title: "1-tap bayar \(Fmt.rp(amount - (quote?.discount ?? 0)))", icon: "hand.tap.fill") { pay(" (1-tap)") }
                    }
                    .listRowBackground(Color.clear)
                }
                if amount - (quote?.discount ?? 0) > app.balance {
                    Text(app.t("Saldo tidak cukup. Top Up dulu.", "Insufficient balance. Top up first.")).font(.footnote).foregroundStyle(Theme.bad)
                }
                Section(app.t("Progres kebiasaan", "Habit progress")) {
                    Text("\(app.int(.habitProgressCurrent)) " + app.t("dari", "of") + " \(app.int(.habitProgressTarget)) " + app.t("transaksi", "transactions"))
                    ProgressBar(value: Double(app.int(.habitProgressCurrent)) / Double(max(1, app.int(.habitProgressTarget))))
                }
            }
            .sheet(isPresented: $done) {
                SuccessView(message: app.t("Pembayaran \(label(category)) berhasil", "\(label(category)) payment successful"),
                            detail: saving, paymentId: paymentId)
            }
        }
    }
}

// MARK: Transport

struct TransportView: View {
    @EnvironmentObject var app: AppState
    @State private var mode = "KRL"
    @State private var done = false
    @State private var paymentId: String?
    private let fares = ["KRL": 6_000, "MRT": 14_000, "TransJakarta": 3_500, "LRT": 10_000]

    var body: some View {
        ScreenContainer(title: "Transport") {
            Form {
                Section(app.t("Moda", "Mode")) {
                    Picker("", selection: $mode) { ForEach(fares.keys.sorted(), id: \.self) { Text($0) } }
                        .pickerStyle(.segmented)
                }
                Section(app.t("Tarif", "Fare")) { Text(Fmt.rp(fares[mode] ?? 0)).font(.title2.bold()) }
                Section {
                    PrimaryButton(title: app.t("Tap dan Bayar", "Tap and Pay"), icon: "wave.3.right") {
                        paymentId = app.complete(.transport, amount: fares[mode] ?? 0, title: mode); done = true
                    }
                }
                .listRowBackground(Color.clear)
                Section { Text(app.t("Mode demo: setiap pembayaran transport mendapat 1 stempel.",
                                     "Demo mode: every transport payment earns 1 stamp.")).font(.footnote).foregroundStyle(.secondary) }
            }
            .sheet(isPresented: $done) {
                SuccessView(message: app.t("Streak sekarang \(min(app.int(.streakDays), PEResolver.shared.streakTarget))/\(PEResolver.shared.streakTarget)",
                                           "Streak is now \(min(app.int(.streakDays), PEResolver.shared.streakTarget))/\(PEResolver.shared.streakTarget)"),
                            paymentId: paymentId)
            }
        }
    }
}

// MARK: Transfer and receive

struct TransferView: View {
    @EnvironmentObject var app: AppState
    let receive: Bool
    @State private var to = "+6281234567099"
    @State private var amount = 50_000
    @State private var done = false

    var body: some View {
        ScreenContainer(title: receive ? app.t("Terima", "Receive") : app.t("Kirim", "Send")) {
            if receive {
                VStack(spacing: 14) {
                    Image(systemName: "qrcode").font(.system(size: 160))
                    Text(app.persona?.fullName ?? "").font(.title3.bold())
                    Text(app.persona?.phone ?? "").foregroundStyle(.secondary)
                    Spacer()
                }.padding(.top, 40)
            } else {
                Form {
                    Section(app.t("Penerima", "Recipient")) { TextField("+62...", text: $to).keyboardType(.phonePad) }
                    Section(app.t("Nominal", "Amount")) {
                        AmountChips(amount: $amount, options: [25_000, 50_000, 100_000])
                    }
                    Section { PrimaryButton(title: app.t("Kirim", "Send") + " \(Fmt.rp(amount))", enabled: amount <= app.balance) {
                        app.complete(.transfer, amount: amount, title: app.t("Kirim ke", "Sent to") + " \(to)"); done = true
                    } }
                    .listRowBackground(Color.clear)
                }
                .sheet(isPresented: $done) { SuccessView(message: app.t("Transfer terkirim", "Transfer sent")) }
            }
        }
    }
}

// MARK: Donasi and Zakat

struct DonasiZakatView: View {
    @EnvironmentObject var app: AppState
    @State private var kind = "donasi"
    @State private var amount = 50_000
    @State private var done = false

    var body: some View {
        ScreenContainer(title: app.t("Donasi dan Zakat", "Donation and Zakat")) {
            Form {
                Section { Picker("", selection: $kind) {
                    Text(app.t("Donasi", "Donation")).tag("donasi"); Text("Zakat").tag("zakat")
                }.pickerStyle(.segmented) }
                Section(app.t("Nominal", "Amount")) { AmountChips(amount: $amount, options: [10_000, 50_000, 100_000]) }
                Section { PrimaryButton(title: app.t("Salurkan", "Give") + " \(Fmt.rp(amount))", enabled: amount <= app.balance) {
                    app.complete(kind == "zakat" ? .zakat : .donasi, amount: amount, title: kind == "zakat" ? "Zakat" : "Donasi")
                    done = true
                } }
                .listRowBackground(Color.clear)
            }
            .sheet(isPresented: $done) { SuccessView(message: app.t("Terima kasih atas kebaikanmu", "Thank you for your generosity")) }
        }
    }
}
