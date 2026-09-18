import Cocoa
import desktop_drop
import FlutterMacOS
import XCTest
@testable import Mushagaeshi_Binary_Editor

class RunnerTests: XCTestCase {
  func testRegularFilesDoNotRequireAnExtension() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let extensionless = directory.appendingPathComponent("firmware")
    let unusualExtension = directory.appendingPathComponent("firmware.custom-image")
    try Data([0x00]).write(to: extensionless)
    try Data([0x01]).write(to: unusualExtension)

    XCTAssertTrue(FileDropValidation.isRegularFile(extensionless))
    XCTAssertTrue(FileDropValidation.isRegularFile(unusualExtension))
    XCTAssertFalse(FileDropValidation.isRegularFile(directory))
  }

  func testDesktopDropTargetSuppressionSearchesNestedViews() {
    let flutter = FlutterViewController()
    let host = FileDropHostView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
    let hostController = NSViewController()
    hostController.view = host
    hostController.addChild(flutter)
    flutter.view.frame = host.bounds
    host.addSubview(flutter.view)
    let window = NSWindow(
      contentRect: host.bounds,
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )
    window.contentViewController = hostController

    DesktopDropPlugin.register(
      with: flutter.engine.registrar(forPlugin: "DesktopDropPluginRegressionTest")
    )
    let pluginTarget = try! XCTUnwrap(
      flutter.view.subviews.first {
        String(reflecting: type(of: $0)) == "desktop_drop.DropTarget"
      }
    )
    XCTAssertTrue(pluginTarget.registeredDraggedTypes.contains(.fileURL))
    XCTAssertEqual(unregisterDesktopDropTargets(in: flutter.view), 1)
    XCTAssertTrue(pluginTarget.registeredDraggedTypes.isEmpty)
  }
}
