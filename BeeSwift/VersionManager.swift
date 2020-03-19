//
//  VersionManager.swift
//  BeeSwift
//
//  Created by Andrew Brett on 3/19/20.
//  Copyright © 2020 APB. All rights reserved.
//

import Foundation

enum VersionError: Error {
    case invalidResponse, invalidBundleInfo
}

class VersionManager : NSObject {
    static let sharedManager = VersionManager()
    
    func currentVersion() -> Decimal? {
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = true
        formatter.numberStyle = NumberFormatter.Style.decimal
        guard let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return nil }
        return formatter.number(from: v) as? Decimal
    }
    
    func updateRequired() -> Bool {
        guard let version = VersionManager.sharedManager.currentVersion() else { return false }
        return version < 5.0
    }
    
    func appStoreVersion(completion: @escaping (Decimal?, Error?) -> Void) throws -> URLSessionDataTask {
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
                let formatter = NumberFormatter()
                formatter.generatesDecimalNumbers = true
                formatter.numberStyle = NumberFormatter.Style.decimal
                if let decimalVersion = formatter.number(from: version) as? Decimal  {
                    completion(decimalVersion, nil)
                } else {
                    throw VersionError.invalidResponse
                }
            } catch {
                completion(nil, error)
            }
        }
        task.resume()
        return task
    }
}
