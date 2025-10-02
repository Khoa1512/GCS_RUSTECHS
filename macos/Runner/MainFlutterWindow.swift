import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    // Set initial window size for VTOL control system
    let initialWidth: CGFloat = 1400
    let initialHeight: CGFloat = 900
    let minWidth: CGFloat = 1200
    let minHeight: CGFloat = 800

    // Get screen dimensions to center the window
    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      let windowX = (screenFrame.width - initialWidth) / 2
      let windowY = (screenFrame.height - initialHeight) / 2

      let windowFrame = NSRect(x: windowX, y: windowY, width: initialWidth, height: initialHeight)
      self.setFrame(windowFrame, display: true)
    }

    // Set minimum window size
    self.minSize = NSSize(width: minWidth, height: minHeight)

    // Set window properties
    self.title = "VTOL Control System"

    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
