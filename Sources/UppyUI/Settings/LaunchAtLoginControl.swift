import AppKit
import ServiceManagement

@MainActor
protocol LaunchAtLoginServicing {
  var status: SMAppService.Status { get }
  func setEnabled(_ enabled: Bool) throws
  func openSettings()
}

@MainActor
private struct SystemLoginService: LaunchAtLoginServicing {
  var status: SMAppService.Status { SMAppService.mainApp.status }
  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }
  func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
final class LaunchAtLoginControl: NSObject {
  let button = NSButton(checkboxWithTitle: "Launch Uppy at login", target: nil, action: nil)
  private let service: any LaunchAtLoginServicing
  private let presentError: ((String) -> Void)?

  init(
    service: any LaunchAtLoginServicing = SystemLoginService(),
    presentError: ((String) -> Void)? = nil
  ) {
    self.service = service
    self.presentError = presentError
    super.init()
    button.target = self
    button.action = #selector(toggle)
    button.font = .systemFont(ofSize: 13)
    button.translatesAutoresizingMaskIntoConstraints = false
    refresh()
  }

  func refresh() {
    switch service.status {
    case .enabled:
      button.state = .on
      button.toolTip = "Uppy starts when you log in."
    case .requiresApproval:
      button.state = .on
      button.toolTip = "Approve Uppy in System Settings → General → Login Items."
    default:
      button.state = .off
      button.toolTip = "Keep an installed copy of Uppy in Applications."
    }
    button.isEnabled = service.status != .notFound
  }

  @objc func toggle() {
    do {
      try service.setEnabled(button.state == .on)
      refresh()
      if service.status == .requiresApproval { service.openSettings() }
    } catch {
      refresh()
      let message =
        "Could not update launch at login. Install Uppy in Applications and try again. \(error.localizedDescription)"
      if let presentError {
        presentError(message)
        return
      }
      guard let window = button.window else { return }
      let alert = NSAlert()
      alert.messageText = "Launch at login could not be changed"
      alert.informativeText = message
      alert.beginSheetModal(for: window)
    }
  }
}
