import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Push notifications (PushService, lib/core/push/push_service.dart).
    // Routes foreground APNs presentation/response through the Firebase SDK
    // (registered as its own delegate internally), which is what lets
    // firebase_messaging's onMessage/onMessageOpenedApp fire on iOS at all.
    // Harmless with no GoogleService-Info.plist present (docs/push-setup.md):
    // nothing calls this app back, since it never registers for remote
    // notifications without a configured Firebase project.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
