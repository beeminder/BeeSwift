//
//  BeeSwiftTests.swift
//  BeeSwiftTests
//
//

import UIKit
import XCTest

class LaunchScreenTests: XCTestCase {
    
    static var app: XCUIApplication?
    var userDefaults: UserDefaults?
    let userDefaultsSuiteName = "TestDefaults"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: userDefaultsSuiteName)
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
        }
        let app = XCUIApplication()
        app.launchArguments += ["UI-Testing"]
        app.launch()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLaunchScreen() {
        let app = XCUIApplication()
        app.activate()
        XCTAssertTrue(app.buttons["I have a Beeminder account"].exists)
        app.buttons["I have a Beeminder account"].tap()
        XCTAssertTrue(app.buttons["Sign In"].exists)
        XCTAssertTrue(app.textFields["Email or username"].exists)
    }
}
