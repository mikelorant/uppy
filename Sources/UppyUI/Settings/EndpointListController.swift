import AppKit
import UppyCore

@MainActor
final class EndpointListController: NSObject, NSTableViewDataSource, NSTableViewDelegate,
  NSTextFieldDelegate
{
  let tableView = NSTableView()
  private let monitor: EndpointMonitor
  private var session: EndpointEditSession = .idle
  let reorderSession: EndpointReorderSession
  private let pasteboardType = NSPasteboard.PasteboardType("com.uppy.endpoint-id")
  private var endpoints: [HealthCheckEndpoint] { monitor.endpoints }
  private var window: NSWindow? { tableView.window }

  init(monitor: EndpointMonitor) {
    self.monitor = monitor
    reorderSession = EndpointReorderSession(monitor: monitor)
    super.init()
    configureTable()
  }

  func endEditing() { finishEditing(cancel: false) }

  private func configureTable() {
    addColumn("handle", width: 46.8)
    addColumn("host", width: 432)
    addColumn("delete", width: 50.4)
    addColumn("scrollbar-gutter", width: 18)
    tableView.headerView = nil
    tableView.style = .plain
    tableView.rowHeight = 54
    tableView.intercellSpacing = .zero
    tableView.columnAutoresizingStyle = .noColumnAutoresizing
    tableView.autoresizingMask = []
    tableView.backgroundColor = .clear
    tableView.allowsMultipleSelection = false
    tableView.dataSource = self
    tableView.delegate = self
    tableView.target = self
    tableView.action = #selector(clickedAddress)
    tableView.setDraggingSourceOperationMask(.move, forLocal: true)
    tableView.setDraggingSourceOperationMask([], forLocal: false)
    tableView.registerForDraggedTypes([pasteboardType])
  }

  private func addColumn(_ name: String, width: CGFloat) {
    let column = NSTableColumn(identifier: .init(name))
    column.width = width
    column.resizingMask = []
    if name != "host" {
      column.minWidth = width
      column.maxWidth = width
    }
    tableView.addTableColumn(column)
  }

  @objc private func clickedAddress() {
    let row = tableView.clickedRow
    guard row >= 0, tableView.clickedColumn == 1 else { return }
    if endpoints.indices.contains(row) {
      beginEditing(at: row)
    } else if row == endpoints.count {
      tableView.scrollRowToVisible(row)
      if let cell = addressCell(at: row) { window?.makeFirstResponder(cell.address) }
    }
  }

  func beginEditing(at row: Int) {
    let endpoint = endpoints[row]
    guard session.endpointID != endpoint.id else { return }
    finishEditing(cancel: false)
    tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    tableView.scrollRowToVisible(row)
    guard let cell = addressCell(at: row) else { return }
    session = .editing(id: endpoint.id, originalAddress: endpoint.host)
    cell.address.isEditable = true
    cell.address.isSelectable = true
    window?.makeFirstResponder(cell.address)
    if let editor = cell.address.currentEditor() as? NSTextView {
      editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
    }
  }

  @objc private func removeEndpoint(_ sender: NSButton) {
    guard let id = sender.identifier?.rawValue else { return }
    finishEditing(cancel: false)
    monitor.remove(id: id)
    tableView.reloadData()
  }

  func controlTextDidBeginEditing(_ notification: Notification) {
    guard let field = notification.object as? NSTextField,
      field.identifier?.rawValue == "new-endpoint"
    else { return }
    session = .adding(field.stringValue)
    field.textColor = .labelColor
    tableView.selectRowIndexes(IndexSet(integer: endpoints.count), byExtendingSelection: false)
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let field = notification.object as? NSTextField else { return }
    addressCell(containing: field)?.updateIcon()
    if field.identifier?.rawValue == "new-endpoint" {
      session = .adding(field.stringValue)
    } else if let id = session.endpointID, field.identifier?.rawValue == id {
      monitor.update(id: id, address: field.stringValue)
    }
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    guard case .editing(let id, let original) = session,
      let field = notification.object as? NSTextField,
      field.identifier?.rawValue == id
    else { return }
    session = .idle
    commit(field.stringValue, id: id, original: original)
    field.stringValue = monitor.endpoints.first(where: { $0.id == id })?.host ?? original
    field.isEditable = false
    field.isSelectable = false
    addressCell(containing: field)?.updateIcon()
    monitor.refresh(id: id)
    // Do not reload or change the responder while AppKit is focusing another field.
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
    -> Bool
  {
    if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      finishEditing(cancel: true)
      return true
    }
    guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
    if control.identifier?.rawValue == "new-endpoint" {
      let address = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !address.isEmpty else { return true }
      session = .idle
      monitor.add(address: address)
      window?.makeFirstResponder(tableView)
      tableView.deselectAll(nil)
      tableView.reloadData()
    } else {
      finishEditing(cancel: false)
    }
    return true
  }

  private func finishEditing(cancel: Bool) {
    let previous = session
    session = .idle  // Avoid responder callbacks finishing the same edit twice.
    if case .editing(let id, let original) = previous {
      let row = endpoints.firstIndex { $0.id == id }
      let address = row.flatMap { addressCell(at: $0)?.address.stringValue } ?? original
      commit(cancel ? original : address, id: id, original: original)
      monitor.refresh(id: id)
    }
    window?.makeFirstResponder(tableView)
    tableView.deselectAll(nil)
    tableView.reloadData()
  }

  private func commit(_ draft: String, id: String, original: String) {
    let address = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    monitor.update(id: id, address: address.isEmpty ? original : address)
  }

  private func addressCell(at row: Int) -> EndpointAddressCell? {
    tableView.view(atColumn: 1, row: row, makeIfNecessary: true) as? EndpointAddressCell
  }

  private func addressCell(containing field: NSTextField) -> EndpointAddressCell? {
    var view: NSView? = field.superview
    while let current = view {
      if let cell = current as? EndpointAddressCell { return cell }
      view = current.superview
    }
    return nil
  }

  func numberOfRows(in tableView: NSTableView) -> Int { endpoints.count + 1 }

  func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
    let view = UppyEndpointRowView()
    view.showsTopDivider = row > 0
    return view
  }

  func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
    let endpoint = endpoints.indices.contains(row) ? endpoints[row] : nil
    switch column?.identifier.rawValue {
    case "handle": return endpoint == nil ? NSTableCellView() : EndpointCells.handle()
    case "delete":
      guard let endpoint else { return NSTableCellView() }
      return EndpointCells.delete(
        endpoint: endpoint, target: self, action: #selector(removeEndpoint(_:)))
    case "host":
      return EndpointAddressCell(
        endpoint: endpoint, draft: session.draft,
        editing: endpoint?.id == session.endpointID && endpoint != nil, delegate: self)
    default: return NSTableCellView()
    }
  }

  func tableView(_ tableView: NSTableView, canDragRowsWith rows: IndexSet, at point: NSPoint)
    -> Bool
  {
    tableView.column(at: point) == 0 && rows.allSatisfy { endpoints.indices.contains($0) }
  }

  func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
  {
    guard endpoints.indices.contains(row) else { return nil }
    let item = NSPasteboardItem()
    item.setString(endpoints[row].id, forType: pasteboardType)
    return item
  }

  func tableView(
    _ tableView: NSTableView, draggingSession drag: NSDraggingSession, willBeginAt point: NSPoint,
    forRowIndexes rows: IndexSet
  ) {
    guard let row = rows.first else { return }
    reorderSession.begin()
    let rect = tableView.rect(ofRow: row)
    guard let bitmap = tableView.bitmapImageRepForCachingDisplay(in: rect) else { return }
    tableView.cacheDisplay(in: rect, to: bitmap)
    let image = NSImage(size: rect.size)
    image.addRepresentation(bitmap)
    drag.draggingFormation = .none
    drag.animatesToStartingPositionsOnCancelOrFail = true
    drag.enumerateDraggingItems(
      options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]
    ) { item, _, _ in
      item.setDraggingFrame(rect, contents: image)
    }
  }

  func tableView(
    _ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
    proposedDropOperation operation: NSTableView.DropOperation
  ) -> NSDragOperation {
    guard let target = validDropRow(info), let source = sourceRow(info) else { return [] }
    if source != target {
      reorderSession.preview(source: source, target: target)
      tableView.reloadData()
      tableView.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
    }
    tableView.setDropRow(target, dropOperation: .on)
    return .move
  }

  func tableView(
    _ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int,
    dropOperation operation: NSTableView.DropOperation
  ) -> Bool {
    guard validDropRow(info) != nil, sourceRow(info) != nil else { return false }
    return true
  }

  func tableView(
    _ tableView: NSTableView, draggingSession drag: NSDraggingSession, endedAt point: NSPoint,
    operation: NSDragOperation
  ) {
    reorderSession.end(accepted: operation == .move)
    tableView.reloadData()
  }

  private func sourceRow(_ info: NSDraggingInfo) -> Int? {
    guard let id = info.draggingPasteboard.string(forType: pasteboardType) else { return nil }
    return endpoints.firstIndex { $0.id == id }
  }

  private func validDropRow(_ info: NSDraggingInfo) -> Int? {
    guard let source = info.draggingSource as? NSTableView, source === tableView else { return nil }
    let point = tableView.convert(info.draggingLocation, from: nil)
    let row = tableView.row(at: point)
    return tableView.visibleRect.contains(point) && endpoints.indices.contains(row) ? row : nil
  }
}
