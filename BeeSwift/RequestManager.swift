//
//  BSSessionManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/10/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import Alamofire

class RequestManager {
    static let baseURLString = Config.baseURLString
    
    class func rawRequest(url: String, method: HTTPMethod, parameters: Parameters?, success: ((Any?) -> Void)?, errorHandler: ((Error?) -> Void)?) {
        Alamofire.request("\(RequestManager.baseURLString)/\(url)", method: method, parameters: parameters, encoding: URLEncoding.default, headers: SessionManager.defaultHTTPHeaders).validate().responseJSON { response in
            switch response.result {
            case .success:
                success?(response.result.value)
                print("Validation Successful")
            case .failure(let error):
                if let error = error as? AFError {
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
                    errorHandler?(response.error)
                    print(error)
                }
            }
        }
    }
    
    class func get(url: String, parameters: Parameters?, success: ((Any?) -> Void)?, errorHandler: ((Error?) -> Void)?) {
        RequestManager.rawRequest(url: url, method: .get, parameters: RequestManager.authedParams(parameters), success: success, errorHandler: errorHandler)
    }
    
    
    class func put(url: String, parameters: Parameters?, success: ((Any?) -> Void)?, errorHandler: ((Error?) -> Void)?) {
        RequestManager.rawRequest(url: url, method: .patch, parameters: RequestManager.authedParams(parameters), success: success, errorHandler: errorHandler)
    }
    
    class func post(url: String, parameters: Parameters?, success: ((Any?) -> Void)?, errorHandler: ((Error?) -> Void)?) {
        RequestManager.rawRequest(url: url, method: .post, parameters: RequestManager.authedParams(parameters), success: success, errorHandler: errorHandler)
    }
    
    
    class func authedParams(_ params: [String: Any]?) -> Parameters? {
        if params == nil { return ["access_token" : CurrentUserManager.sharedManager.accessToken!] }
        if CurrentUserManager.sharedManager.accessToken != nil {
            var localParams = params!
            localParams["access_token"] = CurrentUserManager.sharedManager.accessToken!
            return localParams
        }
        return params
    }

}
