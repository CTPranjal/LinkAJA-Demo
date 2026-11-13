import SwiftUI
import Combine

/// Which payment the Streak screen button makes for this persona.
enum StreakAction { case transport, qris }

struct PromoItem: Identifiable, Equatable {
    enum Validity: Equatable { case days(Int), endOfMonth }

    let id: String
    let title: String
    let code: String
    let category: String
    var minTransaction = 0
    var maxDiscount: Int?
    var percent: Int?
    var fixed: Int?
    var validity: Validity = .days(14)
    var image = "img_banner_graphic"
    /// True for the synthetic promo built from LinkAJA.promo.featured.* values.
    var fromDashboard = false

    /// Rupiah cashback for a transaction of `amount`. Zero when below the minimum.
    func cashback(for amount: Int) -> Int {
        guard amount >= minTransaction else { return 0 }
        if let fixed { return fixed }
        if let percent { return min(amount * percent / 100, maxDiscount ?? Int.max) }
        return 0
    }

    func benefit(_ id: Bool) -> String {
        var parts: [String] = []
        if let percent {
            parts.append(id ? "Cashback \(percent)%" : "\(percent)% cashback")
        } else if let fixed, fixed > 0 {
            parts.append(id ? "Cashback \(Fmt.rp(fixed))" : "\(Fmt.rp(fixed)) cashback")
        } else {
            parts.append(id ? "Promo spesial" : "Special promo")
        }
        if let m = maxDiscount { parts.append(id ? "maks. \(Fmt.rp(m))" : "max \(Fmt.rp(m))") }
        if minTransaction > 0 { parts.append(id ? "min. \(Fmt.rp(minTransaction))" : "min \(Fmt.rp(minTransaction))") }
        return parts.joined(separator: ", ")
    }

    func daysLeft(now: Date = Date()) -> Int {
        switch validity {
        case .days(let d): return d
        case .endOfMonth:
            let cal = Calendar.current
            guard let start = cal.date(from: cal.dateComponents([.year, .month], from: now)),
                  let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else { return 0 }
            return max(0, (cal.dateComponents([.day], from: cal.startOfDay(for: now), to: end).day ?? 0) + 1)
        }
    }
}

/// A bill that is due soon (Budi's Bill Hub and the "Perlu dibayar" card).
struct DueBill: Identifiable {
    let id: String
    let title: String
    let category: String        // BillPaymentView category: PLN, pulsa, internet
    let amount: Int
    let dueInDays: Int
    let symbol: String
}

struct PointsReward: Identifiable, Equatable {
    let id: String
    let title: String
    let points: Int
}

/// Everything that differs between personas. Optional PE overrides are keyed by PEKeys and sit
/// below dashboard values in the resolution order (see PEResolver).
struct PersonaConfig {
    let personaID: String          // the CleverTap Identity
    let displayName: String
    let firstName: String
    let avatarAsset: String
    let tagline: String
    let walletBalance: Int         // Rupiah saldo
    let startingPoints: Int        // seed and offline fallback for Poin Loyalty
    let stampSet: String
    let streakAction: StreakAction
    let overrides: [PEKeys: PEValue]
    let promoCatalog: [PromoItem]
    let rewards: [PointsReward]
    let showsMerchantCard: Bool
    /// Sample recent activity so the Home list is never empty. (title, signed Rupiah)
    let seedActivity: [(String, Int)]
    let dueBills: [DueBill]
    let profileData: () -> [CT.Prop: Any]
}

final class PersonaRegistry: ObservableObject {
    static let shared = PersonaRegistry()
    /// Set at login, cleared at logout.
    @Published private(set) var active: PersonaConfig?

    func activate(_ personaID: String?) {
        active = personaID.flatMap { id in Self.all.first { $0.personaID == id } }
    }

    static func config(for personaID: String) -> PersonaConfig? { all.first { $0.personaID == personaID } }

    static let all = [budi, siti]

    private static func ahead(_ days: Int) -> Date { Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date() }

