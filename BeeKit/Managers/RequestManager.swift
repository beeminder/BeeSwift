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

public actor RequestManager {
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
    let encoding: ParameterEncoding = method == .get ? URLEncoding.default : JSONEncoding.default
    let response = await AF.request(
      "\(baseURLString)/\(urlWithSubstitutions)",
      method: method,
      parameters: parameters,
      encoding: encoding,
      headers: HTTPHeaders.default + headers
    ).validate().serializingData(emptyRequestMethods: [HTTPMethod.post]).response
    switch response.result {
    case .success(let data):
      return try await Task.detached(priority: .low) { try JSONSerialization.jsonObject(with: data) }.value
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
  func authenticationHeaders() -> HTTPHeaders {
    guard let accessToken = ServiceLocator.currentUserManager.accessToken else { return HTTPHeaders() }
    return HTTPHeaders([HTTPHeader(name: "Authorization", value: "Bearer " + accessToken)])
  }
}

extension RequestManager: RequestManaging {
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

extension RequestManager: SignedRequestManaging {
  public func signedGET(url: String, parameters: [String: Any]?) async throws -> Any? {
    let params = signedParameters(parameters)
    return try await rawRequest(url: url, method: .get, parameters: params, headers: authenticationHeaders())
  }
  public func signedPOST(url: String, parameters: [String: Any]?) async throws -> Any? {
    let params = signedParameters(parameters)
    return try await rawRequest(url: url, method: .post, parameters: params, headers: authenticationHeaders())
  }
  fileprivate func signedParameters(_ params: [String: Any]?) -> [String: Any]? {
    if params == nil { return params }
    var signed = params
    var base = ""
    var keys = Array(params!.keys)
    keys.sort(by: { $0 < $1 })
    for key in keys {
      let value: AnyObject? = params![key] as AnyObject?
      if !(value is String) { return params! }
      let allowedCharacterSet = (CharacterSet(charactersIn: "@/").inverted)
      let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
      let escapedValue = (params![key] as AnyObject).addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
      if base.count > 0 { base += "&" }
      base += "\(escapedKey!)=\(escapedValue!)"
    }
    let token = base.hmac(algorithm: HMACAlgorithm.SHA1, key: Config().requestSigningKey)
    signed?["beemios_token"] = token
    return signed! as [String: Any]
  }
}
