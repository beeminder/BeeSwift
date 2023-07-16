import XCTest
import KeychainSwift
@testable import BeeSwift

final class CurrentUserManagerTests: XCTestCase {

    override func setUpWithError() throws {
        let keychain = KeychainSwift(keyPrefix: "CurrentUserManager_")
        keychain.delete("access_token")
    }

    func testCanSetAndRetrieveAccessToken() throws {
        let currentUserManager = CurrentUserManager(requestManager: ServiceLocator.requestManager)
        currentUserManager.setAccessToken("test_access_token")
        XCTAssertEqual(currentUserManager.accessToken, "test_access_token")
    }

    func testCanMigrateAccessToken() throws {
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)!
        userDefaults.set("migrated_access_token", forKey: "access_token")

        let currentUserManager = CurrentUserManager(requestManager: ServiceLocator.requestManager)
        XCTAssertEqual(currentUserManager.accessToken, "migrated_access_token")
    }
}
