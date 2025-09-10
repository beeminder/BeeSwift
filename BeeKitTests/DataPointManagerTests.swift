import XCTest
@testable import BeeKit
import SwiftyJSON
import CoreData

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

class MockRequestManagerForDataPoint: RequestManager {
    var responses: [String: Any] = [:]
    var putCalls: [(url: String, parameters: [String: Any])] = []
    var deleteCalls: [String] = []
    var addDatapointCalls: [(urtext: String, slug: String, requestId: String)] = []
    
    override func get(url: String, parameters: [String : Any]? = nil) async throws -> Any? {
        if let response = responses[url] {
            responses.removeValue(forKey: url)
            return response
        }
        return []
    }
    
    override func put(url: String, parameters: [String : Any]? = nil) async throws -> Any? {
        putCalls.append((url: url, parameters: parameters ?? [:]))
        return [:]
    }
    
    override func delete(url: String, parameters: [String: Any]? = nil) async throws -> Any? {
        deleteCalls.append(url)
        return [:]
    }
    
    override func addDatapoint(urtext: String, slug: String, requestId: String? = nil) async throws -> Any? {
        addDatapointCalls.append((urtext: urtext, slug: slug, requestId: requestId ?? ""))
        return [:]
    }
}

class DataPointManagerTests: XCTestCase {
    var container: BeeminderPersistentContainer!
    var mockRequestManager: MockRequestManagerForDataPoint!
    var dataPointManager: DataPointManager!
    var goal: Goal!
    var user: User!
    
    override func setUpWithError() throws {
        container = BeeminderPersistentContainer.createMemoryBackedForTests()
        mockRequestManager = MockRequestManagerForDataPoint()
        dataPointManager = DataPointManager(requestManager: mockRequestManager, container: container)
        
        let context = container.viewContext
        user = User(context: context,
                   username: "test_user",
                   deadbeat: false,
                   timezone: "America/Los_Angeles",
                   updatedAt: Date(timeIntervalSince1970: 1740350182),
                   defaultAlertStart: 34200,
                   defaultDeadline: 0,
                   defaultLeadTime: 0)
        
        goal = Goal(context: context, owner: user, json: createTestGoalJSON())
        try context.save()
    }
    
    override func tearDownWithError() throws {
        container = nil
        mockRequestManager = nil
        dataPointManager = nil
        goal = nil
        user = nil
    }

    func testSynchronizesPointsByRequestId() async throws {
        let apiResponse = [
            // Existing datapoint with requestId that should be updated
            [
                "id": "existing1",
                "value": 10,
                "daystamp": "20221201",
                "comment": "Old comment",
                "updated_at": 1000,
                "is_dummy": false,
                "is_initial": false,
                "requestid": "hk_workout_1"
            ],
            // Existing datapoint without matching requestId that should be deleted
            [
                "id": "obsolete1",
                "value": 20,
                "daystamp": "20221201",
                "comment": "Should be deleted",
                "updated_at": 1001,
                "is_dummy": false,
                "is_initial": false,
                "requestid": "hk_workout_old"
            ],
            // Metadata points which should be ignored
            [
                "id": "dummy2",
                "value": 20,
                "daystamp": "20221202",
                "comment": "Dummy datapoint",
                "updated_at": 2000,
                "is_dummy": true,
                "is_initial": false
            ]
        ]
        
        mockRequestManager.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
        
        let updatedHealthKitDatapoint = MockHealthKitDataPoint(
            daystamp: try Daystamp(fromString: "20221201"),
            value: NSNumber(value: 15),
            comment: "Updated workout comment",
            requestid: "hk_workout_1"
        )
        
        let newHealthKitDatapoint = MockHealthKitDataPoint(
            daystamp: try Daystamp(fromString: "20221201"),
            value: NSNumber(value: 25),
            comment: "New workout",
            requestid: "hk_workout_2"
        )
        
        try! await dataPointManager.updateToMatchDataPoints(goalID: goal.objectID, healthKitDataPoints: [updatedHealthKitDatapoint, newHealthKitDatapoint])

        // Should update the existing datapoint by requestId
        XCTAssertEqual(mockRequestManager.putCalls.count, 1)
        XCTAssertTrue(mockRequestManager.putCalls[0].url.contains("existing1"))
        XCTAssertEqual(mockRequestManager.putCalls[0].parameters["value"] as? String, "15")
        XCTAssertEqual(mockRequestManager.putCalls[0].parameters["comment"] as? String, "Updated workout comment")
        
        // Should delete the obsolete datapoint
        XCTAssertEqual(mockRequestManager.deleteCalls.count, 1)
        XCTAssertTrue(mockRequestManager.deleteCalls[0].contains("obsolete1"))
        
        // Should create a new datapoint
        XCTAssertEqual(mockRequestManager.addDatapointCalls.count, 1)
        XCTAssertEqual(mockRequestManager.addDatapointCalls[0].urtext, "1 25 \"New workout\"")
        XCTAssertEqual(mockRequestManager.addDatapointCalls[0].slug, "test-goal")
        XCTAssertEqual(mockRequestManager.addDatapointCalls[0].requestId, "hk_workout_2")
    }
    
