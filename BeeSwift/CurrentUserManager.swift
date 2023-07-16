//
//  CurrentUserManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import KeychainSwift
import SwiftyJSON

class CurrentUserManager {
    static let signedInNotificationName     = "com.beeminder.signedInNotification"
    static let willSignOutNotificationName  = "com.beeminder.willSignOutNotification"
    static let failedSignInNotificationName = "com.beeminder.failedSignInNotification"
    static let signedOutNotificationName    = "com.beeminder.signedOutNotification"
    static let resetNotificationName        = "com.beeminder.resetNotification"
    static let willResetNotificationName    = "com.beeminder.willResetNotification"
    static let healthKitMetricRemovedNotificationName = "com.beeminder.healthKitMetricRemovedNotification"
    
    fileprivate let beemiosSecret = "C0QBFPWqDykIgE6RyQ2OJJDxGxGXuVA2CNqcJM185oOOl4EQTjmpiKgcwjki"
    
    internal static let accessTokenKey = "access_token"
    internal static let usernameKey = "username"
    internal static let deadbeatKey = "deadbeat"
    internal static let defaultLeadtimeKey = "default_leadtime"
    internal static let defaultAlertstartKey = "default_alertstart"
    internal static let defaultDeadlineKey = "default_deadline"
    internal static let beemTZKey = "timezone"

    internal static let keychainPrefix = "CurrentUserManager_"

    private let keychain = KeychainSwift(keyPrefix: CurrentUserManager.keychainPrefix)
    private let requestManager: RequestManager
    
    fileprivate static var allKeys: [String] {
        [accessTokenKey, usernameKey, deadbeatKey, defaultLeadtimeKey, defaultAlertstartKey, defaultDeadlineKey, beemTZKey]
    }
    
