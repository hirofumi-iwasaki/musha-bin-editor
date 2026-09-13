// SPDX-License-Identifier: GPL-3.0-or-later
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var channel: FlutterMethodChannel?
  private var accessURLs: [String: URL] = [:]

  override func awakeFromNib() {
    let controller = FlutterViewController()
    contentViewController = controller
    setContentSize(NSSize(width: 1440, height: 860))
    minSize = NSSize(width: 980, height: 600)
    title = "Mushagaeshi Bin Diff"
    center()
    RegisterGeneratedPlugins(registry: controller)
    channel = FlutterMethodChannel(name: "mushagaeshi/files", binaryMessenger: controller.engine.binaryMessenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "openFile", let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      let side = (call.arguments as? [String: String])?["side"] ?? "左"
      let panel = NSOpenPanel()
      panel.title = "\(side)のバイナリーファイルを開く"
      panel.canChooseDirectories = false
      panel.canChooseFiles = true
      panel.allowsMultipleSelection = false
      panel.beginSheetModal(for: self) { response in
        guard response == .OK, let url = panel.url else { result(nil); return }
        self.accessURLs[side]?.stopAccessingSecurityScopedResource()
        if url.startAccessingSecurityScopedResource() { self.accessURLs[side] = url }
        else { self.accessURLs.removeValue(forKey: side) }
        result(url.path)
      }
    }
    super.awakeFromNib()
  }

  deinit { for url in accessURLs.values { url.stopAccessingSecurityScopedResource() } }
}
