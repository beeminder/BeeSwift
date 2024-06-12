import XCTest
import KeychainSwift
@testable import BeeKit

final class CurrentUserManagerTests: XCTestCase {

    override func setUpWithError() throws {
        let keychain = KeychainSwift(keyPrefix: CurrentUserManager.keychainPrefix)
        keychain.delete(CurrentUserManager.accessTokenKey)
    }

    func testCanSetAndRetrieveAccessToken() throws {
        let currentUserManager = CurrentUserManager(requestManager: ServiceLocator.requestManager, container: ServiceLocator.persistentContainer)
        currentUserManager.setAccessToken("test_access_token")
        XCTAssertEqual(currentUserManager.accessToken, "test_access_token")
    }
}
