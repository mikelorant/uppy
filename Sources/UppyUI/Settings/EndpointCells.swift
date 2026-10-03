import AppKit
import UppyCore

@MainActor
enum EndpointCells {
  static func handle() -> NSView {
    let cell = NSTableCellView()
    let grip = UppyDragGripView()
    grip.setAccessibilityLabel("Drag to reorder")
    center(grip, in: cell, size: 18)
    return cell
  }

  static func delete(endpoint: HealthCheckEndpoint, target: AnyObject, action: Selector) -> NSView {
    let cell = NSTableCellView()
    let image =
      NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete endpoint")?
      .withSymbolConfiguration(.init(pointSize: 16.2, weight: .regular)) ?? NSImage()
    let button = UppyRowActionButton(image: image, target: target, action: action)
    button.showsSurface = false
    button.isBordered = false
    button.contentTintColor = .labelColor
    button.identifier = .init(endpoint.id)
    button.toolTip = "Delete endpoint"
    button.setAccessibilityLabel("Delete endpoint: \(endpoint.host)")
    center(button, in: cell, size: 37.8)
    return cell
  }

  private static func center(_ view: NSView, in cell: NSView, size: CGFloat) {
    view.translatesAutoresizingMaskIntoConstraints = false
    cell.addSubview(view)
    NSLayoutConstraint.activate([
      view.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
      view.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
      view.widthAnchor.constraint(equalToConstant: size),
      view.heightAnchor.constraint(equalTo: view.widthAnchor),
    ])
  }
}

final class EndpointAddressCell: NSTableCellView {
  let address = NSTextField()
  private let typeIcon = NSImageView()
  private let isDraft: Bool

  init(endpoint: HealthCheckEndpoint?, draft: String, editing: Bool, delegate: NSTextFieldDelegate)
  {
    isDraft = endpoint == nil
    super.init(frame: .zero)
    configureAddress(endpoint: endpoint, draft: draft, editing: editing, delegate: delegate)
    buildLayout()
    updateIcon()
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func updateIcon() {
    if isDraft && address.stringValue.isEmpty {
      typeIcon.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add endpoint")
      typeIcon.contentTintColor = .secondaryLabelColor
    } else {
      let type = HealthCheckType.inferred(from: address.stringValue)
      typeIcon.image = UppyCheckIcons.image(for: type)
      typeIcon.contentTintColor = .labelColor
      typeIcon.setAccessibilityLabel("\(type.rawValue) check")
    }
  }

  private func configureAddress(
    endpoint: HealthCheckEndpoint?, draft: String, editing: Bool, delegate: NSTextFieldDelegate
  ) {
    address.stringValue = endpoint?.host ?? draft
    address.identifier = .init(endpoint?.id ?? "new-endpoint")
    address.isBezeled = false
    address.isBordered = false
    address.drawsBackground = false
    address.focusRingType = .none
    address.font = .systemFont(ofSize: 16.2)
    address.textColor = isDraft ? .secondaryLabelColor : .labelColor
    address.isEditable = isDraft || editing
    address.isSelectable = address.isEditable
    address.delegate = delegate
    address.lineBreakMode = .byTruncatingTail
    address.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    address.setContentHuggingPriority(.defaultLow, for: .horizontal)
    address.setAccessibilityLabel(isDraft ? "Add endpoint address" : "Endpoint address")
    if isDraft {
      address.placeholderAttributedString = NSAttributedString(
        string: "Add a new endpoint...",
        attributes: [
          .foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 16.2),
        ]
      )
    }
  }

  private func buildLayout() {
    typeIcon.imageScaling = .scaleProportionallyUpOrDown
    typeIcon.translatesAutoresizingMaskIntoConstraints = false
    address.translatesAutoresizingMaskIntoConstraints = false
    let content = NSStackView(views: [typeIcon, address])
    content.orientation = .horizontal
    content.alignment = .centerY
    content.spacing = 19.8
    content.translatesAutoresizingMaskIntoConstraints = false
    addSubview(content)
    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
      content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7.2),
      content.centerYAnchor.constraint(equalTo: centerYAnchor),
      typeIcon.widthAnchor.constraint(equalToConstant: isDraft ? 21.6 : 22.5),
      typeIcon.heightAnchor.constraint(equalTo: typeIcon.widthAnchor),
      address.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
    ])
  }
}

final class UppyEndpointRowView: NSTableRowView {
  var showsTopDivider = false
  override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
  override func drawSelection(in dirtyRect: NSRect) {}

  override func drawBackground(in dirtyRect: NSRect) {
    NSColor.textBackgroundColor.setFill()
    dirtyRect.fill()
    drawSeparator(in: dirtyRect)
  }

  override func drawSeparator(in dirtyRect: NSRect) {
    guard showsTopDivider else { return }
    NSColor.separatorColor.setFill()
    let y = isFlipped ? bounds.minY : bounds.maxY - 1
    NSRect(x: bounds.minX, y: y, width: bounds.width, height: 1).fill()
  }
}
