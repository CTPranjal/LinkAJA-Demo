# LinkAja Demo (CleverTap sales demo)

Native SwiftUI app (iOS 16+) that mimics the LinkAja app and emits the events and profile properties for eight CleverTap journeys. All data is mocked locally. No real payments, no backend.

## 1. Setup

```bash
cd LinkAJA            # this folder
pod install           # already run once; run again if Pods/ is missing
open LinkAJADemo.xcworkspace   # always the .xcworkspace, never the .xcodeproj
```

1. Open `LinkAJADemo/Info.plist` and replace the placeholders:
   - `CleverTapAccountID` = your Account ID
   - `CleverTapToken` = your Account Token
   - `CleverTapRegion` = region code only, e.g. `in1`, `sg1`, `us1`, `eu1`. Leave the key out entirely if your account uses the default region (the current Info.plist does this)
2. Pick an iPhone simulator and Run. The project builds with no other changes (verified on Xcode 26.4, iPhone 17 Pro simulator).
3. For real push, run on a device (see section 3). Simulators cannot receive APNs pushes from CleverTap.

The `.xcodeproj` is generated from `project.yml` with XcodeGen (`xcodegen generate`). You do not need XcodeGen to build; it is only for regenerating the project.

**IDFV is disabled.** `CleverTapDisableIDFV = YES` is in Info.plist and the app never reads `identifierForVendor`. The SDK uses its own generated CleverTap ID instead (shown in Demo Tools).

SDK: `CleverTap-iOS-SDK` 7.8.2 via CocoaPods only. The pod pulls in SDWebImage as its own dependency. No other third-party code.

## 2. How to use the app

1. Log in as **Budi** (Jakarta commuter, KYC completed) or **Siti** (Surabaya student, KYC pending).
2. Open the hidden **Demo Tools**: Profile tab, tap the "LinkAja Demo v1.0" label 5 times.
3. Tap a scenario, read the changed profile properties (red), then do the app action from section 8.
4. The activity log at the bottom of Demo Tools shows every event and profile push sent.

Language: Bahasa Indonesia by default, English toggle in Profile (also sets `LinkAJA_preferred_language`).

## 3. Push (APNs) setup

1. Apple Developer, Certificates, Identifiers and Profiles, Keys: create a key with **Apple Push Notifications service (APNs)**, download the `.p8`. Note Key ID and Team ID.
2. CleverTap dashboard, Settings, Channels, Mobile Push, iOS: upload the `.p8` with Key ID, Team ID and the bundle ID.
3. In Xcode, Signing & Capabilities: set your Team and a unique bundle ID (default `com.clevertap.demo.linkaja`). The Push Notifications capability (`aps-environment` in `LinkAJADemo.entitlements`) and Background Modes, Remote notifications (Info.plist) are already enabled.
4. Run on a device, log in, accept the permission prompt. The token is forwarded with `setPushToken`.
5. Rich push (images, buttons) additionally needs a Notification Service Extension target with the CleverTap Push Notification pod. This is not included to keep the project simple. Basic push and deep links work without it.

## 4. Architecture

```
LinkAJADemo/
  App/        LinkAJADemoApp (SwiftUI + AppDelegate adaptor), AppDelegate (CleverTap init, push)
  Models/     Persona, LocalState, formatting and theme
  Services/   CTNames (all event/property names), CleverTapManager (only file that imports the SDK),
              AppState (session, mock profile, transaction logic), ScenarioEngine, DeepLinkRouter
  Views/      Screens and Components
  Resources/  Assets.xcassets (logo, banners, service icons)
```

Naming rule enforced in `CTNames.swift`: `CT.prefix = "LinkAJA_"`, `CT.Event`, `CT.Prop` apply it. Reserved keys (`CT.Reserved`) and event properties (`CT.EventProp`) are unprefixed. System events (App Launched, Notification Viewed, Notification Clicked) are never recorded manually.

Mocked as profile properties (set by scenarios, not real systems): AppsFlyer attribution (`LinkAJA_install_source`, `LinkAJA_App_Installed`), BigQuery sync fields (`txn_count_90d`, `avg_txn_value_90d`, `unused_promo_count`, `rfm_segment`, `active_days_90d`) and Predictions (`transaction_likelihood`, `churn_propensity`, `next_best_category`).

Extra properties I added beyond your list: `LinkAJA_first_name` (for message personalization) and `LinkAJA_payday_window_active` (segment for 6.8).

## 5. Initialization order (AppDelegate)

`CleverTap.setDebugLevel(2)`, `CleverTap.autoIntegrate()`, `CleverTap.sharedInstance()`, then URL and in-app delegates and `initializeInbox`.

## 6. Deep links

| URL | Opens |
|---|---|
| `linkajademo://kyc` | KYC flow |
| `linkajademo://qris-scan` | Scan tab |
| `linkajademo://promo` | Promo tab (`?code=GAJIAN25` prefills the code field) |
| `linkajademo://bill-payment` | Bill payment |
| `linkajademo://streak` | Streak tracker |
| `linkajademo://inbox` | Inbox tab |
| `linkajademo://home` (or any other host) | Home |

Test: `xcrun simctl openurl booted "linkajademo://promo?code=GAJIAN25"`. Links received before login are replayed after login.

## 7. Event and property dictionary

### Events (custom, all `LinkAJA_` prefixed)

