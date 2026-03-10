//
//  DeeplinkGenerator.swift
//  BeeSwift
//
//  Created by krugerk on 2024-11-29.
//

import Foundation

public enum GoalTab: String {
  case commitment
  case stop
  case data
  case statistics
  case settings
}

public enum WebEndpoint {
  case goal(username: String, goalName: String, tab: GoalTab)
  case apiRedirect(username: String, accessToken: String, redirectTo: URL)
  public var url: URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "www.beeminder.com"
    switch self {
    case .goal(let username, let goalName, let tab):
      components.path = "/\(username)/\(goalName)"
      components.fragment = tab.rawValue
    case .apiRedirect(let username, let accessToken, let redirectTo):
      components.path = "/api/v1/users/\(username).json"
      components.queryItems = [
        URLQueryItem(name: "access_token", value: accessToken),
        URLQueryItem(name: "redirect_to_url", value: redirectTo.absoluteString),
      ]
    }
    return components.url!
  }
}

struct DeeplinkGenerator {
  public static func generateDeepLinkToGoalCommitment(username: String, goalName: String) -> URL {
    WebEndpoint.goal(username: username, goalName: goalName, tab: .commitment).url
  }
  public static func generateDeepLinkToGoalStop(username: String, goalName: String) -> URL {
    WebEndpoint.goal(username: username, goalName: goalName, tab: .stop).url
  }

  public static func generateDeepLinkToGoalData(username: String, goalName: String) -> URL {
    WebEndpoint.goal(username: username, goalName: goalName, tab: .data).url
  }

  public static func generateDeepLinkToGoalStatistics(username: String, goalName: String) -> URL {
    WebEndpoint.goal(username: username, goalName: goalName, tab: .statistics).url
  }
  public static func generateDeepLinkToGoalSettings(username: String, goalName: String) -> URL {
    WebEndpoint.goal(username: username, goalName: goalName, tab: .settings).url
  }
  public static func generateDeepLinkToUrl(accessToken: String, username: String, url: URL) -> URL {
    WebEndpoint.apiRedirect(username: username, accessToken: accessToken, redirectTo: url).url
  }
}
