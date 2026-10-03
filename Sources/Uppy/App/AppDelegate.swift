import AppKit
import UppyCore
import UppyUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let monitor = EndpointMonitor()
  private var statusMenu: StatusMenuController?
  private var settings: SettingsWindowController?
  private var workspaceObservers: [any NSObjectProtocol] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    installApplicationMenu()
    statusMenu = StatusMenuController(monitor: monitor) { [weak self] in self?.openSettings() }
    monitor.start()
    observeSleepAndWake()
  }

  func applicationWillTerminate(_ notification: Notification) {
    monitor.suspend()
    for observer in workspaceObservers {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
  }

  private func observeSleepAndWake() {
    let center = NSWorkspace.shared.notificationCenter
    workspaceObservers.append(
      center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.monitor.suspend() }
      })
    workspaceObservers.append(
      center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.monitor.resumeAfterWake() }
      })
  }

  private func openSettings() {
    NSApp.setActivationPolicy(.regular)
    if settings == nil { settings = SettingsWindowController(monitor: monitor) }
    settings?.showWindow(nil)
    settings?.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func quit() { NSApp.terminate(nil) }
  @objc private func about() { NSApp.orderFrontStandardAboutPanel(nil) }

  private func installApplicationMenu() {
    let main = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu(title: "Uppy")
    let about = NSMenuItem(title: "About Uppy", action: #selector(about), keyEquivalent: "")
    about.target = self
    let quit = NSMenuItem(title: "Quit Uppy", action: #selector(quit), keyEquivalent: "q")
    quit.target = self
    appMenu.addItem(about)
    appMenu.addItem(.separator())
    appMenu.addItem(quit)
    appItem.title = "Uppy"
    appItem.submenu = appMenu
    main.addItem(appItem)
    NSApp.mainMenu = main
  }
}
