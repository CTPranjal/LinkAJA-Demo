import Foundation

/// Wallet credentials from Info.plist. Never logged and never shown in the UI.
struct WalletConfig {
    let walletId: Int
    let host: String
    let accountId: String
    private let passcode: String

    init(bundle: Bundle = .main) {
        func str(_ key: String) -> String {
            (bundle.object(forInfoDictionaryKey: key).map { "\($0)" } ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        walletId = Int(str("CleverTapWalletID")) ?? 1460
        host = str("CleverTapAPIHost")
        accountId = str("CleverTapAccountID")
        passcode = str("CleverTapPasscode")
    }

    private static func isPlaceholder(_ v: String) -> Bool { v.isEmpty || v.uppercased().contains("YOUR_") || v.uppercased().contains("REPLACE") }

    var isConfigured: Bool {
        !Self.isPlaceholder(host) && !Self.isPlaceholder(accountId) && !Self.isPlaceholder(passcode)
    }

    func headers() -> [String: String] {
        ["X-CleverTap-Account-Id": accountId, "X-CleverTap-Passcode": passcode, "Content-Type": "application/json"]
    }
}

enum WalletError: Error {
    case notConfigured
    case network(String)
    case http(Int)
    /// Business error from CleverTap, e.g. code 702, 708 or 777.
    case api(code: Int?, message: String)

    var code: Int? {
        switch self {
        case .api(let c, _): return c
        case .http(let c): return c
        default: return nil
        }
    }

    var detail: String {
        switch self {
        case .notConfigured: return "Wallet is not configured"
        case .network(let m): return m
        case .http(let c): return "HTTP \(c)"
        case .api(let c, let m): return "\(c.map(String.init) ?? "-"): \(m)"
        }
    }

    /// Friendly Indonesian message. 708 and 777 are mapped explicitly, anything else is generic.
    var friendly: String {
        switch self {
        case .api(let c, _) where c == 708: return "Poin menunggu belum bisa dipakai"
        case .api(let c, _) where c == 702: return "Poin tidak cukup"
        case .api(let c, _) where c == 777: return "Permintaan tidak valid, coba lagi"
        case .notConfigured: return "Wallet belum dikonfigurasi"
        default: return "Terjadi kendala, coba lagi"
        }
    }
}

struct CreditDebitRequest {
    var identity: String
    var description: String
    var points: Double
    var isCredit: Bool
    var orderId: String
    var saleAmount: Int?
    var metadata: [String: String]
    var bucket: String?               // credit only: ACTIVE or PENDING
    var activationDuration: String?   // only when bucket is PENDING
    var expiryDuration: String?       // credit only
}

struct CreditDebitResult {
    let txnId: String
    let activePoints: Double
    let points: Double
}

struct WalletSummary {
    let activePoints: Double
    let promisedPoints: Double
}

struct RemoteTransaction: Identifiable {
    let id: String
    let type: String        // CREDIT, DEBIT, EXPIRED, PENDING, REVERSE, REFUND
    let points: Double
    let description: String
    let timestamp: Date
    let metadata: [String: String]
    let orderId: String
    let saleChannel: String
    let saleAmount: Double
}

struct TransactionsPage {
    let items: [RemoteTransaction]
    let promisedPoints: Double
    let hasNext: Bool
}

struct AdjustResult {
    let type: String        // reverse or refund
    let txnId: String
    let parentTxnId: String
    let pointsAdjusted: Double
}

/// Thin client for the CleverTap Promo Wallet REST APIs. No retries: credits and debits are not
/// guaranteed to be idempotent, so a failure is surfaced and the caller decides.
struct PromoWalletService {
    let config: WalletConfig
    private let session: URLSession

    init(config: WalletConfig = WalletConfig()) {
        self.config = config
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        session = URLSession(configuration: c)
    }

    // MARK: Endpoints

    /// POST /1/promo/creditDebit?identity=&walletId=
    func creditDebit(_ r: CreditDebitRequest) async throws -> CreditDebitResult {
        var body: [String: Any] = [
            "description": r.description,
            "points": Self.number(r.points),
            "transactionType": r.isCredit ? "CREDIT" : "DEBIT",
            "orderId": r.orderId,
            "saleChannel": "Mobile"
        ]
        if let s = r.saleAmount { body["saleAmount"] = s }
        if !r.metadata.isEmpty { body["metadata"] = r.metadata }   // an empty object is rejected by the API
        if r.isCredit {
            if let b = r.bucket { body["bucketType"] = b }
            if r.bucket == "PENDING", let a = r.activationDuration, !a.isEmpty { body["activationDuration"] = a }
            if let e = r.expiryDuration, !e.isEmpty { body["expiryDuration"] = e }
        }
        let json = try await send("POST", "/1/promo/creditDebit",
                                  query: ["identity": r.identity, "walletId": "\(config.walletId)"], body: body)
        guard let rec = json["record"] as? [String: Any] else { throw WalletError.network("Unexpected response") }
        // The API spells the transaction id "tnxId".
        let txn = rec["tnxId"] as? String ?? ""
        return CreditDebitResult(txnId: txn, activePoints: Self.double(rec["activePoints"]), points: Self.double(rec["points"]))
    }

    /// GET /1/promo/wallets?identity=  (all wallets of the user, pick ours)
    func walletDetails(identity: String) async throws -> WalletSummary {
        let json = try await send("GET", "/1/promo/wallets", query: ["identity": identity], body: nil)
        let records = json["records"] as? [[String: Any]] ?? []
        guard let mine = records.first(where: { Int("\($0["walletId"] ?? "")") == config.walletId }) else {
            // The user may not have a wallet record yet: treat as zero.
            return WalletSummary(activePoints: 0, promisedPoints: 0)
        }
        return WalletSummary(activePoints: Self.double(mine["activePoints"]), promisedPoints: Self.double(mine["totalPromisedPoints"]))
    }

    /// GET /1/promo/transactions?identity=&walletId=&page=
    func transactions(identity: String, page: Int = 1) async throws -> TransactionsPage {
        let json = try await send("GET", "/1/promo/transactions",
                                  query: ["identity": identity, "walletId": "\(config.walletId)", "page": "\(page)"], body: nil)
        let rec = json["record"] as? [String: Any] ?? [:]
        let all = rec["allTransactions"] as? [[String: Any]] ?? []
        let items = all.map { t -> RemoteTransaction in
            let meta = (t["metadata"] as? [String: Any] ?? [:]).mapValues { "\($0)" }
            return RemoteTransaction(
                id: t["tnxId"] as? String ?? UUID().uuidString,
                type: (t["type"] as? String ?? "").uppercased(),
                points: Self.double(t["points"]),
                description: t["description"] as? String ?? "",
                timestamp: Date(timeIntervalSince1970: Self.double(t["txnTimestamp"])),
                metadata: meta,
                orderId: t["orderId"] as? String ?? "",
                saleChannel: t["saleChannel"] as? String ?? "",
                saleAmount: Self.double(t["saleAmount"]))
        }
        let promised = (rec["promisedPoints"] as? [String: Any]).map { Self.double($0["totalPromisedPoints"]) } ?? 0
        let hasNext = (rec["pagination"] as? [String: Any])?["hasNext"] as? Bool ?? false
        return TransactionsPage(items: items, promisedPoints: promised, hasNext: hasNext)
    }

    /// POST /1/promo/wallet/adjust?identity=  body: txnId, description
    func adjust(identity: String, txnId: String, description: String) async throws -> AdjustResult {
        let json = try await send("POST", "/1/promo/wallet/adjust", query: ["identity": identity],
                                  body: ["txnId": txnId, "description": description])
        let rec = (json["records"] as? [[String: Any]])?.first ?? [:]
        return AdjustResult(type: rec["type"] as? String ?? "reverse", txnId: rec["txnId"] as? String ?? "",
                            parentTxnId: rec["parentTxnId"] as? String ?? txnId,
                            pointsAdjusted: Self.double(rec["pointsAdjusted"]))
    }

    // MARK: Transport

    private func send(_ method: String, _ path: String, query: [String: String], body: [String: Any]?) async throws -> [String: Any] {
        guard config.isConfigured else { throw WalletError.notConfigured }
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = config.host
        comps.path = path
        comps.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw WalletError.network("Bad URL") }

        var req = URLRequest(url: url)
        req.httpMethod = method
        config.headers().forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let data: Data, status: Int
        do {
            let (d, resp) = try await session.data(for: req)
            data = d
            status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        } catch {
            CleverTapManager.shared.note("wallet \(method) \(path) failed: network")
            throw WalletError.network(error.localizedDescription)
        }
        // Log the endpoint and status only. Never headers, query values or the passcode.
        CleverTapManager.shared.note("wallet \(method) \(path) -> \(status)")

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code = (json["code"] as? Int) ?? Int("\(json["code"] ?? "")")
        if status != 200 {
            if let msg = json["error"] as? String { throw WalletError.api(code: code ?? status, message: msg) }
            throw WalletError.http(status)
        }
        guard (json["status"] as? String) == "success" else {
            throw WalletError.api(code: code, message: json["error"] as? String ?? "Request failed")
        }
        return json
    }

    // MARK: Helpers

    /// Whole numbers are sent as integers (500, not 500.0).
    static func number(_ v: Double) -> Any { v == v.rounded() ? Int(v) : v }

    static func double(_ v: Any?) -> Double {
        switch v {
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s) ?? 0
        default: return 0
        }
    }
}
