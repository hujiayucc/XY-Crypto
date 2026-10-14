import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var fileChannel: FlutterMethodChannel?
  private var pendingFileURL: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.hujiayucc.decode/privacy",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "hasCameraPermission" {
          result(AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      fileChannel = FlutterMethodChannel(name: "com.hujiayucc.decode/file", binaryMessenger: controller.binaryMessenger)
      fileChannel?.setMethodCallHandler { [weak self] call, result in
        if call.method == "getInitialFile" {
          guard let url = self?.pendingFileURL else { result(nil); return }
          self?.pendingFileURL = nil
          result(self?.filePayload(url))
        } else { result(FlutterMethodNotImplemented) }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if url.pathExtension.lowercased() == "xyshare" { pendingFileURL = url; return true }
    return super.application(app, open: url, options: options)
  }

  private func filePayload(_ url: URL) -> [String: Any]? {
    guard url.pathExtension.lowercased() == "xyshare" else { return nil }
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    guard let bytes = try? Data(contentsOf: url), bytes.count <= 32 * 1024 * 1024 else { return nil }
    return ["name": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: bytes)]
  }
}
