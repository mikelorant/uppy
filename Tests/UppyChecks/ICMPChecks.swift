import UppyCore

func checkICMPPackets() throws {
  let reply: [UInt8] = [0, 0, 0, 0, 12, 34, 0, 1, 42]
  try expect(
    ICMPChecker.isEchoReply(reply, ipv6: false, sequence: 1, nonce: [42]), "Headerless IPv4 reply")
  var header = [UInt8](repeating: 0, count: 20)
  header[0] = 0x45
  try expect(
    ICMPChecker.isEchoReply(header + reply, ipv6: false, sequence: 1, nonce: [42]),
    "IPv4 header reply")
  try expect(
    !ICMPChecker.isEchoReply(reply, ipv6: false, sequence: 2, nonce: [42]), "Reject wrong sequence")
  try expect(
    !ICMPChecker.isEchoReply(reply, ipv6: false, sequence: 1, nonce: [99]), "Reject wrong nonce")
  try expect(
    !ICMPChecker.isEchoReply([0x45], ipv6: false, sequence: 1, nonce: [42]), "Reject truncation")
  var ipv6 = reply
  ipv6[0] = 129
  try expect(ICMPChecker.isEchoReply(ipv6, ipv6: true, sequence: 1, nonce: [42]), "IPv6 reply")
  var packet: [UInt8] = [8, 0, 0, 0, 0, 0, 0, 1, 42]
  let checksum = ICMPChecker.checksum(packet)
  packet[2] = UInt8(checksum >> 8)
  packet[3] = UInt8(checksum & 255)
  try expect(ICMPChecker.checksum(packet) == 0, "ICMP checksum")
}

func checkICMPLoopback() throws {
  try expect(ICMPChecker.check(host: "127.0.0.1") == .online, "IPv4 loopback socket")
  try expect(ICMPChecker.check(host: "::1") == .online, "IPv6 loopback socket")
}
