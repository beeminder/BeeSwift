//
//  GoalTests.swift
//  BeeSwiftTests
//
//  Created by Theo Spears on 7/30/23.
//  Copyright © 2023 APB. All rights reserved.
//

import CoreData
import Testing
import SwiftyJSON
@testable import BeeKit

final class GoalTests {
    var container: BeeminderPersistentContainer!
    var user: User!
    
    init() {
        container = BeeminderPersistentContainer.createMemoryBackedForTests()
        user = createTestUser(context: container.viewContext)
    }

    @Test func testCreateGoalFromJSON() throws {
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
          "limsum": "100 in 200 days",
          "won": false,
          "safesum": "safe for 200 days",
          "lasttouch": "2022-12-07T03:21:40.000Z",
          "safebuf": 3583,
          "todayta": false,
          "urgencykey": "FROx;PPRx;DL4102469999;P1000000000;test-goal",
          "hhmmformat": false,
          "yaxis": "cumulative total test-goal",
          "initday": 1668963600,
          "pledge": 0,
          "recent_data": [
            {
              "id": "888000000000000000000001",
              "comment": "Auto-entered via Apple Health",
              "value": 10.5,
              "daystamp": "20221203"
            },
            {
              "id": "888000000000000000000002",
              "comment": "Auto-entered via Apple Health",
              "value": 20.5,
              "daystamp": "20221130"
            },
            {
              "id": "888000000000000000000003",
              "comment": "Auto-updated via Apple Health",
              "value": 30.5,
              "daystamp": "20221126"
            },
            {
              "id": "888000000000000000000004",
              "comment": "Auto-updated via Apple Health",
              "value": 5.5,
              "daystamp": "20221125"
            },
            {
              "id": "888000000000000000000005",
              "comment": "Auto-updated via Apple Health",
              "value": 1.5,
              "daystamp": "20221121"
            }
          ]
        }
        """)

        let goal = Goal(context: container.viewContext, owner: user, json: testJSON)

        #expect(goal.slug == "test-goal")
        #expect(goal.title == "Goal for Testing Purposes")
        #expect(goal.graphUrl == "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc.png")
        #expect(goal.thumbUrl == "https://cdn.beeminder.com/uploads/879fb101-0111-4f06-a704-1e5e316c5afc-thumb.png")
        #expect(goal.deadline == 0)
        #expect(goal.leadTime == 0)
        #expect(goal.alertStart == 34200)
        #expect(goal.useDefaults == true)
        #expect(goal.id == "737aaa34f0118a330852e4bd")
        #expect(goal.queued == false)
        #expect(goal.limSum == "100 in 200 days")
        #expect(goal.won == false)
        #expect(goal.safeSum == "safe for 200 days")
        #expect(goal.lastTouch == "2022-12-07T03:21:40.000Z")
        #expect(goal.safeBuf == 3583)
        #expect(goal.todayta == false)
        #expect(goal.urgencyKey == "FROx;PPRx;DL4102469999;P1000000000;test-goal")
        #expect(goal.hhmmFormat == false)
        #expect(goal.yAxis == "cumulative total test-goal")
        #expect(goal.initDay == 1668963600)
        #expect(goal.pledge == 0)
        #expect(goal.recentData.count == 5)

    }

    @Test func testSuggestedNextValueBasedOnLastValue() throws {
        var testJSON = requiredGoalJson
        testJSON["recent_data"] = [
            ["id": "101", "value": 1, "daystamp": "20221130", "updated_at": 300],
            ["id": "102", "value": 2, "daystamp": "20221126", "updated_at": 200],
            ["id": "103", "value": 3.5, "daystamp": "20221125", "updated_at": 100],
        ]

        let goal = Goal(context: container.viewContext, owner: user, json: testJSON)

        #expect(goal.suggestedNextValue == 1)
    }

    @Test func testSuggestedNextValueEmptyIfNoData() throws {
        var testJSON = requiredGoalJson
        testJSON["recent_data"] = []

        let goal = Goal(context: container.viewContext, owner: user, json: testJSON)

        #expect(goal.suggestedNextValue == nil)
    }

    @Test func testSuggestedNextValueIgnoresDerailsAndSelfDestructs() throws {
        var testJSON = requiredGoalJson
        testJSON["recent_data"] = [
            ["id": "101", "value": 0, "daystamp": "20221131", "updated_at": 600, "comment": "Goal #RESTART Point"],
            ["id": "102", "value": 0, "daystamp": "20221131", "updated_at": 500, "comment": "This will #SELFDESTRUCT"],
            ["id": "103", "value": 0, "daystamp": "20221131", "updated_at": 400, "comment": "PESSIMISTIC PRESUMPTION #THISWILLSELFDESTRUCT"],
            ["id": "104", "value": 0, "daystamp": "20221130", "updated_at": 300, "comment": "#DERAIL ON THE 1st"],
            ["id": "105", "value": 2, "daystamp": "20221126", "updated_at": 200],
            ["id": "106", "value": 3.5, "daystamp": "20221125", "updated_at": 100],
        ]

        let goal = Goal(context: container.viewContext, owner: user, json: testJSON)

        #expect(goal.suggestedNextValue == 2)
    }

    func createTestUser(context: NSManagedObjectContext) -> User {
        context.performAndWait {
            return User(context: context, username: "test-user", deadbeat: false, timezone: "Etc/UTC", defaultAlertStart: 0, defaultDeadline: 0, defaultLeadTime: 0)
        }
    }


    /// Return the minimum set of required attributes for creating a goal
    var requiredGoalJson = JSON(parseJSON: """
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
            "safebuf": 1,
            "use_defaults": true,
            "pledge": 0,
            "hhmmformat": false,
            "todayta": false,
            "urgencykey": "FROx;PPRx;DL4102469999;P1000000000;test-goal"
        }
        """)

}
