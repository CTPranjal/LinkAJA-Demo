import SwiftUI

/// Mock merchant numbers for Siti's Home widget and Toko screen.
enum TokoData {
    static let todaySales = 385_000
    static let week: [Double] = [210, 340, 280, 450, 390, 520, 385]
    static func dayLabels(english: Bool) -> [String] {
        english ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] : ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
    }
    static let incoming: [(String, Int, String)] = [
        ("Bu Rina", 25_000, "09.15"), ("Mas Dito", 12_000, "09.02"), ("Kak Nadia", 48_000, "08.47"),
        ("Pak Joko", 30_000, "08.20"), ("Mbak Sari", 18_000, "07.58")
    ]
    static let storeName = "Warung Siti"
    static let nmid = "ID1020304050607"
}

// MARK: Bill Hub (Budi)

struct BillHubView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var pe: PEResolver
    @State private var paid = Set<String>()
    @State private var success: (id: String, text: String)?
    @State private var showSuccess = false
    @AppStorage("ljd_remind_pln") private var remindPLN = true
    @AppStorage("ljd_remind_telkomsel") private var remindTelkomsel = false
    @AppStorage("ljd_remind_indihome") private var remindIndihome = false

    private var bills: [DueBill] { pe.persona?.dueBills ?? [] }

    private func remind(_ id: String) -> Binding<Bool> {
        switch id {
        case "pln": return $remindPLN
        case "telkomsel": return $remindTelkomsel
        default: return $remindIndihome
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    HStack {
                        Text(app.t("TAGIHAN JATUH TEMPO", "BILLS DUE")).font(.caption2.weight(.bold)).foregroundStyle(.secondary).tracking(0.8)
                        Spacer()
                        Text(Fmt.rp(bills.filter { !paid.contains($0.id) }.map(\.amount).reduce(0, +))).font(.subheadline.bold())
                    }
                    ForEach(bills) { b in row(b) }
                    if bills.isEmpty { Text(app.t("Tidak ada tagihan", "No bills")).foregroundStyle(.secondary) }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(app.t("Tagihan", "Bills"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showSuccess) {
            SuccessView(message: success?.text ?? "", paymentId: success?.id)
        }
    }

    private func row(_ b: DueBill) -> some View {
        let isPaid = paid.contains(b.id)
        let urgent = b.dueInDays <= 3
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PIcon(symbol: b.symbol, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.title).font(.subheadline.weight(.semibold))
                    Text(app.t("Jatuh tempo \(b.dueInDays) hari lagi", "Due in \(b.dueInDays) days")).font(.caption.weight(.semibold))
                        .foregroundStyle(urgent ? Theme.secondary : Color.secondary)
                }
                Spacer()
                Text(Fmt.rp(b.amount)).font(.subheadline.bold())
            }
            HStack {
                Toggle(isOn: remind(b.id)) { Text(app.t("Atur pengingat", "Remind me")).font(.caption).foregroundStyle(.secondary) }
                    .toggleStyle(.switch).fixedSize()
                Spacer()
                if isPaid {
                    Chip(text: app.t("Lunas", "Paid"), color: Theme.good)
                } else {
                    Button { pay(b) } label: {
                        Text(app.t("Bayar", "Pay")).font(.subheadline.bold()).padding(.horizontal, 24).padding(.vertical, 7)
                            .background(b.amount <= app.balance ? Theme.cta : Theme.secondary.opacity(0.4)).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: max(Theme.radius - 4, 4)))
                    }
                    .disabled(b.amount > app.balance)
                }
            }
        }
        .overlay(alignment: .leading) { if urgent && !isPaid { Theme.secondary.frame(width: 4).padding(.leading, -Theme.persona.rowPadding).clipShape(Capsule()) } }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func pay(_ b: DueBill) {
        let id = app.complete(.bill(b.category), amount: b.amount, title: b.title)
        paid.insert(b.id)
        success = (id, app.t("Pembayaran \(b.title) berhasil", "\(b.title) payment successful"))
        showSuccess = true
    }
}

// MARK: Toko (Siti)

struct TokoView: View {
    @EnvironmentObject var app: AppState
    private var english: Bool { app.language == "en" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(app.t("Penjualan hari ini", "Today's sales")).font(.headline)
                            Spacer()
                            Chip(text: app.t("12 transaksi", "12 transactions"), color: Theme.secondary)
                        }
                        Text(Fmt.rp(TokoData.todaySales)).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
                        MiniBarChart(values: TokoData.week, labels: TokoData.dayLabels(english: english), color: Theme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).card()

                    VStack(spacing: 10) {
                        Text("QR Toko").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "qrcode").font(.system(size: 130)).foregroundStyle(Theme.accent)
                        Text(TokoData.storeName).font(.title3.bold())
                        Text("NMID " + TokoData.nmid).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(app.t("Pembayaran masuk", "Incoming payments")).font(.headline)
                        ForEach(Array(TokoData.incoming.enumerated()), id: \.offset) { i, row in
                            HStack(spacing: 12) {
                                PIcon(symbol: "arrow.down.circle", tint: i, size: 40)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.0).font(.subheadline.weight(.semibold))
                                    Text(row.2).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+" + Fmt.rp(row.1)).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Theme.good)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).card()

                    PrimaryButton(title: app.t("Tarik Saldo", "Withdraw"), icon: "arrow.up.right.circle.fill") {
                        app.showToast(app.t("Penarikan \(Fmt.rp(TokoData.todaySales)) diproses (simulasi)", "Withdrawal of \(Fmt.rp(TokoData.todaySales)) in progress (simulated)"))
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Toko")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
