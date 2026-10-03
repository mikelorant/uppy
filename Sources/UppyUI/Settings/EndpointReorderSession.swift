import Foundation
import UppyCore

@MainActor
final class EndpointReorderSession {
  private let monitor: EndpointMonitor
  private var originalOrder: [String]?

  init(monitor: EndpointMonitor) { self.monitor = monitor }
  func begin() { originalOrder = monitor.endpoints.map(\.id) }
  func preview(source: Int, target: Int) { monitor.swap(source, target) }
  func end(accepted: Bool) {
    guard let originalOrder else { return }
    if !accepted { monitor.restoreOrder(originalOrder) }
    self.originalOrder = nil
    monitor.save()
  }
}
