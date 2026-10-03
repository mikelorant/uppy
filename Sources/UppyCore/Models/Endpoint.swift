import Foundation

public enum HealthStatus: Equatable, Sendable {
  case unknown, checking, online
  case offline(String)

  public var shortMenuLabel: String {
    switch self {
    case .unknown: return "Not checked"
    case .checking: return "Checking"
    case .online: return "Online"
    case .offline: return "Offline"
    }
  }
}

public enum HealthCheckType: String, Codable, Sendable {
  case http = "HTTP/HTTPS"
  case ping = "Ping"
  case tcp = "TCP"

  public static func inferred(from host: String) -> Self {
    let address = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if address.hasPrefix("http://") || address.hasPrefix("https://") { return .http }
    return HealthCheckEndpoint.tcpAddress(in: address) == nil ? .ping : .tcp
  }
}

public struct HealthCheckEndpoint: Codable, Equatable, Sendable {
  public let id: String
  public var host: String
  public var status: HealthStatus = .unknown
  public var type: HealthCheckType { .inferred(from: host) }

  private enum CodingKeys: String, CodingKey { case id, host, type }

  public init(id: String = UUID().uuidString, host: String) {
    self.id = id
    self.host = host
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    host = try values.decode(String.self, forKey: .host)
  }

  public func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(host, forKey: .host)
    // Retain the existing on-disk schema, but always derive type from the address.
    try values.encode(type, forKey: .type)
  }

  public var httpURL: URL? {
    let address = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: address),
      let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
      url.host != nil
    else { return nil }
    return url
  }

  public var pingHost: String? {
    let address = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !address.isEmpty else { return nil }
    if let url = URL(string: address), let host = url.host { return host }
    return address.components(separatedBy: "/").first
  }

  public var tcpAddress: (host: String, port: UInt16)? { Self.tcpAddress(in: host) }

  public static func tcpAddress(in value: String) -> (host: String, port: UInt16)? {
    let address = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let colon = address.lastIndex(of: ":"),
      let port = UInt16(address[address.index(after: colon)...]), port > 0
    else { return nil }
    let prefix = String(address[..<colon])
    // IPv6 ports require brackets; a bare IPv6 address remains an ICMP target.
    guard !prefix.isEmpty, !prefix.contains(":") || (prefix.hasPrefix("[") && prefix.hasSuffix("]"))
    else { return nil }
    let host = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    guard !host.isEmpty else { return nil }
    return (host, port)
  }
}
