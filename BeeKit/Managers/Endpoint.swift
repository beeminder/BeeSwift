// Part of BeeSwift. Copyright Beeminder

import Alamofire
import Foundation
import OSLog
import SwiftyJSON

public enum Endpoint {
  // signing in
  case signIn(username: String, password: String, beemiosSecret: String)
  // about the app versions the server expects to see
  case appVersions
  // Retrieves information and a list of goalnames for the user with username.
  case getUser(username: String, diff_since: TimeInterval? = nil, emaciated: Bool? = nil)
  // Gets goal details for user u's goal g
  case getGoalDetails(username: String, goalname: String, datapoints_count: Int? = nil, emaciated: Bool? = nil)
  // Get the list of datapoints for user u's goal g
  case getDatapoints(
    username: String,
    goalname: String,
    sort: String? = nil,
    count: Int? = nil,
    page: Int? = nil,
    per: Int? = nil
  )

  // Get all goals for a user
  case getGoals(username: String, emaciated: Bool? = nil)
  // Force a fetch of autodata and graph refresh
  case requestAutodataFetch(username: String, goalname: String)
  // Update the datapoint with ID id for user u's goal g (beeminder.com/u/g).
  case updateDatapoint(
    username: String,
    goalname: String,
    datapointID: String,
    timestamp: Double? = nil,
    value: NSNumber? = nil,
    comment: String? = nil,
    urtext: String? = nil
  )
  // Update a goal for a user
  case updateGoal(
    username: String,
    goalname: String,
    title: String? = nil,
    tmin: String? = nil,
    tmax: String? = nil,
    isSecret: Bool? = nil,
    isDataPublic: Bool? = nil,
    tags: [String]? = nil,
    iiParams: [String: Any?]? = nil,
    leadtime: Int? = nil,
    alertstart: Int? = nil,
    deadline: Int? = nil,
    usesDefaultNotifications: Bool? = nil
  )
  // Update the user
  case updateUser(
    username: String,
    default_alertstart: Int? = nil,
    default_deadline: Int? = nil,
    default_leadtime: Int? = nil
  )
  // Add a new datapoint to user u's goal g — beeminder.com/u/g.
  case createDatapoint(
    username: String,
    goalname: String,
    value: NSNumber? = nil,
    timestamp: Double? = nil,
    daystamp: String? = nil,
    comment: String? = nil,
    urtext: String? = nil,
    requestID: String? = nil
  )
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
    case .signIn: "/api/private/sign_in"

    case .appVersions: "/api/private/app_versions.json"
    case .registerDeviceToken: "/api/private/device_tokens"

    case .getUser(let username, _, _), .updateUser(let username, _, _, _): "/api/v1/users/\(username).json"

    case .getGoalDetails(let username, let goalname, _, _): "/api/v1/users/\(username)/goals/\(goalname)"
    case .getDatapoints(let username, let goalname, _, _, _, _):
      "/api/v1/users/\(username)/goals/\(goalname)/datapoints.json"
    case .getGoals(let username, _): "/api/v1/users/\(username)/goals.json"
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
    case .signIn, .createDatapoint, .registerDeviceToken: .post
    case .appVersions, .getUser, .getGoalDetails, .getDatapoints, .getGoals, .requestAutodataFetch: .get
    case .updateDatapoint, .updateGoal, .updateUser: .put
    case .deletedDatapoint: .delete
    }
  }
  var parameters: [String: Any]? {
    switch self {
    case .signIn(let username, let password, let beemiosSecret):
      return ["user": ["login": username, "password": password], "beemios_secret": beemiosSecret] as [String: Any]
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
    case .updateGoal(
      _,
      _,
      let title,
      let tmin,
      let tmax,
      let isSecret,
      let isDataPublic,
      let tags,
      let iiParams,
      let leadtime,
      let alertstart,
      let deadline,
      let usesDefaultNotifications
    ):
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
    default: return nil
    }
  }
  var shouldSign: Bool {
    return switch self {
    case .registerDeviceToken: true
    default: false
    }
  }
}
