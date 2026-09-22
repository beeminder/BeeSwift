// Part of BeeSwift. Copyright Beeminder

import AppIntents
import CoreData
import SwiftyJSON
import XCTest

@testable import BeeKit
@testable import BeeSwift

final class GoalUserActivityTests: XCTestCase {
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

  func testIdentifierForGoalUsesGoalIdAndEntityType() {
    let identifier = GoalEntity.identifier(for: makeGoal())
    XCTAssertEqual(identifier.identifier, "737aaa34f0118a330852e4bd")
    XCTAssertTrue(identifier.entityType == GoalEntity.self)
  }

  @MainActor func testViewingGoalActivityDescribesTheGoal() {
    let activity = NSUserActivity.viewingGoal(makeGoal())
    XCTAssertEqual(activity.activityType, NSUserActivity.viewingGoalActivityType)
    XCTAssertEqual(activity.title, "read-books")
    XCTAssertEqual(activity.userInfo?["slug"] as? String, "read-books")
    XCTAssertEqual(activity.webpageURL?.absoluteString, "https://www.beeminder.com/alice/read-books")
    XCTAssertTrue(activity.isEligibleForHandoff)
    XCTAssertNotNil(activity.appEntityIdentifier)
  }

  @MainActor func testActivityTypeIsRegisteredInInfoPlist() {
    let types = Bundle(for: MainCoordinator.self).infoDictionary?["NSUserActivityTypes"] as? [String]
    XCTAssertEqual(types, [NSUserActivity.viewingGoalActivityType])
  }

  @MainActor func testGalleryCellsAreAnnotatedWithGoalEntities() throws {
    let goalA = makeGoal(["id": "goal-a", "slug": "alpha"])
    let goalB = makeGoal(["id": "goal-b", "slug": "bravo"])
    let requestManager = RequestManager()
    let currentUserManager = CurrentUserManager(requestManager: requestManager, container: container)
    let goalManager = GoalManager(
      requestManager: requestManager,
      currentUserManager: currentUserManager,
      container: container,
    )
    let versionManager = VersionManager(requestManager: requestManager)
    let coordinator = MainCoordinator(
      navigationController: UINavigationController(),
      currentUserManager: currentUserManager,
      viewContext: container.viewContext,
      versionManager: versionManager,
      goalManager: goalManager,
      healthStoreManager: HealthStoreManager(goalManager: goalManager, container: container),
      requestManager: requestManager,
    )
    let gallery = GalleryViewController(
      currentUserManager: currentUserManager,
      viewContext: container.viewContext,
      versionManager: versionManager,
      goalManager: goalManager,
      requestManager: requestManager,
      coordinator: coordinator,
    )
    gallery.loadViewIfNeeded()

    let collectionView = try XCTUnwrap(Self.firstCollectionView(in: gallery.view))
    let dataSource = try XCTUnwrap(collectionView.appIntentsDataSource)
    XCTAssertTrue(dataSource === gallery)

    let identifiers = (0..<3).map { item in
      dataSource.collectionView(collectionView, appEntityIdentifierForItemAt: IndexPath(item: item, section: 0))
    }
    XCTAssertEqual(Set(identifiers.prefix(2).compactMap { $0?.identifier }), [goalA.id, goalB.id])
    XCTAssertTrue(identifiers.prefix(2).allSatisfy { $0?.entityType == GoalEntity.self })
    XCTAssertNil(identifiers[2], "Rows beyond the fetched goals must not claim an entity")
  }

  private static func firstCollectionView(in view: UIView) -> UICollectionView? {
    if let collectionView = view as? UICollectionView { return collectionView }
    for subview in view.subviews { if let found = firstCollectionView(in: subview) { return found } }
    return nil
  }
}
