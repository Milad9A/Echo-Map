import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set up method channel to get API key from Dart environment
    let controller = window?.rootViewController as! FlutterViewController
    let apiKeyChannel = FlutterMethodChannel(
      name: "com.echomap/environment",
      binaryMessenger: controller.binaryMessenger
    )

    // Initialize with API key from strings.xml immediately to avoid timing issues
    GMSServices.provideAPIKey("AIzaSyCDbCBlp1BPzDJA6syOvXFooptR7wZxkmM")

    // Register a method handler to receive the API key from Dart (for future reference)
    apiKeyChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "setGoogleMapsApiKey" {
        if let args = call.arguments as? [String: Any],
          let apiKey = args["apiKey"] as? String
        {
          // API key already initialized above, just log success
          print("API key confirmed: \(apiKey)")
          result(true)
        } else {
          result(
            FlutterError(
              code: "INVALID_ARGUMENTS",
              message: "Invalid arguments for setGoogleMapsApiKey",
              details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
