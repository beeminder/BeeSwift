//
//  VersionManager.swift
//  BeeSwift
//
//  Created by Andrew Brett on 3/19/20.
//  Copyright © 2020 APB. All rights reserved.
//

import Foundation
import SwiftyJSON

enum VersionError: Error {
    case invalidAppStoreResponse, invalidBundleInfo, invalidServerResponse, noMinimumVersion
}

enum UpdateState {
    case UpToDate, UpdateSuggested, UpdateRequired
}

class VersionManager : NSObject {
    static let sharedManager = VersionManager()

    private var minRequiredVersion : String = "1.0"
    private var updateState = UpdateState.UpToDate

    func lastChckedUpdateState() -> UpdateState {
        return updateState
    }

    func updateState() async throws -> UpdateState {
        let currentVersion = VersionManager.sharedManager.currentVersion()

        async let appStoreVersion = VersionManager.sharedManager.appStoreVersion()
        async let updateRequired = VersionManager.sharedManager.checkIfUpdateRequired()

        if try await updateRequired {
            updateState = UpdateState.UpdateRequired
        } else if try await currentVersion < appStoreVersion {
            updateState = UpdateState.UpdateSuggested
        } else {
            updateState = UpdateState.UpToDate
        }

        return updateState
    }

    private func currentVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    private func checkIfUpdateRequired() async throws -> Bool {
        let responseJSON = try await withCheckedThrowingContinuation { continuation in
            RequestManager.get(url: "api/private/app_versions.json",
                               parameters: nil,
                               success: { responseJSON in continuation.resume(returning: responseJSON) },
                               errorHandler: { (responseError, responseMessage) in continuation.resume(throwing: responseError!) }
                               )
        }

        guard let response = JSON(responseJSON!).dictionary else {
            throw VersionError.invalidServerResponse
        }
        guard let minVersion = response["min_ios"]?.number?.decimalValue else {
            throw VersionError.noMinimumVersion
        }
        VersionManager.sharedManager.minRequiredVersion = "\(minVersion)"

        let currentVersion = VersionManager.sharedManager.currentVersion()
        return currentVersion.compare("\(minVersion)", options: .numeric) == .orderedAscending
    }
    
    private func appStoreVersion() async throws -> String {
        guard let info = Bundle.main.infoDictionary,
            let identifier = info["CFBundleIdentifier"] as? String,
            let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(identifier)") else {
                throw VersionError.invalidBundleInfo
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any]
        guard let result = (json?["results"] as? [Any])?.first as? [String: Any], let version = result["version"] as? String else {
            throw VersionError.invalidAppStoreResponse
        }

        return version
    }
}
