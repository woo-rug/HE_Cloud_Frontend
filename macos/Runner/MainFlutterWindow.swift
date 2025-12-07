import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let preferredSize = NSSize(width: 1200, height: 800)
    let windowFrame = NSRect(
      x: frame.origin.x,
      y: frame.origin.y + (frame.size.height - preferredSize.height),
      width: preferredSize.width,
      height: preferredSize.height
    )
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.center()
    self.minSize = preferredSize
    self.maxSize = preferredSize
    self.styleMask.remove(.resizable)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
