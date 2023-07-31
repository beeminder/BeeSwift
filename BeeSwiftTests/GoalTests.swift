//
//  GoalTests.swift
//  BeeSwiftTests
//
//  Created by Theo Spears on 7/30/23.
//  Copyright © 2023 APB. All rights reserved.
//

import XCTest
import SwiftyJSON
@testable import BeeSwift

final class GoalTests: XCTestCase {

    func testCreateGoalFromJSON() throws {
        // This is a partial copy of the beeminder api response, reduced to
        // only fields which are used by the app
        let testJSON = JSON(parseJSON: """
        {
          "slug": "test-goal",
          "title": "Goal for Testing Purposes",
          "rate": 1,
          "graph_url": "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc.png",
          "thumb_url": "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc-thumb.png",
          "losedate": 2000271599,
          "deadline": 0,
          "leadtime": 0,
          "alertstart": 34200,
          "use_defaults": true,
          "id": "737aaa34f0118a330852e4bd",
          "queued": false,
          "yaw": 1,
          "lane": 3582,
          "runits": "d",
          "limsum": "100 in 200 days",
          "won": false,
          "delta_text": "✔ ✔ ✔",
          "safebump": 3828,
          "safesum": "safe for 200 days",
          "lasttouch": "2022-12-07T03:21:40.000Z",
          "safebuf": 3583,
          "todayta": false,
          "hhmmformat": false,
          "yaxis": "cumulative total test-goal",
          "initday": 1668963600,
          "curval": 4000,
          "dir": 1,
          "pledge": 0,
          "mathishard": [
            2000217600,
            3828,
            1
          ],
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
        XCTAssertEqual(goal.rate, 1)
        XCTAssertEqual(goal.graph_url, "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc.png")
        XCTAssertEqual(goal.thumb_url, "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc-thumb.png")
        XCTAssertEqual(goal.losedate, 2000271599)
        XCTAssertEqual(goal.deadline, 0)
        XCTAssertEqual(goal.leadtime, 0)
        XCTAssertEqual(goal.alertstart, 34200)
        XCTAssertEqual(goal.use_defaults, true)
        XCTAssertEqual(goal.id, "737aaa34f0118a330852e4bd")
        XCTAssertEqual(goal.queued, false)
        XCTAssertEqual(goal.yaw, 1)
        XCTAssertEqual(goal.lane, 3582)
        XCTAssertEqual(goal.runits, "d")
        XCTAssertEqual(goal.limsum, "100 in 200 days")
        XCTAssertEqual(goal.won, false)
        XCTAssertEqual(goal.delta_text, "✔ ✔ ✔")
        XCTAssertEqual(goal.safebump, 3828)
        XCTAssertEqual(goal.safesum, "safe for 200 days")
        XCTAssertEqual(goal.lasttouch, 1670383300)
        XCTAssertEqual(goal.safebuf, 3583)
        XCTAssertEqual(goal.todayta, false)
        XCTAssertEqual(goal.hhmmformat, false)
        XCTAssertEqual(goal.yaxis, "cumulative total test-goal")
        XCTAssertEqual(goal.initday, 1668963600)
        XCTAssertEqual(goal.curval, 4000)
        XCTAssertEqual(goal.dir, 1)
        XCTAssertEqual(goal.pledge, 0)
        XCTAssertEqual(goal.derived_goaldate, 2000217600)
        XCTAssertEqual(goal.derived_goalval, 3828)
        XCTAssertEqual(goal.derived_rate, 1)
        XCTAssertEqual(goal.recent_data!.count, 5)

    }

    func testCanCreateGoalWithoutMathIsHard() throws {
        let testJSON = JSON(parseJSON: """
        {
          "slug": "test-goal",
          "title": "Goal for Testing Purposes",
          "rate": 1,
          "graph_url": "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc.png",
          "thumb_url": "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc-thumb.png",
          "losedate": 2000271599,
          "deadline": 0,
          "leadtime": 0,
          "alertstart": 34200,
          "use_defaults": true,
          "id": "737aaa34f0118a330852e4bd",
          "queued": false,
          "yaw": 1,
          "lane": 3582,
          "runits": "d",
          "limsum": "100 in 200 days",
          "won": false,
          "delta_text": "✔ ✔ ✔",
          "safebump": 3828,
          "safesum": "safe for 200 days",
          "lasttouch": "2022-12-07T03:21:40.000Z",
          "safebuf": 3583,
          "todayta": false,
          "hhmmformat": false,
          "yaxis": "cumulative total test-goal",
          "initday": 1668963600,
          "curval": 4000,
          "dir": 1,
          "pledge": 0,
          "recent_data": []
        }
        """)

        let goal = Goal(json: testJSON)

        XCTAssertEqual(goal.derived_goaldate, 0)
        XCTAssertEqual(goal.derived_goalval, 0)
        XCTAssertEqual(goal.derived_rate, 0)
    }

}
