//
//  SignedRequestManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 11/30/17.
//  Copyright © 2017 APB. All rights reserved.
//

import Foundation
import Alamofire
import BeeKit

class SignedRequestManager {
    private let requestManager: RequestManager

    init(requestManager: RequestManager) {
        self.requestManager = requestManager
    }

    func signedGET(url: String, parameters: [String: Any]?) async throws -> Any? {
        let params = signedParameters(requestManager.authedParams(parameters))
        return try await requestManager.rawRequest(url: url, method: .get, parameters: params)
    }
    
    func signedPOST(url: String, parameters: [String: Any]?) async throws -> Any? {
        let params = signedParameters(requestManager.authedParams(parameters))
        return try await requestManager.rawRequest(url: url, method: .post, parameters: params)
    }
    
    fileprivate func signedParameters(_ params: [String: Any]?) -> [String: Any]? {
        if params == nil { return params }
        var signed = params
        var base = ""
        
        var keys = Array(params!.keys)
        keys.sort(by: { $0 < $1 })
        
        for key in keys {
            let value :AnyObject? = params![key] as AnyObject?
            
            if !(value is String) {
                return params!
            }
            let allowedCharacterSet = (CharacterSet(charactersIn: "@/").inverted)
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
            let escapedValue = (params![key] as AnyObject).addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
            if base.count > 0 {
                base += "&"
            }
            base += "\(escapedKey!)=\(escapedValue!)"
        }
        
        let token = base.hmac(algorithm: HMACAlgorithm.SHA1, key: Config.init().requestSigningKey)
        signed?["beemios_token"] = token
        return signed! as [String : Any]
    }
}
