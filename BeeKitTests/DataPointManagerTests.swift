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

    func testSynchronizesPoints() async throws {
        let apiResponse = [
            // Matching data point to be updated
            [
                "id": "normal3",
                "value": 10,
                "daystamp": "20221201",
                "comment": "Normal datapoint",
                "updated_at": 1000,
                "is_dummy": false,
                "is_initial": false
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
            // Additional datapoint that will be deleted (multiple datapoints for same daystamp)
            [
                "id": "duplicate1",
                "value": 11,
                "daystamp": "20221201",
                "comment": "Duplicate datapoint to be deleted",
                "updated_at": 1001,
                "is_dummy": false,
                "is_initial": false
            ],
        ]
        
        mockRequestManager.responses["api/v1/users/{username}/goals/test-goal/datapoints.json"] = apiResponse
        
        let healthKitDatapoint = MockHealthKitDataPoint(
            daystamp: try Daystamp(fromString: "20221201"),
            value: NSNumber(value: 15),
            comment: "Updated from HealthKit",
            requestid: "hk_test"
        )
        
        let newHealthKitDatapoint = MockHealthKitDataPoint(
            daystamp: try Daystamp(fromString: "20221204"),
            value: NSNumber(value: 25),
            comment: "New HealthKit datapoint",
            requestid: "hk_new"
        )
        
        try! await dataPointManager.updateToMatchDataPoints(goalID: goal.objectID, healthKitDataPoints: [healthKitDatapoint, newHealthKitDatapoint])

        // Should update the matching data point
        XCTAssertEqual(mockRequestManager.putCalls.count, 1)
        XCTAssertTrue(mockRequestManager.putCalls[0].url.contains("normal3"))
        XCTAssertEqual(mockRequestManager.putCalls[0].parameters["value"] as? String, "15")
        
        // Should delete the duplicate data point
        XCTAssertEqual(mockRequestManager.deleteCalls.count, 1)
        XCTAssertTrue(mockRequestManager.deleteCalls[0].contains("duplicate1"))
        
        // Should create a new data point
        XCTAssertEqual(mockRequestManager.addDatapointCalls.count, 1)
        XCTAssertEqual(mockRequestManager.addDatapointCalls[0].urtext, "4 25 \"New HealthKit datapoint\"")
        XCTAssertEqual(mockRequestManager.addDatapointCalls[0].slug, "test-goal")
        XCTAssertEqual(mockRequestManager.addDatapointCalls[0].requestId, "hk_new")
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