| Event | Event properties |
|---|---|
| LinkAJA_Login / LinkAJA_Logout | persona |
| LinkAJA_App_Installed | install_source |
| LinkAJA_Registered | |
| LinkAJA_KYC_Started | |
| LinkAJA_KYC_Step_Completed | step (ktp, selfie) |
| LinkAJA_KYC_Completed | duration_seconds, method |
| LinkAJA_Top_Up_Completed | amount, is_first_transaction |
| LinkAJA_QRIS_Payment_Completed | amount, is_first_transaction, is_workday |
| LinkAJA_Transfer_Completed | amount, is_first_transaction |
| LinkAJA_Voucher_Viewed / _Redeemed | voucher_id (days_left on viewed) |
| LinkAJA_Bill_Payment_Completed | category (PLN, pulsa, internet), amount |
| LinkAJA_Bill_Reminder_Viewed | category, days_left |
| LinkAJA_Transport_Payment_Completed | amount, is_workday |
| LinkAJA_Streak_Updated | streak_days |
| LinkAJA_Streak_Broken | |
| LinkAJA_Streak_Reward_Earned | reward (cashback_5000, badge_komuter_setia) |
| LinkAJA_Transaction_Completed | amount, category |
| LinkAJA_Churn_Offer_Viewed / _Redeemed | offer_id |
| LinkAJA_Winback_Offer_Redeemed | offer_id |
| LinkAJA_Category_Used | category (tagihan, transport, donasi, zakat, qris) |
| LinkAJA_New_Category_Used | category, is_first_in_category |
| LinkAJA_Offer_Variant_Viewed | variant (hemat, praktis) |
| LinkAJA_Campaign_Viewed | campaign_id |
| LinkAJA_Promo_Code_Copied | code |
| LinkAJA_Promo_Code_Applied | code, discount_percent, max_discount, min_transaction |
| LinkAJA_Promo_Code_Redeemed | code, amount, campaign_id |
| LinkAJA_Home_Banner_Viewed / _Clicked | variant (A/B variant name or `default`), title, deeplink |
| LinkAJA_Quick_Action_Clicked | action, position (1 based), is_highlighted |
| LinkAJA_Top_Up_Amount_Selected | amount, is_suggested, bonus_applied |
| LinkAJA_Cross_Sell_Card_Viewed / _Clicked | category, variant (hemat, praktis) |
| LinkAJA_Promo_Layout_Viewed | layout (carousel, grid) |

Note: the bill event `category` is PLN, pulsa or internet. Transport and QRIS have their own events.

### User profile properties

Reserved (unprefixed): Identity, Name, Email, Phone, Gender, MSG-email, MSG-push, MSG-whatsapp.

Custom: `LinkAJA_` + `first_name, city, persona_type, kyc_status, kyc_tier, wallet_balance, preferred_language, whatsapp_opt_in, email_opt_in, push_opt_in, kyc_started_at, registration_date, install_source, voucher_onboarding_eligible, has_transacted, first_transaction_date, kyc_completed_at, transaction_likelihood, ab_variant, txn_count_30d, dominant_category, usual_payment_day, next_bill_due_date, habit_progress_current, habit_progress_target, streak_days, streak_best, last_streak_date, streak_broken_at, badge_komuter_setia, holdout_group, txn_count_90d, avg_txn_value_90d, churn_propensity, unused_promo_count, last_transaction_date, control_group, days_since_last_transaction, sunset_list, last_message_sent_at, categories_used, rfm_segment, active_days_90d, next_best_category, favorite_category, last_campaign_id, campaign_messages_today, redeemed_campaign_ids, payday_window_active`.

`LinkAJA_ab_variant` is shared: 6.2 uses A or B, 6.7 uses hemat or praktis. Scenario 7 sets the 6.7 values, other scenarios reset it to A or B. Segment on the value you need.

Opt-ins: the Profile toggles push `MSG-email`, `MSG-push`, `MSG-whatsapp` plus the three `LinkAJA_*_opt_in` properties in one profile push.

## 8. Event to use case map

| Event | 6.1 | 6.2 | 6.3 | 6.4 | 6.5 | 6.6 | 6.7 | 6.8 |
|---|---|---|---|---|---|---|---|---|
| LinkAJA_App_Installed | x | | | | | | | |
| LinkAJA_Registered | x | | | | | | | |
| LinkAJA_KYC_Started / Step_Completed / Completed | x | x (KYC completed starts the 48h clock) | | | | | | |
| LinkAJA_Top_Up_Completed | | x | | | | | | |
| LinkAJA_QRIS_Payment_Completed | | x | | x | | | x | |
| LinkAJA_Transfer_Completed | | x | | | | | | |
| LinkAJA_Voucher_Viewed / Redeemed | x | x | | | | | | |
| LinkAJA_Bill_Payment_Completed | | | x | | | | x | |
| LinkAJA_Bill_Reminder_Viewed | | | x | | | | | |
| LinkAJA_Transport_Payment_Completed | | | | x | | | x | |
| LinkAJA_Streak_Updated / Broken / Reward_Earned | | | | x | | | | |
| LinkAJA_Transaction_Completed | | | | | x | x | | |
| LinkAJA_Churn_Offer_Viewed / Redeemed | | | | | x | | | |
| LinkAJA_Winback_Offer_Redeemed | | | | | | x | | |
| LinkAJA_Category_Used / New_Category_Used | | | | | | | x | |
| LinkAJA_Offer_Variant_Viewed | | | | | | | x | |
| LinkAJA_Campaign_Viewed / Promo_Code_* | | | | | | | | x |
| LinkAJA_Home_Banner_*, Quick_Action_Clicked, Top_Up_Amount_Selected, Cross_Sell_Card_*, Promo_Layout_Viewed | Product Experiences goal and conversion events (section 13); Cross_Sell_Card_* also supports 6.7 | | | | | | | |
| LinkAJA_Login / Logout | session events, usable in any journey exit or entry rule |

