import Foundation

/// Single source of truth for every CleverTap name used by the app.
/// Custom events and custom profile properties get the LinkAJA_ prefix here and nowhere else.
enum CT {
    static let prefix = "LinkAJA_"

    /// Custom events: prefix + Title_Case words.
    enum Event: String, CaseIterable {
        case login = "Login"
        case logout = "Logout"
        // 6.1 Onboarding
        case appInstalled = "App_Installed"
        case registered = "Registered"
        case kycStarted = "KYC_Started"
        case kycStepCompleted = "KYC_Step_Completed"
        case kycCompleted = "KYC_Completed"
        // 6.2 First transaction
        case topUpCompleted = "Top_Up_Completed"
        case qrisPaymentCompleted = "QRIS_Payment_Completed"
        case transferCompleted = "Transfer_Completed"
        case voucherViewed = "Voucher_Viewed"
        case voucherRedeemed = "Voucher_Redeemed"
        // 6.3 Repeat transaction
        case billPaymentCompleted = "Bill_Payment_Completed"
        case billReminderViewed = "Bill_Reminder_Viewed"
        // 6.4 Streak
        case transportPaymentCompleted = "Transport_Payment_Completed"
        case streakUpdated = "Streak_Updated"
        case streakBroken = "Streak_Broken"
        case streakRewardEarned = "Streak_Reward_Earned"
        // 6.5 and 6.6 Churn and reactivation
        case transactionCompleted = "Transaction_Completed"
        case churnOfferViewed = "Churn_Offer_Viewed"
        case churnOfferRedeemed = "Churn_Offer_Redeemed"
        case winbackOfferRedeemed = "Winback_Offer_Redeemed"
        // 6.7 Cross-sell
        case categoryUsed = "Category_Used"
        case newCategoryUsed = "New_Category_Used"
        case offerVariantViewed = "Offer_Variant_Viewed"
        // 6.8 Campaign
        case campaignViewed = "Campaign_Viewed"
        case promoCodeCopied = "Promo_Code_Copied"
        case promoCodeApplied = "Promo_Code_Applied"
        case promoCodeRedeemed = "Promo_Code_Redeemed"
        // Product Experiences measurement
        case homeBannerViewed = "Home_Banner_Viewed"
        case homeBannerClicked = "Home_Banner_Clicked"
        case quickActionClicked = "Quick_Action_Clicked"
        case topUpAmountSelected = "Top_Up_Amount_Selected"
        case crossSellCardViewed = "Cross_Sell_Card_Viewed"
        case crossSellCardClicked = "Cross_Sell_Card_Clicked"
        case promoLayoutViewed = "Promo_Layout_Viewed"
        // Loyalty wallet, stamps and promos
        case loyaltyPointsEarned = "Loyalty_Points_Earned"
        case loyaltyPointsRedeemed = "Loyalty_Points_Redeemed"
        case walletCredited = "Wallet_Credited"
        case walletDebited = "Wallet_Debited"
        case walletReversed = "Wallet_Reversed"
        case walletOperationFailed = "Wallet_Operation_Failed"
        case payWithPointsUsed = "Pay_With_Points_Used"
        case streakStampEarned = "Streak_Stamp_Earned"
        case streakCycleCompleted = "Streak_Cycle_Completed"
        case badgeEarned = "Badge_Earned"
        case promoViewed = "Promo_Viewed"
        case promoClicked = "Promo_Clicked"

        var name: String { CT.prefix + rawValue }
    }

