import Foundation
import UppyCore

struct CheckFailure: Error, CustomStringConvertible {
  let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  if !condition() { throw CheckFailure(description: message) }
}

/// Records requests for deterministic, manually ordered main-actor completions.
@MainActor
final class CheckRecorder {
  struct Request {
    let endpoint: HealthCheckEndpoint
    let complete: @MainActor @Sendable (HealthStatus) -> Void
  }
  private var pending: [Request] = []
  var requestCount: Int { pending.count }
  let cancellations = CancellationCounter()

  func check(
    _ endpoint: HealthCheckEndpoint,
    completion: @escaping @MainActor @Sendable (HealthStatus) -> Void
  ) -> CheckCancellation {
    pending.append(Request(endpoint: endpoint, complete: completion))
    return CheckCancellation { [cancellations] in cancellations.increment() }
  }

  func take() -> Request { pending.removeFirst() }
}

final class CancellationCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
  func increment() {
    lock.lock()
    count += 1
    lock.unlock()
  }
}

func isolatedStore() -> (EndpointStore, UserDefaults, String) {
  let name = "UppyChecks.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: name)!
  return (EndpointStore(defaults: defaults), defaults, name)
}