## 9. Per use case demo script

Notes for all: the persona first name is in `Name` and `LinkAJA_first_name` for personalization. Every scenario button first resets the profile to a clean baseline, so run scenarios in any order. Demo mode: every transport or QRIS payment counts as one streak day.

### 6.1 Onboarding
- Trigger events: LinkAJA_App_Installed, LinkAJA_Registered, LinkAJA_KYC_Started, LinkAJA_KYC_Step_Completed, LinkAJA_KYC_Completed.
- Profile set: kyc_status (pending, then completed), kyc_started_at, registration_date, install_source, voucher_onboarding_eligible, kyc_completed_at.
- Scenario: **1. Just registered, KYC pending**.
- App action: kill and reopen the app (App Launched triggers the in-app "Verifikasi cuma 2 menit", CTA `linkajademo://kyc`). Tap it or the Home banner, complete KTP, selfie, done. Open Promo to see the Rp10.000 voucher card (min top-up Rp50.000, 7 days); tap Klaim.
- Dashboard: Journey "Welcome dan Verifikasi" entry on LinkAJA_Registered, wait 1 hour, if no LinkAJA_KYC_Completed then push, in-app (on App Launched, segment kyc_status = pending) and email on day 1. Goal LinkAJA_KYC_Completed within 48h.

### 6.2 First transaction
- Trigger events: LinkAJA_KYC_Completed, then LinkAJA_Top_Up_Completed or LinkAJA_QRIS_Payment_Completed or LinkAJA_Transfer_Completed (is_first_transaction), LinkAJA_Voucher_Viewed, LinkAJA_Voucher_Redeemed.
- Profile set: has_transacted, first_transaction_date, kyc_completed_at, transaction_likelihood, ab_variant.
- Scenario: **2. KYC done, no transaction yet** (Budi: likely, variant A; Siti: unlikely, variant B).
- App action: Promo tab shows the Rp15.000 voucher "Sisa 6 hari", tap Pakai Sekarang, which goes to the Scan tab. Simulate Scan and pay. The voucher is redeemed on the first QRIS payment.
- Dashboard: Journey entry LinkAJA_KYC_Completed, exit on has_transacted = true; A/B test on LinkAJA_ab_variant (A cashback QRIS, B edukasi); push plus in-app (countdown, key-value `days_left`) with CTA `linkajademo://qris-scan`. Segment: transaction_likelihood = unlikely for a stronger incentive.

### 6.3 Repeat transaction
- Trigger events: LinkAJA_Bill_Payment_Completed, LinkAJA_Bill_Reminder_Viewed.
- Profile set: txn_count_30d, dominant_category, usual_payment_day, next_bill_due_date, habit_progress_current (2), habit_progress_target (3).
- Scenario: **3. 2 of 3 transactions, due bill in 3 days**.
- App action: open Inbox (local progress card "2 dari 3 transaksi", or the CleverTap card, see below), tap Bayar Sekarang, pay a PLN bill. Progress becomes 3 of 3 and Rp10.000 cashback is credited.
- Dashboard: Campaign push 3 days before `LinkAJA_next_bill_due_date` ("Tagihan listrikmu jatuh tempo 3 hari lagi", `linkajademo://bill-payment`). Inbox card with key-value pairs `progress_current` = `2`, `progress_target` = `3`, `cta_label` = `Bayar Sekarang` and a link to `linkajademo://bill-payment`; the app draws the progress bar from those keys.

### 6.4 Retention (commuter streak)
- Trigger events: LinkAJA_Transport_Payment_Completed, LinkAJA_QRIS_Payment_Completed (is_workday), LinkAJA_Streak_Updated, LinkAJA_Streak_Broken, LinkAJA_Streak_Reward_Earned.
- Profile set: streak_days, streak_best, last_streak_date, streak_broken_at, badge_komuter_setia, holdout_group.
- Scenario: **4. Commuter streak at 3 of 5 days**.
- App action: Home streak card or `linkajademo://streak`, tap "Bayar Transport (+1 hari)" twice: day 5 fires Streak_Reward_Earned (cashback_5000). Tap "Simulasi streak putus" to fire LinkAJA_Streak_Broken and see the local nudge card in Inbox.
- Dashboard: in-app (custom HTML, see section 10) "Streak 3/5 hari" with chip "3 hari beruntun", CTA `linkajademo://streak`, triggered by LinkAJA_Streak_Updated; Inbox soft nudge on LinkAJA_Streak_Broken; holdout via a campaign control group on `LinkAJA_holdout_group`. The app behaves the same for holdout users.

