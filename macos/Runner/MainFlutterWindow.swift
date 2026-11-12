import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(
      name: "entries/google_config", binaryMessenger: flutterViewController.engine.binaryMessenger)
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

    super.awakeFromNib()
  }
}
