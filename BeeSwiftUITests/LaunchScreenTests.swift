//
//  BeeSwiftTests.swift
//  BeeSwiftTests
//
//

import UIKit
import XCTest

class LaunchScreenTests: XCTestCase {
    
    static var app: XCUIApplication?

    override func setUp() {
        super.setUp()
        let app = XCUIApplication()
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
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
//        self.measure() {
//            // Put the code you want to measure the time of here.
//        }
    }
    
}
