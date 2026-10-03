import Foundation
import Network

public enum TCPChecker {
  @discardableResult
  public static func check(
    host: String, port: UInt16,
    completion: @escaping @Sendable (HealthStatus) -> Void
  ) -> CheckCancellation {
    guard port > 0, let port = NWEndpoint.Port(rawValue: port) else {
      completion(.offline("Invalid port"))
      return .none
    }
    let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
    let queue = DispatchQueue(label: "Uppy.tcp-check")
    let gate = CheckCompletionGate()
    let timeout = Task.detached {
      do { try await Task.sleep(for: .seconds(5)) } catch { return }
      if gate.complete(.offline("Connection timed out"), with: completion) {
        connection.stateUpdateHandler = nil
        connection.cancel()
      }
    }
    let finish: @Sendable (HealthStatus) -> Void = { status in
      if gate.complete(status, with: completion) {
        timeout.cancel()
        connection.stateUpdateHandler = nil
        connection.cancel()
      }
    }
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready: finish(.online)
      case .failed(let error): finish(.offline(error.localizedDescription))
      case .cancelled: finish(.offline("Check cancelled"))
      default: break
      }
    }
    connection.start(queue: queue)
    return CheckCancellation { finish(.offline("Check cancelled")) }
  }
}
