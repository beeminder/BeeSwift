//
//  GoalTests.swift
//  BeeSwiftTests
//
//  Created by Theo Spears on 7/30/23.
//  Copyright © 2023 APB. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import BeeKit

final class GoalTests: XCTestCase {

    func testCreateGoalFromJSON() throws {
        // This is a partial copy of the beeminder api response, reduced to
        // only fields which are used by the app
        let testJSON = JSON(parseJSON: """
        {
          "slug": "test-goal",
          "title": "Goal for Testing Purposes",
          "graph_url": "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc.png",
          "thumb_url": "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc-thumb.png",
          "deadline": 0,
          "leadtime": 0,
          "alertstart": 34200,
          "use_defaults": true,
          "id": "737aaa34f0118a330852e4bd",
          "queued": false,
          "yaw": 1,
          "limsum": "100 in 200 days",
          "won": false,
          "delta_text": "✔ ✔ ✔",
          "safebump": 3828,
          "safesum": "safe for 200 days",
          "lasttouch": "2022-12-07T03:21:40.000Z",
          "safebuf": 3583,
          "todayta": false,
          "urgencykey": "FROx;PPRx;DL4102469999;P1000000000;test-goal",
          "hhmmformat": false,
          "yaxis": "cumulative total test-goal",
          "initday": 1668963600,
          "curval": 4000,
          "pledge": 0,
          "recent_data": [
            {
              "id": {
                "$oid": "888000000000000000000001"
              },
              "comment": "Auto-entered via Apple Health",
              "value": 10.5,
              "daystamp": "20221203"
            },
            {
              "id": {
                "$oid": "888000000000000000000002"
              },
              "comment": "Auto-entered via Apple Health",
              "value": 20.5,
              "daystamp": "20221130"
            },
            {
              "id": {
                "$oid": "888000000000000000000003"
              },
              "comment": "Auto-updated via Apple Health",
              "value": 30.5,
              "daystamp": "20221126"
            },
            {
              "id": {
                "$oid": "888000000000000000000004"
              },
              "comment": "Auto-updated via Apple Health",
              "value": 5.5,
              "daystamp": "20221125"
            },
            {
              "id": {
                "$oid": "888000000000000000000005"
              },
              "comment": "Auto-updated via Apple Health",
              "value": 1.5,
              "daystamp": "20221121"
            }
          ]
        }
        """)

        let goal = Goal(json: testJSON)

        XCTAssertEqual(goal.slug, "test-goal")
        XCTAssertEqual(goal.title, "Goal for Testing Purposes")
        XCTAssertEqual(goal.graph_url, "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc.png")
        XCTAssertEqual(goal.thumb_url, "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc-thumb.png")
        XCTAssertEqual(goal.deadline, 0)
        XCTAssertEqual(goal.leadtime, 0)
        XCTAssertEqual(goal.alertstart, 34200)
        XCTAssertEqual(goal.use_defaults, true)
        XCTAssertEqual(goal.id, "737aaa34f0118a330852e4bd")
        XCTAssertEqual(goal.queued, false)
        XCTAssertEqual(goal.yaw, 1)
        XCTAssertEqual(goal.limsum, "100 in 200 days")
        XCTAssertEqual(goal.won, false)
        XCTAssertEqual(goal.delta_text, "✔ ✔ ✔")
        XCTAssertEqual(goal.safebump, 3828)
        XCTAssertEqual(goal.safesum, "safe for 200 days")
        XCTAssertEqual(goal.lasttouch, 1670383300)
        XCTAssertEqual(goal.safebuf, 3583)
        XCTAssertEqual(goal.todayta, false)
        XCTAssertEqual(goal.urgencykey, "FROx;PPRx;DL4102469999;P1000000000;test-goal")
        XCTAssertEqual(goal.hhmmformat, false)
        XCTAssertEqual(goal.yaxis, "cumulative total test-goal")
        XCTAssertEqual(goal.initday, 1668963600)
        XCTAssertEqual(goal.curval, 4000)
        XCTAssertEqual(goal.pledge, 0)
        XCTAssertEqual(goal.recent_data!.count, 5)

    }

    func testSuggestedNextValueBasedOnLastValue() throws {
        var testJSON = requiredGoalJson()
        testJSON["recent_data"] = [
            ["value": 1, "daystamp": "20221130"],
            ["value": 2, "daystamp": "20221126"],
            ["value": 3.5, "daystamp": "20221125"],
        ]
        let goal = Goal(json: testJSON)

        XCTAssertEqual(goal.suggestedNextValue, 1)
    }

    func testSuggestedNextValueEmptyIfNoData() throws {
        var testJSON = requiredGoalJson()
        testJSON["recent_data"] = []
        let goal = Goal(json: testJSON)

        XCTAssertEqual(goal.suggestedNextValue, nil)
    }

    func testSuggestedNextValueIgnoresDerailsAndSelfDestructs() throws {
        var testJSON = requiredGoalJson()
        testJSON["recent_data"] = [
            ["value": 0, "daystamp": "20221131", "comment": "Goal #RESTART Point"],
            ["value": 0, "daystamp": "20221131", "comment": "This will #SELFDESTRUCT"],
            ["value": 0, "daystamp": "20221130", "comment": "#DERAIL ON THE 1st"],
            ["value": 2, "daystamp": "20221126"],
            ["value": 3.5, "daystamp": "20221125"],
        ]
        let goal = Goal(json: testJSON)

        XCTAssertEqual(goal.suggestedNextValue, 2)
    }

    /// Return the minimum set of required attributes for creating a goal
    func requiredGoalJson() -> JSON {
        return JSON(parseJSON: """
        {
            "id": "737aaa34f0118a330852e4bd",
            "title": "Goal for Testing Purposes",
            "slug": "test-goal",
            "initday": 1668963600,
            "deadline": 0,
            "leadtime": 0,
            "alertstart": 34200,
            "queued": false,
            "yaxis": "cumulative total test-goal",
            "won": false,
            "yaw": 1,
            "use_defaults": true,
            "pledge": 0,
            "hhmmformat": false,
            "todayta": false,
            "urgencykey": "FROx;PPRx;DL4102469999;P1000000000;test-goal"
        }
        """)

    }
}
