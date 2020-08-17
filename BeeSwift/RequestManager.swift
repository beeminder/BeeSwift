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

class RequestManager {
    static let baseURLString = Config.baseURLString
    
    class func rawRequest(url: String, method: HTTPMethod, parameters: [String: Any]?, success: ((Any?) -> Void)?, errorHandler: ((Error?, String?) -> Void)?) {
        Alamofire.request("\(RequestManager.baseURLString)/\(url)", method: method, parameters: parameters, encoding: URLEncoding.default, headers: SessionManager.defaultHTTPHeaders).validate().responseJSON { response in
            switch response.result {
            case .success:
                success?(response.result.value)
            case .failure(let e):
                print(response.error)
                if let error = e as? AFError {
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
                        }
                    case .invalidURL(let url): break
                        //
                    case .parameterEncodingFailed(let reason): break
                        //
                    case .multipartEncodingFailed(let reason): break
                        //
                    case .responseSerializationFailed(let reason): break
                        //
                    }
                    errorHandler?(response.error, JSON(data: response.data!)["error_message"].string)
                    print(error)
                    return
                }
                errorHandler?(response.error, JSON(data: response.data!)["error_message"].string)
                print(e)
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
        
        if let accessToken = CurrentUserManager.sharedManager.accessToken {
            var localParams = params!
            localParams["access_token"] = accessToken
            return localParams
        }
        return params
    }

}
