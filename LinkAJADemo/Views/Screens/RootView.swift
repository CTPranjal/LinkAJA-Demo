import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: DeepLinkRouter

    var body: some View {
        ZStack {
            if app.persona == nil {
                LoginView()
            } else {
                MainTabView().id(app.persona?.id ?? "none")
            }
            ToastOverlay()
            if let w = app.welcome {
                WelcomeView(personaID: w).transition(.opacity).zIndex(10)
            }
        }
        .onAppear { router.ready = app.persona != nil }
        .task {
            if AutoDemo.enabled { await AutoDemo.run(app) }
            if AutoDemo.walletTest { await AutoDemo.runWallet(app) }
            if ScreenshotMode.active { await ScreenshotMode.run(app, router) }
        }
        .onChange(of: app.persona?.id) { id in router.ready = id != nil }
    }
}

struct MainTabView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: DeepLinkRouter

    var body: some View {
        let tabs = Theme.persona.tabs
        ZStack {
            switch router.tab {
            case .home: HomeView()
            case .promo: PromoView()
            case .scan: QRISScanView()
            case .inbox: InboxView()
            case .profile: ProfileView()
            case .bills: BillHubView()
            case .shop: TokoView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { PersonaTabBar() }
        .onChange(of: router.tab) { t in
            // Tabs the persona does not have open as a sheet instead (for example Promo for Budi).
            guard !tabs.contains(t) else { return }
            router.tab = .home
            switch t {
            case .promo: router.sheet = .promo
            case .inbox: router.sheet = .inbox
            case .bills: router.sheet = .bills
            case .shop: router.sheet = .shop
            default: break
            }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .kyc: KYCFlowView()
            case .topUp: TopUpView()
            case .bill: BillPaymentView(initial: "PLN")
            case .pulsa: BillPaymentView(initial: "pulsa")
            case .transport: TransportView()
            case .transfer: TransferView(receive: false)
            case .receive: TransferView(receive: true)
            case .donasi: DonasiZakatView()
            case .streak: StreakView()
            case .promo: PromoView()
            case .inbox: InboxView()
            case .bills: BillHubView()
            case .shop: TokoView()
            }
        }
    }
}
