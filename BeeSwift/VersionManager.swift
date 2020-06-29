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
    case invalidResponse, invalidBundleInfo
}

class VersionManager : NSObject {
    static let sharedManager = VersionManager()
    var minRequiredVersion : String = "1.0"
    
    func currentVersion() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    
    func updateRequired() -> Bool {
        guard let version = VersionManager.sharedManager.currentVersion() else { return false }
        return version.compare(VersionManager.sharedManager.minRequiredVersion, options: .numeric) == .orderedAscending
    }
    
    func checkIfUpdateRequired(completion: @escaping (Bool, Error?) -> Void) {        
        RequestManager.get(url: "api/private/app_versions.json", parameters: nil, success: { (responseJSON) in
            guard let response = JSON(responseJSON!).dictionary else { return }
            if let minVersion = response["min_ios"]?.number?.decimalValue,
                let currentVersion = VersionManager.sharedManager.currentVersion() {
                VersionManager.sharedManager.minRequiredVersion = "\(minVersion)"
                completion(currentVersion.compare("\(minVersion)", options: .numeric) == .orderedAscending, nil)
            }
        }) { (responseError) in
            completion(false, responseError)
        }
    }
    
    func appStoreVersion(completion: @escaping (String?, Error?) -> Void) throws -> URLSessionDataTask {
        guard let info = Bundle.main.infoDictionary,
            let identifier = info["CFBundleIdentifier"] as? String,
            let url = URL(string: "http://itunes.apple.com/lookup?bundleId=\(identifier)") else {
                throw VersionError.invalidBundleInfo
        }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            do {
                if let error = error { throw error }
                guard let data = data else { throw VersionError.invalidResponse }
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any]
                guard let result = (json?["results"] as? [Any])?.first as? [String: Any], let version = result["version"] as? String else {
                    throw VersionError.invalidResponse
                }
                completion(version, nil)
            } catch {
                completion(nil, error)
            }
        }
        task.resume()
        return task
    }
}
