import Foundation
import Network

public enum HTTPChecker {
  public static let timeout: TimeInterval = 8

  public static func configuration(timeout: TimeInterval = HTTPChecker.timeout)
    -> URLSessionConfiguration
  {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    return configuration
  }

  @discardableResult
  public static func check(
    url: URL, timeout: TimeInterval = HTTPChecker.timeout,
    completion: @escaping @Sendable (HealthStatus) -> Void
  ) -> CheckCancellation {
    let gate = CheckCompletionGate()
    let finish: @Sendable (HealthStatus) -> Void = { gate.complete($0, with: completion) }
    let delegate = RedirectPolicy(finish: finish)
    let session = URLSession(
      configuration: configuration(timeout: timeout), delegate: delegate, delegateQueue: nil)
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    request.timeoutInterval = timeout
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    let task = session.dataTask(with: request) { _, response, error in
      defer { session.finishTasksAndInvalidate() }
      if let error {
        finish(.offline(error.localizedDescription))
        return
      }
      guard let response = response as? HTTPURLResponse else {
        finish(.offline("No HTTP response"))
        return
      }
      finish(status(for: response.statusCode))
    }
    task.resume()
    return CheckCancellation {
      finish(.offline("Check cancelled"))
      session.invalidateAndCancel()
    }
  }

  public static func allowsRedirect(from source: URL, to destination: URL) -> Bool {
    let scheme = destination.scheme?.lowercased()
    guard scheme == "http" || scheme == "https" else { return false }
    return source.scheme?.lowercased() != "https" || scheme == "https"
  }

  public static func status(for code: Int) -> HealthStatus {
    (200..<400).contains(code) ? .online : .offline("HTTP \(code)")
  }
}

private final class RedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let finish: @Sendable (HealthStatus) -> Void
  init(finish: @escaping @Sendable (HealthStatus) -> Void) { self.finish = finish }

  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    guard let source = response.url, let destination = request.url,
      HTTPChecker.allowsRedirect(from: source, to: destination)
    else {
      finish(.offline("Unsafe redirect blocked"))
      completionHandler(nil)
      task.cancel()
      return
    }
    var redirect = request
    redirect.httpMethod = "HEAD"
    redirect.httpBody = nil
    redirect.httpBodyStream = nil
    completionHandler(redirect)
  }
}
