import Foundation
import UIKit
import Combine
import CleverTapSDK

/// The only file that talks to the CleverTap SDK.
final class CleverTapManager: NSObject, ObservableObject {
    static let shared = CleverTapManager()

    /// Recent calls, shown in Demo Tools so the presenter can narrate what was sent.
    @Published private(set) var activityLog: [String] = []
    @Published private(set) var inboxMessages: [CleverTapInboxMessage] = []
    @Published private(set) var inboxUnread: Int = 0

    /// Set by the app so URL clicks from push, in-app and inbox reach the router.
    var deepLinkHandler: ((URL) -> Void)?

    private var ct: CleverTap? { CleverTap.sharedInstance() }

    // MARK: Setup

    /// Order matters: debug level and autoIntegrate must run before sharedInstance().
    func configure() {
        CleverTap.setDebugLevel(2)
        CleverTap.autoIntegrate()
        _ = CleverTap.sharedInstance()
        ct?.setUrlDelegate(self)
        ct?.setInAppNotificationDelegate(self)
        initializeInbox()
        // Variables must be defined after the instance exists and before the first fetch.
        PEStore.shared.define()
        PEStore.shared.fetch()
    }

    // MARK: Product Experiences (Variables)

    func defineVariable(_ key: PEKeys, onChange: @escaping () -> Void) -> Var? {
        let v: Var?
        switch key.defaultValue {
        case .bool(let b): v = ct?.defineVar(name: key.name, boolean: b)
        case .string(let s): v = ct?.defineVar(name: key.name, string: s)
        case .int(let i): v = ct?.defineVar(name: key.name, integer: Int32(i))
        }
        v?.onValueChanged(onChange)
        return v
    }

    func onVariablesChanged(_ block: @escaping () -> Void) { ct?.onVariablesChanged(block) }

    func fetchVariables(_ done: @escaping (Bool) -> Void) { ct?.fetchVariables { done($0) } }

    /// Pushes variable definitions to the dashboard. Debug builds only.
    func syncVariableDefinitionsInDebug() {
        #if DEBUG
        ct?.syncVariables()
        log("syncVariables (DEBUG)")
        #endif
    }

    /// Name of the A/B test variant the user is in, or "default" when none is assigned.
    var experimentVariant: String {
        (ct?.variants().first?["name"] as? String) ?? "default"
    }

    var cleverTapID: String { ct?.profileGetID() ?? "unavailable" }

    func setPushToken(_ token: Data) {
        ct?.setPushToken(token)
    }

    // MARK: Profile

    /// Logs the persona in. Reserved keys stay unprefixed, custom keys come from CT.Prop.
    func onUserLogin(reserved: [CT.Reserved: Any], custom: [CT.Prop: Any]) {
        var payload: [String: Any] = [:]
        reserved.forEach { payload[$0.key.rawValue] = $0.value }
        custom.forEach { payload[$0.key.key] = $0.value }
        ct?.onUserLogin(payload)
        log("onUserLogin \(reserved[.identity] ?? "")")
    }

    func pushProfile(_ props: [CT.Prop: Any]) {
        guard !props.isEmpty else { return }
        var payload: [String: Any] = [:]
        props.forEach { payload[$0.key.key] = $0.value }
        ct?.profilePush(payload)
        log("profilePush \(props.count) props")
    }

    func removeProfileValues(_ props: [CT.Prop]) {
        props.forEach { ct?.profileRemoveValue(forKey: $0.key) }
        if !props.isEmpty { log("profileRemoveValue \(props.count) props") }
    }

    /// Subscription state uses the reserved MSG- keys; the LinkAJA_ opt-in properties mirror them.
    func setOptIns(email: Bool, push: Bool, whatsapp: Bool) {
        var payload: [String: Any] = [
            CT.Reserved.msgEmail.rawValue: email,
            CT.Reserved.msgPush.rawValue: push,
            CT.Reserved.msgWhatsapp.rawValue: whatsapp
        ]
        payload[CT.Prop.emailOptIn.key] = email
        payload[CT.Prop.pushOptIn.key] = push
        payload[CT.Prop.whatsappOptIn.key] = whatsapp
        ct?.profilePush(payload)
        log("opt-ins email=\(email) push=\(push) wa=\(whatsapp)")
    }

    // MARK: Events

    func record(_ event: CT.Event, _ props: [CT.EventProp: Any] = [:]) {
        var payload: [String: Any] = [:]
        props.forEach { payload[$0.key.rawValue] = $0.value }
        if payload.isEmpty {
            ct?.recordEvent(event.name)
        } else {
            ct?.recordEvent(event.name, withProps: payload)
        }
        let detail = payload.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        log("\(event.name)\(detail.isEmpty ? "" : " [\(detail)]")")
    }

    // MARK: App Inbox

    private func initializeInbox() {
        ct?.initializeInbox { [weak self] success in
            guard success else { return }
            self?.refreshInbox()
            // Fires whenever new inbox messages arrive from the dashboard.
            self?.ct?.registerInboxUpdatedBlock { self?.refreshInbox() }
        }
    }

    func refreshInbox() {
        DispatchQueue.main.async {
            self.inboxMessages = self.ct?.getAllInboxMessages() ?? []
            self.inboxUnread = self.ct?.getInboxMessageUnreadCount() ?? 0
        }
    }

    func inboxMessageViewed(_ m: CleverTapInboxMessage) {
        guard let id = m.messageId else { return }
        ct?.recordInboxNotificationViewedEvent(forID: id)
    }

    /// Records the click, marks the card read and returns its action URL, if any.
    func inboxMessageClicked(_ m: CleverTapInboxMessage) -> URL? {
        guard let id = m.messageId else { return nil }
        ct?.recordInboxNotificationClickedEvent(forID: id)
        ct?.markReadInboxMessage(forID: id)
        refreshInbox()
        return m.content?.first?.actionUrl.flatMap { URL(string: $0) }
    }

    func deleteInboxMessage(_ m: CleverTapInboxMessage) {
        guard let id = m.messageId else { return }
        ct?.deleteInboxMessage(forID: id)
        refreshInbox()
    }

    // MARK: Logging

    /// Adds a line to the Demo Tools activity log. Callers never pass secrets.
    func note(_ line: String) { log(line) }

    private func log(_ line: String) {
        DispatchQueue.main.async {
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
            self.activityLog.insert("\(f.string(from: Date()))  \(line)", at: 0)
            if self.activityLog.count > 60 { self.activityLog.removeLast() }
        }
    }
}

// MARK: - URL and in-app delegates

extension CleverTapManager: CleverTapURLDelegate {
    /// Called for CTA URLs from push, in-app and inbox. Returning false means the app handles the URL itself.
    func shouldHandleCleverTap(_ url: URL?, for channel: CleverTapChannel) -> Bool {
        if let url {
            DispatchQueue.main.async { self.deepLinkHandler?(url) }
        }
        return false
    }
}

extension CleverTapManager: CleverTapInAppNotificationDelegate {
    /// Return true to let the SDK show the in-app. Key-value payloads arrive in `extras`.
    func shouldShowInAppNotification(withExtras extras: [AnyHashable: Any]!) -> Bool {
        log("in-app will show extras=\(extras ?? [:])")
        // Screenshot runs open screens directly, so dashboard in-app campaigns would cover them.
        return !ScreenshotMode.active
    }

    func inAppNotificationDismissed(withExtras extras: [AnyHashable: Any]!, andActionExtras actionExtras: [AnyHashable: Any]!) {
        log("in-app dismissed action=\(actionExtras ?? [:])")
    }
}
