//
//  SignedRequestManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/30/17.
//  Copyright 2017 APB. All rights reserved.
//

import Alamofire
import Foundation

public class SignedRequestManager {
  private let requestManager: RequestManager

  init(requestManager: RequestManager) { self.requestManager = requestManager }

  public func request(endpoint: EndPoint) async throws -> Any? {
    let params = endpoint.shouldSign ? signedParameters(endpoint.parameters) : endpoint.parameters
    return try await requestManager.rawRequest(
      url: endpoint.url.absoluteString,
      method: endpoint.method,
      parameters: params,
      headers: requestManager.authenticationHeaders()
    )
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
