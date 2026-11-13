import SwiftUI

/// One slot of the stamp row. Empty slots are a dashed circle with the day label. Earned slots are a
/// tilted rubber stamp ring with a symbol, pressed in with a short animation when it was just earned.
struct StampSlot: View {
    let earned: Bool
    let symbol: String
    let color: Color
    let label: String
    let tilt: Double
    let animated: Bool
    @State private var landed: Bool

    init(earned: Bool, symbol: String, color: Color, label: String, tilt: Double, animated: Bool) {
        self.earned = earned; self.symbol = symbol; self.color = color
        self.label = label; self.tilt = tilt; self.animated = animated
        _landed = State(initialValue: earned)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .frame(width: 46, height: 46)
                if earned { stamp }
            }
            .frame(height: 52)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: earned) { now in
            if now {
                guard animated else { landed = true; return }
                landed = false
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.5)) { landed = true }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else {
                landed = false
            }
        }
    }

    private var stamp: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 3).frame(width: 48, height: 48)
            Circle().stroke(color.opacity(0.6), lineWidth: 1).frame(width: 40, height: 40)
            Image(systemName: symbol).font(.system(size: 19, weight: .bold)).foregroundStyle(color)
        }
        .scaleEffect(landed ? 1 : 1.9)
        .rotationEffect(.degrees(landed ? tilt : tilt - 28))
        .opacity(landed ? 1 : 0)
    }
}

/// Poin Loyalty chip. Tapping it opens Riwayat Poin.
struct PointsChip: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var pe: PEResolver
    @ObservedObject private var wallet = LoyaltyWallet.shared
    var onDark = false
    @State private var showHistory = false

    var body: some View {
        if pe.loyaltyEnabled {
            Button { showHistory = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "star.circle.fill")
                    Text("\(Fmt.num(wallet.points)) " + pe.loyaltyLabel(english: app.language == "en"))
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(onDark ? Color.white.opacity(0.2) : Theme.highlight.opacity(0.16))
                .foregroundStyle(onDark ? Color.white : Theme.accent)
                .clipShape(Capsule())
            }
            .sheet(isPresented: $showHistory) { PointsHistoryView() }
        }
    }
}

/// Animated "+50 Poin Loyalty" toast.
struct PointsToastView: View {
    @ObservedObject private var wallet = LoyaltyWallet.shared

    var body: some View {
        VStack {
            if let t = wallet.toast {
                HStack(spacing: 8) {
                    Image(systemName: icon(t.kind))
                    Text(t.text).font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(color(t.kind).gradient)
                .clipShape(Capsule())
                .shadow(radius: 6, y: 3)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8)))
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: wallet.toast)
        .allowsHitTesting(false)
    }

    private func icon(_ k: PointsToast.Kind) -> String {
        switch k {
        case .credit: return "plus.circle.fill"
        case .debit: return "minus.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func color(_ k: PointsToast.Kind) -> Color {
        switch k {
        case .credit: return .green
        case .debit: return .orange
        case .error: return Color(red: 0.75, green: 0.15, blue: 0.15)
        case .info: return .blue
        }
    }
}
