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
    
    func testHealthKitSyncFiltersDummyDatapoints() async throws {
        // Create test datapoints with mixed isDummy values
        let context = container.viewContext
        
        let normalDatapoint = DataPoint(
            context: context,
            goal: goal,
            id: "normal1",
            comment: "Normal datapoint",
            daystamp: try Daystamp(fromString: "20221201"),
            requestid: "",
            value: NSNumber(value: 10),
            updatedAt: 1000,
            isDummy: false,
            isInitial: false
        )
        
        let dummyDatapoint = DataPoint(
            context: context,
            goal: goal,
            id: "dummy1",
            comment: "Dummy datapoint",
            daystamp: try Daystamp(fromString: "20221202"),
            requestid: "",
            value: NSNumber(value: 20),
            updatedAt: 2000,
            isDummy: true,
            isInitial: false
        )
        
        try context.save()
        
        // Mock API response that includes both datapoints
        let apiResponse = [
            [
                "id": "normal1",
                "value": 10,
                "daystamp": "20221201",
                "comment": "Normal datapoint",
                "updated_at": 1000,
                "is_dummy": false,
                "is_initial": false
            ],
            [
                "id": "dummy1", 
                "value": 20,
                "daystamp": "20221202",
                "comment": "Dummy datapoint",
                "updated_at": 2000,
                "is_dummy": true,
                "is_initial": false
            ]
        ]
        
        mockRequestManager.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
        
        // Create mock HealthKit datapoint
        let healthKitDatapoint = MockHealthKitDataPoint(
            daystamp: try Daystamp(fromString: "20221201"),
            value: NSNumber(value: 15),
            comment: "Updated from HealthKit",
            requestid: "hk_test"
        )
        
        // Test the update method
        try! await dataPointManager.updateToMatchDataPoints(goalID: goal.objectID, healthKitDataPoints: [healthKitDatapoint])

        // Verify that the normal datapoint was updated, confirming dummy datapoints were filtered out
        XCTAssertEqual(mockRequestManager.putCalls.count, 1)
        XCTAssertTrue(mockRequestManager.putCalls[0].url.contains("normal1"))
        XCTAssertEqual(mockRequestManager.putCalls[0].parameters["value"] as? String, "15")
    }
    
    func testHealthKitSyncFiltersInitialDatapoints() async throws {
        // Create test datapoints with mixed isInitial values  
        let context = container.viewContext
        
        let normalDatapoint = DataPoint(
            context: context,
            goal: goal,
            id: "normal2",
            comment: "Normal datapoint",
            daystamp: try Daystamp(fromString: "20221201"),
            requestid: "",
            value: NSNumber(value: 10),
            updatedAt: 1000,
            isDummy: false,
            isInitial: false
        )
        
        let initialDatapoint = DataPoint(
            context: context,
            goal: goal,
            id: "initial1",
            comment: "Initial datapoint",
            daystamp: try Daystamp(fromString: "20221202"),
            requestid: "",
            value: NSNumber(value: 20),
            updatedAt: 2000,
            isDummy: false,
            isInitial: true
        )
        
        try context.save()
        
        // Mock API response that includes both datapoints
        let apiResponse = [
            [
                "id": "normal2",
                "value": 10,
                "daystamp": "20221201",
                "comment": "Normal datapoint",
                "updated_at": 1000,
                "is_dummy": false,
                "is_initial": false
            ],
            [
                "id": "initial1",
                "value": 20,
                "daystamp": "20221202", 
                "comment": "Initial datapoint",
                "updated_at": 2000,
                "is_dummy": false,
                "is_initial": true
            ]
        ]
        
        mockRequestManager.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
        
        // Create mock HealthKit datapoint
        let healthKitDatapoint = MockHealthKitDataPoint(
            daystamp: try Daystamp(fromString: "20221201"),
            value: NSNumber(value: 15),
            comment: "Updated from HealthKit",
            requestid: "hk_test"
        )
        
        // Test the update method
        try! await dataPointManager.updateToMatchDataPoints(goalID: goal.objectID, healthKitDataPoints: [healthKitDatapoint])

        // Verify that the normal datapoint was updated, confirming initial datapoints were filtered out
        XCTAssertEqual(mockRequestManager.putCalls.count, 1)
        XCTAssertTrue(mockRequestManager.putCalls[0].url.contains("normal2"))
        XCTAssertEqual(mockRequestManager.putCalls[0].parameters["value"] as? String, "15")
    }
    
    func testHealthKitSyncFiltersOutBothDummyAndInitial() async throws {
        // Create test datapoints with all combinations
        let context = container.viewContext
        
        let normalDatapoint = DataPoint(
            context: context,
            goal: goal,
            id: "normal3",
            comment: "Normal datapoint",
            daystamp: try Daystamp(fromString: "20221201"),
            requestid: "",
            value: NSNumber(value: 10),
            updatedAt: 1000,
            isDummy: false,
            isInitial: false
        )
        
        let dummyDatapoint = DataPoint(
            context: context,
            goal: goal,
            id: "dummy2",
            comment: "Dummy datapoint",
            daystamp: try Daystamp(fromString: "20221202"),
            requestid: "",
            value: NSNumber(value: 20),
            updatedAt: 2000,
            isDummy: true,
            isInitial: false
        )
        
        let initialDatapoint = DataPoint(
            context: context,
            goal: goal,
            id: "initial2",
            comment: "Initial datapoint", 
            daystamp: try Daystamp(fromString: "20221203"),
            requestid: "",
            value: NSNumber(value: 30),
            updatedAt: 3000,
            isDummy: false,
            isInitial: true
        )
        
        let bothDatapoint = DataPoint(
            context: context,
            goal: goal,
            id: "both1",
            comment: "Both dummy and initial",
            daystamp: try Daystamp(fromString: "20221204"),
            requestid: "",
            value: NSNumber(value: 40),
            updatedAt: 4000,
            isDummy: true,
            isInitial: true
        )
        
        try context.save()
        
        // Mock API response that includes all datapoints
        let apiResponse = [
            [
                "id": "normal3",
                "value": 10,
                "daystamp": "20221201",
                "comment": "Normal datapoint",
                "updated_at": 1000,
                "is_dummy": false,
                "is_initial": false
            ],
            [
                "id": "dummy2",
                "value": 20,
                "daystamp": "20221202",
                "comment": "Dummy datapoint",
                "updated_at": 2000,
                "is_dummy": true,
                "is_initial": false
            ],
            [
                "id": "initial2",
                "value": 30,
                "daystamp": "20221203",
                "comment": "Initial datapoint",
                "updated_at": 3000,
                "is_dummy": false,
                "is_initial": true
            ],
            [
                "id": "both1",
                "value": 40,
                "daystamp": "20221204",
                "comment": "Both dummy and initial",
                "updated_at": 4000,
                "is_dummy": true,
                "is_initial": true
            ]
        ]
        
        mockRequestManager.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
        
        // Create mock HealthKit datapoint matching the normal one
        let healthKitDatapoint = MockHealthKitDataPoint(
            daystamp: try Daystamp(fromString: "20221201"),
            value: NSNumber(value: 15),
            comment: "Updated from HealthKit",
            requestid: "hk_test"
        )
        
        // Test the update method
        try! await dataPointManager.updateToMatchDataPoints(goalID: goal.objectID, healthKitDataPoints: [healthKitDatapoint])

        // Verify that only the normal datapoint was considered for update
        XCTAssertEqual(mockRequestManager.putCalls.count, 1)
        XCTAssertTrue(mockRequestManager.putCalls[0].url.contains("normal3"))
        XCTAssertEqual(mockRequestManager.putCalls[0].parameters["value"] as? String, "15")
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