    func testDeletesRemovedWorkouts() async throws {
        let apiResponse = [
            [
                "id": "workout1",
                "value": 30,
                "daystamp": "20221201",
                "comment": "Morning run",
                "updated_at": 1000,
                "is_dummy": false,
                "is_initial": false,
                "requestid": "hk_workout_uuid_1"
            ],
            [
                "id": "workout2", 
                "value": 45,
                "daystamp": "20221201",
                "comment": "Evening bike",
                "updated_at": 1001,
                "is_dummy": false,
                "is_initial": false,
                "requestid": "hk_workout_uuid_2"
            ]
        ]
        
        mockRequestManager.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
        
        // Only one workout remains in HealthKit
        let remainingWorkout = MockHealthKitDataPoint(
            daystamp: try Daystamp(fromString: "20221201"),
            value: NSNumber(value: 30),
            comment: "Morning run",
            requestid: "hk_workout_uuid_1"
        )
        
        try! await dataPointManager.updateToMatchDataPoints(goalID: goal.objectID, healthKitDataPoints: [remainingWorkout])

        // Should not update the matching workout (same value/comment)
        XCTAssertEqual(mockRequestManager.putCalls.count, 0)
        
        // Should delete the removed workout
        XCTAssertEqual(mockRequestManager.deleteCalls.count, 1)
        XCTAssertTrue(mockRequestManager.deleteCalls[0].contains("workout2"))
        
        // Should not create any new datapoints
        XCTAssertEqual(mockRequestManager.addDatapointCalls.count, 0)
    }
    
    func testMultipleDaysWithMultipleWorkouts() async throws {
        let apiResponse = [
            [
                "id": "day1_workout1",
                "value": 30,
                "daystamp": "20221201",
                "comment": "Run",
                "updated_at": 1000,
                "is_dummy": false,
                "is_initial": false,
                "requestid": "uuid_1"
            ],
            [
                "id": "day2_workout1",
                "value": 45,
                "daystamp": "20221202", 
                "comment": "Bike",
                "updated_at": 1001,
                "is_dummy": false,
                "is_initial": false,
                "requestid": "uuid_2"
            ]
        ]
        
        mockRequestManager.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
        
        let day1Workouts = [
            MockHealthKitDataPoint(
                daystamp: try Daystamp(fromString: "20221201"),
                value: NSNumber(value: 30),
                comment: "Run",
                requestid: "uuid_1"
            ),
            MockHealthKitDataPoint(
                daystamp: try Daystamp(fromString: "20221201"),
                value: NSNumber(value: 20),
                comment: "Yoga",
                requestid: "uuid_3"
            )
        ]
        
        let day2Workouts = [
            MockHealthKitDataPoint(
                daystamp: try Daystamp(fromString: "20221202"),
                value: NSNumber(value: 60),
                comment: "Long bike ride",
                requestid: "uuid_4"
            )
        ]
        
        try! await dataPointManager.updateToMatchDataPoints(goalID: goal.objectID, healthKitDataPoints: day1Workouts + day2Workouts)

        // Should delete day2 old workout, but not update day1 unchanged workout
        XCTAssertEqual(mockRequestManager.deleteCalls.count, 1)
        XCTAssertTrue(mockRequestManager.deleteCalls[0].contains("day2_workout1"))
        
        // Should create 2 new workouts (day1 yoga, day2 bike)
        XCTAssertEqual(mockRequestManager.addDatapointCalls.count, 2)
        XCTAssertTrue(mockRequestManager.addDatapointCalls.contains { $0.requestId == "uuid_3" })
        XCTAssertTrue(mockRequestManager.addDatapointCalls.contains { $0.requestId == "uuid_4" })
    }
    
    private func createTestGoalJSON() -> JSON {
        return JSON(parseJSON: """
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
        """)
    }
}
