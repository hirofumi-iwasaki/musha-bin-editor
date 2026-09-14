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
    title = "Mushaaeshi Binary Editor"
    center()
    RegisterGeneratedPlugins(registry: controller)
    channel = FlutterMethodChannel(name: "mushaaeshi/files", binaryMessenger: controller.engine.binaryMessenger)
    registerForDraggedTypes([.fileURL])
    channel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "openFile", let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      let side = (call.arguments as? [String: String])?["side"] ?? "Left"
      let panel = NSOpenPanel()
      panel.title = "Open \(side) Binary File"
      panel.prompt = "Open"
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

  private func droppedURLs(_ sender: NSDraggingInfo) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    return sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
  }

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let urls = droppedURLs(sender)
    guard urls.count == 1, !urls[0].hasDirectoryPath else { return [] }
    return .copy
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let urls = droppedURLs(sender)
    guard urls.count == 1 else {
      channel?.invokeMethod("fileDropError", arguments: ["message": "Drop exactly one file at a time."])
      return false
    }
    let url = urls[0]
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
      channel?.invokeMethod("fileDropError", arguments: ["message": "The dropped item is not a readable file."])
      return false
    }
    let side = sender.draggingLocation.x < frame.width / 2 ? "Left" : "Right"
    accessURLs[side]?.stopAccessingSecurityScopedResource()
    if url.startAccessingSecurityScopedResource() { accessURLs[side] = url }
    else { accessURLs.removeValue(forKey: side) }
    channel?.invokeMethod("fileDropped", arguments: ["path": url.path, "side": side])
    return true
  }
}
