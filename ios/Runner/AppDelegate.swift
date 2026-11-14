import Flutter
import LocalAuthentication
import Security
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "EntryNotePrivacy") {
      let channel = FlutterMethodChannel(name: "entries/privacy", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "hasScreenLock":
          result(LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil))
        case "isScreenLockKeyMissing":
          guard let service = call.arguments as? String, service.hasPrefix("entries_recovery_v1") else {
            result(false)
            return
          }
          let context = LAContext()
          context.interactionNotAllowed = true
          let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "private_key",
            kSecUseAuthenticationContext as String: context,
            kSecReturnAttributes as String: true
          ]
          result(SecItemCopyMatching(query as CFDictionary, nil) == errSecItemNotFound)
        case "verifyScreenLock":
          let context = LAContext()
          let reason = (call.arguments as? String) ?? "Unlock private information"
          context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { result(success) }
          }
        case "copyPrivateValue":
          guard let value = call.arguments as? String, !value.isEmpty else {
            result(FlutterError(code: "clipboard_unavailable", message: nil, details: nil))
            return
          }
          UIPasteboard.general.setItems(
            [["public.utf8-plain-text": value]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]
          )
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
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
