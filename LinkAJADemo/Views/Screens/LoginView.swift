import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Spacer(minLength: 20)
                Image("img_logo_white").resizable().scaledToFit().frame(width: 190)
                Text(app.t("Demo CleverTap untuk penjualan", "CleverTap sales demo"))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 10)
                Text(app.t("Masuk sebagai", "Continue as"))
                    .font(.headline).foregroundStyle(.white)
                ForEach(Persona.all) { p in
                    Button { app.login(p) } label: { PersonaButton(persona: p) }.buttonStyle(.plain)
                }
                Picker("", selection: Binding(get: { app.language }, set: { app.setLanguage($0) })) {
                    Text("Bahasa").tag("id"); Text("English").tag("en")
                }
                .pickerStyle(.segmented).frame(width: 220).padding(.top, 4)
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
        }
        .background(
            Image("img_hero").resizable().scaledToFill().ignoresSafeArea()
        )
    }
}

private struct PersonaButton: View {
    @EnvironmentObject var app: AppState
    let persona: Persona
    var body: some View {
        let t = PersonaTheme.theme(for: persona.id)
        HStack(spacing: 0) {
            // Left edge: navy for Budi, teal to violet for Siti.
            LinearGradient(colors: [t.headerStart, t.headerEnd], startPoint: .top, endPoint: .bottom).frame(width: 10)
            HStack(spacing: 14) {
                PersonaAvatar(personaID: persona.id, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(persona.fullName).font(.title3.bold()).foregroundStyle(.primary)
                    Text(app.t(t.modeID, t.modeEN)).font(.caption.weight(.bold)).foregroundStyle(t.accent)
                    Text(app.t(persona.blurbID, persona.blurbEN)).font(.caption)
                        .foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").fontWeight(.bold).foregroundStyle(t.accent)
            }
            .padding(14)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: t.radius + 6, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }
}
