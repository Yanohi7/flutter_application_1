import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EntryNoteGoogleConfig") {
      let channel = FlutterMethodChannel(name: "entries/google_config", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "configuration" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        result([
          "clientId": Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? "",
          "schemes": types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] },
        ])
      }
    }
  }
}
