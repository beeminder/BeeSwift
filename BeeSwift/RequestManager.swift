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
    
    class func rawRequest(url: String, method: HTTPMethod, parameters: [String: Any]?, success: ((Any?) -> Void)?, errorHandler: ((Error?, String?) -> Void)?) {
        AF.request("\(RequestManager.baseURLString)/\(url)", method: method, parameters: parameters, encoding: URLEncoding.default, headers: HTTPHeaders.default).validate().response { response in
            switch response.result {
            case .success(let data):
                let asJSON = data.flatMap{d in try? JSONSerialization.jsonObject(with: d)}
                success?(asJSON)
            case .failure(let error):
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
                errorHandler?(response.error, JSON(data: response.data!)["error_message"].string)
                print(error)
                return
            }
        }
    }
    
    class func get(url: String, parameters: [String: Any]?, success: ((Any?) -> Void)?, errorHandler: ((Error?, String?) -> Void)?) {
        RequestManager.rawRequest(url: url, method: .get, parameters: RequestManager.authedParams(parameters), success: success, errorHandler: errorHandler)
    }
    
    
    class func put(url: String, parameters: [String: Any]?, success: ((Any?) -> Void)?, errorHandler: ((Error?, String?) -> Void)?) {
        RequestManager.rawRequest(url: url, method: .patch, parameters: RequestManager.authedParams(parameters), success: success, errorHandler: errorHandler)
    }
    
    class func post(url: String, parameters: [String: Any]?, success: ((Any?) -> Void)?, errorHandler: ((Error?, String?) -> Void)?) {
        RequestManager.rawRequest(url: url, method: .post, parameters: RequestManager.authedParams(parameters), success: success, errorHandler: errorHandler)
    }
    
    class func delete(url: String, parameters: [String: Any]?, success: ((Any?) -> Void)?, errorHandler: ((Error?, String?) -> Void)?) {
        RequestManager.rawRequest(url: url, method: .delete, parameters: RequestManager.authedParams(parameters), success: success, errorHandler: errorHandler)
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

    class func addDatapoint(urtext: String, slug: String, success: ((Any?) -> Void)?, errorHandler: ((Error?, String?) -> Void)?) {
        let params = ["urtext": urtext, "requestid": UUID().uuidString]
        
        RequestManager.post(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(slug)/datapoints.json", parameters: params, success: success, errorHandler: errorHandler)
    }
}