### 6.5 Churn prevention
- Trigger events: LinkAJA_Churn_Offer_Viewed, LinkAJA_Churn_Offer_Redeemed, LinkAJA_Transaction_Completed.
- Profile set: txn_count_90d, avg_txn_value_90d, churn_propensity (high_risk), wallet_balance, unused_promo_count, last_transaction_date, control_group.
- Scenario: **5. High churn risk, balance still present**.
- App action: open Promo (card "Kami kangen kamu" fires Churn_Offer_Viewed), tap Gunakan (simulated payment plus Churn_Offer_Redeemed). Inbox shows the local "Kami kangen kamu" card, CTA `linkajademo://promo`.
- Dashboard: Segment churn_propensity = high_risk AND wallet_balance > 0. IntelliNODE journey choosing push vs in-app per user; Inbox card "Kami kangen kamu", Rp10.000 cashback for 1 transaction in 7 days. Control group on `LinkAJA_control_group` = true. Exit on LinkAJA_Transaction_Completed.

### 6.6 Reactivation
- Trigger events: App Launched (system), LinkAJA_Transaction_Completed, LinkAJA_Winback_Offer_Redeemed.
- Profile set: days_since_last_transaction, wallet_balance, opt-in properties, sunset_list, last_message_sent_at.
- Scenario: **6. Dormant 45 days, balance Rp75.000**.
- App action: kill and relaunch the app (App Launched). Open Promo: "Saldo Rp75.000 masih nunggu", tap Gunakan to redeem (Winback_Offer_Redeemed, Rp15.000 cashback). In Profile, toggle WhatsApp or Email off to demo suppression.
- Dashboard: Segment days_since_last_transaction 30 to 90 AND wallet_balance > 0. Journey wave 1 email plus push on day 0 ("Saldo Rp75.000 masih nunggu", CTA to `linkajademo://home`), wait 3 days, if no App Launched then WhatsApp or SMS (add-on); after 7 days with no LinkAJA_Transaction_Completed set `LinkAJA_sunset_list` = true.

### 6.7 Cross-sell
- Trigger events: LinkAJA_Category_Used, LinkAJA_New_Category_Used, LinkAJA_Offer_Variant_Viewed.
- Profile set: categories_used, dominant_category, rfm_segment, active_days_90d, next_best_category, ab_variant (hemat, praktis).
- Scenario: **7. QRIS only user, next best category predicted**.
- App action: Home shows the cross-sell card "QRIS-mu udah jago, coba bayar tagihan yuk" (a Product Experiences card, see section 13), Coba Sekarang opens bill payment. Pay a bill: New_Category_Used fires, categories_used becomes [qris, tagihan], Rp7.500 cashback, and next_best_category is cleared so the cycle changes.
- Dashboard: Segment categories_used has only qris AND rfm_segment = high. Email plus push plus in-app, A/B on `LinkAJA_ab_variant`. Exit on LinkAJA_New_Category_Used.

### 6.8 Campaign engagement (payday)
- Trigger events: LinkAJA_Campaign_Viewed, LinkAJA_Promo_Code_Copied, LinkAJA_Promo_Code_Applied, LinkAJA_Promo_Code_Redeemed.
- Profile set: favorite_category, rfm_segment, last_campaign_id, campaign_messages_today, redeemed_campaign_ids, payday_window_active.
- Scenario: **8. Payday window active**.
- App action: Home shows the Gajian banner. Promo: tap Salin (Promo_Code_Copied), Pakai Kode (Applied), pick Rp150.000 and Bayar dengan kode (Redeemed, 10 percent, max Rp25.000, min Rp100.000). Merchant tiles follow `LinkAJA_favorite_category`. Use `linkajademo://promo?code=GAJIAN25` for the in-app CTA. In Demo Tools use "Simulate campaign message" to count toward the 2 per day cap.
- Dashboard: in-app "Gajian Deals!" with chip GAJIAN25, CTA "Pakai Kode" to `linkajademo://promo?code=GAJIAN25`. Frequency cap max 2 per day plus segment on `LinkAJA_campaign_messages_today`. Segment payday_window_active = true.

## 10. In-app and inbox notes

- The SDK displays in-apps. The app implements `CleverTapInAppNotificationDelegate` (logs key-value extras) and `CleverTapURLDelegate`, which routes CTA URLs to the router and returns `false` so the SDK does not also open them.
- Custom HTML in-apps (countdown, streak): author them in the dashboard. Use anchor tags like `<a href="linkajademo://streak">Lihat Progres</a>` or the dashboard's built-in CTA/close handlers.
- Inbox: `initializeInbox`, unread badge on the Inbox tab from `getInboxMessageUnreadCount`, custom card rendering with `getAllInboxMessages`, view and click events recorded, click opens the card link through the router. Cards marked "Demo lokal" are local fallbacks so the journey works without a dashboard campaign.

## 11. Dashboard objects to create

