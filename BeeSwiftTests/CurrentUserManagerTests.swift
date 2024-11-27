import Testing
import KeychainSwift
@testable import BeeKit

final class CurrentUserManagerTests {

    init() throws {
        let keychain = KeychainSwift(keyPrefix: CurrentUserManager.keychainPrefix)
        keychain.delete(CurrentUserManager.accessTokenKey)
    }

    @Test func testCanSetAndRetrieveAccessToken() async throws {
        let currentUserManager = CurrentUserManager(requestManager: ServiceLocator.requestManager, container: ServiceLocator.persistentContainer)
        currentUserManager.setAccessToken("test_access_token")
        #expect(currentUserManager.accessToken == "test_access_token")
    }
}
