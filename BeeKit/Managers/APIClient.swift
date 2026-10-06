// Part of BeeSwift. Copyright Beeminder

import Foundation

open class APIClient {
  private let requestManager: RequestManager

  public init(requestManager: RequestManager) { self.requestManager = requestManager }

  open func signIn(email: String, password: String, beemiosSecret: String) async throws -> Any? {
    try await requestManager.post(
      url: "api/private/sign_in",
      parameters: ["user": ["login": email, "password": password], "beemios_secret": beemiosSecret] as [String: Any],
    )
  }

  open func fetchAppVersions() async throws -> Any? {
    try await requestManager.get(url: "api/private/app_versions.json")
  }

  open func fetchUser(diffSince: TimeInterval? = nil, emaciated: Bool? = nil) async throws -> Any? {
    var parameters: [String: Any] = [:]
    if let diffSince { parameters["diff_since"] = diffSince }
    if let emaciated { parameters["emaciated"] = emaciated ? "true" : "false" }
    return try await requestManager.get(
      url: "api/v1/users/{username}.json",
      parameters: parameters.isEmpty ? nil : parameters,
    )
  }

  open func fetchGoals(emaciated: Bool? = nil) async throws -> Any? {
    let parameters = emaciated.map { ["emaciated": $0 ? "true" : "false"] }
    return try await requestManager.get(url: "api/v1/users/{username}/goals.json", parameters: parameters)
  }

  open func fetchGoalDetails(slug: String, datapointsCount: Int? = nil, emaciated: Bool? = nil) async throws -> Any? {
    var parameters: [String: Any] = [:]
    if let datapointsCount { parameters["datapoints_count"] = "\(datapointsCount)" }
    if let emaciated { parameters["emaciated"] = emaciated ? "true" : "false" }
    return try await requestManager.get(
      url: "api/v1/users/{username}/goals/\(slug)",
      parameters: parameters.isEmpty ? nil : parameters,
    )
  }

  open func requestAutodataRefresh(goalSlug: String) async throws -> Any? {
    try await requestManager.get(url: "api/v1/users/{username}/goals/\(goalSlug)/refresh_graph.json")
  }

  open func fetchDatapoints(goalSlug: String, sort: String, per: Int, page: Int) async throws -> Any? {
    try await requestManager.get(
      url: "api/v1/users/{username}/goals/\(goalSlug)/datapoints.json",
      parameters: ["sort": sort, "per": per, "page": page],
    )
  }

  open func updateDatapoint(
    goalSlug: String,
    datapointID: String,
    value: String? = nil,
    comment: String? = nil,
    urtext: String? = nil,
  ) async throws -> Any? {
    var parameters: [String: Any] = [:]
    if let value { parameters["value"] = value }
    if let comment { parameters["comment"] = comment }
    if let urtext { parameters["urtext"] = urtext }
    return try await requestManager.put(
      url: "api/v1/users/{username}/goals/\(goalSlug)/datapoints/\(datapointID).json",
      parameters: parameters,
    )
  }

  open func deleteDatapoint(goalSlug: String, datapointID: String) async throws -> Any? {
    try await requestManager.delete(url: "api/v1/users/{username}/goals/\(goalSlug)/datapoints/\(datapointID).json")
  }

  open func createDatapoint(goalSlug: String, urtext: String, requestID: String? = nil) async throws -> Any? {
    var parameters = ["urtext": urtext]
    if let requestID { parameters["requestid"] = requestID }
    return try await requestManager.post(
      url: "api/v1/users/{username}/goals/\(goalSlug)/datapoints.json",
      parameters: parameters,
    )
  }

  open func updateUser(defaultAlertstart: Int? = nil, defaultDeadline: Int? = nil, defaultLeadtime: Int? = nil)
    async throws -> Any?
  {
    var parameters: [String: Any] = [:]
    if let defaultAlertstart { parameters["default_alertstart"] = defaultAlertstart }
    if let defaultDeadline { parameters["default_deadline"] = defaultDeadline }
    if let defaultLeadtime { parameters["default_leadtime"] = defaultLeadtime }
    return try await requestManager.put(url: "api/v1/users/{username}.json", parameters: parameters)
  }

  open func updateGoal(
    slug: String,
    leadtime: Int? = nil,
    alertstart: Int? = nil,
    deadline: Int? = nil,
    usesDefaultNotifications: Bool? = nil,
    iiParams: [String: Any]? = nil,
  ) async throws -> Any? {
    var parameters: [String: Any] = [:]
    if let leadtime { parameters["leadtime"] = leadtime }
    if let alertstart { parameters["alertstart"] = alertstart }
    if let deadline { parameters["deadline"] = deadline }
    if let usesDefaultNotifications { parameters["use_defaults"] = usesDefaultNotifications }
    if let iiParams { parameters["ii_params"] = iiParams }
    return try await requestManager.put(url: "api/v1/users/{username}/goals/\(slug).json", parameters: parameters)
  }

  open func registerDeviceToken(token: String, environment: String? = nil) async throws -> Any? {
    var parameters = ["device_token": token]
    if let environment { parameters["server"] = environment }
    return try await requestManager.post(url: "/api/private/device_tokens", parameters: signedParameters(parameters))
  }

  private func signedParameters(_ parameters: [String: Any]) -> [String: Any] {
    var base = ""
    for key in parameters.keys.sorted() {
      guard let value = parameters[key] as? String else { return parameters }
      let allowedCharacterSet = CharacterSet(charactersIn: "@/").inverted
      guard let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet),
        let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet)
      else { return parameters }
      if !base.isEmpty { base += "&" }
      base += "\(escapedKey)=\(escapedValue)"
    }
    var signed = parameters
    signed["beemios_token"] = base.hmac(algorithm: HMACAlgorithm.SHA1, key: Config().requestSigningKey)
    return signed
  }
}
