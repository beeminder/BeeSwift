//
//  DeeplinkGenerator.swift
//  BeeSwift
//
//  Created by krugerk on 2024-11-29.
//

struct DeeplinkGenerator {
  public static func generateDeepLinkToGoalCommitment(username: String, goalName: String) -> URL {
    URL(string: "https://www.beeminder.com/\(username)/\(goalName)#commitment")!
  }
  public static func generateDeepLinkToGoalStop(username: String, goalName: String) -> URL {
    URL(string: "https://www.beeminder.com/\(username)/\(goalName)#stop")!
  }

  public static func generateDeepLinkToGoalData(username: String, goalName: String) -> URL {
    URL(string: "https://www.beeminder.com/\(username)/\(goalName)#data")!
  }

  public static func generateDeepLinkToGoalStatistics(username: String, goalName: String) -> URL {
    URL(string: "https://www.beeminder.com/\(username)/\(goalName)#statistics")!
  }
  public static func generateDeepLinkToGoalSettings(username: String, goalName: String) -> URL {
    URL(string: "https://www.beeminder.com/\(username)/\(goalName)#settings")!
  }
  public static func generateDeepLinkToUrl(accessToken: String, username: String, url: URL) -> URL {
    let baseUrlString = "https://www.beeminder.com/api/v1/users/\(username).json"
    var components = URLComponents(string: baseUrlString)!
    components.queryItems = [
      URLQueryItem(name: "access_token", value: accessToken),
      URLQueryItem(name: "redirect_to_url", value: url.absoluteString),
    ]
    return components.url!
  }
}
