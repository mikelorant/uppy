import Darwin
import Foundation

/// Uses macOS's unprivileged ICMP datagram sockets, not raw sockets or a subprocess.
public enum ICMPChecker {
  public static func check(
    host: String, cancellation: ProbeCancellation = ProbeCancellation(),
    timeout: TimeInterval = 8
  ) -> HealthStatus {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    guard !cancellation.isCancelled else { return .offline("Check cancelled") }
    guard timeout > 0 else { return .offline("ICMP check timed out") }
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC
    hints.ai_socktype = SOCK_DGRAM
    var addresses: UnsafeMutablePointer<addrinfo>?
    let result = getaddrinfo(host, nil, &hints, &addresses)
    guard result == 0 else {
      return .offline("DNS: \(String(cString: gai_strerror(result)))")
    }
    defer { if let addresses { freeaddrinfo(addresses) } }

    var current = addresses
    var lastFailure: HealthStatus = .offline("No usable IP address")
    while let address = current {
      if address.pointee.ai_family == AF_INET || address.pointee.ai_family == AF_INET6 {
        guard !cancellation.isCancelled else { return .offline("Check cancelled") }
        guard ProcessInfo.processInfo.systemUptime < deadline else {
          return .offline("ICMP check timed out")
        }
        let status = probe(address.pointee, cancellation: cancellation, deadline: deadline)
        if status == .online { return status }
        lastFailure = status
      }
      current = address.pointee.ai_next
    }
    return lastFailure
  }

  private static func probe(
    _ address: addrinfo, cancellation: ProbeCancellation, deadline: TimeInterval
  ) -> HealthStatus {
    let ipv6 = address.ai_family == AF_INET6
    let descriptor = socket(address.ai_family, SOCK_DGRAM, ipv6 ? IPPROTO_ICMPV6 : IPPROTO_ICMP)
    guard descriptor >= 0 else { return systemError("ICMP socket") }
    defer { close(descriptor) }
    guard connect(descriptor, address.ai_addr, address.ai_addrlen) == 0 else {
      return systemError("ICMP connection")
    }
    let flags = fcntl(descriptor, F_GETFL, 0)
    guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
      return systemError("ICMP socket configuration")
    }

    // The kernel may replace the echo identifier; correlate with sequence and nonce instead.
    let nonce = Array(UUID().uuidString.utf8)
    for attempt in UInt16(1)...UInt16(3) {
      guard !cancellation.isCancelled else { return .offline("Check cancelled") }
      guard ProcessInfo.processInfo.systemUptime < deadline else {
        return .offline("ICMP check timed out")
      }
      var packet: [UInt8] =
        [ipv6 ? 128 : 8, 0, 0, 0, 0, 0, UInt8(attempt >> 8), UInt8(attempt & 255)] + nonce
      if !ipv6 {
        let sum = checksum(packet)
        packet[2] = UInt8(sum >> 8)
        packet[3] = UInt8(sum & 255)
      }
      let sent = packet.withUnsafeBytes { send(descriptor, $0.baseAddress, $0.count, 0) }
      guard sent == packet.count else { return systemError("ICMP send") }

      let attemptDeadline = min(deadline, ProcessInfo.processInfo.systemUptime + 1.5)
      while ProcessInfo.processInfo.systemUptime < attemptDeadline {
        guard !cancellation.isCancelled else { return .offline("Check cancelled") }
        let remaining = attemptDeadline - ProcessInfo.processInfo.systemUptime
        var event = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let ready = poll(&event, 1, Int32(max(1, min(remaining, 0.1) * 1000)))
        if ready < 0 {
          if errno == EINTR { continue }
          return systemError("ICMP receive")
        }
        if ready == 0 { continue }
        var bytes = [UInt8](repeating: 0, count: 2048)
        let count = bytes.withUnsafeMutableBytes { recv(descriptor, $0.baseAddress, $0.count, 0) }
        if count < 0 {
          if errno == EAGAIN || errno == EINTR { continue }
          return systemError("ICMP receive")
        }
        let response = Array(bytes.prefix(count))
        if isEchoReply(response, ipv6: ipv6, sequence: attempt, nonce: nonce) { return .online }
      }
    }
    return .offline("No ICMP reply after 3 attempts")
  }

  public static func isEchoReply(_ bytes: [UInt8], ipv6: Bool, sequence: UInt16, nonce: [UInt8])
    -> Bool
  {
    // Darwin IPv4 sockets can return the IP header before the ICMP message.
    let offset =
      !ipv6 && bytes.first.map({ $0 >> 4 == 4 }) == true
      ? Int(bytes[0] & 15) * 4 : 0
    guard offset == 0 || offset >= 20, bytes.count >= offset + 8 + nonce.count else { return false }
    return bytes[offset] == (ipv6 ? 129 : 0)
      && bytes[offset + 1] == 0
      && bytes[offset + 6] == UInt8(sequence >> 8)
      && bytes[offset + 7] == UInt8(sequence & 255)
      && Array(bytes[(offset + 8)..<(offset + 8 + nonce.count)]) == nonce
  }

  public static func checksum(_ bytes: [UInt8]) -> UInt16 {
    var sum: UInt32 = 0
    for index in stride(from: 0, to: bytes.count, by: 2) {
      sum += UInt32(bytes[index]) << 8
      if index + 1 < bytes.count { sum += UInt32(bytes[index + 1]) }
    }
    while sum >> 16 != 0 { sum = (sum & 0xffff) + (sum >> 16) }
    return ~UInt16(sum)
  }

  private static func systemError(_ operation: String) -> HealthStatus {
    .offline("\(operation): \(String(cString: strerror(errno)))")
  }
}
