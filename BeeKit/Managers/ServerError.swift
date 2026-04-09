// Part of BeeSwift. Copyright Beeminder

import Foundation

public enum ServerError: LocalizedError {
  case notFound
  case unauthorized
  case forbidden
  case serverError(Int)
  case custom(String, requestError: Error?)
  public var errorDescription: String? {
    switch self {
    case .notFound: return "Not found"
    case .unauthorized: return "Unauthorized"
    case .forbidden: return "Permission denied"
    case .serverError(let code): return "Server error (\(code)). Please try again later"
    case .custom(let message, _): return message
    }
  }
  var requestError: Error? {
    switch self {
    case .custom(_, let error): return error
    default: return nil
    }
  }
}
