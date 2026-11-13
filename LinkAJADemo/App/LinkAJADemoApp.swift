import SwiftUI

@main
struct LinkAJADemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState()
    @StateObject private var router = DeepLinkRouter()
    @StateObject private var ct = CleverTapManager.shared
    @StateObject private var pe = PEStore.shared
    @StateObject private var theme = ThemeProvider.shared
    @StateObject private var resolver = PEResolver.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(router)
                .environmentObject(ct)
                .environmentObject(pe)
                .environmentObject(resolver)
                .environmentObject(theme)
                .tint(theme.primary)
                .preferredColorScheme(.light)
                .personaFont(theme.persona.fontDesign)
                .onOpenURL { router.handle($0) }
                .onChange(of: scenePhase) { phase in if phase == .active { PEStore.shared.fetch() } }
                .onAppear {
                    CleverTapManager.shared.deepLinkHandler = { router.handle($0) }
                }
        }
    }
}
