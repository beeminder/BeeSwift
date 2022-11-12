//
//  BSSessionManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/10/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import BeeKit

class RequestManager {
    static let baseURLString = Config.init().baseURLString
    
    class func rawRequest(url: String, method: HTTPMethod, parameters: [String: Any]?) async throws -> Any? {
        let response = await AF.request("\(RequestManager.baseURLString)/\(url)", method: method, parameters: parameters, encoding: URLEncoding.default, headers: HTTPHeaders.default).serializingData().response

        switch response.result {
        case .success(let data):
            let asJSON = try? JSONSerialization.jsonObject(with: data)
            return asJSON

        case .failure(let error):
            // TODO: Extract any server error message and throw
            switch error {
            case .responseValidationFailed(let reason):
                print(reason)
                switch reason {
                case .dataFileNil, .dataFileReadFailed:
                    print("Downloaded file could not be read")
                case .missingContentType(let acceptableContentTypes):
                    print("Content Type Missing: \(acceptableContentTypes)")
                case .unacceptableContentType(let acceptableContentTypes, let responseContentType):
                    print("Response content type: \(responseContentType) was unacceptable: \(acceptableContentTypes)")
                case .unacceptableStatusCode(let code):
                    if code == 401 {
                        CurrentUserManager.sharedManager.signOut()
                    }
                    print("Response status code was unacceptable: \(code)")
                case .customValidationFailed(let error):
                    print("Custom validation failed: \(error)")
                @unknown default:
                    print(reason)
                    break
                }
            case .invalidURL(let url):
                print(url)
                break
            case .parameterEncodingFailed(let reason):
                print(reason)
                break
            case .multipartEncodingFailed(let reason):
                print(reason)
                break
            case .responseSerializationFailed(let reason):
                print(reason)
                break
            default:
                print(error)
            }

            // TODO: Extract `JSON(data: response.data!)["error_message"].string` and include if relevant
            throw error;
        }
    }
    
    class func get(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await RequestManager.rawRequest(url: url, method: .get, parameters: RequestManager.authedParams(parameters))
    }
    
    
    class func put(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await RequestManager.rawRequest(url: url, method: .patch, parameters: RequestManager.authedParams(parameters))
    }
    
    class func post(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await RequestManager.rawRequest(url: url, method: .post, parameters: RequestManager.authedParams(parameters))
    }
    
    class func delete(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await RequestManager.rawRequest(url: url, method: .delete, parameters: RequestManager.authedParams(parameters))
    }
    
    
    class func authedParams(_ params: [String: Any]?) -> Parameters? {
        if params == nil { return ["access_token" : CurrentUserManager.sharedManager.accessToken ?? ""] }
        if CurrentUserManager.sharedManager.accessToken != nil {
            var localParams = params!
            localParams["access_token"] = CurrentUserManager.sharedManager.accessToken!
            return localParams
        }
        return params
    }

    class func addDatapoint(urtext: String, slug: String) async throws -> Any? {
        let params = ["urtext": urtext, "requestid": UUID().uuidString]
        
        return try await RequestManager.post(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(slug)/datapoints.json", parameters: params)
    }
}
