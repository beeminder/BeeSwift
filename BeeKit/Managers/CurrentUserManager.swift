//
//  CurrentUserManager.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/26/15.
//  Copyright 2015 APB. All rights reserved.
//

import CoreData
import CoreDataEvolution
import Foundation
import KeychainSwift
import OSLog
import SwiftyJSON

@NSModelActor(disableGenerateInit: true) public actor CurrentUserManager {
  let logger = Logger(subsystem: "com.beeminder.beeminder", category: "CurrentUserManager")

  public enum NotificationName {
    public static let signedIn = NSNotification.Name(rawValue: "com.beeminder.signedInNotification")
    public static let willSignOut = NSNotification.Name(rawValue: "com.beeminder.willSignOutNotification")
    public static let failedSignIn = NSNotification.Name(rawValue: "com.beeminder.failedSignInNotification")
    public static let signedOut = NSNotification.Name(rawValue: "com.beeminder.signedOutNotification")
    public static let healthKitMetricRemoved = NSNotification.Name(
      rawValue: "com.beeminder.healthKitMetricRemovedNotification"
    )
  }
  fileprivate let beemiosSecret = "C0QBFPWqDykIgE6RyQ2OJJDxGxGXuVA2CNqcJM185oOOl4EQTjmpiKgcwjki"
  internal static let accessTokenKey = "access_token"
  internal static let usernameKey = "username"
  internal static let deadbeatKey = "deadbeat"
  internal static let defaultLeadtimeKey = "default_leadtime"
  internal static let defaultAlertstartKey = "default_alertstart"
  internal static let defaultDeadlineKey = "default_deadline"
  internal static let beemTZKey = "timezone"

  internal static let keychainPrefix = "CurrentUserManager_"

  private let requestManager: RequestManager

  fileprivate static var allKeys: [String] {
    [accessTokenKey, usernameKey, deadbeatKey, defaultLeadtimeKey, defaultAlertstartKey, defaultDeadlineKey, beemTZKey]
  }

  init(requestManager: RequestManager, container: BeeminderPersistentContainer) {
    self.requestManager = requestManager
    self.modelContainer = container
    let context = container.newBackgroundContext()
    context.name = "CurrentUserManager"
    self.modelExecutor = .init(context: context)

    migrateValuesToCoreData()
    cleanUpUserDefaults()
  }

  // If there is an existing session based on UserDefaults, create a new User object
  private nonisolated func migrateValuesToCoreData() {
    let context = modelContainer.newBackgroundContext()
    let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)!

    // If there is already a session do nothing
    if user(context: context) != nil { return }

    // If we are logged out, do nothing
    if accessToken == nil || userDefaults.object(forKey: CurrentUserManager.usernameKey) == nil { return }

    // Create a new user
    let _ = User(
      context: context,
      username: userDefaults.object(forKey: CurrentUserManager.usernameKey) as! String,
      deadbeat: userDefaults.object(forKey: CurrentUserManager.deadbeatKey) != nil,
      timezone: userDefaults.object(forKey: CurrentUserManager.beemTZKey) as? String ?? "Unknown",
      updatedAt: Date(timeIntervalSince1970: 0),
      defaultAlertStart: (userDefaults.object(forKey: CurrentUserManager.defaultAlertstartKey) ?? 0) as! Int,
      defaultDeadline: (userDefaults.object(forKey: CurrentUserManager.defaultDeadlineKey) ?? 0) as! Int,
      defaultLeadTime: (userDefaults.object(forKey: CurrentUserManager.defaultLeadtimeKey) ?? 0) as! Int
    )
    try! context.save()
  }

  private nonisolated func cleanUpUserDefaults() {
    let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)!
    for key in CurrentUserManager.allKeys { userDefaults.removeObject(forKey: key) }
  }

  // MARK: - User Management

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

  public var username: String? { return user(context: modelContext)?.username }

  private func deleteUser() throws {
    // Delete any existing users. We expect at most one, but delete all to be safe.
    modelContext.refreshAllObjects()
    while let user = self.user(context: modelContext) { modelContext.delete(user) }
    try modelContext.save()
  }

  // MARK: - Keychain Management

  nonisolated func setAccessToken(_ accessToken: String) {
    let keychain = KeychainSwift(keyPrefix: CurrentUserManager.keychainPrefix)
    keychain.set(accessToken, forKey: CurrentUserManager.accessTokenKey, withAccess: .accessibleAfterFirstUnlock)
  }
  public nonisolated var accessToken: String? {
    let keychain = KeychainSwift(keyPrefix: CurrentUserManager.keychainPrefix)
    return keychain.get(CurrentUserManager.accessTokenKey)
  }

  // MARK: - Authentication

  public nonisolated func signedIn(context: NSManagedObjectContext) -> Bool {
    return self.accessToken != nil && self.user(context: context)?.username != nil
  }
  public func signInWithEmail(_ email: String, password: String) async {
    do {
      let response = try await requestManager.post(
        url: "api/private/sign_in",
        parameters: ["user": ["login": email, "password": password], "beemios_secret": self.beemiosSecret]
          as [String: Any]
      )
      try! await self.handleSuccessfulSignin(JSON(response!))
    } catch { try! await self.handleFailedSignin(error, errorMessage: error.localizedDescription) }
  }
  func handleSuccessfulSignin(_ responseJSON: JSON) async throws {
    try deleteUser()

    let _ = User(context: modelContext, json: responseJSON)
    try modelContext.save()

    self.setAccessToken(responseJSON[CurrentUserManager.accessTokenKey].string!)
    await Task { @MainActor in
      NotificationCenter.default.post(name: CurrentUserManager.NotificationName.signedIn, object: self)
    }.value
  }
  func handleFailedSignin(_ responseError: Error, errorMessage: String?) async throws {
    await Task { @MainActor in
      NotificationCenter.default.post(
        name: CurrentUserManager.NotificationName.failedSignIn,
        object: self,
        userInfo: ["error": responseError]
      )
    }.value
    try await self.signOut()
  }
  public func signOut() async throws {
    await Task { @MainActor in
      NotificationCenter.default.post(name: CurrentUserManager.NotificationName.willSignOut, object: self)
    }.value

    try deleteUser()

    let keychain = KeychainSwift(keyPrefix: CurrentUserManager.keychainPrefix)
    keychain.delete(CurrentUserManager.accessTokenKey)

    await Task { @MainActor in
      NotificationCenter.default.post(name: CurrentUserManager.NotificationName.signedOut, object: self)
    }.value
  }
}