    static let budi = PersonaConfig(
        personaID: Persona.budi.id, displayName: "Budi Santoso", firstName: "Budi",
        avatarAsset: Persona.budi.imageName, tagline: "Komuter Jakarta",
        walletBalance: 450_000, startingPoints: 1_250, stampSet: "commuter", streakAction: .transport,
        overrides: [
            .heroTitle: .string("Halo Budi, tagihan listrikmu jatuh tempo 3 hari lagi"),
            .heroSubtitle: .string("Bayar sekarang dan dapat cashback Rp10.000"),
            .heroCTAText: .string("Bayar Tagihan"),
            .heroDeeplink: .string("linkajademo://bill-payment"),
            .quickActionsOrder: .string("tagihan,transport,pulsa,topup,qris,kirim,terima,donasi"),
            .quickActionsHighlight: .string("tagihan"),
            .topupSuggested: .string("100000,200000,500000,1000000"),
            .topupDefault: .int(200_000),
            .methodsOrder: .string("bank_va,atm,debit_card,minimarket"),
            .methodsHighlight: .string("bank_va"),
            .promoLayout: .string("carousel"),
            .promoFeatured: .string("tagihan"),
            .stampSet: .string("commuter"),
            .streakChip: .string("hari kerja beruntun"),
            .badgeLabel: .string("Komuter Setia"),
            .crossTitle: .string("Tagihan rutin sudah jago, coba bayar pakai QRIS yuk"),
            .crossCategory: .string("qris"),
            .crossCTA: .string("Coba Scan"),
            .crossVariant: .string("praktis"),
            .flagOneTapPay: .bool(true),
            .flagQrisEducation: .bool(true),
            // Design tokens that double as variables, so a dashboard value can still win.
            .themePrimary: .string(PersonaTheme.budi.accentHex),
            .themeRadius: .int(Int(PersonaTheme.budi.radius)),
            .stampColor: .string(PersonaTheme.budi.highlightHex),
            .progressColor: .string(PersonaTheme.budi.highlightHex),
            .crossCashback: .int(5_000),
            .bonusMin: .int(200_000),
            .bonusAmount: .int(10_000),
            .bonusBanner: .string("Top up Rp200.000, dapat bonus Rp10.000")
        ],
        promoCatalog: [
            PromoItem(id: "pln_cashback", title: "Cashback Rp10.000 bayar listrik PLN", code: "PLNHEMAT", category: "tagihan",
                      minTransaction: 50_000, fixed: 10_000, image: "img_banner_phone"),
            PromoItem(id: "krl_mrt", title: "Cashback 20% naik KRL dan MRT", code: "KOMUTER20", category: "transport",
                      maxDiscount: 5_000, percent: 20, image: "img_banner_home"),
            PromoItem(id: "pulsa_data", title: "Diskon 10% pulsa dan paket data", code: "PULSA10", category: "pulsa",
                      percent: 10, image: "img_banner_phone"),
            PromoItem(id: "gajian25", title: "Gajian Deals", code: "GAJIAN25", category: "qris",
                      minTransaction: 100_000, maxDiscount: 25_000, percent: 10, validity: .endOfMonth, image: "img_banner_graphic")
        ],
        rewards: [
            PointsReward(id: "voucher_tagihan_5k", title: "Voucher tagihan Rp5.000", points: 300),
            PointsReward(id: "voucher_transport_10k", title: "Voucher transport Rp10.000", points: 600)
        ],
        showsMerchantCard: false,
        seedActivity: [("PLN listrik", -387_500), ("KRL Commuter Line", -7_000), ("Telkomsel pulsa", -100_000)],
        dueBills: [DueBill(id: "pln", title: "PLN listrik", category: "PLN", amount: 387_500, dueInDays: 3, symbol: "bolt"),
                   DueBill(id: "telkomsel", title: "Telkomsel pulsa", category: "pulsa", amount: 100_000, dueInDays: 8, symbol: "iphone"),
                   DueBill(id: "indihome", title: "Indihome", category: "internet", amount: 350_000, dueInDays: 12, symbol: "wifi")],
        profileData: {
            [.walletBalance: 450_000, .dominantCategory: "tagihan", .favoriteCategory: "tagihan",
             .usualPaymentDay: 25, .nextBillDueDate: ahead(3), .avgTopupAmount: 200_000,
             .habitProgressCurrent: 2, .habitProgressTarget: 3, .streakDays: 3,
             .streakCyclesCompleted: 1, .txnCount30d: 2]
        })