| Use case | Segments | Journey / campaigns | Templates |
|---|---|---|---|
| 6.1 | kyc_status = pending; Did LinkAJA_Registered but not LinkAJA_KYC_Completed | Welcome and Verifikasi journey, goal LinkAJA_KYC_Completed in 48h | Push, in-app pop-up (kyc_status pending), email |
| 6.2 | KYC done AND has_transacted = false; transaction_likelihood = unlikely | First Transaction journey with A/B on ab_variant; exit on has_transacted | Push and in-app voucher Rp15.000 countdown |
| 6.3 | habit_progress_current = 2; next_bill_due_date within 3 days | Bill reminder push campaign | Push, Inbox card with key-values progress_current, progress_target, cta_label |
| 6.4 | streak_days >= 3; Did LinkAJA_Streak_Broken; holdout_group = true | Streak campaigns triggered by Streak_Updated, Streak_Broken, with holdout | Custom HTML in-app, push, Inbox nudge |
| 6.5 | churn_propensity = high_risk AND wallet_balance > 0; control_group | IntelliNODE journey (push vs in-app) | Inbox "Kami kangen kamu", push, in-app |
| 6.6 | days_since_last_transaction 30 to 90 AND wallet_balance > 0; sunset_list = true | Win-back journey wave 1 (email, push), wave 2 (WhatsApp or SMS), sunset update | Email, push, WhatsApp template |
| 6.7 | categories_used only qris AND rfm_segment = high | Cross-sell journey with A/B on ab_variant | Email, push, in-app |
| 6.8 | payday_window_active = true; favorite_category | Payday campaign with frequency cap 2 per day | In-app "Gajian Deals!", push, email |

## 12. Things I was unsure about (verify)

- `shouldHandleCleverTap(_:for:)` is the Swift name of the URL delegate method in 7.8.2. Returning `false` hands handling to the app. If the SDK also opens the URL you may see a duplicate; the router ignores repeats within 1 second.
- With `autoIntegrate()` the SDK swizzles the push delegate methods and registers tokens itself. The explicit `setPushToken` call is harmless duplication kept because you asked for it.
- CleverTap has no logout call. Logout fires LinkAJA_Logout and clears local state; the next login calls `onUserLogin`, which switches the profile.
- Custom HTML in-app link handling: I did not verify the exact dashboard JavaScript API; use plain `href` deep links.
- Push tapping while the app is cold-started is routed by the URL delegate and the `wzrk_dl` fallback in AppDelegate. Test on a device.
- Scenarios 5 and 6 have no behavioral entry event by design (they are profile and segment driven).
- I could not tap through the UI in an automated way here: the build succeeds and the login screen was checked in the simulator, the remaining screens were not walked through visually.

## 13. Product Experiences (CleverTap Variables)

Change the app's look, copy, layout and logic from the dashboard, A/B test it, and measure it with events.

**Code:** `Services/PEKeys.swift` (every variable, default and screen), `Services/PEStore.swift` (defines variables, live values, typed accessors, local previews), `Services/ThemeProvider.swift` (primary color and corner radius), `Views/Screens/PEInspectorView.swift` (Demo Tools, "PE Inspector"). CleverTap calls go through `CleverTapManager` (`defineVariable`, `fetchVariables`, `onVariablesChanged`, `syncVariableDefinitionsInDebug`).

**Lifecycle:** variables are defined once in `CleverTapManager.configure()` right after `CleverTap.sharedInstance()` and before the first fetch. Values are fetched on launch, on login, when the app returns to the foreground, and on pull-to-refresh on Home. A variables-changed callback plus a per-variable `onValueChanged` callback publish changes, so SwiftUI re-renders live. Missing or malformed values fall back to the defaults (empty amounts string, bad hex color, unknown quick action token, and so on). Comma separated strings are trimmed, de-duplicated, and unknown tokens are ignored.

### Variable table

All names start with `LinkAJA.` (one nested group).

| Name | Type | Default | What it changes |
|---|---|---|---|
| home.hero_banner.visible | boolean | true | Shows or hides the Home hero banner |
| home.hero_banner.title | string | Halo, mau ngapain hari ini? | Banner title |
| home.hero_banner.subtitle | string | Bayar, top up, dan kirim uang dalam satu aplikasi | Banner subtitle |
| home.hero_banner.image_url | string | img_banner_home | `https://` URL, or a bundled asset name. Falls back to the default asset on failure |
| home.hero_banner.cta_text | string | Lihat Promo | Banner button text |
| home.hero_banner.deeplink | string | linkajademo://promo | Where the banner button goes |
| home.quick_actions.order | string | kirim,terima,qris,topup,pulsa,tagihan,transport,donasi | Order of the Home tiles. Tokens left out are hidden |
| home.quick_actions.highlight | string | qris | Tile drawn with a red ring and dot |
| home.balance_card.show_topup_cta | boolean | true | Top up button on the balance card |
| home.balance_card.topup_cta_text | string | Isi Saldo | Text of that button |
| topup.suggested_amounts | string | 50000,100000,200000,500000 | Amount chips on Top Up |
| topup.default_amount | number | 100000 | Preselected amount |
| topup.bonus.enabled | boolean | false | Bonus banner, and bonus credit in the mock |
| topup.bonus.min_amount | number | 100000 | Minimum top up to earn the bonus |
| topup.bonus.amount | number | 10000 | Bonus credited to the balance |
| topup.bonus.banner_text | string | Top up Rp100.000, dapat bonus Rp10.000 | Bonus banner copy |
| promo.layout | string | carousel | `carousel` or `grid` for the promo tiles |
| promo.featured_category | string | qris | Tiles of this category come first |
| promo.code_field.visible | boolean | true | Promo code field on the Promo tab |
| gamification.streak.enabled | boolean | true | Streak card, streak events and reward |
| gamification.streak.target_days | number | 5 | Tracker length (1 to 14) and the day the reward is earned |
| gamification.streak.chip_text | string | beruntun | Text after the day count in the chip |
| gamification.badge.label | string | Komuter Setia | Badge name in copy |
| gamification.progress_bar.color_hex | string | #E4002B | Progress bar and day dot color |
| crosssell.card.visible | boolean | true | Home cross-sell card |
| crosssell.card.title | string | QRIS-mu udah jago, coba bayar tagihan yuk | Card title |
| crosssell.card.cta_text | string | Coba Sekarang | Card button |
| crosssell.card.category | string | tagihan | Where the button goes (tagihan, pulsa, transport, donasi, zakat, qris) |
| crosssell.card.cashback_amount | number | 7500 | Cashback shown (hemat) and credited on a first transaction in a new category |
| crosssell.card.variant | string | hemat | `hemat` shows cashback, `praktis` shows 1-tap bayar |
| theme.primary_color_hex | string | #E4002B | App wide primary color |
| theme.corner_radius | number | 16 | App wide card and button radius (0 to 32) |
| flags.qris_education_tile | boolean | false | Adds the "Cara bayar QRIS" tile on Home |
| flags.one_tap_pay | boolean | false | Adds a 1-tap bayar button on the bill payment screen |

