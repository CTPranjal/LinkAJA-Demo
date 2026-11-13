import SwiftUI

struct StreakView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: DeepLinkRouter
    @EnvironmentObject var pe: PEResolver
    @ObservedObject private var wallet = LoyaltyWallet.shared
    private let tilts: [Double] = [-8, 5, -4, 7, -6, 4, -9]

    private var english: Bool { app.language == "en" }

    var body: some View {
        // Never show a number above the cycle target.
        let target = pe.streakTarget
        let streak = min(app.int(.streakDays), target)
        let color = pe.progressColor
        let cycles = app.int(.streakCyclesCompleted)
        let required = pe.badgeCycles
        let label = pe.loyaltyLabel(english: english)
        ScreenContainer(title: app.persona?.id == Persona.siti.id ? app.t("Streak QRIS", "QRIS Streak") : app.t("Streak Komuter", "Commuter Streak")) {
            ScrollView {
                VStack(spacing: 16) {
                    if let c = app.celebration { celebration(c, label: label) }

                    VStack(spacing: 12) {
                        HStack {
                            Text("Streak \(streak)/\(target)").font(.title3.bold())
                            Spacer()
                            if streak > 0 { Chip(text: "\(streak) \(pe.streakChip(english: english))", color: color) }
                        }
                        stampRow(streak: streak, target: target)
                        Text(app.persona?.id == Persona.siti.id
                             ? app.t("Bayar pakai QRIS di hari kerja untuk mendapat satu stempel.", "Pay with QRIS on workdays to earn one stamp.")
                             : app.t("Bayar transport di hari kerja untuk mendapat satu stempel.", "Pay transport on workdays to earn one stamp."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(app.t("Hadiah", "Rewards")).font(.headline)
                        rewardRow(app.t("\(target) hari kerja = +\(pe.rewardPoints) \(label)", "\(target) workdays = +\(pe.rewardPoints) \(label)"),
                                  done: app.celebration != nil)
                        rewardRow(app.t("\(required) siklus = badge \(pe.badgeLabel) plus bonus", "\(required) cycles = \(pe.badgeLabel) badge plus bonus"),
                                  done: app.bool(.badgeEarned))
                        ProgressBar(value: Double(min(cycles, required)) / Double(required), color: color)
                        HStack {
                            Text(app.t("Siklus \(min(cycles, required))/\(required)", "Cycle \(min(cycles, required))/\(required)"))
                            Spacer()
                            Label(app.bool(.badgeEarned) ? pe.badgeLabel : app.t("Terkunci", "Locked"),
                                  systemImage: app.bool(.badgeEarned) ? "rosette" : "lock.fill")
                                .foregroundStyle(app.bool(.badgeEarned) ? color : .secondary)
                        }
                        .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).card()

                    HStack(spacing: 12) {
                        pointsTile(label: label)
                        statTile(app.t("Siklus selesai", "Cycles completed"), "\(cycles)")
                    }

                    if app.persona.flatMap({ PersonaRegistry.config(for: $0.id) })?.streakAction == .qris {
                        SecondaryButton(title: app.t("Bayar QRIS (+1 hari)", "Pay QRIS (+1 day)"), icon: "qrcode") {
                            app.complete(.qris, amount: 35_000, title: "QRIS Warung Bu Tini")
                        }
                    } else {
                        SecondaryButton(title: app.t("Bayar Transport (+1 hari)", "Pay Transport (+1 day)"), icon: "tram.fill") {
                            app.complete(.transport, amount: 6_000, title: "KRL")
                        }
                    }
                    SecondaryButton(title: app.t("Simulasikan streak putus", "Simulate broken streak"), icon: "bolt.slash.fill") {
                        app.breakStreak()
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
        }
    }

    // MARK: Pieces

    private func stampRow(streak: Int, target: Int) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: min(target, 7))
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<target, id: \.self) { i in
                StampSlot(earned: i < streak,
                          symbol: StampSets.symbol(set: pe.stampSet, index: i, target: target, finalSymbol: pe.stampFinalSymbol),
                          color: pe.stampColor,
                          label: app.t("H\(i + 1)", "D\(i + 1)"),
                          tilt: tilts[i % tilts.count],
                          animated: pe.stampAnimation)
            }
        }
    }

    private func celebration(_ c: Celebration, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "party.popper.fill").font(.largeTitle).foregroundStyle(.white)
            if c.queued {
                Text(app.t("Selamat! Siklus \(c.cycle) selesai", "Congratulations! Cycle \(c.cycle) complete")).font(.headline)
                Text(app.t("Poin belum masuk, coba lagi dari Demo Tools", "Points not credited yet, retry from Demo Tools")).font(.caption)
            } else if c.points > 0 {
                Text(app.t("Selamat! +\(c.points) \(label)", "Congratulations! +\(c.points) \(label)")).font(.headline)
                if let n = c.note { Text(n).font(.caption) }
            } else {
                Text(app.t("Selamat! Siklus \(c.cycle) selesai", "Congratulations! Cycle \(c.cycle) complete")).font(.headline)
            }
            Button(app.t("Tutup", "Dismiss")) { app.celebration = nil }
                .font(.caption.bold()).padding(.horizontal, 14).padding(.vertical, 5)
                .background(.white).foregroundStyle(Theme.red).clipShape(Capsule())
        }
        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(16)
        .background(Theme.gradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .transition(.scale.combined(with: .opacity))
    }

    private func rewardRow(_ text: String, done: Bool) -> some View {
        HStack { Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? Theme.good : Color.secondary); Text(text).font(.subheadline) }
    }

    private func pointsTile(label: String) -> some View {
        VStack(spacing: 6) {
            Text(Fmt.num(wallet.points)).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
            if wallet.pendingPoints > 0 {
                Text(app.t("\(wallet.pendingPoints) menunggu aktif", "\(wallet.pendingPoints) pending")).font(.caption2).foregroundStyle(Theme.secondary)
            }
            PointsChip()
        }
        .frame(maxWidth: .infinity).card()
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(value).font(.headline); Text(title).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity).card()
    }
}
