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

public protocol RequestManaging { func request(endpoint: EndPoint) async throws -> Any? }

public class RequestManager: RequestManaging {
  public let baseURLString = Config().baseURLString
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RequestManager")
  public func request(endpoint: EndPoint) async throws -> Any? {
    print("rawRequest(endpoint) \(endpoint)")
    let parameters = endpoint.shouldSign ? signedParameters(endpoint.parameters) : endpoint.parameters
    return try await rawRequest(
      url: endpoint.url,
      method: endpoint.method,
      parameters: parameters,
      headers: authenticationHeaders()
    )
  }
}

extension RequestManager {
  fileprivate func rawRequest(url: URL, method: HTTPMethod, parameters: [String: Any]? = nil, headers: HTTPHeaders)
    async throws -> Any?
  {
    let encoding: ParameterEncoding = method == .get ? URLEncoding.default : JSONEncoding.default
    let headers = HTTPHeaders.default + headers
    logger.debug("rawRequest: \(url.absoluteString), method \(method.rawValue)")
    let response = await AF.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
      .validate().serializingData(emptyRequestMethods: [HTTPMethod.post]).response
    switch response.result {
    case .success(let data):
      let asJSON = try? JSONSerialization.jsonObject(with: data)
      return asJSON

    case .failure(let error):
      logger.error("Error issuing request \(url.absoluteString): \(error, privacy: .public)")

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
  fileprivate func authenticationHeaders() -> HTTPHeaders {
    guard let accessToken = ServiceLocator.currentUserManager.accessToken else { return HTTPHeaders() }
    return HTTPHeaders([HTTPHeader(name: "Authorization", value: "Bearer " + accessToken)])
  }
}

extension RequestManager {
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

extension HTTPHeaders {
  fileprivate static func + (lhs: HTTPHeaders, rhs: HTTPHeaders) -> HTTPHeaders {
    var allHeaders = [HTTPHeader]()
    allHeaders.append(contentsOf: lhs)
    allHeaders.append(contentsOf: rhs)
    return HTTPHeaders(allHeaders)
  }
}