    /// Custom user profile properties: prefix + snake_case.
    enum Prop: String, CaseIterable {
        // Login
        case firstName = "first_name"
        case city, personaType = "persona_type", kycStatus = "kyc_status", kycTier = "kyc_tier"
        case walletBalance = "wallet_balance", preferredLanguage = "preferred_language"
        case whatsappOptIn = "whatsapp_opt_in", emailOptIn = "email_opt_in", pushOptIn = "push_opt_in"
        // 6.1
        case kycStartedAt = "kyc_started_at", registrationDate = "registration_date"
        case installSource = "install_source", voucherOnboardingEligible = "voucher_onboarding_eligible"
        // 6.2
        case hasTransacted = "has_transacted", firstTransactionDate = "first_transaction_date"
        case kycCompletedAt = "kyc_completed_at", transactionLikelihood = "transaction_likelihood"
        case abVariant = "ab_variant"
        // 6.3
        case txnCount30d = "txn_count_30d", dominantCategory = "dominant_category"
        case usualPaymentDay = "usual_payment_day", nextBillDueDate = "next_bill_due_date"
        case habitProgressCurrent = "habit_progress_current", habitProgressTarget = "habit_progress_target"
        // 6.4
        case streakDays = "streak_days", lastStreakDate = "last_streak_date"
        case streakBrokenAt = "streak_broken_at"
        case streakCyclesCompleted = "streak_cycles_completed", badgeEarned = "badge_earned"
        case avgTopupAmount = "avg_topup_amount"
        // Loyalty wallet
        case loyaltyPoints = "loyalty_points", loyaltyWalletId = "loyalty_wallet_id"
        case lastIncentiveRule = "last_incentive_rule", lastIncentiveDate = "last_incentive_date"
        case holdoutGroup = "holdout_group"
        // 6.5
        case txnCount90d = "txn_count_90d", avgTxnValue90d = "avg_txn_value_90d"
        case churnPropensity = "churn_propensity", unusedPromoCount = "unused_promo_count"
        case lastTransactionDate = "last_transaction_date", controlGroup = "control_group"
        // 6.6
        case daysSinceLastTransaction = "days_since_last_transaction", sunsetList = "sunset_list"
        case lastMessageSentAt = "last_message_sent_at"
        // 6.7
        case categoriesUsed = "categories_used", rfmSegment = "rfm_segment"
        case activeDays90d = "active_days_90d", nextBestCategory = "next_best_category"
        // 6.8
        case favoriteCategory = "favorite_category", lastCampaignId = "last_campaign_id"
        case campaignMessagesToday = "campaign_messages_today", redeemedCampaignIds = "redeemed_campaign_ids"
        case paydayWindowActive = "payday_window_active"
        // Product Experiences
        case peVariantCrossSell = "pe_variant_cross_sell"

        var key: String { CT.prefix + rawValue }
    }

    /// CleverTap reserved profile keys. Never prefixed.
    enum Reserved: String {
        case identity = "Identity", name = "Name", email = "Email", phone = "Phone", gender = "Gender"
        case msgEmail = "MSG-email", msgPush = "MSG-push", msgWhatsapp = "MSG-whatsapp"
    }

    /// Properties attached to events. Plain snake_case, never prefixed.
    enum EventProp: String {
        case installSource = "install_source", persona, step
        case durationSeconds = "duration_seconds", method
        case isFirstTransaction = "is_first_transaction", category, amount
        case isWorkday = "is_workday", streakDays = "streak_days", reward
        case isFirstInCategory = "is_first_in_category", variant
        case code, discountPercent = "discount_percent", maxDiscount = "max_discount"
        case minTransaction = "min_transaction", campaignId = "campaign_id"
        case voucherId = "voucher_id", offerId = "offer_id", daysLeft = "days_left"
        case title, deeplink, action, position, layout
        case isHighlighted = "is_highlighted", isSuggested = "is_suggested", bonusApplied = "bonus_applied"
        case targetDays = "target_days", points, rule
        case orderId = "order_id", txnId = "txn_id", balanceAfter = "balance_after", bucket
        case type, operation, errorCode = "error_code", message
        case rupiahSaved = "rupiah_saved", billAmount = "bill_amount"
        case dayIndex = "day_index", stampSymbol = "stamp_symbol", isFinal = "is_final"
        case cycleNumber = "cycle_number", pointsAwarded = "points_awarded"
        case badgeLabel = "badge_label", cyclesCompleted = "cycles_completed"
        case promoId = "promo_id", source
    }
}
