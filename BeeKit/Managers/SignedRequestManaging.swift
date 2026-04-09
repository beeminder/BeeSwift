// Part of BeeSwift. Copyright Beeminder

public protocol SignedRequestManaging {
  func signedGET(url: String, parameters: [String: Any]?) async throws -> Any?
  func signedPOST(url: String, parameters: [String: Any]?) async throws -> Any?
}

extension SignedRequestManaging {
  public func signedGET(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    try await signedGET(url: url, parameters: parameters)
  }
  public func signedPOST(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    try await signedPOST(url: url, parameters: parameters)
  }
}
