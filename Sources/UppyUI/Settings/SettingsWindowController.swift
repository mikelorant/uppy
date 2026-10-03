import AppKit
import UppyCore

@MainActor
public final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private let listController: EndpointListController

  public init(monitor: EndpointMonitor) {
    listController = EndpointListController(monitor: monitor)
    let content = SettingsContentView(tableView: listController.tableView)
    let window = UppySettingsWindow(
      contentRect: NSRect(origin: .zero, size: content.preferredSize),
      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false
    )
    super.init(window: window)
    window.delegate = self
    window.contentView = content
    configureWindow(window)
  }

  public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  private func configureWindow(_ window: NSWindow) {
    window.backgroundColor = NSColor(name: .init("UppySettingsBackground")) { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(calibratedWhite: 0.15, alpha: 1)
        : NSColor(calibratedWhite: 0.90, alpha: 1)
    }
    window.title = ""
    window.titleVisibility = .hidden
    window.center()
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 540, height: 315)
  }

  public func windowDidBecomeKey(_ notification: Notification) {
    (window?.contentView as? SettingsContentView)?.loginControl.refresh()
  }

  public func windowShouldClose(_ sender: NSWindow) -> Bool {
    listController.endEditing()
    return true
  }

  public func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
