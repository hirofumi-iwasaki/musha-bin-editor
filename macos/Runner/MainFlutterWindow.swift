// SPDX-License-Identifier: GPL-3.0-or-later
import Cocoa
import FlutterMacOS

private final class FileDropHostView: NSView {
  var channel: FlutterMethodChannel?
  private var accessURLs: [String: URL] = [:]

  override var isFlipped: Bool { true }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL, .URL])
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes([.fileURL, .URL])
  }

  private func URLs(_ sender: NSDraggingInfo) -> [URL] {
    sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
  }

  private func point(_ sender: NSDraggingInfo) -> NSPoint {
    convert(sender.draggingLocation, from: nil)
  }

  private func notify(_ method: String, sender: NSDraggingInfo) {
    let location = point(sender)
    channel?.invokeMethod(method, arguments: ["x": location.x, "y": location.y])
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    notify("fileDragUpdated", sender: sender)
    return .copy
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    notify("fileDragUpdated", sender: sender)
    return .copy
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    channel?.invokeMethod("fileDragExited", arguments: nil)
  }

  override func draggingEnded(_ sender: NSDraggingInfo) {
    channel?.invokeMethod("fileDragExited", arguments: nil)
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    defer { channel?.invokeMethod("fileDragExited", arguments: nil) }
    let urls = URLs(sender)
    guard urls.count == 1 else {
      channel?.invokeMethod("fileDropError", arguments: ["message": "Drop exactly one file at a time."])
      return false
    }
    let url = urls[0]
    guard url.isFileURL else {
      channel?.invokeMethod("fileDropError", arguments: ["message": "Only files from Finder can be dropped here."])
      return false
    }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
      channel?.invokeMethod("fileDropError", arguments: ["message": "The dropped item is not a readable file."])
      return false
    }
    let location = point(sender)
    if url.startAccessingSecurityScopedResource() { accessURLs[url.path] = url }
    channel?.invokeMethod("fileDropped", arguments: ["path": url.path, "x": location.x, "y": location.y])
    return true
  }

  deinit { for url in accessURLs.values { url.stopAccessingSecurityScopedResource() } }
}

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var channel: FlutterMethodChannel?
  private var accessURLs: [String: URL] = [:]
  private var allowClose = false

  override func awakeFromNib() {
    let controller = FlutterViewController()
    let host = FileDropHostView(frame: frame)
    let hostController = NSViewController()
    hostController.view = host
    hostController.addChild(controller)
    controller.view.frame = host.bounds
    controller.view.autoresizingMask = [.width, .height]
    host.addSubview(controller.view)
    contentViewController = hostController
    setContentSize(NSSize(width: 1440, height: 860))
    minSize = NSSize(width: 980, height: 600)
    title = "Mushagaeshi Binary Editor"
    delegate = self
    center()
    RegisterGeneratedPlugins(registry: controller)
    channel = FlutterMethodChannel(name: "mushagaeshi/files", binaryMessenger: controller.engine.binaryMessenger)
    host.channel = channel
    channel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      if call.method == "confirmClose" {
        self.allowClose = true
        self.performClose(nil)
        result(nil)
        return
      }
      if call.method == "saveFile" {
        let arguments = call.arguments as? [String: String]
        let side = arguments?["side"] ?? "File"
        let panel = NSSavePanel()
        panel.title = "Save \(side) Binary File As"
        panel.prompt = "Save"
        panel.nameFieldStringValue = arguments?["name"] ?? "binary.bin"
        panel.beginSheetModal(for: self) { response in
          guard response == .OK, let url = panel.url else { result(nil); return }
          if url.startAccessingSecurityScopedResource() { self.accessURLs[url.path] = url }
          result(url.path)
        }
        return
      }
      if call.method == "installSavedFile" {
        guard
          let arguments = call.arguments as? [String: String],
          let stagedPath = arguments["stagedPath"],
          let destinationPath = arguments["destinationPath"]
        else {
          result(FlutterError(code: "invalid-save", message: "The save request is incomplete.", details: nil))
          return
        }
        let stagedURL = URL(fileURLWithPath: stagedPath)
        let destinationURL = URL(fileURLWithPath: destinationPath)
        do {
          if FileManager.default.fileExists(atPath: destinationPath) {
            _ = try FileManager.default.replaceItemAt(
              destinationURL,
              withItemAt: stagedURL,
              backupItemName: nil,
              options: []
            )
          } else {
            try FileManager.default.moveItem(at: stagedURL, to: destinationURL)
          }
          result(nil)
        } catch {
          result(FlutterError(code: "save-failed", message: "Unable to install the saved file: \(error.localizedDescription)", details: nil))
        }
        return
      }
      guard call.method == "openFile" else {
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
        if url.startAccessingSecurityScopedResource() { self.accessURLs[url.path] = url }
        result(url.path)
      }
    }
    super.awakeFromNib()
  }

  deinit { for url in accessURLs.values { url.stopAccessingSecurityScopedResource() } }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if allowClose { return true }
    channel?.invokeMethod("requestClose", arguments: nil)
    return false
  }
}
