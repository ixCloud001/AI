import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 注册剪贴板方法通道
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      super.applicationDidFinishLaunching(notification)
      return
    }
    
    let clipboardChannel = FlutterMethodChannel(
      name: "com.remotedesktopmacos.clipboard",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    clipboardChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "setImage" {
        // 设置图片到剪贴板
        if let imageData = call.arguments as? FlutterStandardTypedData {
          let nsImage = NSImage(data: imageData.data)
          if let image = nsImage {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            result(nil)
          } else {
            result(FlutterError(code: "INVALID_IMAGE", message: "无法解析图片数据", details: nil))
          }
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "参数必须是Uint8List", details: nil))
        }
      } else if call.method == "getImage" {
        // 从剪贴板获取图片
        let pasteboard = NSPasteboard.general
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
          if let tiffData = image.tiffRepresentation,
             let bitmapImage = NSBitmapImageRep(data: tiffData),
             let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            result(FlutterStandardTypedData(bytes: pngData))
          } else {
            result(nil)
          }
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
