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
        
        // Set up initial user
        let context = container.viewContext
        let user = User(context: context,
                        username: "theospears_test1",
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
        // Set up mock responses
        let userResponse = """
        {"username":"theospears_test1","timezone":"America/Los_Angeles","goals":["deletable-goal"],"created_at":1740350064,"updated_at":1740350182,"urgency_load":0,"deadbeat":false,"has_authorized_fitbit":false,"default_leadtime":0,"default_alertstart":34200,"default_deadline":0,"subscription":null,"subs_downto":null,"subs_freq":null,"subs_lifetime":null,"remaining_subs_credit":0,"id":"67bba270d4865fb1a5f556dd"}
        """
        
        let goalsResponse = """
        [{"slug":"deletable-goal","title":"We will delete this","description":null,"goalval":null,"rate":1.0,"goaldate":4102444799,"svg_url":"https://cdn.beeminder.com/uploads/e2d311f3-be50-43d4-9210-fbc3d3c5068a.svg","graph_url":"https://cdn.beeminder.com/uploads/e2d311f3-be50-43d4-9210-fbc3d3c5068a.png","thumb_url":"https://cdn.beeminder.com/uploads/e2d311f3-be50-43d4-9210-fbc3d3c5068a-thumb.png","goal_type":"hustler","autodata":null,"healthkitmetric":"","autodata_config":{},"losedate":1740988799,"urgencykey":"FROx;PPRx;DL1740988799;P1000000000;deletable-goal","deadline":0,"leadtime":0,"alertstart":34200,"use_defaults":true,"id":"67bba2e4d4865fb1a5f556e0","ephem":false,"queued":false,"panic":54000,"updated_at":1740350182,"burner":"frontburner","yaw":1,"lane":6,"delta":0,"runits":"d","limsum":"+1 in 7 days","frozen":false,"lost":false,"won":false}]
        """
        
        mockRequestManager.responses = [
            "api/v1/users/{username}.json": try JSONSerialization.jsonObject(with: userResponse.data(using: .utf8)!, options: []),
            "api/v1/users/{username}/goals.json": try JSONSerialization.jsonObject(with: goalsResponse.data(using: .utf8)!, options: [])
        ]
        
        // Execute refresh
        try await goalManager.refreshGoals()
        
        // Verify results
        let context = container.viewContext
        context.refreshAllObjects()
        
        let user = try XCTUnwrap(currentUserManager.user(context: context))
        XCTAssertEqual(user.goals.count, 1)
        
        let goal = try XCTUnwrap(user.goals.first)
        XCTAssertEqual(goal.slug, "deletable-goal")
        XCTAssertEqual(goal.title, "We will delete this")
    }
    
    func testGoalDeletion() async throws {
        // First create a goal
        try await testInitialGoalCreation()
        
        // Now simulate a deletion update
        let deletionResponse = """
        {"username":"theospears_test1","timezone":"America/Los_Angeles","goals":[],"created_at":1740350064,"updated_at":1740350657,"urgency_load":0,"deadbeat":false,"has_authorized_fitbit":false,"default_leadtime":0,"default_alertstart":34200,"default_deadline":0,"subscription":null,"subs_downto":null,"subs_freq":null,"subs_lifetime":null,"remaining_subs_credit":0,"id":"67bba270d4865fb1a5f556dd","deleted_goals":[{"id":"67bba2e4d4865fb1a5f556e0","slug":"deletable-goal"}]}
        """
        
        mockRequestManager.responses = [
            "api/v1/users/{username}.json": try JSONSerialization.jsonObject(with: deletionResponse.data(using: .utf8)!, options: [])
        ]
        
        // Execute refresh
        try await goalManager.refreshGoals()
        
        // Verify results
        let context = container.viewContext
        context.refreshAllObjects()
        
        let user = try XCTUnwrap(currentUserManager.user(context: context))
        XCTAssertEqual(user.goals.count, 0, "All goals should be deleted")
    }
}
