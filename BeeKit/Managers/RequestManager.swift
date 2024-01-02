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

public class RequestManager {
    public let baseURLString = Config.init().baseURLString
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RequestManager")
    
    func rawRequest(url: String, method: HTTPMethod, parameters: [String: Any]?) async throws -> Any? {
        let response = await AF.request("\(baseURLString)/\(url)", method: method, parameters: parameters, encoding: URLEncoding.default, headers: HTTPHeaders.default)
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
                        await ServiceLocator.currentUserManager.signOut()
                    }
                }
            }

            // If we receive an error message from the server use it as our user-visible error
            if let data = response.data,
               let errorMessage = try JSON(data: data)["error_message"].string {
                throw ServerError(errorMessage, requestError: error)
            }

            throw error;
        }
    }
    
    public func get(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await rawRequest(url: url, method: .get, parameters: authedParams(parameters))
    }
    
    
    public func put(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await rawRequest(url: url, method: .patch, parameters: authedParams(parameters))
    }
    
    public func post(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await rawRequest(url: url, method: .post, parameters: authedParams(parameters))
    }
    
    public func delete(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await rawRequest(url: url, method: .delete, parameters: authedParams(parameters))
    }
    
    
    func authedParams(_ params: [String: Any]?) -> Parameters? {
        if params == nil { return ["access_token" : ServiceLocator.currentUserManager.accessToken ?? ""] }
        if ServiceLocator.currentUserManager.accessToken != nil {
            var localParams = params!
            localParams["access_token"] = ServiceLocator.currentUserManager.accessToken!
            return localParams
        }
        return params
    }

    public func addDatapoint(urtext: String, slug: String) async throws -> Any? {
        let params = ["urtext": urtext, "requestid": UUID().uuidString]
        
        return try await post(url: "api/v1/users/\(ServiceLocator.currentUserManager.username!)/goals/\(slug)/datapoints.json", parameters: params)
    }
}
