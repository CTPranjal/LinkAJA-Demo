import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // CleverTap must be configured before any other SDK call.
        CleverTapManager.shared.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Called from the Profile and login flow once the user is in the app.
    static func registerForPush() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        CleverTapManager.shared.setPushToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: UNUserNotificationCenterDelegate
    // With autoIntegrate the SDK swizzles these and records Notification Viewed / Clicked itself.
    // They are implemented here so the app also shows banners in the foreground and routes deep links.

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Push deep links come as wzrk_dl in the payload. The SDK also forwards them through the URL delegate,
        // and DeepLinkRouter ignores a repeat of the same URL within a second.
        let userInfo = response.notification.request.content.userInfo
        if let dl = userInfo["wzrk_dl"] as? String, let url = URL(string: dl) {
            DispatchQueue.main.async { CleverTapManager.shared.deepLinkHandler?(url) }
        }
        completionHandler()
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
    }
}
