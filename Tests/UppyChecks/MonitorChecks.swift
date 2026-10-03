import Foundation
import UppyCore

@MainActor
func checkMonitoring() async throws {
  let (store, defaults, name) = isolatedStore()
  defer { defaults.removePersistentDomain(forName: name) }
  let original = HealthCheckEndpoint(id: "first", host: "original.example")
  store.save([original])
  let recorder = CheckRecorder()
  let monitor = EndpointMonitor(store: store, checker: recorder.check)
  var notifications = 0
  monitor.onChange = { notifications += 1 }
  monitor.refresh()
  let old = recorder.take()
  try expect(monitor.endpoints[0].status == .checking, "Refresh announces checking")
  monitor.update(id: original.id, address: "new.example")
  old.complete(.online)
  try expect(monitor.endpoints[0].status == .unknown, "Edited address rejects stale reply")

  monitor.refresh()
  let first = recorder.take()
  monitor.refresh()
  let latest = recorder.take()
  latest.complete(.offline("Latest"))
  first.complete(.online)
  try expect(monitor.endpoints[0].status == .offline("Latest"), "Newer check wins")
  latest.complete(.online)
  try expect(monitor.endpoints[0].status == .offline("Latest"), "Ignore duplicate completion")
  try expect(monitor.counts.offline == 1, "Count failures")

  monitor.update(id: original.id, address: original.host)
  try expect(store.load()[0].host == original.host, "Restoring an edit saves original address")
  monitor.add(address: "  https://new.example  ")
  let added = recorder.take()
  try expect(added.endpoint.host == "https://new.example", "Add trims and immediately checks")
  added.complete(.online)
  try expect(monitor.counts.online == 1 && monitor.counts.unknown == 1, "Aggregate health counts")
  let order = monitor.endpoints.map(\.id)
  monitor.swap(0, 1)
  try expect(store.load().map(\.id) == order, "Hover preview does not persist")
  monitor.restoreOrder(order)
  try expect(monitor.endpoints.map(\.id) == order, "Cancelled drag restores order")
  monitor.swap(0, 1)
  monitor.save()
  try expect(store.load().map(\.id) == order.reversed().map { $0 }, "Accepted drag persists order")
  monitor.refresh(id: original.id)
  let removed = recorder.take()
  monitor.remove(id: original.id)
  removed.complete(.online)
  try expect(monitor.endpoints.count == 1, "Deleted endpoint rejects late reply")
  monitor.remove(id: added.endpoint.id)
  monitor.add(address: " \n ")
  try expect(monitor.endpoints.isEmpty, "Deleting all endpoints leaves the running app empty")
  let savedData = defaults.data(forKey: "healthChecker.endpoints")!
  let saved = try JSONDecoder().decode([HealthCheckEndpoint].self, from: savedData)
  try expect(saved.isEmpty, "Blank add is ignored; empty list is saved")
  let restarted = EndpointMonitor(store: store, checker: recorder.check)
  try expect(
    restarted.endpoints.map(\.host) == ["https://google.com", "github.com:22", "1.1.1.1"],
    "Restarting with no endpoints restores defaults")
  try expect(notifications > 0, "Notify menu of changes")
}

@MainActor
func checkMonitorLifetime() async throws {
  let (store, defaults, name) = isolatedStore()
  defer { defaults.removePersistentDomain(forName: name) }
  store.save([HealthCheckEndpoint(host: "test.example")])
  let recorder = CheckRecorder()
  weak var weakMonitor: EndpointMonitor?
  do {
    let monitor = EndpointMonitor(store: store, checker: recorder.check)
    weakMonitor = monitor
    monitor.start()
    monitor.start()  // Starting twice must not install two schedules.
    try expect(recorder.requestCount == 1, "Starting twice triggers one initial check")
  }
  try expect(weakMonitor == nil, "Monitoring schedule must not retain owner")
}
