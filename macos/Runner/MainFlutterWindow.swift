import Cocoa
import FlutterMacOS
import Network

class MainFlutterWindow: NSWindow {
  private let localNetwork = LocalNetworkProbe()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let network = FlutterMethodChannel(
      name: "shop.it/network",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    network.setMethodCallHandler { [weak self] call, result in
      guard call.method == "multicastLock" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.localNetwork.setEnabled(call.arguments as? Bool ?? false)
      result(nil)
    }

    super.awakeFromNib()
  }
}

/// Asks macOS for local-network permission. An Android phone cannot see this
/// Mac on Wi-Fi, or finish a QR sync, until that permission is allowed.
final class LocalNetworkProbe {
  private var browser: NWBrowser?

  func setEnabled(_ on: Bool) {
    if !on {
      browser?.cancel()
      browser = nil
      return
    }
    if browser != nil { return }
    let browser = NWBrowser(
      for: .bonjour(type: "_shopit._udp", domain: "local."),
      using: .tcp
    )
    browser.stateUpdateHandler = { _ in }
    browser.browseResultsChangedHandler = { _, _ in }
    browser.start(queue: .main)
    self.browser = browser
  }
}
