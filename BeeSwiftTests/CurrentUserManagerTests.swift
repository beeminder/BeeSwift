import XCTest
import KeychainSwift
@testable import BeeKit

final class CurrentUserManagerTests: XCTestCase {

    override func setUpWithError() throws {
        let keychain = KeychainSwift(keyPrefix: CurrentUserManager.keychainPrefix)
        keychain.delete(CurrentUserManager.accessTokenKey)
    }

    func testCanSetAndRetrieveAccessToken() throws {
        let currentUserManager = CurrentUserManager(requestManager: ServiceLocator.requestManager)
        currentUserManager.setAccessToken("test_access_token")
        XCTAssertEqual(currentUserManager.accessToken, "test_access_token")
    }

    func testCanMigrateAccessToken() throws {
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)!
        userDefaults.set("migrated_access_token", forKey: CurrentUserManager.accessTokenKey)

        let currentUserManager = CurrentUserManager(requestManager: ServiceLocator.requestManager)
        XCTAssertEqual(currentUserManager.accessToken, "migrated_access_token")

        // The value should also have been removed from UserDefaults
        XCTAssertNil(userDefaults.object(forKey: CurrentUserManager.accessTokenKey))
    }
}
