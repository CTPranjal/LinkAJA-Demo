import Foundation

/// App-only state that is not a CleverTap profile property.
struct LocalState: Codable {
    var voucherOnboardingIssued = false
    var voucherOnboardingRedeemed = false
    var voucher15IssuedAt: Date?
    var voucher15Redeemed = false
    var paydayActive = false
    var categoryCounts: [String: Int] = [:]
    var habitCashbackGranted = false
    var streakNudge = false
    var kycStartTime: Date?
    var activity: [ActivityItem] = []
}

struct ActivityItem: Codable, Identifiable {
    var id = UUID()
    var title: String
    var amount: Int      // negative for spend, positive for money in
    var date: Date
}

enum TxnKind {
    case topUp, qris, transfer, transport, donasi, zakat
    case bill(String)    // PLN, pulsa, internet

    /// Category names used by LinkAJA_Category_Used and LinkAJA_dominant_category.
    var category: String? {
        switch self {
        case .qris: return "qris"
        case .transport: return "transport"
        case .donasi: return "donasi"
        case .zakat: return "zakat"
        case .bill: return "tagihan"
        case .topUp, .transfer: return nil
        }
    }

    var label: String {
        switch self {
        case .topUp: return "Top Up"
        case .qris: return "QRIS"
        case .transfer: return "Transfer"
        case .transport: return "Transport"
        case .donasi: return "Donasi"
        case .zakat: return "Zakat"
        case .bill(let b): return b
        }
    }
}
