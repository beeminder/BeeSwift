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
import OSLog

struct ServerError: Error {
    let message: String
    let requestError: Error

    init(_ message: String, requestError: Error) {
        self.message = message
        self.requestError = requestError
    }

    public var localizedDescription: String {
        return message
    }
}

class RequestManager {
    static let baseURLString = Config.init().baseURLString
    private static let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RequestManager")
    
    class func rawRequest(url: String, method: HTTPMethod, parameters: [String: Any]?) async throws -> Any? {
        let response = await AF.request("\(RequestManager.baseURLString)/\(url)", method: method, parameters: parameters, encoding: URLEncoding.default, headers: HTTPHeaders.default)
            .validate()
            .serializingData(emptyRequestMethods: [HTTPMethod.post])
            .response

        switch response.result {
        case .success(let data):
            let asJSON = try? JSONSerialization.jsonObject(with: data)
            return asJSON

        case .failure(let error):
            logger.error("Error issuing request \(url): \(error, privacy: .public)")

            // Log out the user on an unauthorized response
            if case .responseValidationFailed(let reason) = error {
                if case .unacceptableStatusCode(let code) = reason {
                    if code == 401 {
                        await CurrentUserManager.sharedManager.signOut()
                    }
                }
            }

            // If we receive an error message from the server use it as our user-visible error
            if let data = response.data,
               let errorMessage = JSON(data: data)["error_message"].string {
                throw ServerError(errorMessage, requestError: error)
            }

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