### Measurement events and profile property

`LinkAJA_Home_Banner_Viewed`, `LinkAJA_Home_Banner_Clicked`, `LinkAJA_Quick_Action_Clicked`, `LinkAJA_Top_Up_Amount_Selected`, `LinkAJA_Cross_Sell_Card_Viewed`, `LinkAJA_Cross_Sell_Card_Clicked`, `LinkAJA_Promo_Layout_Viewed` (properties in section 7). The user property `LinkAJA_pe_variant_cross_sell` holds the active cross-sell variant and is pushed on login and whenever it changes, so segments can use it.

### Sync and publish the variables (one time)

1. Add the simulator or device to the **test profiles**: Run a debug build, log in, open Demo Tools to copy the CleverTap ID, then in the dashboard open the user profile and choose "Add to test profiles". CleverTap only accepts variable definitions from a test profile. Without this the log shows `Vars sync error: Unauthorized`, which is what you will see until this is done.
2. Run a **DEBUG** build (Xcode default Run). `syncVariables()` is called at launch in DEBUG builds only and pushes the definitions.
3. Dashboard, **Settings, Product Experiences, Variables** (some accounts show it under Campaigns, Product Experiences): the `LinkAJA` group appears with all variables.
4. Edit values or create an A/B test (below), then **publish** the variables (Save, then Publish) so production users get them.
5. In the app, pull down on Home or reopen the app. Check Demo Tools, PE Inspector: changed values are red.

### Demo scripts

1. **Change the hero banner text and image live.** Dashboard: set `home.hero_banner.title`, `subtitle` and `image_url` (any `https://` PNG), publish. App: pull to refresh on Home. Result: new text and image; tap the button to fire `LinkAJA_Home_Banner_Clicked`. Show the event in Live View.
2. **Reorder quick actions and highlight QRIS.** Set `home.quick_actions.order` to `qris,topup,tagihan,kirim,terima,pulsa,transport,donasi` and `highlight` to `qris`. Refresh Home. Tap a tile and show `LinkAJA_Quick_Action_Clicked` with position and `is_highlighted`.
3. **Top up bonus and new suggested amounts.** Set `topup.bonus.enabled` true, `topup.suggested_amounts` to `25000,100000,250000,1000000`, `topup.default_amount` 250000. Open Top Up: banner, new chips, preselected amount. Pay Rp250.000 and the balance grows by the bonus. `LinkAJA_Top_Up_Amount_Selected` carries `bonus_applied`.
4. **A/B test crosssell.card.variant.** Dashboard: Product Experiences, create an A/B test on `crosssell.card.variant`: control `hemat`, variant `praktis`. Goal event `LinkAJA_Cross_Sell_Card_Clicked`, with `LinkAJA_Cross_Sell_Card_Viewed` as the view metric. Segment or report on `LinkAJA_pe_variant_cross_sell`. Without the dashboard, show the effect with PE Inspector, "Praktis variant".
5. **Streak target 5 to 7 and a new bar color.** Set `gamification.streak.target_days` to 7 and `progress_bar.color_hex` to `#1D4E89`. Open the Streak screen (Home card): 7 day dots in the new color, reward copy says 7 days. Run scenario 4 and pay transport 4 times to reach the reward at day 7.

### Local previews

Demo Tools, PE Inspector has three one tap previews that never reach CleverTap: "Top up bonus on", "Praktis variant", "Grid promo layout". "Reset to defaults" ignores dashboard values until you tap "Refresh from CleverTap".

### Things I was unsure about

- Variables are defined immediately after `CleverTap.sharedInstance()`, not before it; the SDK needs the instance to define variables. Everything is defined before the first fetch.
- I define each variable by its dotted name, which creates the nested `LinkAJA` groups, instead of defining one dictionary variable.
- `syncVariables()` is wrapped in `#if DEBUG`. Pushing definitions from a release build would need `syncVariables(true)`, which this project does not call.
- A/B variant name on the banner events comes from `variants()` on the CleverTap instance (first assigned variant, else `default`); verify that against how your test is set up.
- Dashboard menu names for the Variables screen vary by account version.
- The test-profile requirement is inferred from the `Unauthorized` sync error seen in the simulator log.

## 14. Personas, stamp streak and Loyalty Points wallet

