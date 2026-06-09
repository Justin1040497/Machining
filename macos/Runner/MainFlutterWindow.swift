import Cocoa
import FlutterMacOS
import ObjectiveC.runtime

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
    // FlutterView and desktop_drop's native drag view must handle the click
    // that also activates an inactive macOS window.
    FrameLeanFirstMouse.enable(for: flutterViewController.view)

    super.awakeFromNib()
  }
}
