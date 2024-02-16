//
//  CurrentUserManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import CoreData
import Foundation
import KeychainSwift
import SwiftyJSON

public class CurrentUserManager {
    public static let signedInNotificationName     = "com.beeminder.signedInNotification"
    public static let willSignOutNotificationName  = "com.beeminder.willSignOutNotification"
    public static let failedSignInNotificationName = "com.beeminder.failedSignInNotification"
    public static let signedOutNotificationName    = "com.beeminder.signedOutNotification"
    public static let resetNotificationName        = "com.beeminder.resetNotification"
    public static let willResetNotificationName    = "com.beeminder.willResetNotification"
    public static let healthKitMetricRemovedNotificationName = "com.beeminder.healthKitMetricRemovedNotification"

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
    private let container: BeeminderPersistentContainer

    fileprivate static var allKeys: [String] {
        [accessTokenKey, usernameKey, deadbeatKey, defaultLeadtimeKey, defaultAlertstartKey, defaultDeadlineKey, beemTZKey]
    }
    
    let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)!
    
    init(requestManager: RequestManager, container: BeeminderPersistentContainer) {
        self.requestManager = requestManager
        self.container = container
        migrateValuesToGroupStore()
        migrateValuesToCoreData()
    }
    
    /// Migrate settings values from the standard store to a group store
    ///
    /// Originally BeeSwift stored all configuration values in the standard UserDefaults store. However
    /// these values are not available within extensions. To address this now values are stored in a
    /// group-scoped settings object. Values written by old versions of the app may be in the previous store
    /// so we migrate any such values on initialization.
    private func migrateValuesToGroupStore() {
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

    // If there is an existing session based on UserDefaults, create a new User object
    private func migrateValuesToCoreData() {
        // If there is already a session do nothing
        if user() != nil {
            return
        }

        // If we are logged out, do nothing
        if accessToken == nil || userDefaults.object(forKey: CurrentUserManager.usernameKey) == nil {
            return
        }

        let context = container.newBackgroundContext()

        // Create a new user
        let _ = User(context: context,
            username: userDefaults.object(forKey: CurrentUserManager.usernameKey) as! String,
            deadbeat: userDefaults.object(forKey: CurrentUserManager.deadbeatKey) != nil,
            timezone: userDefaults.object(forKey: CurrentUserManager.beemTZKey) as? String ?? "Unknown",
            defaultAlertStart: (userDefaults.object(forKey: CurrentUserManager.defaultAlertstartKey) ?? 0) as! Int32,
            defaultDeadline: (userDefaults.object(forKey: CurrentUserManager.defaultDeadlineKey) ?? 0) as! Int32,
            defaultLeadTime: (userDefaults.object(forKey: CurrentUserManager.defaultLeadtimeKey) ?? 0) as! Int32
       )
        try! context.save()
    }


    private func user(context: NSManagedObjectContext? = nil) -> User? {
        // Fetch a user from the persistent store
        let request = NSFetchRequest<User>(entityName: "User")
        // TODO: Handle (or at least log) an error here
        let users = try? (context ?? container.viewContext).fetch(request)
        return users?.first
    }

    private func modifyUser(_ callback: (User)->()) throws {
        let context = container.newBackgroundContext()
        guard let user = self.user(context: context) else { return }
        callback(user)
        try context.save()
    }

    private func deleteUser() throws {
        let context = container.newBackgroundContext()

        // Delete any existing users. We expect at most one, but delete all to be safe.
        while let user = self.user(context: context) {
            context.delete(user)
        }
        try context.save()
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

    
    public var accessToken :String? {
        return keychain.get(CurrentUserManager.accessTokenKey)
    }
    
    public var username :String? {
        return user()?.username
    }
    
    public var signingUp : Bool = false
    
    public func defaultLeadTime() -> NSNumber {
        return (user()?.defaultLeadTime ?? 0) as NSNumber
    }
    
    public func setDefaultLeadTime(_ leadtime : NSNumber) {
        try! modifyUser { $0.defaultLeadTime = leadtime as! Int32 }
        self.set(leadtime, forKey: CurrentUserManager.defaultLeadtimeKey)
    }

    public func defaultAlertstart() -> NSNumber {
        return (user()?.defaultAlertStart ?? 0) as NSNumber
    }
    
    public func setDefaultAlertstart(_ alertstart : NSNumber) {
        try! modifyUser { $0.defaultAlertStart = alertstart as! Int32 }
        self.set(alertstart, forKey: CurrentUserManager.defaultAlertstartKey)
    }
    
    public func defaultDeadline() -> NSNumber {
        return (user()?.defaultDeadline ?? 0) as NSNumber
    }
    
    public func setDefaultDeadline(_ deadline : NSNumber) {
        try! modifyUser { $0.defaultDeadline = deadline as! Int32 }
        self.set(deadline, forKey: CurrentUserManager.defaultDeadlineKey)
    }
    
    public func signedIn() -> Bool {
        return self.accessToken != nil && self.username != nil
    }
    
    public func isDeadbeat() -> Bool {
        return user()?.deadbeat ?? false
    }
    
    public func timezone() -> String {
        return user()?.timezone ?? "Unknown"
    }
    
    public func setDeadbeat(_ deadbeat: Bool) {
        try! modifyUser { $0.deadbeat = deadbeat }
        if deadbeat {
            self.set(true, forKey: CurrentUserManager.deadbeatKey)
        } else {
            self.removeObject(forKey: CurrentUserManager.deadbeatKey)
        }
    }
    
    func setAccessToken(_ accessToken: String) {
        keychain.set(accessToken, forKey: CurrentUserManager.accessTokenKey, withAccess: .accessibleAfterFirstUnlock)
    }
    
    public func signInWithEmail(_ email: String, password: String) async {
        do {
            let response = try await requestManager.post(url: "api/private/sign_in", parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret] as Dictionary<String, Any>)
            try! await self.handleSuccessfulSignin(JSON(response!))
        } catch {
            try! await self.handleFailedSignin(error, errorMessage: error.localizedDescription)
        }
    }
    
    func handleSuccessfulSignin(_ responseJSON: JSON) async throws {
        try deleteUser()

        let context = container.newBackgroundContext()

        let _ = User(context: context,
             username: responseJSON[CurrentUserManager.usernameKey].string!,
             deadbeat: responseJSON["deadbeat"].boolValue,
             timezone: responseJSON[CurrentUserManager.beemTZKey].string!,
             defaultAlertStart: responseJSON[CurrentUserManager.defaultAlertstartKey].int32!,
             defaultDeadline: responseJSON[CurrentUserManager.defaultDeadlineKey].int32!,
             defaultLeadTime: responseJSON[CurrentUserManager.defaultLeadtimeKey].int32!)
        try context.save()

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
    
    public func syncNotificationDefaults() async throws {
        let response = try await requestManager.get(url: "api/v1/users/\(username!).json", parameters: [:])
        let responseJSON = JSON(response!)

        try! modifyUser { user in
            user.defaultAlertStart = responseJSON["default_alertstart"].int32!
            user.defaultDeadline = responseJSON["default_deadline"].int32!
            user.defaultLeadTime = responseJSON["default_leadtime"].int32!
        }

        self.set(responseJSON["default_alertstart"].number!, forKey: "default_alertstart")
        self.set(responseJSON["default_deadline"].number!, forKey: "default_deadline")
        self.set(responseJSON["default_leadtime"].number!, forKey: "default_leadtime")
    }
    
    func handleFailedSignin(_ responseError: Error, errorMessage : String?) async throws {
        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.failedSignInNotificationName), object: self, userInfo: ["error" : responseError])
        }.value
        try await self.signOut()
    }
    
    public func signOut() async throws {
        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.willSignOutNotificationName), object: self)
        }.value

        try deleteUser()

        keychain.delete(CurrentUserManager.accessTokenKey)
        self.removeObject(forKey: CurrentUserManager.deadbeatKey)
        self.removeObject(forKey: CurrentUserManager.usernameKey)

        await Task { @MainActor in
            NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: self)
        }.value
    }
    
}
