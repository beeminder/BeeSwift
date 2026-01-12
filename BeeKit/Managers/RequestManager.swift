//
//  BSSessionManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/10/15.
//  Copyright 2015 APB. All rights reserved.
//

import Alamofire
import Foundation
import OSLog
import SwiftyJSON

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

public class RequestManager {
  public let baseURLString = Config().baseURLString
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RequestManager")
  func rawRequest(url: String, method: HTTPMethod, parameters: [String: Any]? = nil, headers: HTTPHeaders) async throws
    -> Any?
  {

    var urlWithSubstitutions = url
    if url.contains("{username}") {
      guard let username = await ServiceLocator.currentUserManager.username else {
        throw ServerError.custom(
          "Attempted to make request to username-based URL \(url) while logged out",
          requestError: nil
        )
      }
      urlWithSubstitutions = urlWithSubstitutions.replacingOccurrences(of: "{username}", with: username)
    }

    let encoding: ParameterEncoding = if method == .get { URLEncoding.default } else { JSONEncoding.default }  // TODO
    let response = await AF.request(
      "\(baseURLString)/\(urlWithSubstitutions)",
      method: method,
      parameters: parameters,
      encoding: encoding,
      headers: HTTPHeaders.default + headers
    ).validate().serializingData(emptyRequestMethods: [HTTPMethod.post]).response

    switch response.result {
    case .success(let data): return try await Task.detached { try JSONSerialization.jsonObject(with: data) }.value

    case .failure(let error):
      logger.error("Error issuing request \(url): \(error, privacy: .public)")

      // Log out the user on an unauthorized response
      if case .responseValidationFailed(let reason) = error {
        if case .unacceptableStatusCode(let code) = reason {
          if code == 401 { try? await ServiceLocator.currentUserManager.signOut() }
        }
      }

      // If we receive an error message from the server use it as our user-visible error
      if let data = response.data, let errorMessage = try JSON(data: data)["error_message"].string {
        throw ServerError.custom(errorMessage, requestError: error)
      }

      // Handle common HTTP errors with specific error types
      if case .responseValidationFailed(let reason) = error {
        if case .unacceptableStatusCode(let code) = reason {
          switch code {
          case 401: throw ServerError.unauthorized
          case 403: throw ServerError.forbidden
          case 404: throw ServerError.notFound
          case 500...599: throw ServerError.serverError(code)
          default: throw ServerError.custom("Request failed (error \(code))", requestError: error)
          }
        }
      }

      throw error
    }
  }
  public func get(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    return try await rawRequest(url: url, method: .get, parameters: parameters, headers: authenticationHeaders())
  }
  public func put(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    return try await rawRequest(url: url, method: .patch, parameters: parameters, headers: authenticationHeaders())
  }
  public func post(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    return try await rawRequest(url: url, method: .post, parameters: parameters, headers: authenticationHeaders())
  }
  public func delete(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
    return try await rawRequest(url: url, method: .delete, parameters: parameters, headers: authenticationHeaders())
  }
  func authenticationHeaders() -> HTTPHeaders {
    guard let accessToken = ServiceLocator.currentUserManager.accessToken else { return HTTPHeaders() }
    return HTTPHeaders([HTTPHeader(name: "Authorization", value: "Bearer " + accessToken)])
  }

  public func addDatapoint(urtext: String, slug: String, requestId: String? = nil) async throws -> Any? {
    let params = ["urtext": urtext, "requestid": requestId].compactMapValues { $0 }
    return try await post(url: "api/v1/users/{username}/goals/\(slug)/datapoints.json", parameters: params)
  }
}

extension HTTPHeaders {
  static func + (lhs: HTTPHeaders, rhs: HTTPHeaders) -> HTTPHeaders {
    var allHeaders = [HTTPHeader]()
    allHeaders.append(contentsOf: lhs)
    allHeaders.append(contentsOf: rhs)
    return HTTPHeaders(allHeaders)
  }
}
