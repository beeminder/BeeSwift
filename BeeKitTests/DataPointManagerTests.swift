import CoreData
import SwiftyJSON
import XCTest

@testable import BeeKit

class MockHealthKitDataPoint: BeeDataPoint {
  let daystamp: Daystamp
  let value: NSNumber
  let comment: String
  let requestid: String
  init(daystamp: Daystamp, value: NSNumber, comment: String = "", requestid: String = "") {
    self.daystamp = daystamp
    self.value = value
    self.comment = comment
    self.requestid = requestid
  }
}

class MockAPIClientForDataPoint: APIClient {
  private let queue = DispatchQueue(label: "com.beeminder.MockAPIClientForDataPoint")
  private var _responses: [String: Any] = [:]
  private var _putCalls: [(url: String, parameters: [String: Any])] = []
  private var _deleteCalls: [String] = []
  private var _addDatapointCalls: [(urtext: String, slug: String, requestId: String)] = []

  init() { super.init(requestManager: RequestManager()) }

  var responses: [String: Any] {
    get { queue.sync { _responses } }
    set { queue.sync { _responses = newValue } }
  }
  var putCalls: [(url: String, parameters: [String: Any])] { queue.sync { _putCalls } }
  var deleteCalls: [String] { queue.sync { _deleteCalls } }
  var addDatapointCalls: [(urtext: String, slug: String, requestId: String)] { queue.sync { _addDatapointCalls } }

  override func fetchDatapoints(goalSlug: String, sort: String, per: Int, page: Int) async throws -> Any? {
    let url = "api/v1/users/{username}/goals/\(goalSlug)/datapoints.json"
    let response = queue.sync { () -> Any? in
      if let response = _responses[url] {
        _responses.removeValue(forKey: url)
        return response
      }
      return nil
    }
    return response ?? []
  }
  override func updateDatapoint(
    goalSlug: String,
    datapointID: String,
    value: String? = nil,
    comment: String? = nil,
    urtext: String? = nil,
  ) async throws -> Any? {
    var parameters: [String: Any] = [:]
    if let value { parameters["value"] = value }
    if let comment { parameters["comment"] = comment }
    if let urtext { parameters["urtext"] = urtext }
    let url = "api/v1/users/{username}/goals/\(goalSlug)/datapoints/\(datapointID).json"
    queue.sync { _putCalls.append((url: url, parameters: parameters)) }
    return [:]
  }
  override func deleteDatapoint(goalSlug: String, datapointID: String) async throws -> Any? {
    let url = "api/v1/users/{username}/goals/\(goalSlug)/datapoints/\(datapointID).json"
    queue.sync { _deleteCalls.append(url) }
    return [:]
  }
  override func createDatapoint(goalSlug: String, urtext: String, requestID: String? = nil) async throws -> Any? {
    queue.sync { _addDatapointCalls.append((urtext: urtext, slug: goalSlug, requestId: requestID ?? "")) }
    return [:]
  }
}

class DataPointManagerTests: XCTestCase {
  var container: BeeminderPersistentContainer!
  var mockAPIClient: MockAPIClientForDataPoint!
  var dataPointManager: DataPointManager!
  var goal: Goal!
  var user: User!
  override func setUpWithError() throws {
    container = BeeminderPersistentContainer.createMemoryBackedForTests()
    mockAPIClient = MockAPIClientForDataPoint()
    dataPointManager = DataPointManager(apiClient: mockAPIClient, container: container)
    let context = container.viewContext
    user = User(
      context: context,
      username: "test_user",
      deadbeat: false,
      timezone: "America/Los_Angeles",
      updatedAt: Date(timeIntervalSince1970: 1_740_350_182),
      defaultAlertStart: 34200,
      defaultDeadline: 0,
      defaultLeadTime: 0,
    )
    goal = Goal(context: context, owner: user, json: createTestGoalJSON())
    try context.save()
  }
  override func tearDownWithError() throws {
    container = nil
    mockAPIClient = nil
    dataPointManager = nil
    goal = nil
    user = nil
  }