### 14.1 Setup (Info.plist)

| Key | Value |
|---|---|
| CleverTapAccountID, CleverTapToken | existing |
| CleverTapWalletID | `1460` |
| CleverTapAPIHost | API host of your account region, no scheme (see below) |
| CleverTapPasscode | Account passcode (Dashboard, Settings, Passcodes). This is NOT the Token. |

API hosts from the current Region docs: India `in1.api.clevertap.com`, Singapore `sg1.api.clevertap.com`, US `us1.api.clevertap.com`, Indonesia `aps3.api.clevertap.com`, Middle East `mec1.api.clevertap.com`, Europe `api.clevertap.com` (no `eu1` API host exists).

**WARNING: the Passcode ships inside the app binary. This build is for internal demos only and must never be distributed. A production app must call these APIs from a server.**

Dashboard prerequisites: Loyalty Wallets enabled and wallet 1460 existing on the account. Without credentials, switch on Demo Tools, "Mock wallet (offline)" and everything still demos.

Auth note: the Promo API pages I read (Debit/Credit, Get Wallet Details, Transactions, Reverse/Refund, Authentication) describe the `X-CleverTap-Account-Id` and `X-CleverTap-Passcode` headers only. I did not find Basic Auth with API key and secret for these endpoints, so the app uses the header form from the Debit/Credit sample. Re-check if your docs differ.

### 14.2 Endpoints used

| Purpose | Call |
|---|---|
| Credit / debit | `POST /1/promo/creditDebit?identity=&walletId=1460`. Success: `status=success`, `record.activePoints`, `record.tnxId` (docs say this spelling is correct), `record.points` |
| Balance | `GET /1/promo/wallets?identity=` (all wallets, we pick 1460; `activePoints`, `totalPromisedPoints`). There is no walletId parameter |
| Riwayat Poin | `GET /1/promo/transactions?identity=&walletId=1460&page=1` (`record.allTransactions`) |
| Reverse / refund | `POST /1/promo/wallet/adjust?identity=` body `txnId`, `description` |

Flagged from the docs: insufficient points is error **702** (not 777); 708 only appears on the Debit/Credit page (debit on PENDING); the adjust response mixes `availablePoints` and `pointsBalance`, so the app re-reads the balance after a reversal instead of trusting either; business errors on adjust can be HTTP 200 with `status: fail`, so the body is always checked; the docs say an empty `metadata` object is rejected, so the key is omitted when empty. No automatic retries. Logs show endpoint and status only.

### 14.3 Resolution order

1. Dashboard override (live value that differs from the variable default). 2. Persona value. 3. Global default.
Edge cases: a dashboard value equal to the global default is not an override, so the persona value still wins. For string variables whose default is empty (`promo.featured.*`, `promo.list.order`, `incentives.expiry_duration`) any non-empty dashboard value wins. Demo Tools, PE Inspector, "Persona defaults" off means only 1 and 3 apply. The Inspector shows a Source column (Dashboard, Persona, Default).

Source of truth for Poin Loyalty: the wallet API (`activePoints`) when reachable. `startingPoints` is only the offline and mock seed. Saldo (Rupiah, `LinkAJA_wallet_balance`) and Poin Loyalty (`LinkAJA_loyalty_points`) are never mixed.

### 14.4 Budi vs Siti

| Item | Budi (Jakarta commuter) | Siti (Surabaya student and merchant) | On screen |
|---|---|---|---|
| Tagline, saldo, start points | Komuter Jakarta, Rp450.000, 1.250 | Mahasiswa dan pemilik usaha kecil, Rp120.000, 400 | Home header, balance card |
| Hero | Bill due in 3 days, CTA Bayar Tagihan, deep link bill-payment | Scan QRIS cashback, CTA Scan QRIS, deep link qris-scan | Home hero |
| Quick actions | tagihan first, highlight tagihan | qris first, highlight qris | Home grid |
| Top up | 100k to 1M, default 200k, bank_va first and suggested | 20k to 200k, default 50k, minimarket first and suggested | Top Up |
| Promo | carousel, featured category tagihan, 4 Budi promos | grid, featured category qris, 4 Siti promos | Promo |
| Stamps | commuter set, chip "hari kerja beruntun", badge Komuter Setia | qris set, chip "hari QRIS beruntun", badge Jagoan QRIS | Streak |
| Cross-sell | qris, variant praktis | tagihan, variant hemat | Home card |
| Flags | one_tap_pay on, QRIS education tile on | both off | Bill screen, Home |
| Merchant card | no | "Terima Pembayaran" opens Terima | Home |
| Profile at login | habit 2/3, streak 3, cycles 1, 2 txns, next bill in 3 days | habit 1/3, streak 2, cycles 0, 14 txns | Profile properties |

Promo expiry "Sisa N hari" counts from the validity length (14 days) and does not tick down in the demo; Gajian Deals counts to month end. Persona hero and promo texts are Indonesian only; English toggle applies to app labels.

### 14.5 Incentive rules

