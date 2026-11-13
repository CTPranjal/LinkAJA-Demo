import SwiftUI

enum AppTab: String, Hashable { case home, promo, scan, inbox, profile, bills, shop }

enum AppSheet: String, Identifiable {
    case kyc, topUp, bill, pulsa, transport, transfer, receive, donasi, streak, promo, inbox, bills, shop
    var id: String { rawValue }
}

/// Handles linkajademo:// URLs from onOpenURL, push, in-app and inbox.
final class DeepLinkRouter: ObservableObject {
    @Published var tab: AppTab = .home
    @Published var sheet: AppSheet?
    @Published var promoCode: String?

    /// False until a persona is logged in; links received earlier are replayed after login.
    var ready = false { didSet { if ready { flushPending() } } }
    private var pending: URL?
    private var lastURL: (String, Date)?

    func handle(_ url: URL) {
        guard url.scheme == "linkajademo" else { return }
        // Push taps can reach us through several paths at once, so drop an immediate repeat.
        if let last = lastURL, last.0 == url.absoluteString, Date().timeIntervalSince(last.1) < 1 { return }
        lastURL = (url.absoluteString, Date())
        guard ready else { pending = url; return }

        switch url.host?.lowercased() {
        case "kyc": sheet = .kyc
        case "qris-scan": sheet = nil; tab = .scan
        case "promo":
            sheet = nil
            tab = .promo
            promoCode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
        case "bill-payment": sheet = .bill
        case "streak": sheet = .streak
        case "inbox": sheet = nil; tab = .inbox
        case "bills": sheet = nil; tab = .bills
        case "toko", "shop": sheet = nil; tab = .shop
        default: sheet = nil; tab = .home
        }
    }

    private func flushPending() {
        guard let url = pending else { return }
        pending = nil
        lastURL = nil
        handle(url)
    }
}
