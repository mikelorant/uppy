import Foundation
import Network
import UppyCore

@MainActor
func checkRecoveryAndValidation() throws {
  let (store, defaults, name) = isolatedStore()
  defer { defaults.removePersistentDomain(forName: name) }
  let original = HealthCheckEndpoint(host: "original.example")
  store.save([original])
  let recorder = CheckRecorder()
  let monitor = EndpointMonitor(store: store, checker: recorder.check)
  monitor.refresh()
  monitor.update(id: original.id, address: "new.example")
  try expect(recorder.cancellations.value == 1, "Editing cancels old network work")
  monitor.update(id: original.id, address: "  ")
  try expect(store.load()[0].host == "new.example", "Blank edit cannot corrupt saved configuration")
  let corrupt = Data("broken configuration".utf8)
  defaults.set(corrupt, forKey: "healthChecker.endpoints")
  let recovered = EndpointMonitor(store: store, checker: recorder.check)
  try expect(recovered.configurationWarning != nil, "Recovery is visible")
  try expect(store.recoveryBackupKeys.count == 1, "Recovery saves original bytes")
  try expect(
    defaults.data(forKey: store.recoveryBackupKeys[0]) == corrupt, "Backup is byte-for-byte exact")
  try expect(store.load().count == 3, "Defaults are saved after backup")
  recovered.acknowledgeRecovery()
  try expect(
    store.recoveryMessage == nil && store.recoveryBackupKeys.count == 1,
    "Acknowledgment keeps backup")
}

@MainActor
func checkScheduling() async throws {
  let (store, defaults, name) = isolatedStore()
  defer { defaults.removePersistentDomain(forName: name) }
  store.save([HealthCheckEndpoint(host: "schedule.example")])
  let recorder = CheckRecorder()
  let monitor = EndpointMonitor(store: store, checker: recorder.check, interval: .milliseconds(30))
  monitor.start()
  let deadline = ContinuousClock.now + .seconds(2)
  while recorder.requestCount < 2 && ContinuousClock.now < deadline {
    try await Task.sleep(for: .milliseconds(10))
  }
  try expect(recorder.requestCount >= 2, "Automatic schedule refreshes")
  monitor.suspend()
  let suspendedCount = recorder.requestCount
  try await Task.sleep(for: .milliseconds(80))
  try expect(recorder.requestCount == suspendedCount, "Sleep suspends schedule")
  monitor.resumeAfterWake()
  try expect(recorder.requestCount == suspendedCount + 1, "Wake refreshes immediately")
  monitor.suspend()
}

func checkHTTPPolicy() throws {
  let configuration = HTTPChecker.configuration()
  try expect(configuration.timeoutIntervalForResource == 8, "HTTP has a total resource deadline")
  try expect(
    configuration.tlsMinimumSupportedProtocolVersion == .TLSv12, "HTTPS requires TLS 1.2 or newer")
  try expect(
    !configuration.httpShouldSetCookies && configuration.urlCredentialStorage == nil,
    "Checks do not share cookies or stored credentials")
  let http = URL(string: "http://example.com")!
  let https = URL(string: "https://example.com")!
  try expect(HTTPChecker.allowsRedirect(from: http, to: https), "HTTP can upgrade to HTTPS")
  try expect(!HTTPChecker.allowsRedirect(from: https, to: http), "HTTPS cannot downgrade to HTTP")
  if CommandLine.arguments.contains("--packaged") {
    let policy = Bundle.main.infoDictionary?["NSAppTransportSecurity"] as? [String: Any]
    try expect(
      policy?["NSAllowsArbitraryLoads"] as? Bool == true,
      "Packaged app permits user-defined HTTP hosts")
    try expect(
      Bundle.main.infoDictionary?["NSLocalNetworkUsageDescription"] as? String != nil,
      "Packaged app explains local-network access")
  }
}

func checkICMPDeadlines() throws {
  let cancellation = ProbeCancellation()
  cancellation.cancel()
  try expect(
    ICMPChecker.check(host: "127.0.0.1", cancellation: cancellation) == .offline("Check cancelled"),
    "ICMP cancellation precedes DNS/socket work")
  try expect(
    ICMPChecker.check(host: "127.0.0.1", timeout: 0) == .offline("ICMP check timed out"),
    "ICMP total deadline")
}
