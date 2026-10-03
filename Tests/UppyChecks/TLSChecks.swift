import Foundation
import UppyCore

@MainActor
func checkCertificateValidation() async throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
  process.arguments = ["Scripts/tls-fixture.py"]
  let output = Pipe()
  let diagnostics = Pipe()
  process.standardOutput = output
  process.standardError = diagnostics
  try process.run()
  defer {
    if process.isRunning { process.terminate() }
    process.waitUntilExit()
    let diagnosticData = diagnostics.fileHandleForReading.readDataToEndOfFile()
    if process.terminationStatus != 0 && !diagnosticData.isEmpty {
      FileHandle.standardError.write(diagnosticData)
    }
  }
  let line = output.fileHandleForReading.availableData
  guard
    let port = UInt16(
      String(decoding: line, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
  else {
    throw CheckFailure(description: "TLS fixture did not start")
  }
  let status = await withCheckedContinuation { continuation in
    HTTPChecker.check(url: URL(string: "https://127.0.0.1:\(port)/health")!) {
      continuation.resume(returning: $0)
    }
  }
  process.waitUntilExit()
  try expect(process.terminationStatus == 0, "TLS fixture must exit cleanly")
  if case .offline = status { return }
  throw CheckFailure(description: "Self-signed certificates must not be accepted")
}
