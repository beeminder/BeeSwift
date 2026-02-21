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

public enum ServerError: LocalizedError {
  case notFound
  case unauthorized
  case forbidden
  case serverError(Int)
  case custom(String, requestError: Error?)
  public var errorDescription: String? {
    switch self {
    case .notFound: return "Not found"
    case .unauthorized: return "Unauthorized"
    case .forbidden: return "Permission denied"
    case .serverError(let code): return "Server error (\(code)). Please try again later"
    case .custom(let message, _): return message
    }
  }
  var requestError: Error? {
    switch self {
    case .custom(_, let error): return error
    default: return nil
    }
  }
}

public class RequestManager {
  public let baseURLString = Config().baseURLString
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "RequestManager")
  
  private func rawRequest(url: String, method: HTTPMethod, parameters: [String: Any]? = nil, headers: HTTPHeaders) async throws
    -> Any?
  {

    var urlWithSubstitutions = url
    if url.contains("{username}") {
      guard let username = await ServiceLocator.currentUserManager.username else {
        throw ServerError.custom(
          "Attempted to make request to username-based URL \(url) while logged out",
          requestError: nil
        )
      }
      urlWithSubstitutions = urlWithSubstitutions.replacingOccurrences(of: "{username}", with: username)
    }

    let encoding: ParameterEncoding = if method == .get { URLEncoding.default } else { JSONEncoding.default }  // TODO
    
    // TODO no longer needed once migrated to endpoint enum
    let urlStr = urlWithSubstitutions.starts(with: baseURLString) ? urlWithSubstitutions : "\(baseURLString)/\(urlWithSubstitutions)"
    
    logger.debug("rawRequest: \(urlStr), method \(method.rawValue)")
    let response = await AF.request(
      urlStr,
      method: method,
      parameters: parameters,
      encoding: encoding,
      headers: HTTPHeaders.default + headers
    ).validate().serializingData(emptyRequestMethods: [HTTPMethod.post]).response

    switch response.result {
    case .success(let data):
      let asJSON = try? JSONSerialization.jsonObject(with: data)
      return asJSON

    case .failure(let error):
      logger.error("Error issuing request \(url): \(error, privacy: .public)")

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
  func authenticationHeaders() -> HTTPHeaders {
    guard let accessToken = ServiceLocator.currentUserManager.accessToken else { return HTTPHeaders() }
    return HTTPHeaders([HTTPHeader(name: "Authorization", value: "Bearer " + accessToken)])
  }
  
  public func request(endpoint: EndPoint) async throws -> Any? {
    print("rawRequest(endpoint) \(endpoint)")
    
    let parameters = endpoint.shouldSign ? signedParameters(endpoint.parameters) : endpoint.parameters
    return try await rawRequest(url: endpoint.url.absoluteString,
                                method: endpoint.method,
                                parameters: parameters,
                                headers: authenticationHeaders())
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


public enum EndPoint {
  // signing in
  case signIn(username: String, password: String, beemiosSecret: String)
  
  // about the app versions the server expects to see
  case appVersions
  
  // Retrieves information and a list of goalnames for the user with username.
  case getUser(username: String, diff_since: TimeInterval? = nil, emaciated: Bool? = nil)
  
  // Gets goal details for user u's goal g
  case getGoalDetails(username: String, goalname: String, datapoints_count: Int? = nil, emaciated: Bool? = nil)
  
  // Get the list of datapoints for user u's goal g
  case getDatapoints(username: String, goalname: String, sort: String? = nil, count: Int? = nil, page: Int? = nil, per: Int? = nil)

  // Get all goals for a user
  case getGoals(username: String, emaciated: Bool? = nil)
  
  // Force a fetch of autodata and graph refresh
  case requestAutodataFetch(username: String, goalname: String)
  
  // Update the datapoint with ID id for user u's goal g (beeminder.com/u/g).
  case updateDatapoint(username: String, goalname: String, datapointID: String, timestamp: Double? = nil, value: NSNumber? = nil, comment: String? = nil, urtext: String? = nil)
  
  // Update a goal for a user
  case updateGoal(username: String,
                  goalname: String,
                  title: String? = nil,
                  tmin: String? = nil,
                  tmax: String? = nil,
                  isSecret: Bool? = nil,
                  isDataPublic: Bool? = nil,
                  tags: [String]? = nil,
                  iiParams: [String:Any?]? = nil,
                  leadtime: Int? = nil,
                  alertstart: Int? = nil,
                  deadline: Int? = nil,
                  usesDefaultNotifications: Bool? = nil)
  
  // Update the user
  case updateUser(username: String,
                  default_alertstart: Int? = nil,
                  default_deadline: Int? = nil,
                  default_leadtime: Int? = nil)
  
  // Add a new datapoint to user u's goal g — beeminder.com/u/g.
  case createDatapoint(username: String,
                       goalname: String,
                       value: NSNumber? = nil,
                       timestamp: Double? = nil,
                       daystamp: String? = nil,
                       comment: String? = nil,
                       urtext: String? = nil,
                       requestID: String? = nil)
  
  case deletedDatapoint(username: String, goalname: String, datapointID: String)
  
  case registerDeviceToken(token: String, environment: String? = nil)

  var url: URL {
    var urlComponents: URLComponents {
      var urlComponents = URLComponents()
      urlComponents.scheme = "https"
      urlComponents.host = Config().apiHost
      urlComponents.path = self.path
      return urlComponents
    }
    
    return urlComponents.url!
  }
  
  var path: String {
    return switch self {
    case .signIn:
      "/api/private/sign_in"

    case .appVersions:
      "/api/private/app_versions.json"
      
    case .registerDeviceToken:
      "/api/private/device_tokens"

    case .getUser(let username, _, _), .updateUser(let username, _, _, _):
      "/api/v1/users/\(username).json"

    case .getGoalDetails(let username, let goalname, _, _):
      "/api/v1/users/\(username)/goals/\(goalname)"
      
    case .getDatapoints(let username, let goalname, _, _, _, _):
      "/api/v1/users/\(username)/goals/\(goalname)/datapoints.json"
      
    case .getGoals(let username, _):
      "/api/v1/users/\(username)/goals.json"
      
    case .requestAutodataFetch(let username, let goalname):
      "/api/v1/users/\(username)/goals/\(goalname)/refresh_graph.json"
      
    case .updateDatapoint(let username, let goalname, let datapointID, _, _, _, _):
      "/api/v1/users/\(username)/goals/\(goalname)/datapoints/\(datapointID).json"
      
    case .updateGoal(let username, let goalname, _, _, _, _, _, _, _, _, _, _, _):
      "/api/v1/users/\(username)/goals/\(goalname).json"
      
    case .createDatapoint(let username, let goalname, _, _, _, _, _, _):
      "/api/v1/users/\(username)/goals/\(goalname)/datapoints.json"
      
    case .deletedDatapoint(let username, let goalname, let datapointID):
      "/api/v1/users/\(username)/goals/\(goalname)/datapoints/\(datapointID).json"
    }
  }
  
  var method: HTTPMethod {
    return switch self {
    case .signIn, .createDatapoint, .registerDeviceToken:
        .post
    case .appVersions, .getUser, .getGoalDetails, .getDatapoints, .getGoals, .requestAutodataFetch:
        .get
    case .updateDatapoint, .updateGoal, .updateUser:
        .put
    case .deletedDatapoint:
        .delete
    }
  }
  
  var parameters: [String: Any]? {
    switch self {
    case .signIn(let username, let password, let beemiosSecret):
      return ["user":
        [
          "login": username,
          "password": password
        ],
       "beemios_secret": beemiosSecret]
      as [String: Any]
      
    case .getUser(_, let diff_since, let emaciated):
      var parameters: [String: Any] = [:]
      if let diff_since { parameters["diff_since"] = diff_since }
      if let emaciated { parameters["emaciated"] = emaciated }
      return parameters.isEmpty ? nil : parameters
    
    case .getGoalDetails(_, _, let datapoints_count, let emaciated):
      var parameters: [String: Any] = [:]
      if let datapoints_count { parameters["datapoints_count"] = datapoints_count }
      if let emaciated { parameters["emaciated"] = emaciated }
      return parameters.isEmpty ? nil : parameters
      
    case .getDatapoints(_, _, let sort, let count, let page, let per):
      var parameters: [String: Any] = [:]
      if let sort { parameters["sort"] = sort }
      if let count { parameters["count"] = count }
      if let page { parameters["page"] = page }
      if let per { parameters["per"] = per }
      return parameters.isEmpty ? nil : parameters
      
    case .getGoals(_, let emaciated):
      if let emaciated { return ["emaciated": emaciated] }
      return nil
      
    case .updateDatapoint(_, _, _, let timestamp, let value, let comment, let urtext):
      var parameters: [String: Any] = [:]
      if let timestamp { parameters["timestamp"] = timestamp }
      if let value { parameters["value"] = value }
      if let comment { parameters["comment"] = comment }
      if let urtext { parameters["urtext"] = urtext }
      return parameters.isEmpty ? nil : parameters
        
    case .updateGoal(_, _, let title, let tmin, let tmax, let isSecret, let isDataPublic, let tags, let iiParams, let leadtime, let alertstart, let deadline, let usesDefaultNotifications):
      var parameters: [String: Any] = [:]
      if let title { parameters["title"] = title }
      if let tmin { parameters["tmin"] = tmin }
      if let tmax { parameters["tmax"] = tmax }
      if let isSecret { parameters["is_secret"] = isSecret }
      if let isDataPublic { parameters["is_data_public"] = isDataPublic }
      if let tags { parameters["tags"] = tags }
      if let iiParams { parameters["ii_params"] = iiParams }
      if let leadtime { parameters["leadtime"] = leadtime }
      if let alertstart { parameters["alertstart"] = alertstart }
      if let deadline { parameters["deadline"] = deadline }
      if let usesDefaultNotifications { parameters["use_defaults"] = usesDefaultNotifications }
      return parameters.isEmpty ? nil : parameters
      
    case .updateUser(_, let default_alertstart, let default_deadline, let default_leadtime):
      var parameters: [String: Any] = [:]
      if let default_alertstart { parameters["default_alertstart"] = default_alertstart }
      if let default_deadline { parameters["default_deadline"] = default_deadline }
      if let default_leadtime { parameters["default_leadtime"] = default_leadtime }
      return parameters.isEmpty ? nil : parameters
      
    case .createDatapoint(_, _, let value, let timestamp, let daystamp, let comment, let urtext, let requestID):
      var parameters: [String: Any] = [:]
      if let value { parameters["value"] = value }
      if let timestamp { parameters["timestamp"] = timestamp }
      if let daystamp { parameters["daystamp"] = daystamp }
      if let comment { parameters["comment"] = comment }
      if let urtext { parameters["urtext"] = urtext }
      if let requestID { parameters["request_id"] = requestID }
      return parameters.isEmpty ? nil : parameters
      
    case .registerDeviceToken(let token, let environment):
      var parameters: [String: Any] = [:]
      parameters["device_token"] = token
      if let environment { parameters["server"] = environment }
      return parameters.isEmpty ? nil : parameters
        
    default:
      return nil
    }
  }
  
  var shouldSign: Bool {
    return switch self {
    case .registerDeviceToken:
      true
    default:
      false
    }
  }
}


fileprivate extension RequestManager {
  func signedParameters(_ params: [String: Any]?) -> [String: Any]? {
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
