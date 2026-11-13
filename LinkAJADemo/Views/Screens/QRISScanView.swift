import SwiftUI

/// Mock scanner: no camera, a "simulate scan" button opens the payment sheet.
struct QRISScanView: View {
    @EnvironmentObject var app: AppState
    @State private var sweep = false
    @State private var paying = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(app.t("Arahkan kamera ke kode QRIS", "Point the camera at a QRIS code"))
                    .foregroundStyle(.white).font(.headline).padding(.top, 60)
                ZStack {
                    RoundedRectangle(cornerRadius: 20).stroke(Color.white, lineWidth: 3).frame(width: 260, height: 260)
                    Rectangle().fill(Theme.red).frame(width: 240, height: 3)
                        .offset(y: sweep ? 110 : -110)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: sweep)
                }
                Spacer()
                PrimaryButton(title: app.t("Simulasikan Scan", "Simulate Scan"), icon: "qrcode.viewfinder") { paying = true }
                    .padding(.horizontal, 24).padding(.bottom, 32)
            }
        }
        .onAppear { sweep = true }
        .sheet(isPresented: $paying) { QRISPayView() }
    }
}

struct QRISPayView: View {
    @EnvironmentObject var app: AppState
    @State private var amount = 35_000
    @State private var done = false
    @State private var usePoints = false
    @State private var paymentId: String?
    @State private var saving: String?

    private var quote: PointsQuote? { usePoints ? app.payWithPointsQuote(amount: amount) : nil }

    var body: some View {
        ScreenContainer(title: "QRIS") {
            Form {
                Section(app.t("Merchant", "Merchant")) {
                    Label("Warung Bu Tini", systemImage: "storefront.fill")
                    Text("NMID ID1234567890123").font(.footnote).foregroundStyle(.secondary)
                }
                Section(app.t("Nominal", "Amount")) { AmountChips(amount: $amount, options: [15_000, 35_000, 75_000]) }
                if app.voucher15DaysLeft > 0 && !app.local.voucher15Redeemed {
                    Section { Label(app.t("Voucher Rp15.000 akan dipakai otomatis", "Rp15,000 voucher will apply automatically"),
                                    systemImage: "ticket.fill").foregroundStyle(Theme.red) }
                }
                PayWithPointsRow(amount: amount, use: $usePoints)
                Section { PrimaryButton(title: app.t("Bayar", "Pay") + " \(Fmt.rp(amount - (quote?.discount ?? 0)))",
                                        enabled: amount - (quote?.discount ?? 0) <= app.balance) {
                    let q = quote
                    paymentId = app.complete(.qris, amount: amount, title: "QRIS Warung Bu Tini",
                                             discount: q?.discount ?? 0, pointsUsed: q?.points ?? 0)
                    saving = app.savingLine(q)
                    done = true
                } }
                .listRowBackground(Color.clear)
            }
            .sheet(isPresented: $done) {
                SuccessView(message: app.t("Pembayaran QRIS berhasil", "QRIS payment successful"), detail: saving, paymentId: paymentId)
            }
        }
    }
}