| Action | Rule key | Default points | Bucket | Frequency |
|---|---|---|---|---|
| KYC completed | kyc_completed | 200 | ACTIVE | once |
| First top up | first_topup | 150 | ACTIVE | once |
| QRIS payment | qris_payment | floor(amount/10000) x 1, max 100 | ACTIVE | each payment, skipped at 0 |
| Bill payment | bill_payment | 50 | ACTIVE | each payment |
| Habit 3rd payment | habit_third_payment | 200 | ACTIVE | once per habit cycle |
| Streak cycle complete | streak_cycle | reward_points (500) | `streak_cycle.bucket`, `activation_duration` if PENDING | once per cycle |
| Promo code redeemed | promo_code_redeemed | 100 | ACTIVE | once per code |
| New category | new_category | 100 | ACTIVE | once per category |

All rules are gated by `incentives.enabled` and their own `enabled` flag; `incentives.expiry_duration` is sent as `expiryDuration` when non-empty. `streak.reward_type` is reserved: any value is treated as points.
Debits: Tukar poin (catalog reward, voucher card on success) and Bayar pakai poin (discount = points x `points_to_rupiah`, capped at `max_percent_of_bill`; debited after the mock payment, orderId = payment id, saleAmount = bill). A debit above the local balance shows "Poin tidak cukup, kurang N" and is never sent. PENDING points are shown as "Poin menunggu aktif".
Reversal: "Batalkan transaksi" on the success screen reverses the earn credit and refunds the points debit (up to two adjust calls), fires `LinkAJA_Wallet_Reversed` per call and restores the saldo.
Failures: toast "Poin gagal ditambahkan", item goes to the failed queue (Demo Tools) and Retry reuses the same orderId. Once-only keys are stored per Identity on the device; "Reset wallet state on this device" clears them.

New PE variables: `gamification.*` (stamp, loyalty, streak points, badge cycles), `promo.featured.*`, `promo.list.order`, `incentives.*`, plus `topup.methods.order` and `topup.methods.highlight` (needed by the persona values). Removed: `gamification.streak.reward_amount` and the 20 day streak logic. Variables must be synced again (run a DEBUG build with a test profile) and published.

### 14.6 Demo scripts

1. Log in as Budi. Walk Home (bill hero, tagihan first, Poin chip), Top Up (bank_va suggested), Promo (carousel), Streak (3/5, commuter stamps).
2. Demo Tools, Switch persona. Show Siti: QRIS hero, grid promos, minimarket top up, qris stamps, merchant card, no 1-tap bayar.
3. As Siti open Home, KYC, finish it: "+200 Poin Loyalty" toast. Tap the points chip for Riwayat Poin; in CleverTap check the `LinkAJA_Wallet_Credited` event and the wallet transactions.
4. Streak screen, tap "Bayar QRIS (+1 hari)" until the 5th stamp: celebration "+500 Poin Loyalty". Promo, Tukar a reward (debit).
5. Pay a bill, switch on "Pakai Poin", see "Hemat Rp X dengan N poin", pay, then "Batalkan transaksi" to show the refund and reversal toasts.
6. In the dashboard set `incentives.qris_payment.points_per_10k` to 5 and `incentives.streak_cycle.bucket` to PENDING, publish, pull to refresh. Pay QRIS (more points), complete a cycle ("Poin menunggu aktif dalam 1 hari"). In PE Inspector those rows show Source Dashboard.

Unverified: live wallet calls were not run (no passcode yet); mock mode was exercised on the simulator with a headless run (`-autowallet -ljd_wallet_mock YES`).

## 15. Persona design system

Tokens live in `PersonaTheme` (persona-only, not variables) and are exposed as `ThemeProvider.persona`; views read them through `Theme.*`, `card()`, `PIcon` and `PersonaTabBar`. Color and radius resolve as: dashboard `LinkAJA.theme.primary_color_hex` and `LinkAJA.theme.corner_radius` if overridden, else the persona theme, else the global default. When the dashboard overrides the primary color, it also drives buttons and the header gradient.

| | Budi: Komuter Mode | Siti: Mode Toko |
|---|---|---|
| Header gradient | #12294D to #2F4B7C | #0E9F8E to #6C4BD6 |
| Background / cards | #EEF1F6, white with 1pt #D9DFEA border | #FFF7EE, white, colored soft shadow |
| Accent / secondary / CTA | #1F3A68 / #F2A900 / #E4002B | #0E9F8E / #FF6B5A / #E4002B |
| Radius, font, spacing | 12, SF default, 12 | 24, SF Rounded, 16 |
| Icons | line, rounded squares | filled, colored circles |
| Tabs | Home, Tagihan, Scan, Inbox, Profile | Home, Promo, raised Scan, Toko, Profile |
| Home modules | `PersonaHomeLayout.budi` | `PersonaHomeLayout.siti` |

Notes: the Budi Promo screen is a sheet (no Promo tab) and the "carousel" layout renders as a vertical list with category chips; "grid" renders the 2 column grid plus a merchant strip. Inbox is a sheet for Siti. The persona stamp and progress colors are persona values of `gamification.stamp.color_hex` and `progress_bar.color_hex`. "Reset demo state" (Demo Tools) also runs automatically on the first launch of a new build (CFBundleVersion).

Demo Tools, Persona Diff lists theme tokens and 30 resolved variables side by side ("N of M differ"). Tests: `xcodebuild test -workspace LinkAJADemo.xcworkspace -scheme LinkAJADemo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

Screenshot harness (no taps, in-app campaigns suppressed): launch with `-screen <login|welcome|home|topup|promo|streak|inbox|profile|hub> -persona <budi|siti> [-scrolled] [-holdwelcome] -ljd_wallet_mock YES`.
