import Foundation

public struct CheckCancellation: Sendable {
  private let work: @Sendable () -> Void
  public static let none = CheckCancellation {}

  public init(_ work: @escaping @Sendable () -> Void) { self.work = work }
  public func cancel() { work() }
}

/// Serializes completion across network, cancellation, and timeout callbacks.
final class CheckCompletionGate: @unchecked Sendable {
  private let lock = NSLock()
  private var completed = false

  @discardableResult
  func complete(_ status: HealthStatus, with completion: @Sendable (HealthStatus) -> Void) -> Bool {
    lock.lock()
    guard !completed else {
      lock.unlock()
      return false
    }
    completed = true
    lock.unlock()
    completion(status)
    return true
  }
}

public final class ProbeCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false

  public init() {}
  public var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }
  public func cancel() {
    lock.lock()
    cancelled = true
    lock.unlock()
  }
}
