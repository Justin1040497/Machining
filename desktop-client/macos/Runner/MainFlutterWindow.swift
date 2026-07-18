import Cocoa
import FlutterMacOS
import ObjectiveC.runtime
import Sparkle

private final class FrameLeanManagedPreferencesBridge {
  private static let managedKeys = [
    "schemaVersion",
    "mode",
    "updateBaseUrl",
    "channel",
    "ring",
    "allowAutomaticChecks",
    "allowInAppInstall",
    "macosAppcastUrl",
    "trustedReleaseKeyIds"
  ]

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "framelean/enterprise_update_config",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "readManagedPreferences" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(readManagedPreferences())
    }
  }

  private static func readManagedPreferences() -> [String: Any] {
    let bundleId = Bundle.main.bundleIdentifier ?? "com.justin.framelean"
    var values: [String: Any] = [:]
    for key in managedKeys {
      if CFPreferencesAppValueIsForced(key as CFString, bundleId as CFString) {
        if let value = UserDefaults.standard.object(forKey: key) {
          values[key] = value
        }
      }
    }
    return values
  }
}

private final class FrameLeanSparkleBridge: NSObject, SPUUpdaterDelegate {
  private var controller: SPUStandardUpdaterController!
  private var feedURLOverride: String?
  private var allowInAppInstall = true
  private var updaterStarted = false
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "framelean/sparkle_update",
      binaryMessenger: messenger
    )
    super.init()
    controller = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: self,
      userDriverDelegate: nil
    )

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let args = call.arguments as? [String: Any] ?? [:]
      self.configure(args: args)
      self.startUpdaterIfNeeded()
      switch call.method {
      case "checkForUpdates":
        if self.controller.updater.canCheckForUpdates {
          self.controller.updater.checkForUpdates()
        }
        result(nil)
      case "checkForUpdateInformation":
        if self.controller.updater.canCheckForUpdates {
          self.controller.updater.checkForUpdateInformation()
        }
        result(nil)
      case "getUpdatePolicyStatus":
        result([
          "available": true,
          "automaticChecksEnabled": self.controller.updater.automaticallyChecksForUpdates,
          "appcastUrl": self.feedURLOverride ?? ""
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configure(args: [String: Any]) {
    if let appcastUrl = args["appcastUrl"] as? String, !appcastUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      feedURLOverride = appcastUrl
    }
    if let allowAutomaticChecks = args["allowAutomaticChecks"] as? Bool {
      controller.updater.automaticallyChecksForUpdates = allowAutomaticChecks
    }
    if let allowed = args["allowInAppInstall"] as? Bool {
      allowInAppInstall = allowed
    }
  }

  private func startUpdaterIfNeeded() {
    if updaterStarted {
      return
    }
    controller.startUpdater()
    updaterStarted = true
  }

  func feedURLString(for updater: SPUUpdater) -> String? {
    return feedURLOverride
  }

  func updater(
    _ updater: SPUUpdater,
    shouldProceedWithUpdate updateItem: SUAppcastItem,
    updateCheck: SPUUpdateCheck
  ) throws {
    if !allowInAppInstall {
      throw NSError(
        domain: "com.justin.framelean.update",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "当前更新策略不允许在应用内安装更新。"]
      )
    }
  }

  func updater(
    _ updater: SPUUpdater,
    shouldPostponeRelaunchForUpdate item: SUAppcastItem,
    untilInvokingBlock installHandler: @escaping () -> Void
  ) -> Bool {
    channel.invokeMethod("prepareForUpdateRestart", arguments: nil) { response in
      DispatchQueue.main.async {
        if response != nil {
          let error = response as? FlutterError
          let alert = NSAlert()
          alert.alertStyle = .warning
          alert.messageText = "无法准备更新重启"
          alert.informativeText = error?.message ?? "请停止运行中的任务后重试。"
          alert.runModal()
          return
        }
        installHandler()
      }
    }
    return true
  }
}

private enum FrameLeanFirstMouse {
  private static var patchedClassNames = Set<String>()

  static func enable(for rootView: NSView) {
    patchClass(type(of: rootView))

    for subview in rootView.subviews {
      enable(for: subview)
    }
  }

  private static func patchClass(_ viewClass: AnyClass) {
    let className = NSStringFromClass(viewClass)
    if patchedClassNames.contains(className) {
      return
    }
    patchedClassNames.insert(className)

    let selector = #selector(NSView.acceptsFirstMouse(for:))
    let acceptsFirstMouse: @convention(block) (AnyObject, NSEvent?) -> Bool = { _, _ in
      true
    }
    class_replaceMethod(
      viewClass,
      selector,
      imp_implementationWithBlock(acceptsFirstMouse as Any),
      "c@:@"
    )
  }
}

class MainFlutterWindow: NSWindow {
  private var sparkleBridge: FrameLeanSparkleBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let defaultWindowSize = NSSize(width: 685, height: 685)
    let windowFrame = self.frame
    let defaultWindowFrame = NSRect(
      x: windowFrame.origin.x,
      y: windowFrame.origin.y,
      width: defaultWindowSize.width,
      height: defaultWindowSize.height
    )
    self.contentViewController = flutterViewController
    self.minSize = defaultWindowSize
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.setFrame(defaultWindowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FrameLeanManagedPreferencesBridge.register(messenger: flutterViewController.engine.binaryMessenger)
    sparkleBridge = FrameLeanSparkleBridge(messenger: flutterViewController.engine.binaryMessenger)
    // FlutterView and desktop_drop's native drag view must handle the click
    // that also activates an inactive macOS window.
    FrameLeanFirstMouse.enable(for: flutterViewController.view)

    super.awakeFromNib()
  }
}
