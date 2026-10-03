import Darwin
import Foundation
import UppyCore

@main
struct RegressionRunner {
  @MainActor
  static func main() async {
    let suites: [(String, @MainActor () async throws -> Void)] = [
      ("Endpoint inference and HTTP status", { try checkModels() }),
      ("Persistence and migration", { try checkStorage() }),
      ("HTTP and TCP loopback adapters", { try await checkNetworkAdapters() }),
      ("Monitoring, stale replies, editing and ordering", { try await checkMonitoring() }),
      ("Monitoring lifetime", { try await checkMonitorLifetime() }),
      ("Recovery, blank edits and cancellation", { try checkRecoveryAndValidation() }),
      ("Scheduling and sleep/wake", { try await checkScheduling() }),
      ("HTTP transport and redirect policy", { try checkHTTPPolicy() }),
      ("HTTPS certificate validation", { try await checkCertificateValidation() }),
      ("ICMP cancellation and deadlines", { try checkICMPDeadlines() }),
      ("ICMP packet validation", { try checkICMPPackets() }),
      ("ICMP loopback sockets", { try checkICMPLoopback() }),
    ]
    var failures = 0
    for (name, suite) in suites {
      do {
        try await suite()
        print("PASS: \(name)")
      } catch {
        failures += 1
        print("FAIL: \(name): \(error)")
      }
    }
    print("\(suites.count - failures)/\(suites.count) suites passed")
    if failures != 0 { exit(1) }
  }
}
