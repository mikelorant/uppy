import Foundation

/// Draft rows are not configuration until Return is pressed.
enum EndpointEditSession: Equatable {
  case idle
  case adding(String)
  case editing(id: String, originalAddress: String)

  var endpointID: String? {
    if case .editing(let id, _) = self { return id }
    return nil
  }

  var draft: String {
    if case .adding(let address) = self { return address }
    return ""
  }
}
