import Foundation
import UppyCore

func checkModels() throws {
  for address in ["https://example.com:443", " HTTP://Example.com "] {
    try expect(HealthCheckType.inferred(from: address) == .http, "HTTP scheme must take priority")
  }
  for address in ["example.com:22", "[::1]:443", "127.0.0.1:65535"] {
    try expect(HealthCheckType.inferred(from: address) == .tcp, "TCP inference: \(address)")
  }
  for address in [
    "1.1.1.1", "::1", "2001:db8::1234", "host:0", "host:65536", "host:no", "[]:22", "",
  ] {
    try expect(HealthCheckType.inferred(from: address) == .ping, "Ping inference: \(address)")
  }
  let ipv6 = HealthCheckEndpoint(host: "[::1]:443")
  try expect(
    ipv6.tcpAddress?.host == "::1" && ipv6.tcpAddress?.port == 443, "Bracketed IPv6 TCP parsing")
  try expect(HealthCheckEndpoint(host: "https://").httpURL == nil, "Reject URL without host")
  try expect(
    HealthCheckEndpoint(host: "https://google.com").httpURL?.host == "google.com", "Valid URL")
  try expect(HealthCheckEndpoint(host: "  ::1  ").pingHost == "::1", "Trim ping target")
  for code in [200, 204, 301, 399] {
    try expect(HTTPChecker.status(for: code) == .online, "HTTP success range")
  }
  for code in [199, 400, 503] {
    try expect(HTTPChecker.status(for: code) == .offline("HTTP \(code)"), "HTTP failure range")
  }
}

func checkStorage() throws {
  let (store, defaults, name) = isolatedStore()
  defer { defaults.removePersistentDomain(forName: name) }
  try expect(
    store.load().map(\.host) == ["https://google.com", "github.com:22", "1.1.1.1"],
    "Startup defaults")
  defaults.set(" \n\t ", forKey: "healthChecker.hosts")
  try expect(
    store.load().map(\.host) == ["https://google.com", "github.com:22", "1.1.1.1"],
    "Empty legacy configuration must seed defaults")
  defaults.set(" example.com \n\n ::1 ", forKey: "healthChecker.hosts")
  try expect(store.load().map(\.host) == ["example.com", "::1"], "Legacy migration")
  var endpoint = HealthCheckEndpoint(id: "saved-id", host: "custom:22")
  endpoint.status = .offline("Temporary failure")
  store.save([endpoint])
  let encoded = try JSONEncoder().encode(endpoint)
  let fields = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
  try expect(
    Set(fields?.keys.map { $0 } ?? []) == Set(["id", "host", "type"]),
    "Keep existing JSON field set")
  let loaded = store.load()
  try expect(loaded[0].id == "saved-id" && loaded[0].type == .tcp, "Preserve ID and infer type")
  try expect(loaded[0].status == .unknown, "Never persist transient health")
  store.save([])
  try expect(
    store.load().map(\.host) == ["https://google.com", "github.com:22", "1.1.1.1"],
    "Saved empty configuration must seed defaults on startup")
  let oldJSON = "[{\"id\":\"old\",\"host\":\"https://example.com\",\"type\":\"Ping\"}]"
  defaults.set(Data(oldJSON.utf8), forKey: "healthChecker.endpoints")
  try expect(store.load()[0].type == .http, "Decode existing JSON and infer current type")
  store.save([endpoint, endpoint])
  let repaired = store.load()
  try expect(Set(repaired.map(\.id)).count == 2, "Repair duplicate IDs")
}
