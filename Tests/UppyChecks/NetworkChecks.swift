import Darwin
import Foundation
import UppyCore

@MainActor
func checkNetworkAdapters() async throws {
  for code in [204, 503] {
    let port = try loopbackServer(httpStatus: code)
    let status = await withCheckedContinuation { continuation in
      HTTPChecker.check(url: URL(string: "http://127.0.0.1:\(port)/health")!) {
        continuation.resume(returning: $0)
      }
    }
    try expect(
      status == HTTPChecker.status(for: code), "HTTP HEAD request and response classification")
  }
  let redirectPort = try loopbackServer(httpStatus: 303)
  let redirected = await withCheckedContinuation { continuation in
    HTTPChecker.check(url: URL(string: "http://127.0.0.1:\(redirectPort)/health")!) {
      continuation.resume(returning: $0)
    }
  }
  try expect(redirected == .online, "Redirects preserve HEAD instead of downloading a body")
  let delayedPort = try loopbackServer(httpStatus: -1)
  let timedOut = await withCheckedContinuation { continuation in
    HTTPChecker.check(url: URL(string: "http://127.0.0.1:\(delayedPort)/health")!, timeout: 0.1) {
      continuation.resume(returning: $0)
    }
  }
  if case .offline = timedOut {
  } else {
    throw CheckFailure(description: "Slow HTTP request must time out")
  }
  let cancelPort = try loopbackServer(httpStatus: -1)
  let cancelled = await withCheckedContinuation { continuation in
    let cancellation = HTTPChecker.check(url: URL(string: "http://127.0.0.1:\(cancelPort)/health")!)
    {
      continuation.resume(returning: $0)
    }
    cancellation.cancel()
  }
  try expect(cancelled == .offline("Check cancelled"), "HTTP cancellation completes exactly once")
  let port = try loopbackServer(httpStatus: nil)
  let status = await withCheckedContinuation { continuation in
    TCPChecker.check(host: "127.0.0.1", port: port) { continuation.resume(returning: $0) }
  }
  try expect(status == .online, "TCP connection to local listener")
  let invalidPort = await withCheckedContinuation { continuation in
    TCPChecker.check(host: "127.0.0.1", port: 0) { continuation.resume(returning: $0) }
  }
  try expect(invalidPort == .offline("Invalid port"), "Reject invalid TCP port")
}

/// A bounded local fixture; redirects accept a second HEAD request.
private func loopbackServer(httpStatus: Int?) throws -> UInt16 {
  let descriptor = socket(AF_INET, SOCK_STREAM, 0)
  guard descriptor >= 0 else { throw CheckFailure(description: "Create test listener") }
  var transferred = false
  defer { if !transferred { close(descriptor) } }
  var address = sockaddr_in()
  address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  address.sin_family = sa_family_t(AF_INET)
  address.sin_addr.s_addr = inet_addr("127.0.0.1")
  let bound = withUnsafePointer(to: &address) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  guard bound == 0, listen(descriptor, 1) == 0 else {
    throw CheckFailure(description: "Bind test listener")
  }
  var length = socklen_t(MemoryLayout<sockaddr_in>.size)
  let named = withUnsafeMutablePointer(to: &address) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
  }
  guard named == 0 else { throw CheckFailure(description: "Read test port") }
  let port = UInt16(bigEndian: address.sin_port)
  transferred = true
  DispatchQueue.global(qos: .utility).async {
    defer { close(descriptor) }
    for attempt in 0..<(httpStatus == 303 ? 2 : 1) {
      var event = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
      guard poll(&event, 1, 10_000) > 0 else { return }
      let client = accept(descriptor, nil, nil)
      guard client >= 0 else { return }
      defer { close(client) }
      guard let httpStatus else { return }
      serveHTTP(client, status: attempt == 1 ? 204 : httpStatus)
    }
  }
  return port
}

private func serveHTTP(_ client: Int32, status: Int) {
  if status == -1 {
    Thread.sleep(forTimeInterval: 0.4)
    return
  }
  var timeout = timeval(tv_sec: 3, tv_usec: 0)
  _ = setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
  var noSignal: Int32 = 1
  _ = setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
  var bytes = [UInt8](repeating: 0, count: 4096)
  let count = bytes.withUnsafeMutableBytes { recv(client, $0.baseAddress, $0.count, 0) }
  guard count > 0 else { return }
  let request = String(decoding: bytes.prefix(count), as: UTF8.self)
  let isHead = request.hasPrefix("HEAD /health ") || request.hasPrefix("HEAD /final ")
  let code = isHead ? status : 500
  let location = code == 303 ? "Location: /final\r\n" : ""
  let response = Array(
    "HTTP/1.1 \(code) Test\r\n\(location)Content-Length: 0\r\nConnection: close\r\n\r\n".utf8)
  _ = response.withUnsafeBytes { send(client, $0.baseAddress, $0.count, 0) }
}
