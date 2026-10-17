import AVFoundation
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
    let channel = FlutterMethodChannel(
      name: "shop_it/barcode",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "scan" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let portrait = (call.arguments as? [String: Any])?["portrait"] as? Bool ?? false
      DispatchQueue.main.async {
        guard let presenter = Self.topViewController() else {
          result(nil)
          return
        }
        let scanner = BarcodeScannerController()
        scanner.lockPortrait = portrait
        scanner.onCode = { code in result(code) }
        scanner.modalPresentationStyle = .fullScreen
        presenter.present(scanner, animated: true)
      }
    }
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
      ?? scene?.windows.first?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}

/// Reads one product barcode. An iPhone stays portrait. An iPad can rotate.
final class BarcodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  var onCode: ((String?) -> Void)?
  var lockPortrait = false

  private let session = AVCaptureSession()
  private var finished = false
  private let preview = AVCaptureVideoPreviewLayer()

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    lockPortrait ? .portrait : .all
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    preview.videoGravity = .resizeAspectFill
    view.layer.addSublayer(preview)

    let close = UIButton(type: .system)
    close.setTitle("Cancel", for: .normal)
    close.tintColor = .white
    close.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
    close.addTarget(self, action: #selector(cancel), for: .touchUpInside)
    close.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(close)
    NSLayoutConstraint.activate([
      close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
    ])

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      startCamera()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          if granted {
            self.startCamera()
          } else {
            self.finish(nil)
          }
        }
      }
    default:
      finish(nil)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    preview.frame = view.bounds
  }

  private func startCamera() {
    guard
      let device = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input)
    else {
      finish(nil)
      return
    }
    session.addInput(input)
    let output = AVCaptureMetadataOutput()
    guard session.canAddOutput(output) else {
      finish(nil)
      return
    }
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: .main)
    output.metadataObjectTypes = [.ean8, .ean13, .upce]
    preview.session = session
    DispatchQueue.global(qos: .userInitiated).async {
      self.session.startRunning()
    }
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard
      let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
      let value = object.stringValue,
      !value.isEmpty
    else { return }
    finish(value)
  }

  @objc private func cancel() {
    finish(nil)
  }

  private func finish(_ code: String?) {
    if finished { return }
    finished = true
    if session.isRunning {
      session.stopRunning()
    }
    let deliver = onCode
    onCode = nil
    if presentingViewController != nil || parent != nil {
      dismiss(animated: true) { deliver?(code) }
    } else {
      deliver?(code)
    }
  }
}
