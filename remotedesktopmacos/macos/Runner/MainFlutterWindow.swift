import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    
    // 设置默认窗口大小（1000x750）
    let defaultFrame = NSRect(x: 0, y: 0, width: 1000, height: 750)
    self.setFrame(defaultFrame, display: true)
    
    // 窗口居中显示
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
