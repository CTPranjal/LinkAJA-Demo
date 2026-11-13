import Foundation

struct Persona: Identifiable, Equatable {
    let id: String            // CleverTap Identity
    let fullName: String
    let city: String
    let personaType: String
    let age: Int
    let phone: String
    let email: String
    let gender: String
    let blurbID: String
    let blurbEN: String
    let imageName: String
    let initialKYCStatus: String
    let initialKYCTier: String
    let initialBalance: Int
    let favoriteCategory: String
    let abVariant: String

    var firstName: String { fullName.components(separatedBy: " ").first ?? fullName }

    static let budi = Persona(
        id: "budi.santoso.demo", fullName: "Budi Santoso", city: "Jakarta",
        personaType: "salaried_commuter", age: 34, phone: "+6281234567001",
        email: "budi.demo@example.com", gender: "M",
        blurbID: "Karyawan, 34 th, Jakarta. Komuter KRL/MRT, bayar PLN dan pulsa tiap bulan.",
        blurbEN: "Salaried, 34, Jakarta. KRL/MRT commuter, pays PLN and pulsa monthly.",
        imageName: "img_persona_male", initialKYCStatus: "completed", initialKYCTier: "full",
        initialBalance: 450_000, favoriteCategory: "tagihan", abVariant: "A")

    static let siti = Persona(
        id: "siti.rahayu.demo", fullName: "Siti Rahayu", city: "Surabaya",
        personaType: "student_merchant", age: 22, phone: "+6281234567002",
        email: "siti.demo@example.com", gender: "F",
        blurbID: "Mahasiswi dan pedagang kecil, 22 th, Surabaya. Pengguna QRIS dan transfer aktif.",
        blurbEN: "University student and small merchant, 22, Surabaya. Heavy QRIS and transfer user.",
        imageName: "img_persona_female", initialKYCStatus: "pending", initialKYCTier: "basic",
        initialBalance: 120_000, favoriteCategory: "qris", abVariant: "B")

    static let all = [budi, siti]
}
