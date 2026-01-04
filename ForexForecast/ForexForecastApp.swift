import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// ===============================
// Firebase / Notification AppDelegate
// ===============================
class AppDelegate: NSObject,
                   UIApplicationDelegate,
                   UNUserNotificationCenterDelegate,
                   MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Firebase 初期化
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // 通知許可
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            print("🔔 通知許可:", granted)
            if let error = error {
                print("❌ 通知許可エラー:", error)
            }
        }

        application.registerForRemoteNotifications()
        return true
    }

    // ===============================
    // フォアグラウンド通知表示対応
    // ===============================
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // アラート、バッジ、サウンドで通知を表示
        completionHandler([.alert, .badge, .sound])
    }

    // ===============================
    // FCM トークン取得
    // ===============================
    func messaging(_ messaging: Messaging,
                   didReceiveRegistrationToken fcmToken: String?) {

        guard let token = fcmToken else {
            print("❌ FCMトークン nil")
            return
        }

        print("🔥 FCMトークン:", token)

        guard let url = URL(string: "https://harukitech.site/register_token") else {
            print("❌ URL生成失敗")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["token": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("❌ トークン送信エラー:", error)
            } else {
                print("✅ トークン送信成功")
            }
        }.resume()
    }

    // APNs → Firebase
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

// ===============================
// SwiftUI App
// ===============================
@main
struct ForexForecastApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}