    static let siti = PersonaConfig(
        personaID: Persona.siti.id, displayName: "Siti Rahayu", firstName: "Siti",
        avatarAsset: Persona.siti.imageName, tagline: "Mahasiswa dan pemilik usaha kecil",
        walletBalance: 120_000, startingPoints: 400, stampSet: "qris", streakAction: .qris,
        overrides: [
            .heroTitle: .string("Halo Siti, scan QRIS dan dapat cashback hari ini"),
            .heroSubtitle: .string("Bayar di warung favoritmu, terima pembayaran dari pelanggan"),
            .heroCTAText: .string("Scan QRIS"),
            .heroDeeplink: .string("linkajademo://qris-scan"),
            .quickActionsOrder: .string("qris,kirim,terima,topup,pulsa,donasi,tagihan,transport"),
            .quickActionsHighlight: .string("qris"),
            .topupSuggested: .string("20000,50000,100000,200000"),
            .topupDefault: .int(50_000),
            .methodsOrder: .string("minimarket,bank_va,atm,debit_card"),
            .methodsHighlight: .string("minimarket"),
            .promoLayout: .string("grid"),
            .promoFeatured: .string("qris"),
            .stampSet: .string("qris"),
            .streakChip: .string("hari QRIS beruntun"),
            .badgeLabel: .string("Jagoan QRIS"),
            .crossTitle: .string("QRIS-mu udah jago, coba bayar tagihan yuk"),
            .crossCategory: .string("tagihan"),
            .crossCTA: .string("Coba Sekarang"),
            .crossVariant: .string("hemat"),
            .flagOneTapPay: .bool(false),
            .flagQrisEducation: .bool(false),
            .themePrimary: .string(PersonaTheme.siti.accentHex),
            .themeRadius: .int(Int(PersonaTheme.siti.radius)),
            .stampColor: .string(PersonaTheme.siti.highlightHex),
            .progressColor: .string(PersonaTheme.siti.highlightHex),
            .crossCashback: .int(10_000),
            .bonusMin: .int(50_000),
            .bonusAmount: .int(5_000),
            .bonusBanner: .string("Top up di minimarket, bonus Rp5.000")
        ],
        promoCatalog: [
            PromoItem(id: "qris_cashback", title: "Cashback 15% bayar QRIS di warung", code: "QRISJAGO", category: "qris",
                      maxDiscount: 10_000, percent: 15, image: "img_banner_graphic"),
            PromoItem(id: "transfer_free", title: "Gratis biaya transfer 5x", code: "KIRIMGRATIS", category: "transfer",
                      fixed: 0, image: "img_banner_app"),
            PromoItem(id: "minimarket_topup", title: "Top up di minimarket, bonus Rp5.000", code: "TOPUPMART", category: "topup",
                      minTransaction: 50_000, fixed: 5_000, image: "img_banner_home"),
            PromoItem(id: "gajian25", title: "Gajian Deals", code: "GAJIAN25", category: "qris",
                      minTransaction: 100_000, maxDiscount: 25_000, percent: 10, validity: .endOfMonth, image: "img_banner_graphic")
        ],
        rewards: [
            PointsReward(id: "voucher_qris_5k", title: "Voucher QRIS Rp5.000", points: 300),
            PointsReward(id: "cashback_merchant_10k", title: "Cashback merchant Rp10.000", points: 600)
        ],
        showsMerchantCard: true,
        seedActivity: [("Warung makan", -28_000), ("Kantin kampus", -15_000), ("Transfer ke teman", -50_000)],
        dueBills: [],
        profileData: {
            [.walletBalance: 120_000, .dominantCategory: "qris", .favoriteCategory: "qris",
             .usualPaymentDay: 1, .avgTopupAmount: 50_000,
             .habitProgressCurrent: 1, .habitProgressTarget: 3, .streakDays: 2,
             .streakCyclesCompleted: 0, .txnCount30d: 14]
        })
}

/// Stamp symbols per set. Every name is validated against SF Symbols and falls back to star.fill.
enum StampSets {
    static let names = ["classic", "commuter", "qris"]

    private static let symbols: [String: [String]] = [
        "classic": ["star.fill", "star.fill", "star.fill", "star.fill"],
        "commuter": ["tram.fill", "bus.fill", "ticket.fill", "figure.walk"],
        "qris": ["qrcode", "cart.fill", "cup.and.saucer.fill", "bag.fill"]
    ]

    static func valid(_ name: String) -> String {
        UIImage(systemName: name) != nil ? name : "star.fill"
    }

    /// Symbol for slot `index` of a cycle with `target` slots. The last slot is always the final symbol.
    static func symbol(set: String, index: Int, target: Int, finalSymbol: String) -> String {
        if index == target - 1 { return valid(finalSymbol) }
        let list = symbols[set.lowercased()] ?? symbols["classic"]!
        return valid(list[index % list.count])
    }
}