    let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)!
    
    init(requestManager: RequestManager) {
        self.requestManager = requestManager
        migrateValues()
    }
    
    /// Migrate settings values from the standard store to a group store
    ///
    /// Originally BeeSwift stored all configuration values in the standard UserDefaults store. However
    /// these values are not available within extensions. To address this now values are stored in a
    /// group-scoped settings object. Values written by old versions of the app may be in the previous store
    /// so we migrate any such values on initialization.
    private func migrateValues() {
        for key in CurrentUserManager.allKeys {
            let standardValue = UserDefaults.standard.object(forKey: key)
            let groupValue = userDefaults.object(forKey: key)
            
            if groupValue == nil && standardValue != nil {
                userDefaults.set(standardValue, forKey: key)
                // It would be neater to clean up, but for now we want to support
                // downgrading to prior versions, so leave old keys in place.
                // userDefaults.removeObject(forKey: key)
            }
        }

        // Ensure that the user's access token is stored in the keychain, and only in the
        // keychain. This will require the user to login again if they downgrade.
        let maybeKeychainAccessToken = keychain.get(CurrentUserManager.accessTokenKey)
        let maybeUserDefaultsAccessToken = userDefaults.object(forKey: CurrentUserManager.accessTokenKey) as? String
        if let userDefaultsAccessToken = maybeUserDefaultsAccessToken, maybeKeychainAccessToken == nil {
            setAccessToken(userDefaultsAccessToken)
        }
        userDefaults.removeObject(forKey: CurrentUserManager.accessTokenKey)
        UserDefaults.standard.removeObject(forKey: CurrentUserManager.accessTokenKey)
    }
    
    /// Write a value to the UserDefaults store
    ///
    /// During migration to the appGroup shared store we still want to support users downgrading
    /// to prior versions, and thus write all values to both stores.
    func set(_ value: Any, forKey key: String) {
        userDefaults.set(value, forKey: key)
        UserDefaults.standard.set(value, forKey: key)
    }
    
    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }

    
    var accessToken :String? {
        return keychain.get(CurrentUserManager.accessTokenKey)
    }
    
    var username :String? {
        return userDefaults.object(forKey: CurrentUserManager.usernameKey) as! String?
    }
    
    var signingUp : Bool = false
    
    func defaultLeadTime() -> NSNumber {
        return (userDefaults.object(forKey: CurrentUserManager.defaultLeadtimeKey) ?? 0) as! NSNumber
    }
    
    func setDefaultLeadTime(_ leadtime : NSNumber) {
        self.set(leadtime, forKey: CurrentUserManager.defaultLeadtimeKey)    }
    
    func defaultAlertstart() -> NSNumber {
        return (userDefaults.object(forKey: CurrentUserManager.defaultAlertstartKey) ?? 0) as! NSNumber
    }
    
    func setDefaultAlertstart(_ alertstart : NSNumber) {
        self.set(alertstart, forKey: CurrentUserManager.defaultAlertstartKey)
    }
    
    func defaultDeadline() -> NSNumber {
        return (userDefaults.object(forKey: CurrentUserManager.defaultDeadlineKey) ?? 0) as! NSNumber
    }
    
    func setDefaultDeadline(_ deadline : NSNumber) {
        self.set(deadline, forKey: CurrentUserManager.defaultDeadlineKey)
    }
    
    func signedIn() -> Bool {
        return self.accessToken != nil && self.username != nil
    }
    
    func isDeadbeat() -> Bool {
        return userDefaults.object(forKey: CurrentUserManager.deadbeatKey) != nil
    }
    
    func timezone() -> String {
        return userDefaults.object(forKey: CurrentUserManager.beemTZKey) as? String ?? "Unknown"
    }
    
    func setDeadbeat(_ deadbeat: Bool) {
        if deadbeat {
            self.set(true, forKey: CurrentUserManager.deadbeatKey)
        } else {
            self.removeObject(forKey: CurrentUserManager.deadbeatKey)
        }
    }
    
    func setAccessToken(_ accessToken: String) {
        keychain.set(accessToken, forKey: CurrentUserManager.accessTokenKey, withAccess: .accessibleAfterFirstUnlock)
    }
    
    func signInWithEmail(_ email: String, password: String) async {
        do {
           let response = try await requestManager.post(url: "api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret] as Dictionary<String, Any>)
            await self.handleSuccessfulSignin(JSON(response!))
        } catch {
            await self.handleFailedSignin(error, errorMessage: error.localizedDescription)
        }
    }
    
    func handleSuccessfulSignin(_ responseJSON: JSON) async {
        if responseJSON["deadbeat"].boolValue {
            self.setDeadbeat(true)
        }
        self.setAccessToken(responseJSON[CurrentUserManager.accessTokenKey].string!)
        self.set(responseJSON[CurrentUserManager.usernameKey].string!, forKey: CurrentUserManager.usernameKey)
        self.set(responseJSON[CurrentUserManager.defaultAlertstartKey].number!, forKey: CurrentUserManager.defaultAlertstartKey)
        self.set(responseJSON[CurrentUserManager.defaultDeadlineKey].number!, forKey: CurrentUserManager.defaultDeadlineKey)
        self.set(responseJSON[CurrentUserManager.defaultLeadtimeKey].number!, forKey: CurrentUserManager.defaultLeadtimeKey)
        self.set(responseJSON[CurrentUserManager.beemTZKey].string!, forKey: CurrentUserManager.beemTZKey)
        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: self)
        }.value
    }
    
    func syncNotificationDefaults() async throws {
        let response = try await requestManager.get(url: "api/v1/users/\(username!).json", parameters: [:])
        let responseJSON = JSON(response!)
        self.set(responseJSON["default_alertstart"].number!, forKey: "default_alertstart")
        self.set(responseJSON["default_deadline"].number!, forKey: "default_deadline")
        self.set(responseJSON["default_leadtime"].number!, forKey: "default_leadtime")

    }
    
    func handleFailedSignin(_ responseError: Error, errorMessage : String?) async {
        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: self, userInfo: ["error" : responseError])
        }.value
        await self.signOut()
    }
    
    func signOut() async {

        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: self)
        }.value

        keychain.delete(CurrentUserManager.accessTokenKey)
        self.removeObject(forKey: CurrentUserManager.deadbeatKey)
        self.removeObject(forKey: CurrentUserManager.usernameKey)

        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: self)
        }.value
    }
    
}
