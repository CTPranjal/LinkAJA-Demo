import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: DeepLinkRouter
    @State private var taps = 0
    @State private var showTools = false

    @ViewBuilder private var personaSection: some View {
        if app.persona?.id == Persona.budi.id {
            Section(app.t("Kebiasaan bayar", "Payment habits")) {
                HStack {
                    Label(app.t("Biasa bayar tanggal", "Usual payment day"), systemImage: "calendar"); Spacer()
                    Text("\(app.int(.usualPaymentDay) == 0 ? 25 : app.int(.usualPaymentDay))").fontWeight(.bold).foregroundStyle(Theme.accent)
                }
            }
            Section(app.t("Tagihan terhubung", "Linked bills")) {
                ForEach(PersonaRegistry.budi.dueBills) { b in
                    HStack(spacing: 12) {
                        PIcon(symbol: b.symbol, size: 34)
                        Text(b.title)
                        Spacer()
                        Text(app.t("Terhubung", "Linked")).font(.caption).foregroundStyle(Theme.good)
                    }
                }
            }
        } else if app.persona?.id == Persona.siti.id {
            Section(app.t("Toko", "Shop")) {
                HStack(spacing: 14) {
                    PIcon(symbol: "storefront", tint: 1, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TokoData.storeName).font(.headline)
                        Text("NMID " + TokoData.nmid).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Image(systemName: "qrcode").font(.system(size: 70)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QR Toko").font(.subheadline.bold())
                        Button(app.t("Tampilkan", "Show")) { router.sheet = .receive }.font(.caption.bold())
                    }
                    Spacer()
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        if let p = app.persona {
                            PersonaAvatar(personaID: p.id, size: 60)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.fullName).font(.headline)
                                Text("\(p.city) | \(p.phone)").font(.caption).foregroundStyle(.secondary)
                                Text(p.email).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button { router.sheet = .kyc } label: {
                        HStack {
                            Text("KYC"); Spacer()
                            Chip(text: app.str(.kycStatus) == "completed" ? "\(app.t("Terverifikasi", "Verified")) (\(app.str(.kycTier)))" : app.t("Belum selesai", "Pending"),
                                 color: app.str(.kycStatus) == "completed" ? .green : Theme.red)
                        }
                    }
                }

                personaSection

                Section(app.t("Bahasa", "Language")) {
                    Picker("", selection: Binding(get: { app.language }, set: { app.setLanguage($0) })) {
                        Text("Bahasa Indonesia").tag("id"); Text("English").tag("en")
                    }.pickerStyle(.segmented)
                }

                Section(app.t("Notifikasi dan komunikasi", "Notifications and communication")) {
                    Toggle("Email", isOn: $app.optEmail).onChange(of: app.optEmail) { _ in app.updateOptIns() }
                    Toggle("Push", isOn: $app.optPush).onChange(of: app.optPush) { _ in app.updateOptIns() }
                    Toggle("WhatsApp", isOn: $app.optWhatsapp).onChange(of: app.optWhatsapp) { _ in app.updateOptIns() }
                }

                Section {
                    Button(role: .destructive) { app.logout() } label: { Text(app.t("Keluar", "Log out")) }
                }

                Section {
                    // Five taps reveal Demo Tools.
                    Text("LinkAja Demo v1.0")
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { taps += 1; if taps >= 5 { taps = 0; showTools = true } }
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(app.t("Profil", "Profile"))
            .navigationDestination(isPresented: $showTools) { DemoToolsView() }
        }
    }
}
