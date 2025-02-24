import XCTest
@testable import BeeKit
import SwiftyJSON
import CoreData
import OrderedCollections

class MockRequestManager: RequestManager {
    var responses: [String: Any] = [:]
    
    override func get(url: String, parameters: [String : Any]? = nil) async throws -> Any? {
        if let response = responses[url] {
            return response
        }
        XCTFail("Unexpected URL requested: \(url)")
        return nil
    }
}

class GoalManagerTests: XCTestCase {
    var container: BeeminderPersistentContainer!
    var mockRequestManager: MockRequestManager!
    var currentUserManager: CurrentUserManager!
    var goalManager: GoalManager!
    
    override func setUpWithError() throws {
        container = BeeminderPersistentContainer.createMemoryBackedForTests()
        mockRequestManager = MockRequestManager()
        currentUserManager = CurrentUserManager(requestManager: mockRequestManager, container: container)
        goalManager = GoalManager(requestManager: mockRequestManager, currentUserManager: currentUserManager, container: container)
        
        let context = container.viewContext
        let _ = User(context: context,
                        username: "test_user",
                        deadbeat: false,
                        timezone: "America/Los_Angeles",
                        updatedAt: Date(timeIntervalSince1970: 1740350182),
                        defaultAlertStart: 34200,
                        defaultDeadline: 0,
                        defaultLeadTime: 0)
        try context.save()
    }
    
    override func tearDownWithError() throws {
        container = nil
        mockRequestManager = nil
        currentUserManager = nil
        goalManager = nil
    }
    
    func testInitialGoalCreation() async throws {
        let userResponse = """
        {
            "username": "test_user",
            "timezone": "America/Los_Angeles",
            "updated_at": 1740350182,
            "deadbeat": false,
            "default_leadtime": 0,
            "default_alertstart": 34200,
            "default_deadline": 0
        }
        """
        
        let goalsResponse = """
        [
            {
                "id": "67bba2e4d4865fb1a5f556e0",
                "slug": "deletable-goal",
                "title": "We will delete this",
                "graph_url": "https://cdn.beeminder.com/uploads/e2d311f3-be50-43d4-9210-fbc3d3c5068a.png",
                "thumb_url": "https://cdn.beeminder.com/uploads/e2d311f3-be50-43d4-9210-fbc3d3c5068a-thumb.png",
                "healthkitmetric": "",
                "urgencykey": "FROx;PPRx;DL1740988799;P1000000000;deletable-goal",
                "deadline": 0,
                "leadtime": 0,
                "alertstart": 34200,
                "use_defaults": true,
                "queued": false,
                "limsum": "+1 in 7 days",
                "safesum": "7 days",
                "last_touch": "2024-02-23",
                "init_day": 1740350182,
                "hhmmformat": false,
                "won": false,
                "y_axis": "hours"
            }
        ]
        """
        
        mockRequestManager.responses = [
            "api/v1/users/{username}.json": try JSONSerialization.jsonObject(with: userResponse.data(using: .utf8)!, options: []),
            "api/v1/users/{username}/goals.json": try JSONSerialization.jsonObject(with: goalsResponse.data(using: .utf8)!, options: [])
        ]
        
        try await goalManager.refreshGoals()
        
        let context = container.viewContext
        context.refreshAllObjects()
        
        let user = try XCTUnwrap(currentUserManager.user(context: context))
        XCTAssertEqual(user.goals.count, 1)
        
        let goal = try XCTUnwrap(user.goals.first)
        XCTAssertEqual(goal.slug, "deletable-goal")
        XCTAssertEqual(goal.title, "We will delete this")
    }
    
    func testGoalDeletion() async throws {
        try await testInitialGoalCreation()
        
        let deletionResponse = """
        {
            "username": "test_user",
            "timezone": "America/Los_Angeles",
            "updated_at": 1740350657,
            "deadbeat": false,
            "default_leadtime": 0,
            "default_alertstart": 34200,
            "default_deadline": 0,
            "deleted_goals": [
                {
                    "id": "67bba2e4d4865fb1a5f556e0",
                    "slug": "deletable-goal"
                }
            ]
        }
        """
        
        mockRequestManager.responses = [
            "api/v1/users/{username}.json": try JSONSerialization.jsonObject(with: deletionResponse.data(using: .utf8)!, options: [])
        ]
        
        try await goalManager.refreshGoals()
        
        let context = container.viewContext
        context.refreshAllObjects()
        
        let user = try XCTUnwrap(currentUserManager.user(context: context))
        XCTAssertEqual(user.goals.count, 0, "All goals should be deleted")
    }
}
