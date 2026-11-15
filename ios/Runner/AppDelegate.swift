import Flutter
import CommonCrypto
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
      Self.registerPrivateCrypto(registrar.messenger())
      let channel = FlutterMethodChannel(name: "entries/privacy", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "hasScreenLock":
          var error: NSError?
          let available = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
          if available || error?.code == LAError.Code.passcodeNotSet.rawValue {
            result(available)
          } else {
            result(FlutterError(code: "recovery_prompt_failed", message: nil, details: error?.code))
          }
        case "canOfferBiometrics":
          let context = LAContext()
          var error: NSError?
          let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
          result(available || error?.code == LAError.Code.biometryNotEnrolled.rawValue)
        case "isScreenLockKeyMissing":
          if let service = call.arguments as? String, service.hasPrefix("entries_recovery_v3_") {
            result(Self.systemRecoveryStatus(service) == errSecItemNotFound)
            return
          }
          guard let service = call.arguments as? String,
                service.hasPrefix("entries_recovery_v1") || service.hasPrefix("entries_recovery_v2") else {
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
        case "wrapSystemRecoveryKey", "unwrapSystemRecoveryKey":
          Self.handleSystemRecovery(call, result: result)
        case "verifyScreenLock":
          let context = LAContext()
          let reason = (call.arguments as? String) ?? "Unlock private information"
          guard let accessControl = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .devicePasscode, nil
          ) else {
            result(false)
            return
          }
          context.evaluateAccessControl(accessControl, operation: .useItem, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
              switch (error as? LAError)?.code {
              case .userCancel, .systemCancel, .appCancel:
                result(false)
              case .passcodeNotSet:
                result(FlutterError(code: "no_screen_lock", message: nil, details: nil))
              case nil where success:
                result(true)
              default:
                result(FlutterError(code: "recovery_prompt_failed", message: nil, details: (error as NSError?)?.code))
              }
            }
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

  private static func systemRecoveryQuery(_ alias: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: alias,
      kSecAttrAccount as String: "EntryNote device recovery"
    ]
  }

  private static func systemRecoveryStatus(_ alias: String) -> OSStatus {
    let context = LAContext()
    context.interactionNotAllowed = true
    var query = systemRecoveryQuery(alias)
    query[kSecUseAuthenticationContext as String] = context
    query[kSecReturnAttributes as String] = true
    return SecItemCopyMatching(query as CFDictionary, nil)
  }

  private static func handleSystemRecovery(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let alias = arguments["alias"] as? String, alias.hasPrefix("entries_recovery_v3_") else {
      result(FlutterError(code: "invalid_key", message: nil, details: nil))
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let reply: Any?
      var query = systemRecoveryQuery(alias)
      if call.method == "wrapSystemRecoveryKey" {
        guard let bytes = arguments["data"] as? FlutterStandardTypedData, bytes.data.count == 32,
              let access = SecAccessControlCreateWithFlags(
                nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, nil
              ) else {
          DispatchQueue.main.async {
            result(FlutterError(code: "invalid_key", message: nil, details: nil))
          }
          return
        }
        if arguments["replace"] as? Bool == true {
          let deletion = SecItemDelete(query as CFDictionary)
          if deletion != errSecSuccess && deletion != errSecItemNotFound {
            DispatchQueue.main.async {
              result(FlutterError(code: "recovery_setup_failed", message: nil, details: deletion))
            }
            return
          }
        }
        query[kSecAttrAccessControl as String] = access
        query[kSecValueData as String] = bytes.data
        let status = SecItemAdd(query as CFDictionary, nil)
        reply = status == errSecSuccess || status == errSecDuplicateItem
          ? nil : FlutterError(code: "recovery_setup_failed", message: nil, details: status)
      } else {
        let context = LAContext()
        context.localizedReason = (arguments["prompt"] as? String) ?? "Unlock private information"
        query[kSecUseAuthenticationContext as String] = context
        query[kSecReturnData as String] = true
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecSuccess, let bytes = value as? Data {
          reply = FlutterStandardTypedData(bytes: bytes)
        } else if status == errSecUserCanceled {
          reply = nil
        } else {
          let code = status == errSecItemNotFound ? "recovery_key_missing" : "recovery_key_access_failed"
          reply = FlutterError(code: code, message: nil, details: status)
        }
      }
      DispatchQueue.main.async { result(reply) }
    }
  }

  private static func registerPrivateCrypto(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "entries/private_crypto", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "derivePasswordKey" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let typedSalt = arguments["salt"] as? FlutterStandardTypedData,
            typedSalt.data.count == 12,
            let password = arguments["password"] as? String else {
        result(FlutterError(code: "invalid_kdf_input", message: nil, details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        var passwordBytes = Data(password.utf8)
        let salt = typedSalt.data
        let keySize = 32
        var derived = Data(count: keySize)
        let status = derived.withUnsafeMutableBytes { (key: UnsafeMutableRawBufferPointer) in
          passwordBytes.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
            salt.withUnsafeBytes { (saltBuffer: UnsafeRawBufferPointer) in
              CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                input.bindMemory(to: Int8.self).baseAddress, input.count,
                saltBuffer.bindMemory(to: UInt8.self).baseAddress, saltBuffer.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 600_000,
                key.bindMemory(to: UInt8.self).baseAddress, keySize
              )
            }
          }
        }
        passwordBytes.resetBytes(in: 0..<passwordBytes.count)
        let response = status == Int32(kCCSuccess) ? FlutterStandardTypedData(bytes: derived) : nil
        DispatchQueue.main.async { result(response) }
      }
    }
  }
}
