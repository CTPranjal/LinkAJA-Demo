import SwiftUI

extension View {
    /// Persona card: radius, padding, border and shadow all come from the live theme.
    func card(padding: CGFloat? = nil) -> some View {
        let p = Theme.persona
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        return self.padding(padding ?? p.rowPadding)
            .background(Theme.card, in: shape)
            .overlay { if let b = p.border { shape.stroke(b, lineWidth: 1) } }
            .shadow(color: p.shadow, radius: p.shadowRadius, y: p.compact ? 1 : 5)
    }

    /// Applies the persona font design (SF default or SF Rounded) to all text below.
    @ViewBuilder func personaFont(_ design: Font.Design) -> some View {
        if #available(iOS 16.1, *) { self.fontDesign(design) } else { self }
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Theme.persona.compact ? 12 : 16)
            .background(enabled ? Theme.cta : Theme.secondary.opacity(0.35))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: max(Theme.radius - 4, 4), style: .continuous))
        }
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Theme.persona.compact ? 10 : 14)
            .background(Theme.accent.opacity(0.12))
            .foregroundStyle(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: max(Theme.radius - 4, 4), style: .continuous))
        }
    }
}

/// Circular image icon from the asset catalog.
struct ServiceIcon: View {
    let name: String
    var size: CGFloat = 52
    var body: some View {
        Image(name).resizable().scaledToFill()
            .frame(width: size, height: size).clipShape(Circle())
    }
}

/// Persona icon style: line icons in soft rounded squares (Budi) or filled icons in colored circles (Siti).
struct PIcon: View {
    let symbol: String
    var tint = 0
    var size: CGFloat = 44

    private func filled(_ s: String) -> String { UIImage(systemName: s + ".fill") != nil ? s + ".fill" : s }

    var body: some View {
        let p = Theme.persona
        if p.squareIcons {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Theme.accent.opacity(0.10))
                .frame(width: size, height: size)
                .overlay(Image(systemName: symbol).font(.system(size: size * 0.44, weight: .regular)).foregroundStyle(Theme.accent))
        } else {
            let c = p.iconTints[tint % max(1, p.iconTints.count)]
            Circle().fill(c).frame(width: size, height: size)
                .overlay(Image(systemName: filled(symbol)).font(.system(size: size * 0.44, weight: .semibold)).foregroundStyle(.white))
        }
    }
}

/// Persona photo, or a monogram circle in the persona accent when the asset is missing. Never a shared image.
struct PersonaAvatar: View {
    let personaID: String
    var size: CGFloat = 46
    var body: some View {
        let cfg = PersonaRegistry.config(for: personaID)
        let accent = PersonaTheme.theme(for: personaID).accent
        if let name = cfg?.avatarAsset, UIImage(named: name) != nil {
            Image(name).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
                .background(Circle().fill(accent.opacity(0.2)))
        } else {
            Circle().fill(accent).frame(width: size, height: size)
                .overlay(Text(String((cfg?.firstName ?? "?").prefix(1))).font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(.white))
        }
    }
}

struct Chip: View {
    let text: String
    var color: Color = Theme.accent
    var body: some View {
        Text(text).font(.caption.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.14)).foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct ProgressBar: View {
    let value: Double   // 0...1
    var color: Color = Theme.accent
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule().fill(color).frame(width: g.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 8)
    }
}

/// Tiny bar chart (last 7 days of sales).
struct MiniBarChart: View {
    let values: [Double]
    let labels: [String]
    var color: Color = Theme.accent
    var body: some View {
        let maxV = max(values.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == values.count - 1 ? color : color.opacity(0.35))
                        .frame(height: max(6, 54 * v / maxV))
                    Text(labels[i % labels.count]).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 70, alignment: .bottom)
    }
}

/// Wraps a sheet screen in a NavigationStack with a Close button.
struct ScreenContainer<Content: View>: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack {
            content
                .scrollContentBackground(.hidden)
                .background(Theme.bg)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(app.t("Tutup", "Close")) { dismiss() } }
                }
        }
        .tint(Theme.accent)
    }
}

struct AmountChips: View {
    @Binding var amount: Int
    let options: [Int]
    var onSelect: ((Int) -> Void)? = nil
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(options, id: \.self) { v in
                Button { amount = v; onSelect?(v) } label: {
                    Text(Fmt.rp(v)).font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(amount == v ? Theme.accent : Theme.accent.opacity(0.10))
                        .foregroundStyle(amount == v ? .white : Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: max(Theme.radius - 6, 6)))
                }
            }
        }
    }
}

struct ToastOverlay: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ZStack {
            PointsToastView()
            textToast
        }
    }

    private var textToast: some View {
        VStack {
            Spacer()
            if let t = app.toast {
                Text(t).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.persona.accent.opacity(0.95)).clipShape(Capsule())
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: app.toast)
        .allowsHitTesting(false)
    }
}

/// Small success screen used after a mock payment. With a payment id it offers "Batalkan transaksi".
struct SuccessView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let message: String
    var detail: String? = nil
    var paymentId: String? = nil
    @State private var cancelling = false
    @State private var cancelled = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: cancelled ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 72)).foregroundStyle(cancelled ? Theme.secondary : Theme.good)
            Text(cancelled ? app.t("Dibatalkan", "Cancelled") : app.t("Berhasil!", "Success!")).font(.title2.bold())
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            if let detail, !cancelled { Label(detail, systemImage: "star.circle.fill").font(.subheadline.bold()).foregroundStyle(Theme.good) }
            if let id = paymentId, !cancelled {
                SecondaryButton(title: cancelling ? app.t("Membatalkan...", "Cancelling...") : app.t("Batalkan transaksi", "Cancel transaction"),
                                icon: "arrow.uturn.backward") {
                    guard !cancelling else { return }
                    cancelling = true
                    Task { @MainActor in
                        cancelled = await app.cancelPayment(id)
                        cancelling = false
                    }
                }
            }
            PrimaryButton(title: app.t("Selesai", "Done")) { dismiss() }.padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
