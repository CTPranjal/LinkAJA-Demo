import SwiftUI
import CleverTapSDK

struct InboxView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: DeepLinkRouter
    @EnvironmentObject var ct: CleverTapManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    localCards
                    ForEach(ct.inboxMessages, id: \.messageId) { m in
                        InboxCard(message: m) { open(m) }
                    }
                    if ct.inboxMessages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                            Text(app.t("Belum ada pesan dari CleverTap. Kirim kampanye App Inbox dari dashboard.",
                                       "No CleverTap messages yet. Send an App Inbox campaign from the dashboard."))
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.padding(.top, 30)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Inbox")
            .refreshable { ct.refreshInbox() }
            .onAppear { ct.refreshInbox() }
        }
    }

    private func open(_ m: CleverTapInboxMessage) {
        if let url = ct.inboxMessageClicked(m) { router.handle(url) }
    }

    // Local fallback cards so the journeys can be shown without a dashboard campaign.
    @ViewBuilder private var localCards: some View {
        if app.persona?.id == Persona.budi.id {
            localCard(title: app.t("Tagihan listrikmu jatuh tempo 3 hari lagi", "Your electricity bill is due in 3 days"),
                      body: app.t("PLN listrik Rp387.500. Bayar sekarang supaya tidak kena denda.", "PLN electricity Rp387,500. Pay now to avoid a late fee."),
                      progress: nil, cta: app.t("Bayar Sekarang", "Pay Now")) { router.sheet = .bill }
        } else if app.persona?.id == Persona.siti.id {
            localCard(title: app.t("QRIS-mu udah jago, coba bayar tagihan yuk", "You are a QRIS pro, try paying a bill"),
                      body: app.t("Cashback Rp10.000 untuk tagihan pertamamu.", "Rp10,000 cashback on your first bill."),
                      progress: nil, cta: app.t("Coba Sekarang", "Try Now")) { router.sheet = .bill }
        }
        if app.int(.habitProgressCurrent) > 0 {
            let cur = app.int(.habitProgressCurrent), target = max(1, app.int(.habitProgressTarget))
            localCard(title: "\(cur) " + app.t("dari", "of") + " \(target) " + app.t("transaksi", "transactions"),
                      body: app.t("Satu transaksi lagi untuk cashback Rp10.000.", "One more transaction for Rp10,000 cashback."),
                      progress: Double(cur) / Double(target), cta: app.t("Bayar Sekarang", "Pay Now")) { router.sheet = .bill }
        }
        if app.local.streakNudge {
            localCard(title: app.t("Streak-mu terputus, mulai lagi yuk", "Your streak broke, start again"),
                      body: app.t("Bayar transport hari ini untuk memulai streak baru.", "Pay transport today to start a new streak."),
                      progress: nil, cta: app.t("Lihat Progres", "View Progress")) { router.sheet = .streak }
        }
        if app.showChurnOffer {
            localCard(title: app.t("Kami kangen kamu", "We miss you"),
                      body: app.t("Cashback Rp10.000 untuk 1 transaksi dalam 7 hari.", "Rp10,000 cashback for 1 transaction in 7 days."),
                      progress: nil, cta: app.t("Cek Promo", "Check Promo")) { router.tab = .promo }
        }
    }

    private func localCard(title: String, body: String, progress: Double?, cta: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Chip(text: app.t("Demo lokal", "Local demo"), color: .gray); Spacer() }
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
            if let progress { ProgressBar(value: progress) }
            SecondaryButton(title: cta, action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }
}

/// Renders a CleverTap inbox message. A card whose key-value data holds progress_current and
/// progress_target is drawn with a progress bar.
struct InboxCard: View {
    let message: CleverTapInboxMessage
    let onTap: () -> Void
    @EnvironmentObject var ct: CleverTapManager

    private var content: CleverTapInboxMessageContent? { message.content?.first }
    private var data: [String: Any] { message.customData as? [String: Any] ?? [:] }
    private var progress: (Double, Int, Int)? {
        guard let c = Int("\(data["progress_current"] ?? "")"), let t = Int("\(data["progress_target"] ?? "")"), t > 0 else { return nil }
        return (Double(c) / Double(t), c, t)
    }
    private var ctaLabel: String {
        if let l = data["cta_label"] as? String { return l }
        if let link = content?.links?.first as? [String: Any], let text = link["text"] as? String { return text }
        return "Buka"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(content?.title ?? "").font(.headline)
                Spacer()
                if !message.isRead { Circle().fill(Theme.red).frame(width: 9, height: 9) }
            }
            Text(content?.message ?? "").font(.subheadline).foregroundStyle(.secondary)
            if let p = progress {
                ProgressBar(value: p.0)
                Text("\(p.1) / \(p.2)").font(.caption).foregroundStyle(.secondary)
            }
            if content?.actionHasUrl == true || content?.actionHasLinks == true {
                SecondaryButton(title: ctaLabel, action: onTap)
            }
            Text(message.relativeDate ?? "").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
        .onAppear { ct.inboxMessageViewed(message) }
        .onTapGesture { onTap() }
    }
}
