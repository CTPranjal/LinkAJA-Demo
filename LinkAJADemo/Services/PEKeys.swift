import Foundation

enum PEValue {
    case bool(Bool), string(String), int(Int)

    var display: String {
        switch self {
        case .bool(let b): return b ? "true" : "false"
        case .string(let s): return s
        case .int(let i): return "\(i)"
        }
    }
}

/// Every Product Experiences variable. All live under the single "LinkAJA" group, in dot notation:
/// LinkAJA.<screen>.<element>[.<attribute>]. Nothing is defined outside this enum.
enum PEKeys: String, CaseIterable {
    static let group = "LinkAJA"

    // Home
    case heroVisible = "home.hero_banner.visible"
    case heroTitle = "home.hero_banner.title"
    case heroSubtitle = "home.hero_banner.subtitle"
    case heroImageURL = "home.hero_banner.image_url"
    case heroCTAText = "home.hero_banner.cta_text"
    case heroDeeplink = "home.hero_banner.deeplink"
    case quickActionsOrder = "home.quick_actions.order"
    case quickActionsHighlight = "home.quick_actions.highlight"
    case balanceShowTopup = "home.balance_card.show_topup_cta"
    case balanceTopupText = "home.balance_card.topup_cta_text"
    // Top Up
    case topupSuggested = "topup.suggested_amounts"
    case methodsOrder = "topup.methods.order"
    case methodsHighlight = "topup.methods.highlight"
    case topupDefault = "topup.default_amount"
    case bonusEnabled = "topup.bonus.enabled"
    case bonusMin = "topup.bonus.min_amount"
    case bonusAmount = "topup.bonus.amount"
    case bonusBanner = "topup.bonus.banner_text"
    // Promo
    case promoLayout = "promo.layout"
    case promoFeatured = "promo.featured_category"
    case promoCodeVisible = "promo.code_field.visible"
    case promoFeaturedVisible = "promo.featured.visible"
    case promoFeaturedTitle = "promo.featured.title"
    case promoFeaturedSubtitle = "promo.featured.subtitle"
    case promoFeaturedCode = "promo.featured.code"
    case promoFeaturedBadge = "promo.featured.badge_text"
    case promoFeaturedDeeplink = "promo.featured.deeplink"
    case promoListOrder = "promo.list.order"
    // Gamification
    case streakEnabled = "gamification.streak.enabled"
    case streakTarget = "gamification.streak.target_days"
    case streakChip = "gamification.streak.chip_text"
    case streakRewardType = "gamification.streak.reward_type"
    case streakRewardPoints = "gamification.streak.reward_points"
    case badgeLabel = "gamification.badge.label"
    case badgeCycles = "gamification.badge.cycles_required"
    case stampSet = "gamification.stamp.set"
    case stampFinalSymbol = "gamification.stamp.final_symbol"
    case stampColor = "gamification.stamp.color_hex"
    case stampAnimation = "gamification.stamp.animation_enabled"
    case loyaltyEnabled = "gamification.loyalty.enabled"
    case loyaltyLabel = "gamification.loyalty.label"
    case loyaltyCatalogVisible = "gamification.loyalty.catalog_visible"
    case progressColor = "gamification.progress_bar.color_hex"
    // Cross-sell
    case crossVisible = "crosssell.card.visible"
    case crossTitle = "crosssell.card.title"
    case crossCTA = "crosssell.card.cta_text"
    case crossCategory = "crosssell.card.category"
    case crossCashback = "crosssell.card.cashback_amount"
    case crossVariant = "crosssell.card.variant"
    // Theme and flags
    case themePrimary = "theme.primary_color_hex"
    case themeRadius = "theme.corner_radius"
    case flagQrisEducation = "flags.qris_education_tile"
    case flagOneTapPay = "flags.one_tap_pay"
    // Incentives (loyalty wallet credit and debit rules)
    case incEnabled = "incentives.enabled"
    case incExpiry = "incentives.expiry_duration"
    case incKycEnabled = "incentives.kyc_completed.enabled"
    case incKycPoints = "incentives.kyc_completed.points"
    case incTopupEnabled = "incentives.first_topup.enabled"
    case incTopupPoints = "incentives.first_topup.points"
    case incQrisEnabled = "incentives.qris_payment.enabled"
    case incQrisPer10k = "incentives.qris_payment.points_per_10k"
    case incQrisMax = "incentives.qris_payment.max_points"
    case incBillEnabled = "incentives.bill_payment.enabled"
    case incBillPoints = "incentives.bill_payment.points"
    case incHabitEnabled = "incentives.habit_third_payment.enabled"
    case incHabitPoints = "incentives.habit_third_payment.points"
    case incCycleEnabled = "incentives.streak_cycle.enabled"
    case incCycleBucket = "incentives.streak_cycle.bucket"
    case incCycleActivation = "incentives.streak_cycle.activation_duration"
    case incPromoEnabled = "incentives.promo_code_redeemed.enabled"
    case incPromoPoints = "incentives.promo_code_redeemed.points"
    case incNewCatEnabled = "incentives.new_category.enabled"
    case incNewCatPoints = "incentives.new_category.points"
    case incPayEnabled = "incentives.pay_with_points.enabled"
    case incPayRate = "incentives.pay_with_points.points_to_rupiah"
    case incPayMaxPercent = "incentives.pay_with_points.max_percent_of_bill"

