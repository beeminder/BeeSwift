// Part of BeeSwift. Copyright Beeminder

import CoreData
import SwiftyJSON
import UniformTypeIdentifiers
import XCTest

@testable import BeeKit
@testable import BeeSwift

final class GoalEntityTests: XCTestCase {
  var container: BeeminderPersistentContainer!
  var user: User!

  override func setUp() {
    super.setUp()
    container = BeeminderPersistentContainer.createMemoryBackedForTests()
    user = User(
      context: container.viewContext,
      username: "alice",
      deadbeat: false,
      timezone: "Etc/UTC",
      updatedAt: Date(timeIntervalSince1970: 0),
      defaultAlertStart: 0,
      defaultDeadline: 0,
      defaultLeadTime: 0,
    )
  }

  override func tearDown() {
    container = nil
    user = nil
    super.tearDown()
  }

  private func makeGoal(_ overrides: [String: Any] = [:]) -> Goal {
    var fields: [String: Any] = [
      "id": "737aaa34f0118a330852e4bd", "slug": "read-books", "title": "Read more books", "graph_url": "",
      "svg_url": "", "thumb_url": "", "deadline": 0, "leadtime": 0, "alertstart": 34200, "use_defaults": true,
      "queued": false, "limsum": "+2 within 1 day", "won": false, "safesum": "safe for 3 days",
      "lasttouch": "2022-12-07T03:21:40.000Z", "safebuf": 3, "todayta": true,
      "urgencykey": "FROx;PPRx;DL4102469999;P1000000000;read-books", "hhmmformat": false, "yaxis": "books",
      "initday": 1_668_963_600, "pledge": 5, "recent_data": [],
    ]
    for (key, value) in overrides { fields[key] = value }
    return Goal(context: container.viewContext, owner: user, json: JSON(fields))
  }

  func testEntityCarriesOwnerUsernameAndWebURL() {
    let entity = GoalEntity(from: makeGoal())
    XCTAssertEqual(entity.username, "alice")
    XCTAssertEqual(entity.webURL.absoluteString, "https://www.beeminder.com/alice/read-books")
  }

  func testPlainTextSummaryForManualGoal() {
    let entity = GoalEntity(from: makeGoal())
    XCTAssertEqual(
      entity.plainTextSummary,
      """
      Beeminder goal read-books: Read more books
      Status: Safe for 3 days
      Pledge: $5
      Data entered today: yes
      Data source: entered manually
      Recent datapoints: none
      Link: https://www.beeminder.com/alice/read-books
      """,
    )
  }

  func testPlainTextSummaryForBeemergencyAutodataGoal() {
    let goal = makeGoal(["safebuf": 0, "todayta": false, "autodata": "apple", "safesum": "+1 fruits due by 12am"])
    let summary = GoalEntity(from: goal).plainTextSummary
    XCTAssertTrue(summary.contains("Status: +1 fruits due by 12am"), summary)
    XCTAssertTrue(summary.contains("Data entered today: no"), summary)
    XCTAssertTrue(summary.contains("Data source: apple (automatic)"), summary)
  }

  func testPlainTextSummaryForCompletedGoal() {
    let summary = GoalEntity(from: makeGoal(["won": true])).plainTextSummary
    XCTAssertTrue(summary.contains("Status: completed."), summary)
  }

  func testPlainTextSummaryListsRecentDatapointsNewestFirst() {
    let goal = makeGoal([
      "recent_data": [
        ["id": "dp1", "daystamp": "20260822", "value": 1, "comment": "Dry bath", "updated_at": 100],
        ["id": "dp2", "daystamp": "20260914", "value": 2.5, "comment": "", "updated_at": 200],
        ["id": "dp3", "daystamp": "20260914", "value": 1, "comment": "", "updated_at": 300],
      ]
    ])
    let summary = GoalEntity(from: goal).plainTextSummary
    XCTAssertTrue(
      summary.contains(
        """
        Recent datapoints, newest first:
        - 2026-09-14: 1
        - 2026-09-14: 2.5
        - 2026-08-22: 1, comment: Dry bath
        """
      ),
      summary,
    )
  }

  func testPlainTextSummaryUsesHoursAndMinutesForHHMMGoals() {
    let goal = makeGoal([
      "hhmmformat": true, "recent_data": [["id": "dp1", "daystamp": "20260901", "value": 1.5, "comment": ""]],
    ])
    XCTAssertTrue(GoalEntity(from: goal).plainTextSummary.contains("- 2026-09-01: 1:30"))
  }

  private func dueBy(_ delta: String, _ total: String) -> [String: Any] {
    ["delta": 0, "total": 0, "formatted_delta_for_beedroid": delta, "formatted_total_for_beedroid": total]
  }

  func testPlainTextSummaryListsDueByDaysWhenSomethingIsOutstanding() {
    let goal = makeGoal([
      "dueby": [
        "20260923": dueBy("✔", "249"), "20260921": dueBy("+0.28572", "248.28572"),
        "20260922": dueBy("+0.57143", "248.57143"),
      ]
    ])
    let summary = GoalEntity(from: goal).plainTextSummary
    XCTAssertTrue(
      summary.contains(
        """
        Due by day:
        - 2026-09-21 (Mon): +0.28572, total 248.28572
        - 2026-09-22 (Tue): +0.57143, total 248.57143
        - 2026-09-23 (Wed): already covered
        Recent datapoints
        """
      ),
      summary,
    )
  }

  func testPlainTextSummaryOmitsDueByDaysWhenEveryDayIsCovered() {
    let goal = makeGoal(["dueby": ["20260921": dueBy("✔", "249"), "20260922": dueBy("✔", "249")]])
    let entity = GoalEntity(from: goal)
    XCTAssertEqual(entity.dueBy.count, 2)
    XCTAssertFalse(entity.plainTextSummary.contains("Due by day"), entity.plainTextSummary)
  }

  func testPlainTextSummaryCapsRecentDatapoints() {
    let data = (1...15).map {
      ["id": "dp\($0)", "daystamp": String(format: "202608%02d", $0), "value": $0, "comment": ""]
    }
    let entity = GoalEntity(from: makeGoal(["recent_data": data]))
    XCTAssertEqual(entity.recentDatapoints.count, GoalEntity.maxRecentDatapointsInSummary)
    XCTAssertEqual(entity.recentDatapoints.first?.date, "2026-08-15")
  }

  func testEntityCanSkipRecentDataForIndexing() {
    let goal = makeGoal(["recent_data": [["id": "dp1", "daystamp": "20260901", "value": 1, "comment": ""]]])
    XCTAssertFalse(GoalEntity(from: goal).recentDatapoints.isEmpty)
    XCTAssertTrue(GoalEntity(from: goal, includeRecentData: false).recentDatapoints.isEmpty)
  }

  func testEntityExportsPlainTextAndURL() async throws {
    let entity = GoalEntity(from: makeGoal())
    let text = try await entity.exported(as: .plainText)
    XCTAssertEqual(String(data: text, encoding: .utf8), entity.plainTextSummary)
    // Foundation exports a URL as a property list whose first element is the absolute string.
    let urlData = try await entity.exported(as: .url)
    let urlPlist = try PropertyListSerialization.propertyList(from: urlData, format: nil) as? [Any]
    XCTAssertEqual(urlPlist?.first as? String, "https://www.beeminder.com/alice/read-books")
  }
}
