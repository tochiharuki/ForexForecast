//
//  ForexForecastApp.swift
//  ForexForecast
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging       // ★追加
import UserNotifications

// ===============================
// Firebase / Notification AppDelegate
// ===============================
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // ★ Firebase 初期化
        FirebaseApp.configure()

        // ★ 通知 delegate 設定
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // ★ 通知許可リクエスト
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            print("🔔 通知許可:", granted)
            if let error = error {
                print("❌ 通知許可エラー:", error)
            }
        }

        application.registerForRemoteNotifications() // ★必須

        return true
    }

    // ===============================
    // FCM トークン取得
    // ===============================
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("❌ FCMトークン nil")
            return
        }

        print("🔥 FCMトークン:", token)

        // ===============================
        // FastAPI にトークン送信
        // ===============================
        guard let url = URL(string: "https://harukitech.site/register_token") else {
            print("❌ URL生成失敗")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "token": token
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("❌ トークン送信エラー:", error)
                return
            }
            print("✅ トークン送信成功")
        }.resume()
    }

    // ===============================
    // APNs トークン → Firebase
    // ===============================
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

    // ★ AppDelegate を SwiftUI に接続
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}