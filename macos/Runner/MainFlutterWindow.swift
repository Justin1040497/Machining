import Cocoa
import FlutterMacOS

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
    self.setFrame(defaultWindowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
