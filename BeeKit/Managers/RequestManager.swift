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
    let requestError: Error?

    init(_ message: String, requestError: Error?) {
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
    
    func rawRequest(url: String, method: HTTPMethod, parameters: [String: Any]?, headers: HTTPHeaders) async throws -> Any? {

        var urlWithSubstitutions = url
        if url.contains("{username}") {
            guard let username = ServiceLocator.currentUserManager.username else {
                throw ServerError("Attempted to make request to username-based URL \(url) while logged out", requestError: nil)
            }
            urlWithSubstitutions = urlWithSubstitutions.replacingOccurrences(of: "{username}", with: username)
        }

        let encoding: ParameterEncoding = if method == .get { URLEncoding.default } else { JSONEncoding.default }// TODO
        let response = await AF.request(
            "\(baseURLString)/\(urlWithSubstitutions)",
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: HTTPHeaders.default + headers
        )
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
                        try? await ServiceLocator.currentUserManager.signOut()
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
        return try await rawRequest(url: url, method: .get, parameters: parameters, headers: authenticationHeaders())
    }
    
    
    public func put(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await rawRequest(url: url, method: .patch, parameters: parameters, headers: authenticationHeaders())
    }
    
    public func post(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await rawRequest(url: url, method: .post, parameters: parameters, headers: authenticationHeaders())
    }
    
    public func delete(url: String, parameters: [String: Any]?) async throws -> Any? {
        return try await rawRequest(url: url, method: .delete, parameters: parameters, headers: authenticationHeaders())
    }
    
    
    func authenticationHeaders() -> HTTPHeaders {
        guard let accessToken = ServiceLocator.currentUserManager.accessToken else {
            return HTTPHeaders()
        }
        return HTTPHeaders([
            HTTPHeader(name: "Authorization", value: "Bearer " + accessToken)
        ])
    }

    public func addDatapoint(urtext: String, slug: String) async throws -> Any? {
        let params = ["urtext": urtext, "requestid": UUID().uuidString]
        
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
