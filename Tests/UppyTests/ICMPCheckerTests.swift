import XCTest

@testable import UppyCore

final class ICMPCheckerTests: XCTestCase {
  func testReplyWithoutIPHeader() {
    XCTAssertTrue(
      ICMPChecker.isEchoReply(
        [0, 0, 0, 0, 12, 34, 0, 1, 42], ipv6: false, sequence: 1, nonce: [42]))
  }

  func testReplyWithIPv4Header() {
    var header = [UInt8](repeating: 0, count: 20)
    header[0] = 0x45
    XCTAssertTrue(
      ICMPChecker.isEchoReply(
        header + [0, 0, 0, 0, 0, 0, 0, 1, 42], ipv6: false, sequence: 1, nonce: [42]))
  }

  func testRejectsWrongNonceSequenceAndTruncatedReply() {
    XCTAssertFalse(
      ICMPChecker.isEchoReply([0, 0, 0, 0, 0, 0, 0, 2, 42], ipv6: false, sequence: 1, nonce: [42]))
    XCTAssertFalse(
      ICMPChecker.isEchoReply([0, 0, 0, 0, 0, 0, 0, 1, 99], ipv6: false, sequence: 1, nonce: [42]))
    XCTAssertFalse(ICMPChecker.isEchoReply([0x45], ipv6: false, sequence: 1, nonce: [42]))
  }

  func testIPv6Reply() {
    XCTAssertTrue(
      ICMPChecker.isEchoReply([129, 0, 0, 0, 0, 0, 0, 1, 42], ipv6: true, sequence: 1, nonce: [42]))
  }

  func testChecksum() {
    var packet: [UInt8] = [8, 0, 0, 0, 0, 0, 0, 1, 42]
    let checksum = ICMPChecker.checksum(packet)
    packet[2] = UInt8(checksum >> 8)
    packet[3] = UInt8(checksum & 255)
    XCTAssertEqual(ICMPChecker.checksum(packet), 0)
  }

  func testLocalIPv4Socket() {
    XCTAssertEqual(ICMPChecker.check(host: "127.0.0.1"), .online)
  }

  func testLocalIPv6Socket() {
    XCTAssertEqual(ICMPChecker.check(host: "::1"), .online)
  }
}
