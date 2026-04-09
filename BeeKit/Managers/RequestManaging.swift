// Part of BeeSwift. Copyright Beeminder

public protocol RequestManaging {
  func get(url: String, parameters: [String: Any]?) async throws -> Any?
  func put(url: String, parameters: [String: Any]?) async throws -> Any?
  func post(url: String, parameters: [String: Any]?) async throws -> Any?
  func delete(url: String, parameters: [String: Any]?) async throws -> Any?
  func addDatapoint(urtext: String, slug: String, requestId: String?) async throws -> Any?
}

extension RequestManaging {
  public func get(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    try await get(url: url, parameters: parameters)
  }
  public func put(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    try await put(url: url, parameters: parameters)
  }
  public func post(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    try await post(url: url, parameters: parameters)
  }
  public func delete(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    try await delete(url: url, parameters: parameters)
  }
  public func addDatapoint(urtext: String, slug: String, requestId: String? = nil) async throws -> Any? {
    try await addDatapoint(urtext: urtext, slug: slug, requestId: requestId)
  }
}
