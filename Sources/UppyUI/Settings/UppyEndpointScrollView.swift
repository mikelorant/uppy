import AppKit

/// Sizes endpoint columns from the outer viewport, never the scroller's clip width.
final class UppyEndpointScrollView: NSScrollView {
  override func tile() {
    super.tile()
    updateEndpointWidth()
  }

  override func layout() {
    super.layout()
    updateEndpointWidth()
  }

  private func updateEndpointWidth() {
    guard let table = documentView as? NSTableView,
      let addressColumn = table.tableColumns.first(where: { $0.identifier.rawValue == "host" })
    else { return }
    let fixedWidth = table.tableColumns
      .filter { !$0.isHidden && $0 !== addressColumn }
      .reduce(CGFloat.zero) { $0 + $1.width }
    let availableWidth = bounds.width
    let addressWidth = max(80, availableWidth - fixedWidth)
    if abs(addressColumn.width - addressWidth) > 0.1 {
      addressColumn.width = addressWidth
    }
    if abs(table.frame.width - availableWidth) > 0.1 {
      table.setFrameSize(NSSize(width: availableWidth, height: table.frame.height))
    }
  }
}
