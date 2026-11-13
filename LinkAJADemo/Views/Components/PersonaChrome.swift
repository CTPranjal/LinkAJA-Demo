import SwiftUI

/// Bottom bar that follows the persona: its own tab set, accent pill, and for Siti a raised center scan button.
struct PersonaTabBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: DeepLinkRouter
    @EnvironmentObject var ct: CleverTapManager

    private func title(_ t: AppTab) -> String {
        switch t {
        case .home: return "Home"
        case .promo: return "Promo"
        case .scan: return "Scan"
        case .inbox: return "Inbox"
        case .profile: return app.t("Profil", "Profile")
        case .bills: return app.t("Tagihan", "Bills")
        case .shop: return app.t("Toko", "Shop")
        }
    }

    private func symbol(_ t: AppTab) -> String {
        switch t {
        case .home: return "house"
        case .promo: return "tag"
        case .scan: return "qrcode.viewfinder"
        case .inbox: return "envelope"
        case .profile: return "person"
        case .bills: return "doc.text"
        case .shop: return "storefront"
        }
    }

    var body: some View {
        let p = Theme.persona
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(p.tabs, id: \.self) { tab in
                if tab == .scan && !p.compact { raisedScan } else { item(tab) }
            }
        }
        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 4)
        .background(
            Theme.card
                .overlay(alignment: .top) { if let b = p.border { b.frame(height: 1) } }
                .shadow(color: p.shadow, radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func item(_ tab: AppTab) -> some View {
        let selected = router.tab == tab
        return Button { router.tab = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: selected ? symbol(tab) + ".fill" : symbol(tab)).font(.system(size: 20))
                    .overlay(alignment: .topTrailing) {
                        if tab == .inbox && ct.inboxUnread > 0 {
                            Circle().fill(Theme.cta).frame(width: 9, height: 9).offset(x: 6, y: -2)
                        }
                    }
                Text(title(tab)).font(.system(size: 10, weight: selected ? .bold : .medium))
            }
            .foregroundStyle(selected ? Theme.accent : Color.secondary)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(selected ? Theme.accent.opacity(0.14) : Color.clear))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var raisedScan: some View {
        let selected = router.tab == .scan
        return Button { router.tab = .scan } label: {
            VStack(spacing: 2) {
                Circle().fill(Theme.gradient).frame(width: 60, height: 60)
                    .overlay(Image(systemName: "qrcode.viewfinder").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white))
                    .overlay(Circle().stroke(Theme.card, lineWidth: 4))
                    .shadow(color: Theme.persona.shadow, radius: 8, y: 4)
                    .offset(y: -18)
                Text("Scan").font(.system(size: 10, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? Theme.accent : Color.secondary).offset(y: -14)
            }
            .frame(maxWidth: .infinity).frame(height: 36, alignment: .bottom)
        }
        .buttonStyle(.plain)
    }
}

/// Full screen welcome in the persona gradient, shown for 1.2 seconds after login.
struct WelcomeView: View {
    @EnvironmentObject var app: AppState
    let personaID: String

    var body: some View {
        let t = PersonaTheme.theme(for: personaID)
        ZStack {
            t.headerGradient.ignoresSafeArea()
            VStack(spacing: 16) {
                PersonaAvatar(personaID: personaID, size: 110).overlay(Circle().stroke(.white, lineWidth: 4))
                Text(app.t(t.welcomeID, t.welcomeEN)).font(.system(size: 34, weight: .bold))
                Text(app.t(t.modeID, t.modeEN)).font(.title3.weight(.medium)).opacity(0.9)
                    .padding(.horizontal, 16).padding(.vertical, 6).background(.white.opacity(0.2), in: Capsule())
            }
            .foregroundStyle(.white)
        }
        .personaFont(t.fontDesign)
        .task {
            if CommandLine.arguments.contains("-holdwelcome") { return }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.35)) { app.welcome = nil }
        }
    }
}
