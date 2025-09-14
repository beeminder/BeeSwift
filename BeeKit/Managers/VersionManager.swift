//
//  VersionManager.swift
//  BeeSwift
//
//  Created by Andrew Brett on 3/19/20.
//  Copyright 2020 APB. All rights reserved.
//

import Foundation
import SwiftyJSON

public enum VersionError: Error {
  case invalidAppStoreResponse, invalidBundleInfo, invalidServerResponse, noMinimumVersion
}

public enum UpdateState { case UpToDate, UpdateSuggested, UpdateRequired }

// We release new versions of the app incrementally over the course of 7 days. We allow slightly more
// time than this to pass before suggesting users upgrade to avoid excess nagging.
private let dayInSeconds = 24.0 * 60.0 * 60.0
private let ageOfReleaseToWarn: TimeInterval = 10.0 * dayInSeconds

public class VersionManager {
  private var minRequiredVersion: String = "1.0"
  private var updateState = UpdateState.UpToDate
  private let requestManager: RequestManager

  init(requestManager: RequestManager) { self.requestManager = requestManager }

  public func lastChckedUpdateState() -> UpdateState { return updateState }

  public func updateState() async throws -> UpdateState {
    let currentVersion = currentVersion()
    let now = Date()

    async let (version:appStoreVersion, releaseDate:appStoreReleaseDate) = appStoreVersion()
    async let updateRequired = checkIfUpdateRequired()

    if try await updateRequired {
      updateState = UpdateState.UpdateRequired
      return updateState
    }

    let newerVersionAvailable = try await currentVersion < appStoreVersion
    let currentVersionHasFullyRolledOut = try await (appStoreReleaseDate + ageOfReleaseToWarn) < now
    if newerVersionAvailable && currentVersionHasFullyRolledOut {
      updateState = UpdateState.UpdateSuggested
      return updateState
    }

    updateState = UpdateState.UpToDate
    return updateState
  }

  private func currentVersion() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
  }
  private func checkIfUpdateRequired() async throws -> Bool {
    let responseJSON = try await requestManager.get(url: "api/private/app_versions.json")

    guard let response = JSON(responseJSON!).dictionary else { throw VersionError.invalidServerResponse }
    guard let minVersion = response["min_ios"]?.number?.decimalValue else { throw VersionError.noMinimumVersion }
    minRequiredVersion = "\(minVersion)"

    let currentVersion = currentVersion()
    return currentVersion.compare("\(minVersion)", options: .numeric) == .orderedAscending
  }
  private func appStoreVersion() async throws -> (version: String, releaseDate: Date) {
    guard let info = Bundle.main.infoDictionary, let identifier = info["CFBundleIdentifier"] as? String,
      let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(identifier)")
    else { throw VersionError.invalidBundleInfo }

    let dateFormatter = ISO8601DateFormatter()

    let (data, _) = try await URLSession.shared.data(from: url)

    let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any]
    guard let result = (json?["results"] as? [Any])?.first as? [String: Any],
      let version = result["version"] as? String,
      let currentVersionReleaseDateString = result["currentVersionReleaseDate"] as? String,
      let currentVersionReleaseDate = dateFormatter.date(from: currentVersionReleaseDateString)
    else { throw VersionError.invalidAppStoreResponse }

    return (version: version, releaseDate: currentVersionReleaseDate)
  }
}
