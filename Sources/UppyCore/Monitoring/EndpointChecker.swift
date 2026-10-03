import Foundation

public typealias EndpointCheck =
  @MainActor @Sendable (
    HealthCheckEndpoint, @escaping @MainActor @Sendable (HealthStatus) -> Void
  ) -> CheckCancellation

@MainActor
public enum EndpointChecker {
  @discardableResult
  public static func check(
    _ endpoint: HealthCheckEndpoint,
    completion: @escaping @MainActor @Sendable (HealthStatus) -> Void
  ) -> CheckCancellation {
    let deliver: @Sendable (HealthStatus) -> Void = { status in
      Task { @MainActor in completion(status) }
    }
    switch endpoint.type {
    case .http:
      guard let url = endpoint.httpURL else {
        completion(.offline("Invalid URL"))
        return .none
      }
      return HTTPChecker.check(url: url, completion: deliver)
    case .tcp:
      guard let address = endpoint.tcpAddress else {
        completion(.offline("Invalid port"))
        return .none
      }
      return TCPChecker.check(host: address.host, port: address.port, completion: deliver)
    case .ping:
      guard let host = endpoint.pingHost else {
        completion(.offline("Invalid host"))
        return .none
      }
      return checkPing(host, completion: deliver)
    }
  }

  private static func checkPing(
    _ host: String, completion: @escaping @Sendable (HealthStatus) -> Void
  ) -> CheckCancellation {
    let token = ProbeCancellation()
    let gate = CheckCompletionGate()
    let queue = DispatchQueue.global(qos: .utility)
    let timeout = Task.detached {
      do { try await Task.sleep(for: .seconds(8)) } catch { return }
      token.cancel()
      gate.complete(.offline("ICMP check timed out"), with: completion)
    }
    queue.async {
      let status = ICMPChecker.check(host: host, cancellation: token)
      if gate.complete(status, with: completion) { timeout.cancel() }
    }
    return CheckCancellation {
      token.cancel()
      timeout.cancel()
      gate.complete(.offline("Check cancelled"), with: completion)
    }
  }
}
