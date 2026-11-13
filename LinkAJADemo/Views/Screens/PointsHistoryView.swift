import SwiftUI

/// Riwayat Poin: wallet transactions from the Get Wallet Transactions API (or the local ledger in mock mode).
struct PointsHistoryView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var pe: PEResolver
    @ObservedObject private var wallet = LoyaltyWallet.shared

    private var english: Bool { app.language == "en" }

    var body: some View {
        ScreenContainer(title: app.t("Riwayat Poin", "Points History")) {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pe.loyaltyLabel(english: english)).font(.caption).foregroundStyle(.secondary)
                            Text(Fmt.num(wallet.points)).font(.largeTitle.bold())
                        }
                        Spacer()
                        if wallet.mockMode { Chip(text: "mock", color: .orange) }
                    }
                    if wallet.pendingPoints > 0 {
                        Label(app.t("Poin menunggu aktif: \(wallet.pendingPoints)", "Points pending activation: \(wallet.pendingPoints)"),
                              systemImage: "hourglass").font(.subheadline).foregroundStyle(Theme.secondary)
                    }
                }
                Section(app.t("Transaksi", "Transactions")) {
                    if wallet.loadingHistory && wallet.history.isEmpty { ProgressView() }
                    if !wallet.loadingHistory && wallet.history.isEmpty {
                        Text(app.t("Belum ada transaksi poin", "No point transactions yet")).foregroundStyle(.secondary)
                    }
                    ForEach(wallet.history) { row in historyRow(row) }
                }
                if let e = wallet.lastError, !wallet.mockMode {
                    Section { Text(app.t("Menampilkan data di perangkat. ", "Showing on-device data. ") + e).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .refreshable { await wallet.refreshBalance(); await wallet.loadHistory() }
        }
        .task { await wallet.refreshBalance(); await wallet.loadHistory() }
    }

    private func historyRow(_ r: HistoryRow) -> some View {
        let plus = r.signed > 0
        let neutral = r.signed == 0
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: neutral ? "hourglass.circle.fill" : (plus ? "plus.circle.fill" : "minus.circle.fill"))
                .font(.title2).foregroundStyle(neutral ? .orange : (plus ? .green : .orange))
            VStack(alignment: .leading, spacing: 3) {
                Text(title(r)).font(.subheadline.bold())
                if !r.detail.isEmpty { Text(r.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                Text(Self.dateFormat.string(from: r.date)).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text((neutral ? "" : (plus ? "+" : "-")) + LoyaltyWallet.fmt(r.points))
                    .font(.subheadline.bold()).foregroundStyle(neutral ? .orange : (plus ? .green : .primary))
                if r.runningBalance > 0 || !neutral { Text(app.t("Saldo ", "Balance ") + LoyaltyWallet.fmt(r.runningBalance)).font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }

    private func title(_ r: HistoryRow) -> String {
        if let rule = IncentiveRule(rawValue: r.rule) { return rule.title(english: english) }
        switch r.kind {
        case "expired": return app.t("Poin kedaluwarsa", "Points expired")
        case "reverse": return app.t("Poin dibatalkan", "Points reversed")
        case "refund": return app.t("Poin dikembalikan", "Points refunded")
        case "pending": return app.t("Poin menunggu aktif", "Pending points")
        case "debit": return app.t("Poin dipakai", "Points used")
        default: return app.t("Poin masuk", "Points earned")
        }
    }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy HH:mm"; return f
    }()
}
