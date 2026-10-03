import AppKit
import UppyCore

@MainActor
public final class StatusMenuController: NSObject, NSMenuDelegate {
  private let monitor: EndpointMonitor
  private let openSettings: () -> Void
  private let item: NSStatusItem?
  var statusMenu: NSMenu { menu }
  private let menu = NSMenu()

  public init(
    monitor: EndpointMonitor, showStatusItem: Bool = true, openSettings: @escaping () -> Void
  ) {
    item = showStatusItem ? NSStatusBar.system.statusItem(withLength: 28) : nil
    self.monitor = monitor
    self.openSettings = openSettings
    super.init()
    menu.delegate = self
    item?.menu = menu
    item?.button?.imagePosition = .imageOnly
    item?.button?.imageScaling = .scaleProportionallyDown
    item?.button?.toolTip = "Uppy"
    monitor.onChange = { [weak self] in self?.updatePresentation() }
    updateIcon()
  }

  private var isTracking = false
  public func menuWillOpen(_ menu: NSMenu) { isTracking = true }
  public func menuDidClose(_ menu: NSMenu) { isTracking = false }

  public func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu() }

  private func rebuildMenu() {
    menu.removeAllItems()
    if monitor.configurationWarning != nil {
      addAction(
        "Settings recovered…", symbol: "exclamationmark.triangle", key: "",
        selector: #selector(showRecovery))
      menu.addItem(.separator())
    }
    if monitor.endpoints.isEmpty {
      let empty = NSMenuItem(title: "No endpoints configured", action: nil, keyEquivalent: "")
      empty.isEnabled = false
      menu.addItem(empty)
    }
    for endpoint in monitor.endpoints {
      let row = NSMenuItem(title: "", action: nil, keyEquivalent: "")
      row.view = EndpointMenuRow(endpoint)
      menu.addItem(row)
    }
    menu.addItem(.separator())
    addAction("Settings…", symbol: "gear", key: ",", selector: #selector(settings))
    addAction("Quit", symbol: "power", key: "q", selector: #selector(quit))
  }

  private func addAction(_ title: String, symbol: String, key: String, selector: Selector) {
    let action = NSMenuItem(title: title, action: selector, keyEquivalent: key)
    action.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
    action.target = self
    menu.addItem(action)
  }

  private func updatePresentation() {
    updateIcon()
    guard isTracking else { return }
    guard menu.items.compactMap({ $0.view as? EndpointMenuRow }).count == monitor.endpoints.count
    else {
      rebuildMenu()
      return
    }
    for (index, endpoint) in monitor.endpoints.enumerated() {
      let offset = monitor.configurationWarning == nil ? 0 : 2
      guard let row = menu.item(at: index + offset)?.view as? EndpointMenuRow else {
        rebuildMenu()
        return
      }
      row.update(endpoint)
    }
  }

  @objc private func showRecovery() {
    let alert = NSAlert()
    alert.messageText = "Endpoint settings recovered"
    alert.informativeText = monitor.configurationWarning ?? "No recovery notice."
    alert.addButton(withTitle: "OK")
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
    monitor.acknowledgeRecovery()
  }

  private func updateIcon() {
    let counts = monitor.counts
    item?.button?.image = HealthPieIcon.image(online: counts.online, offline: counts.offline)
  }

  @objc private func settings() { openSettings() }
  @objc private func quit() { NSApp.terminate(nil) }
}

@MainActor
final class EndpointMenuRow: NSStackView {
  private let dot: NSImageView
  private let type: NSImageView
  private let label: NSTextField

  init(_ endpoint: HealthCheckEndpoint) {
    dot = Self.icon(
      NSImage(
        systemSymbolName: "circle.fill", accessibilityDescription: endpoint.status.shortMenuLabel)
        ?? NSImage(), size: 13)
    type = Self.icon(UppyCheckIcons.image(for: endpoint.type), size: 16)
    label = NSTextField(labelWithString: endpoint.host)
    super.init(frame: .zero)
    label.font = .menuFont(ofSize: 13)
    label.lineBreakMode = .byTruncatingTail
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    for view in [dot, type, label] { addArrangedSubview(view) }
    orientation = .horizontal
    alignment = .centerY
    spacing = 8
    edgeInsets = NSEdgeInsets(top: 3, left: 12, bottom: 3, right: 12)
    frame = NSRect(x: 0, y: 0, width: 280, height: 24)
    update(endpoint)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func update(_ endpoint: HealthCheckEndpoint) {
    switch endpoint.status {
    case .online: dot.contentTintColor = .systemGreen
    case .offline: dot.contentTintColor = .systemRed
    default: dot.contentTintColor = .systemGray
    }
    label.stringValue = endpoint.host
    type.image = UppyCheckIcons.image(for: endpoint.type)
    type.toolTip = "\(endpoint.type.rawValue) check"
    let detail: String
    if case .offline(let reason) = endpoint.status {
      detail = "Offline: \(reason)"
    } else {
      detail = endpoint.status.shortMenuLabel
    }
    toolTip = detail
    label.toolTip = detail
    dot.toolTip = detail
    dot.setAccessibilityLabel(detail)
    setAccessibilityLabel("\(endpoint.host): \(detail)")
  }

  private static func icon(_ image: NSImage, size: CGFloat) -> NSImageView {
    let view = NSImageView(image: image)
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.widthAnchor.constraint(equalToConstant: size),
      view.heightAnchor.constraint(equalToConstant: size),
    ])
    return view
  }
}
