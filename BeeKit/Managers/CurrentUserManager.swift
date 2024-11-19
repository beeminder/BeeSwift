//
//  CurrentUserManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import CoreData
import CoreDataEvolution
import Foundation
import KeychainSwift
import OSLog
import SwiftyJSON

@NSModelActor(disableGenerateInit: true)
public actor CurrentUserManager {
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "CurrentUserManager")

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

    fileprivate static var allKeys: [String] {
        [accessTokenKey, usernameKey, deadbeatKey, defaultLeadtimeKey, defaultAlertstartKey, defaultDeadlineKey, beemTZKey]
    }
    
    nonisolated let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)!

    init(requestManager: RequestManager, container: BeeminderPersistentContainer) {
        self.requestManager = requestManager
        modelContainer = container
        let context = container.newBackgroundContext()
        context.name = "CurrentUserManager"
        modelExecutor = .init(context: context)
        migrateValuesToCoreData()
    }

    // If there is an existing session based on UserDefaults, create a new User object
    private nonisolated func migrateValuesToCoreData() {
        let context = modelContainer.newBackgroundContext()

        // If there is already a session do nothing
        if user(context: context) != nil {
            return
        }

        // If we are logged out, do nothing
        if accessToken == nil || userDefaults.object(forKey: CurrentUserManager.usernameKey) == nil {
            return
        }


        // Create a new user
        let _ = User(context: context,
            username: userDefaults.object(forKey: CurrentUserManager.usernameKey) as! String,
            deadbeat: userDefaults.object(forKey: CurrentUserManager.deadbeatKey) != nil,
            timezone: userDefaults.object(forKey: CurrentUserManager.beemTZKey) as? String ?? "Unknown",
            defaultAlertStart: (userDefaults.object(forKey: CurrentUserManager.defaultAlertstartKey) ?? 0) as! Int,
            defaultDeadline: (userDefaults.object(forKey: CurrentUserManager.defaultDeadlineKey) ?? 0) as! Int,
            defaultLeadTime: (userDefaults.object(forKey: CurrentUserManager.defaultLeadtimeKey) ?? 0) as! Int
       )
        try! context.save()
    }


    public nonisolated func user(context: NSManagedObjectContext) -> User? {
        do {
            let request = NSFetchRequest<User>(entityName: "User")
            let users = try context.fetch(request)
            return users.first
        } catch {
            logger.error("Unable to fetch users \(error)")
            return nil
        }
    }

    private func modifyUser(_ callback: (User)->()) throws {
        guard let user = self.user(context: modelContext) else { return }
        modelContext.refresh(user, mergeChanges: false)
        callback(user)
        try modelContext.save()
    }

    private func deleteUser() throws {
        // Delete any existing users. We expect at most one, but delete all to be safe.
        modelContext.refreshAllObjects()
        while let user = self.user(context: modelContext) {
            modelContext.delete(user)
        }
        try modelContext.save()
    }

    /// Write a value to the UserDefaults store
    ///
    /// During migration to the appGroup shared store we still want to support users downgrading
    /// to prior versions, and thus write all values to both stores.
    func set(_ value: Any, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }

    public nonisolated var accessToken :String? {
        return keychain.get(CurrentUserManager.accessTokenKey)
    }
    
    public var username :String? {
        return user(context: modelContext)?.username
    }

    public nonisolated func signedIn(context: NSManagedObjectContext) -> Bool {
        return self.accessToken != nil && self.user(context: context)?.username != nil
    }
    
    public nonisolated func isDeadbeat(context: NSManagedObjectContext) -> Bool {
        return user(context: context)?.deadbeat ?? false
    }
    
    nonisolated func setAccessToken(_ accessToken: String) {
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

        let _ = User(context: modelContext, json: responseJSON)
        try modelContext.save()

        if responseJSON["deadbeat"].boolValue {
            self.set(true, forKey: CurrentUserManager.deadbeatKey)
        } else {
            self.removeObject(forKey: CurrentUserManager.deadbeatKey)
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
    
    public func refreshUser() async throws {
        let response = try await requestManager.get(url: "api/v1/users/\(username!).json", parameters: [:])
        let responseJSON = JSON(response!)

        try! modifyUser { user in
            user.updateToMatch(json: responseJSON)
        }

        self.set(responseJSON[CurrentUserManager.usernameKey].string!, forKey: CurrentUserManager.usernameKey)
        self.set(responseJSON[CurrentUserManager.defaultAlertstartKey].number!, forKey: CurrentUserManager.defaultAlertstartKey)
        self.set(responseJSON[CurrentUserManager.defaultDeadlineKey].number!, forKey: CurrentUserManager.defaultDeadlineKey)
        self.set(responseJSON[CurrentUserManager.defaultLeadtimeKey].number!, forKey: CurrentUserManager.defaultLeadtimeKey)
        self.set(responseJSON[CurrentUserManager.beemTZKey].string!, forKey: CurrentUserManager.beemTZKey)

        await Task { @MainActor in
            guard let user = self.user(context: modelContainer.viewContext) else { return }
            modelContainer.viewContext.refresh(user, mergeChanges: false)
        }.value
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

public enum CurrentUserManagerError : Error {
    case loggedOut
}
