import SwiftUI

struct KYCFlowView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0   // 0 KTP, 1 selfie, 2 done
    @State private var nik = "3578012345670001"

    var body: some View {
        ScreenContainer(title: app.t("Verifikasi Akun", "Account Verification")) {
            VStack(spacing: 20) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in Capsule().fill(i <= step ? Theme.red : Color.gray.opacity(0.25)).frame(height: 6) }
                }
                Text(app.t("Langkah \(step + 1) dari 3", "Step \(step + 1) of 3")).font(.caption).foregroundStyle(.secondary)
                Group {
                    switch step {
                    case 0: ktp
                    case 1: selfie
                    default: finished
                    }
                }
                Spacer()
            }
            .padding(20)
        }
        .onAppear { if app.str(.kycStatus) == "pending" { app.startKYC() } else { step = 2 } }
    }

    private var ktp: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle").font(.system(size: 80)).foregroundStyle(Theme.red)
            Text("Foto KTP").font(.title3.bold())
            Text(app.t("Pastikan KTP terlihat jelas dan tidak buram.", "Make sure your KTP is clear and not blurry.")).foregroundStyle(.secondary)
            TextField("NIK", text: $nik).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            PrimaryButton(title: app.t("Ambil Foto KTP", "Capture KTP"), icon: "camera.fill") {
                app.completeKYCStep("ktp"); step = 1
            }
        }
    }

    private var selfie: some View {
        VStack(spacing: 16) {
            Image(systemName: "face.smiling").font(.system(size: 80)).foregroundStyle(Theme.red)
            Text("Selfie").font(.title3.bold())
            Text(app.t("Foto wajahmu sambil menghadap kamera.", "Take a photo of your face looking at the camera.")).foregroundStyle(.secondary)
            PrimaryButton(title: app.t("Ambil Selfie", "Take Selfie"), icon: "camera.fill") {
                app.completeKYCStep("selfie"); app.completeKYC(); step = 2
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 80)).foregroundStyle(Theme.good)
            Text(app.t("Akun terverifikasi!", "Account verified!")).font(.title3.bold())
            Text(app.t("Voucher Rp10.000 sudah ada di halaman Promo (min. top-up Rp50.000, berlaku 7 hari).",
                       "Your Rp10,000 voucher is on the Promo page (min top-up Rp50,000, valid 7 days).")).multilineTextAlignment(.center).foregroundStyle(.secondary)
            PrimaryButton(title: app.t("Selesai", "Done")) { dismiss() }
        }
    }
}