  func testSynchronizesPointsByRequestId() async throws {
    let apiResponse = [
      // Existing datapoint with requestId that should be updated
      [
        "id": "existing1", "value": 10, "daystamp": "20221201", "comment": "Old comment", "updated_at": 1000,
        "is_dummy": false, "is_initial": false, "requestid": "hk_workout_1",
      ],
      // Existing datapoint without matching requestId that should be deleted
      [
        "id": "obsolete1", "value": 20, "daystamp": "20221201", "comment": "Should be deleted", "updated_at": 1001,
        "is_dummy": false, "is_initial": false, "requestid": "hk_workout_old",
      ],
      // Metadata points which should be ignored
      [
        "id": "dummy2", "value": 20, "daystamp": "20221202", "comment": "Dummy datapoint", "updated_at": 2000,
        "is_dummy": true, "is_initial": false,
      ],
    ]
    mockAPIClient.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
    let updatedHealthKitDatapoint = MockHealthKitDataPoint(
      daystamp: try Daystamp(fromString: "20221201"),
      value: NSNumber(value: 15),
      comment: "Updated workout comment",
      requestid: "hk_workout_1",
    )
    let newHealthKitDatapoint = MockHealthKitDataPoint(
      daystamp: try Daystamp(fromString: "20221201"),
      value: NSNumber(value: 25),
      comment: "New workout",
      requestid: "hk_workout_2",
    )
    try! await dataPointManager.updateToMatchDataPoints(
      goalID: goal.objectID,
      healthKitDataPoints: [updatedHealthKitDatapoint, newHealthKitDatapoint],
    )

    // Should update the existing datapoint by requestId
    XCTAssertEqual(mockAPIClient.putCalls.count, 1)
    XCTAssertTrue(mockAPIClient.putCalls[0].url.contains("existing1"))
    XCTAssertEqual(mockAPIClient.putCalls[0].parameters["value"] as? String, "15")
    XCTAssertEqual(mockAPIClient.putCalls[0].parameters["comment"] as? String, "Updated workout comment")
    // Should delete the obsolete datapoint
    XCTAssertEqual(mockAPIClient.deleteCalls.count, 1)
    XCTAssertTrue(mockAPIClient.deleteCalls[0].contains("obsolete1"))
    // Should create a new datapoint
    XCTAssertEqual(mockAPIClient.addDatapointCalls.count, 1)
    XCTAssertEqual(mockAPIClient.addDatapointCalls[0].urtext, "1 25 \"New workout\"")
    XCTAssertEqual(mockAPIClient.addDatapointCalls[0].slug, "test-goal")
    XCTAssertEqual(mockAPIClient.addDatapointCalls[0].requestId, "hk_workout_2")
  }
  func testDeletesRemovedWorkouts() async throws {
    let apiResponse = [
      [
        "id": "workout1", "value": 30, "daystamp": "20221201", "comment": "Morning run", "updated_at": 1000,
        "is_dummy": false, "is_initial": false, "requestid": "hk_workout_uuid_1",
      ],
      [
        "id": "workout2", "value": 45, "daystamp": "20221201", "comment": "Evening bike", "updated_at": 1001,
        "is_dummy": false, "is_initial": false, "requestid": "hk_workout_uuid_2",
      ],
    ]
    mockAPIClient.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
    // Only one workout remains in HealthKit
    let remainingWorkout = MockHealthKitDataPoint(
      daystamp: try Daystamp(fromString: "20221201"),
      value: NSNumber(value: 30),
      comment: "Morning run",
      requestid: "hk_workout_uuid_1",
    )
    try! await dataPointManager.updateToMatchDataPoints(goalID: goal.objectID, healthKitDataPoints: [remainingWorkout])

    // Should not update the matching workout (same value/comment)
    XCTAssertEqual(mockAPIClient.putCalls.count, 0)
    // Should delete the removed workout
    XCTAssertEqual(mockAPIClient.deleteCalls.count, 1)
    XCTAssertTrue(mockAPIClient.deleteCalls[0].contains("workout2"))
    // Should not create any new datapoints
    XCTAssertEqual(mockAPIClient.addDatapointCalls.count, 0)
  }
  func testMultipleDaysWithMultipleWorkouts() async throws {
    let apiResponse = [
      [
        "id": "day1_workout1", "value": 30, "daystamp": "20221201", "comment": "Run", "updated_at": 1000,
        "is_dummy": false, "is_initial": false, "requestid": "uuid_1",
      ],
      [
        "id": "day2_workout1", "value": 45, "daystamp": "20221202", "comment": "Bike", "updated_at": 1001,
        "is_dummy": false, "is_initial": false, "requestid": "uuid_2",
      ],
    ]
    mockAPIClient.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
    let day1Workouts = [
      MockHealthKitDataPoint(
        daystamp: try Daystamp(fromString: "20221201"),
        value: NSNumber(value: 30),
        comment: "Run",
        requestid: "uuid_1",
      ),
      MockHealthKitDataPoint(
        daystamp: try Daystamp(fromString: "20221201"),
        value: NSNumber(value: 20),
        comment: "Yoga",
        requestid: "uuid_3",
      ),
    ]
    let day2Workouts = [
      MockHealthKitDataPoint(
        daystamp: try Daystamp(fromString: "20221202"),
        value: NSNumber(value: 60),
        comment: "Long bike ride",
        requestid: "uuid_4",
      )
    ]
    try! await dataPointManager.updateToMatchDataPoints(
      goalID: goal.objectID,
      healthKitDataPoints: day1Workouts + day2Workouts,
    )

    // Should delete day2 old workout, but not update day1 unchanged workout
    XCTAssertEqual(mockAPIClient.deleteCalls.count, 1)
    XCTAssertTrue(mockAPIClient.deleteCalls[0].contains("day2_workout1"))
    // Should create 2 new workouts (day1 yoga, day2 bike)
    XCTAssertEqual(mockAPIClient.addDatapointCalls.count, 2)
    XCTAssertTrue(mockAPIClient.addDatapointCalls.contains { $0.requestId == "uuid_3" })
    XCTAssertTrue(mockAPIClient.addDatapointCalls.contains { $0.requestId == "uuid_4" })
  }
  private func createTestGoalJSON() -> JSON {
    JSON(
      parseJSON: """
        {
            "id": "test-goal-id",
            "title": "Test Goal",
            "slug": "test-goal",
            "initday": 1668963600,
            "deadline": 0,
            "leadtime": 0,
            "alertstart": 34200,
            "queued": false,
            "yaxis": "test axis",
            "won": false,
            "safebuf": 1,
            "use_defaults": true,
            "pledge": 0,
            "hhmmformat": false,
            "todayta": false,
            "urgencykey": "test-urgency-key",
            "graph_url": "https://example.com/graph.png",
            "thumb_url": "https://example.com/thumb.png",
            "limsum": "test limsum",
            "safesum": "test safesum",
            "lasttouch": "2022-12-07T03:21:40.000Z"
        }
        """
    )
  }
}
