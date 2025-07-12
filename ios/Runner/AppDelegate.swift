import UIKit
import Flutter
import GoogleMaps
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()
    print("AppDelegate: Firebase configured")

    // Set up Google Maps Method Channel
    let controller = window?.rootViewController as! FlutterViewController
    let mapsChannel = FlutterMethodChannel(name: "com.mhealth.nhap/maps", binaryMessenger: controller.binaryMessenger)
    mapsChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "setGoogleMapsApiKey" {
        if let args = call.arguments as? [String: String], let apiKey = args["apiKey"] {
          GMSServices.provideAPIKey(apiKey)
          print("AppDelegate: Google Maps API key set: \(apiKey)")
          result(true)
        } else {
          result(FlutterError(code: "INVALID_API_KEY", message: "API key not provided", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Set up Firebase Messaging
    Messaging.messaging().delegate = self
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]) { granted, error in
        print("AppDelegate: Notification permission granted: \(granted)")
        if let error = error {
          print("AppDelegate: Notification permission error: \(error)")
        }
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    print("AppDelegate: Registered for remote notifications with APNs token")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("AppDelegate: Failed to register for remote notifications: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // UNUserNotificationCenterDelegate methods
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    print("AppDelegate: Notification will present: \(notification.request.content.userInfo)")
    completionHandler([.alert, .badge, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("AppDelegate: Notification tapped: \(userInfo)")
    if let flutterEngine = (window?.rootViewController as? FlutterViewController)?.engine {
      let channel = FlutterMethodChannel(
        name: "com.mhealth.nhap/notifications",
        binaryMessenger: flutterEngine.binaryMessenger
      )
      channel.invokeMethod("handleNotification", arguments: userInfo)
    }
    completionHandler()
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("AppDelegate: FCM Token: \(fcmToken ?? "None")")
    if let token = fcmToken {
      let channel = FlutterMethodChannel(
        name: "com.mhealth.nhap/notifications",
        binaryMessenger: (window?.rootViewController as! FlutterViewController).binaryMessenger
      )
      channel.invokeMethod("updateFcmToken", arguments: token)
    }
  }
}