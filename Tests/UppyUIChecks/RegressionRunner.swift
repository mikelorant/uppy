import AppKit
import Foundation
import ServiceManagement
import UppyCore

@testable import UppyUI

@main
struct UIRegressionRunner {
  @MainActor
  static func main() {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    do {
      try checkEditing()
      try checkReordering()
      try checkMenuUpdates()
      try checkLoginControl()
      try checkKeyboardAndLayout()
      try checkTrashAppearance()
      print(
        "PASS: settings editing, reorder transactions, live menu, login controls, keyboard, layout and trash appearance"
      )
    } catch {
      print("FAIL: UI regression: \(error)")
      exit(1)
    }
  }
}

struct UIError: Error { let message: String }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  if !condition() { throw UIError(message: message) }
}

@MainActor
final class Fixture {
  let name = "UppyUIChecks.\(UUID().uuidString)"
  let defaults: UserDefaults
  let monitor: EndpointMonitor
  let list: EndpointListController
  let window: UppySettingsWindow

  init() {
    defaults = UserDefaults(suiteName: name)!
    let store = EndpointStore(defaults: defaults)
    store.save([
      HealthCheckEndpoint(host: "example.com"), HealthCheckEndpoint(host: "other.example"),
    ])
    monitor = EndpointMonitor(store: store, checker: { _, _ in .none })
    list = EndpointListController(monitor: monitor)
    let content = SettingsContentView(tableView: list.tableView)
    window = UppySettingsWindow(
      contentRect: NSRect(origin: .zero, size: content.preferredSize),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.contentView = content
    content.layoutSubtreeIfNeeded()
    list.tableView.reloadData()
    list.tableView.layoutSubtreeIfNeeded()
  }

  func field(_ row: Int) -> NSTextField {
    (list.tableView.view(atColumn: 1, row: row, makeIfNecessary: true) as! EndpointAddressCell)
      .address
  }
  func change(_ field: NSTextField, to address: String) {
    field.stringValue = address
    list.controlTextDidChange(
      Notification(name: NSControl.textDidChangeNotification, object: field))
  }
  func command(_ field: NSTextField, _ selector: Selector) {
    let editor = NSTextView()
    editor.string = field.stringValue
    _ = list.control(field, textView: editor, doCommandBy: selector)
  }
  func cleanUp() {
    window.close()
    defaults.removePersistentDomain(forName: name)
  }
}

@MainActor
func checkEditing() throws {
  let fixture = Fixture()
  defer { fixture.cleanUp() }
  fixture.list.beginEditing(at: 0)
  let field = fixture.field(0)
  fixture.change(field, to: " \t ")
  fixture.command(field, #selector(NSResponder.insertNewline(_:)))
  try require(fixture.monitor.endpoints[0].host == "example.com", "Blank edit restores original")
  fixture.list.beginEditing(at: 0)
  fixture.change(fixture.field(0), to: "changed.example")
  fixture.command(fixture.field(0), #selector(NSResponder.cancelOperation(_:)))
  try require(fixture.monitor.endpoints[0].host == "example.com", "Escape restores edit")
  let draft = fixture.field(fixture.monitor.endpoints.count)
  fixture.list.controlTextDidBeginEditing(
    Notification(name: NSControl.textDidBeginEditingNotification, object: draft))
  fixture.change(draft, to: "https://new.example")
  fixture.command(draft, #selector(NSResponder.insertNewline(_:)))
  try require(fixture.monitor.endpoints.count == 3, "Return adds draft")
  let next = fixture.field(3)
  fixture.change(next, to: "cancelled.example")
  fixture.command(next, #selector(NSResponder.cancelOperation(_:)))
  try require(
    fixture.monitor.endpoints.count == 3 && fixture.field(3).stringValue.isEmpty,
    "Escape discards draft")
  try require(fixture.list.tableView.rowHeight == 54, "Fixed row height")
  try require(
    fixture.window.firstResponder === fixture.list.tableView,
    "Editing returns keyboard focus to table")
}

@MainActor
func checkReordering() throws {
  let fixture = Fixture()
  defer { fixture.cleanUp() }
  let original = fixture.monitor.endpoints.map(\.id)
  fixture.list.reorderSession.begin()
  fixture.list.reorderSession.preview(source: 0, target: 1)
  fixture.list.reorderSession.end(accepted: false)
  try require(fixture.monitor.endpoints.map(\.id) == original, "Cancel restores order")
  fixture.list.reorderSession.begin()
  fixture.list.reorderSession.preview(source: 0, target: 1)
  fixture.list.reorderSession.end(accepted: true)
  let store = EndpointStore(defaults: fixture.defaults)
  try require(store.load().map(\.id) == Array(original.reversed()), "Accepted reorder persists")
}

@MainActor
func checkMenuUpdates() throws {
  let fixture = Fixture()
  defer { fixture.cleanUp() }
  var reply: (@MainActor @Sendable (HealthStatus) -> Void)?
  let store = EndpointStore(defaults: fixture.defaults)
  let monitor = EndpointMonitor(
    store: store,
    checker: { _, completion in
      reply = completion
      return .none
    })
  let controller = StatusMenuController(monitor: monitor, showStatusItem: false, openSettings: {})
  let menu = controller.statusMenu
  controller.menuNeedsUpdate(menu)
  controller.menuWillOpen(menu)
  monitor.refresh(id: monitor.endpoints[0].id)
  reply?(.offline("DNS failure"))
  try require(
    menu.item(at: 0)?.view?.toolTip == "Offline: DNS failure",
    "Open menu exposes fresh error detail")
  monitor.remove(id: monitor.endpoints[0].id)
  try require(
    menu.items.compactMap { $0.view as? EndpointMenuRow }.count == 1, "Open menu removes stale rows"
  )
  controller.menuDidClose(menu)
}

@MainActor
final class MockLoginService: LaunchAtLoginServicing {
  var status: SMAppService.Status = .notRegistered
  var fail = false
  var openedSettings = false
  func setEnabled(_ enabled: Bool) throws {
    if fail { throw UIError(message: "Denied") }
    status = enabled ? .requiresApproval : .notRegistered
  }
  func openSettings() { openedSettings = true }
}

@MainActor
func checkKeyboardAndLayout() throws {
  let fixture = Fixture()
  defer { fixture.cleanUp() }
  let editor = NSTextView(frame: .zero)
  editor.string = "endpoint"
  fixture.window.contentView?.addSubview(editor)
  fixture.window.makeFirstResponder(editor)
  let event = NSEvent.keyEvent(
    with: .keyDown, location: .zero, modifierFlags: .command,
    timestamp: 0, windowNumber: fixture.window.windowNumber, context: nil,
    characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0)!
  try require(fixture.window.performKeyEquivalent(with: event), "Command-A is routed to editor")
  try require(editor.selectedRange() == NSRange(location: 0, length: 8), "Command-A selects text")
  try require(
    abs((fixture.list.tableView.enclosingScrollView?.frame.height ?? 0) - 324) < 0.1,
    "Viewport remains six rows after adding login control")
  fixture.window.appearance = NSAppearance(named: .darkAqua)
  fixture.window.contentView?.layoutSubtreeIfNeeded()
  try require(
    fixture.window.contentView?.hasAmbiguousLayout == false, "Dark-mode layout is not ambiguous")
}

@MainActor
func checkLoginControl() throws {
  let service = MockLoginService()
  var failure: String?
  let control = LaunchAtLoginControl(service: service, presentError: { failure = $0 })
  control.button.state = .on
  control.toggle()
  try require(
    service.openedSettings && control.button.state == .on, "Login approval opens settings")
  control.button.state = .off
  control.toggle()
  try require(
    service.status == .notRegistered && control.button.state == .off, "Login can be disabled")
  service.fail = true
  control.button.state = .on
  control.toggle()
  try require(failure != nil && control.button.state == .off, "Login errors restore checkbox state")
}