    var name: String { Self.group + "." + rawValue }

    var screen: String { String(rawValue.split(separator: ".").first ?? "") }

    var defaultValue: PEValue {
        switch self {
        case .heroVisible: return .bool(true)
        case .heroTitle: return .string("Halo, mau ngapain hari ini?")
        case .heroSubtitle: return .string("Bayar, top up, dan kirim uang dalam satu aplikasi")
        case .heroImageURL: return .string("img_banner_home")   // bundled asset name
        case .heroCTAText: return .string("Lihat Promo")
        case .heroDeeplink: return .string("linkajademo://promo")
        case .quickActionsOrder: return .string("kirim,terima,qris,topup,pulsa,tagihan,transport,donasi")
        case .quickActionsHighlight: return .string("qris")
        case .balanceShowTopup: return .bool(true)
        case .balanceTopupText: return .string("Isi Saldo")
        case .topupSuggested: return .string("50000,100000,200000,500000")
        case .methodsOrder: return .string("bank_va,atm,debit_card,minimarket")
        case .methodsHighlight: return .string("bank_va")
        case .topupDefault: return .int(100_000)
        case .bonusEnabled: return .bool(false)
        case .bonusMin: return .int(100_000)
        case .bonusAmount: return .int(10_000)
        case .bonusBanner: return .string("Top up Rp100.000, dapat bonus Rp10.000")
        case .promoLayout: return .string("carousel")
        case .promoFeatured: return .string("qris")
        case .promoCodeVisible: return .bool(true)
        case .promoFeaturedVisible: return .bool(true)
        case .promoFeaturedTitle, .promoFeaturedSubtitle, .promoFeaturedCode, .promoFeaturedBadge,
             .promoFeaturedDeeplink, .promoListOrder: return .string("")
        case .streakEnabled: return .bool(true)
        case .streakTarget: return .int(5)
        case .streakChip: return .string("hari beruntun")
        case .streakRewardType: return .string("points")
        case .streakRewardPoints: return .int(500)
        case .badgeLabel: return .string("Komuter Setia")
        case .badgeCycles: return .int(4)
        case .stampSet: return .string("classic")
        case .stampFinalSymbol: return .string("trophy.fill")
        case .stampColor: return .string("#E4002B")
        case .stampAnimation: return .bool(true)
        case .loyaltyEnabled: return .bool(true)
        case .loyaltyLabel: return .string("Poin Loyalty")
        case .loyaltyCatalogVisible: return .bool(true)
        case .progressColor: return .string("#E4002B")
        case .crossVisible: return .bool(true)
        case .crossTitle: return .string("QRIS-mu udah jago, coba bayar tagihan yuk")
        case .crossCTA: return .string("Coba Sekarang")
        case .crossCategory: return .string("tagihan")
        case .crossCashback: return .int(7_500)
        case .crossVariant: return .string("hemat")
        case .themePrimary: return .string("#E4002B")
        case .themeRadius: return .int(16)
        case .flagQrisEducation: return .bool(false)
        case .flagOneTapPay: return .bool(false)
        case .incEnabled: return .bool(true)
        case .incExpiry: return .string("")
        case .incKycEnabled: return .bool(true)
        case .incKycPoints: return .int(200)
        case .incTopupEnabled: return .bool(true)
        case .incTopupPoints: return .int(150)
        case .incQrisEnabled: return .bool(true)
        case .incQrisPer10k: return .int(1)
        case .incQrisMax: return .int(100)
        case .incBillEnabled: return .bool(true)
        case .incBillPoints: return .int(50)
        case .incHabitEnabled: return .bool(true)
        case .incHabitPoints: return .int(200)
        case .incCycleEnabled: return .bool(true)
        case .incCycleBucket: return .string("ACTIVE")
        case .incCycleActivation: return .string("1d")
        case .incPromoEnabled: return .bool(true)
        case .incPromoPoints: return .int(100)
        case .incNewCatEnabled: return .bool(true)
        case .incNewCatPoints: return .int(100)
        case .incPayEnabled: return .bool(true)
        case .incPayRate: return .int(10)
        case .incPayMaxPercent: return .int(50)
        }
    }

    var typeName: String {
        switch defaultValue { case .bool: return "boolean"; case .string: return "string"; case .int: return "number" }
    }
}

/// Quick action tokens the dashboard may use in LinkAJA.home.quick_actions.order.
enum QuickActionToken: String, CaseIterable {
    case kirim, terima, qris, topup, pulsa, tagihan, transport, donasi
}
