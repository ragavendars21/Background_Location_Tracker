import Flutter
import UIKit
import GoogleMaps

/*
 How Platform Channels work (recruiter-ready explanation):
 ─────────────────────────────────────────────────────────
 Flutter and Swift live in separate worlds. A FlutterMethodChannel is the
 named pipe connecting them — both sides must use the same name string.

 Flutter calls:   channel.invokeMethod("getBatteryLevel")
 iOS hears it via setMethodCallHandler and runs Swift code.
 iOS replies with a Dictionary ["level": 78, "isCharging": true].
 Flutter receives it as Map<Object?, Object?> and shows the number.

 Three rules (same on all platforms):
   1. Channel name must match Dart exactly.
   2. Only Foundation types cross the boundary: Int, Double, Bool, String,
      Array, Dictionary. Swift structs/enums do NOT travel — use primitives.
   3. Always call result() exactly once per handler invocation.
*/
@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Google Maps must be initialised before GeneratedPluginRegistrant.
        // Replace YOUR_GOOGLE_MAPS_API_KEY with a key from the Google Cloud Console.
        // Enable: Maps SDK for iOS
        // Restrict to: iOS apps → bundle ID (com.backgroundtracker.app)
        GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")

        GeneratedPluginRegistrant.register(with: self)
        setupBatteryChannel()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: – Battery Platform Channel

    private func setupBatteryChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        // Must match AppConstants.batteryChannelName on the Dart side.
        let channel = FlutterMethodChannel(
            name: "com.backgroundtracker.app/battery",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard call.method == "getBatteryLevel" else {
                result(FlutterMethodNotImplemented)
                return
            }
            self.handleGetBatteryLevel(result: result)
        }
    }

    // MARK: – Handler

    private func handleGetBatteryLevel(result: FlutterResult) {
        // batteryLevel is disabled by default to conserve power.
        // We enable it here, read once, then disable again — so we never
        // leave the monitor running between 30-second polling intervals.
        UIDevice.current.isBatteryMonitoringEnabled = true
        defer { UIDevice.current.isBatteryMonitoringEnabled = false }

        let rawLevel = UIDevice.current.batteryLevel

        // batteryLevel returns -1.0 when monitoring is unavailable:
        // always true on the iOS Simulator.
        guard rawLevel >= 0 else {
            result(FlutterError(
                code:    "UNAVAILABLE",
                message: "Battery information is not available on this device or simulator",
                details: nil
            ))
            return
        }

        // rawLevel is a Float in [0.0, 1.0]. Multiply by 100 and truncate to Int.
        let level = Int(rawLevel * 100)

        // isCharging = plugged in AND not yet full.
        // isFull     = plugged in AND at 100 %.
        // We report both as "charging" because the user just wants to know
        // "am I on the charger?" — the distinction only matters for animations.
        let state = UIDevice.current.batteryState
        let isCharging = (state == .charging || state == .full)

        // Return a Dictionary. FlutterStandardMessageCodec serialises it to
        // Dart's Map<Object?, Object?> automatically.
        result([
            "level"      : level,
            "isCharging" : isCharging
        ])
    }
}
