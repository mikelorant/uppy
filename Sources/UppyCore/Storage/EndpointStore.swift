import Foundation

public final class EndpointStore {
  public static let defaults = ["https://google.com", "github.com:22", "1.1.1.1"]
    .map { HealthCheckEndpoint(host: $0) }
  private let defaults: UserDefaults
  private let key = "healthChecker.endpoints"
  private let noticeKey = "healthChecker.recoveryNotice"
  public var recoveryMessage: String? { defaults.string(forKey: noticeKey) }
  public var recoveryBackupKeys: [String] {
    defaults.dictionaryRepresentation().keys.filter {
      $0.hasPrefix("healthChecker.recoveryBackup.")
    }.sorted()
  }

  public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  public func load() -> [HealthCheckEndpoint] {
    if let data = defaults.data(forKey: key) {
      do {
        let saved = try JSONDecoder().decode([HealthCheckEndpoint].self, from: data)
        guard !saved.isEmpty else { return Self.defaults }
        var seen = Set<String>()
        let normalized = saved.compactMap { endpoint -> HealthCheckEndpoint? in
          let host = endpoint.host.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !host.isEmpty else { return nil }
          return HealthCheckEndpoint(
            id: seen.insert(endpoint.id).inserted ? endpoint.id : UUID().uuidString, host: host)
        }
        return normalized.isEmpty ? Self.defaults : normalized
      } catch {
        // Preserve the original bytes before startup writes a replacement configuration.
        defaults.set(data, forKey: "healthChecker.recoveryBackup.\(UUID().uuidString)")
        defaults.set(
          "Saved endpoints could not be read. The original data was backed up in macOS user defaults; legacy endpoints or defaults were loaded instead.",
          forKey: noticeKey)
      }
    }
    if let legacy = defaults.string(forKey: "healthChecker.hosts") {
      let migrated = legacy.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map { HealthCheckEndpoint(host: $0) }
      return migrated.isEmpty ? Self.defaults : migrated
    }
    return Self.defaults
  }

  public func acknowledgeRecovery() { defaults.removeObject(forKey: noticeKey) }

  public func save(_ endpoints: [HealthCheckEndpoint]) {
    guard let data = try? JSONEncoder().encode(endpoints) else { return }
    defaults.set(data, forKey: key)
  }
}
