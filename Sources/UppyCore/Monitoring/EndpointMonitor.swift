import Foundation

/// Owns endpoint configuration and health independently of all windows.
@MainActor
public final class EndpointMonitor {
  public private(set) var endpoints: [HealthCheckEndpoint]
  public var onChange: (() -> Void)?
  public private(set) var configurationWarning: String?
  private let store: EndpointStore
  private let checker: EndpointCheck
  private let interval: Duration
  private var requests: [String: UUID] = [:]
  private var cancellations: [String: CheckCancellation] = [:]
  private var schedule: Task<Void, Never>?

  public init(
    store: EndpointStore = EndpointStore(),
    checker: @escaping EndpointCheck = EndpointChecker.check,
    interval: Duration = .seconds(60)
  ) {
    self.store = store
    self.checker = checker
    self.interval = interval
    endpoints = store.load()
    configurationWarning = store.recoveryMessage
    store.save(endpoints)
  }

  deinit {
    schedule?.cancel()
    for cancellation in cancellations.values { cancellation.cancel() }
  }

  public func start() {
    guard schedule == nil else { return }
    refresh()
    let interval = self.interval
    schedule = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: interval) } catch { return }
        self?.refresh()
      }
    }
  }

  public func add(address: String) {
    let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !address.isEmpty else { return }
    let endpoint = HealthCheckEndpoint(host: address)
    endpoints.append(endpoint)
    save()
    refresh(id: endpoint.id)
  }

  public func update(id: String, address: String) {
    let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !address.isEmpty else { return }
    guard let index = endpoints.firstIndex(where: { $0.id == id }), endpoints[index].host != address
    else { return }
    invalidate(id)
    endpoints[index].host = address
    endpoints[index].status = .unknown
    save()
  }

  public func remove(id: String) {
    invalidate(id)
    endpoints.removeAll { $0.id == id }
    save()
  }

  public func swap(_ source: Int, _ target: Int) {
    guard endpoints.indices.contains(source), endpoints.indices.contains(target) else { return }
    endpoints.swapAt(source, target)
  }

  public func restoreOrder(_ ids: [String]) {
    let byID = Dictionary(uniqueKeysWithValues: endpoints.map { ($0.id, $0) })
    let known = Set(ids)
    endpoints = ids.compactMap { byID[$0] } + endpoints.filter { !known.contains($0.id) }
  }

  public func save() {
    store.save(endpoints)
    onChange?()
  }

  public func refresh(id: String? = nil) {
    let due = endpoints.filter { id == nil || $0.id == id }
    for endpoint in due {
      invalidate(endpoint.id)
      let ticket = UUID()
      requests[endpoint.id] = ticket
      if let index = endpoints.firstIndex(where: { $0.id == endpoint.id }) {
        endpoints[index].status = .checking
      }
      let cancellation = checker(endpoint) { [weak self] status in
        self?.receive(status, for: endpoint, ticket: ticket)
      }
      if requests[endpoint.id] == ticket {
        cancellations[endpoint.id] = cancellation
      } else {
        cancellation.cancel()
      }
    }
    onChange?()
  }

  public var counts: (online: Int, offline: Int, unknown: Int) {
    let online = endpoints.filter { $0.status == .online }.count
    let offline = endpoints.filter {
      if case .offline = $0.status { return true }
      return false
    }.count
    return (online, offline, endpoints.count - online - offline)
  }

  public func acknowledgeRecovery() {
    configurationWarning = nil
    store.acknowledgeRecovery()
    onChange?()
  }

  public func suspend() {
    schedule?.cancel()
    schedule = nil
    for id in Array(requests.keys) { invalidate(id) }
  }

  public func resumeAfterWake() {
    suspend()
    start()
  }

  private func invalidate(_ id: String) {
    requests[id] = nil
    cancellations.removeValue(forKey: id)?.cancel()
  }

  private func receive(_ status: HealthStatus, for endpoint: HealthCheckEndpoint, ticket: UUID) {
    guard requests[endpoint.id] == ticket,
      let index = endpoints.firstIndex(where: { $0.id == endpoint.id }),
      endpoints[index].host == endpoint.host
    else { return }
    requests[endpoint.id] = nil
    cancellations[endpoint.id] = nil
    endpoints[index].status = status
    onChange?()
  }
}
