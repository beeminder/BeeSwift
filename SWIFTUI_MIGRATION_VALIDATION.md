# SwiftUI Migration Automated Validation Strategy

## Overview

This document outlines automated validation techniques to ensure the SwiftUI migration maintains feature parity, visual fidelity, performance, and accessibility.

---

## 1. Unit Testing ViewModels

As you extract logic from UIViewControllers into ViewModels, create comprehensive unit tests.

### Pattern: ViewModel Testing

```swift
// GoalDetailViewModelTests.swift
import XCTest
import Combine
@testable import BeeSwift
@testable import BeeKit

final class GoalDetailViewModelTests: XCTestCase {
    var container: BeeminderPersistentContainer!
    var mockRequestManager: MockRequestManager!
    var viewModel: GoalDetailViewModel!
    var cancellables = Set<AnyCancellable>()

    override func setUpWithError() throws {
        container = BeeminderPersistentContainer.createMemoryBackedForTests()
        mockRequestManager = MockRequestManager()
        // Create test goal
        let context = container.viewContext
        let user = User(context: context, username: "test", ...)
        let goal = Goal(context: context, ...)
        try context.save()

        viewModel = GoalDetailViewModel(
            goal: goal,
            requestManager: mockRequestManager,
            goalManager: GoalManager(...)
        )
    }

    func testSubmitDatapointUpdatesState() async throws {
        // Given
        XCTAssertFalse(viewModel.isSubmitting)

        // When
        mockRequestManager.responses["api/v1/..."] = successResponse
        try await viewModel.submitDatapoint(date: Date(), value: "5", comment: "test")

        // Then
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSubmitDatapointShowsErrorOnFailure() async throws {
        // Given
        mockRequestManager.shouldFail = true

        // When/Then
        do {
            try await viewModel.submitDatapoint(date: Date(), value: "5", comment: "")
            XCTFail("Should have thrown")
        } catch {
            XCTAssertNotNil(viewModel.errorMessage)
        }
    }

    func testDateStepperCalculation() {
        // Test the date stepper logic extracted from GoalViewController
        let result = viewModel.calculateDateFromStepper(value: -1, for: goal)
        XCTAssertEqual(result, Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
    }
}
```

### What to Test in ViewModels
- State transitions (`isLoading`, `isSubmitting`, `errorMessage`)
- Data transformations (date formatting, value parsing)
- Business logic (validation, calculations)
- Async operations (network calls, CoreData updates)

---

## 2. Snapshot Testing (Visual Regression)

Use snapshot testing to catch visual regressions when migrating views.

### Setup with swift-snapshot-testing

```swift
// Package.swift addition
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")

// Test target
.testTarget(
    name: "BeeSwiftSnapshotTests",
    dependencies: [
        "BeeSwift",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ]
)
```

### Snapshot Test Examples

```swift
import SnapshotTesting
import SwiftUI
import XCTest
@testable import BeeSwift

final class GalleryViewSnapshotTests: XCTestCase {

    func testGalleryViewWithGoals() {
        let view = GalleryView(viewModel: mockViewModel)
            .frame(width: 390, height: 844) // iPhone 14 size

        assertSnapshot(of: view, as: .image)
    }

    func testGalleryViewEmpty() {
        let view = GalleryView(viewModel: emptyViewModel)
            .frame(width: 390, height: 844)

        assertSnapshot(of: view, as: .image)
    }

    func testGalleryViewWithSearch() {
        let view = GalleryView(viewModel: searchingViewModel)
            .frame(width: 390, height: 844)

        assertSnapshot(of: view, as: .image)
    }

    // Test multiple device sizes
    func testGalleryViewiPad() {
        let view = GalleryView(viewModel: mockViewModel)
            .frame(width: 1024, height: 768)

        assertSnapshot(of: view, as: .image)
    }

    // Test dark mode
    func testGalleryViewDarkMode() {
        let view = GalleryView(viewModel: mockViewModel)
            .frame(width: 390, height: 844)
            .environment(\.colorScheme, .dark)

        assertSnapshot(of: view, as: .image)
    }

    // Test dynamic type
    func testGalleryViewLargeText() {
        let view = GalleryView(viewModel: mockViewModel)
            .frame(width: 390, height: 844)
            .environment(\.sizeCategory, .accessibilityExtraLarge)

        assertSnapshot(of: view, as: .image)
    }
}
```

### UIKit vs SwiftUI Comparison Snapshots

```swift
final class MigrationComparisonTests: XCTestCase {

    func testGoalCardVisualParity() {
        // Capture UIKit version
        let uikitCell = GoalCollectionViewCell()
        uikitCell.configure(with: testGoal)
        uikitCell.frame = CGRect(x: 0, y: 0, width: 320, height: 120)

        // Capture SwiftUI version
        let swiftUIView = GoalCardView(goal: testGoal)
            .frame(width: 320, height: 120)

        // Compare (with tolerance for minor differences)
        assertSnapshot(of: uikitCell, as: .image, named: "uikit")
        assertSnapshot(of: swiftUIView, as: .image, named: "swiftui")

        // Or use perceptual diff
        // assertSnapshot(of: swiftUIView, as: .image, record: false)
    }
}
```

---

## 3. UI Testing (XCUITest)

### Accessibility Identifier Strategy

Add consistent accessibility identifiers that work in both UIKit and SwiftUI:

```swift
// UIKit
self.collectionView.accessibilityIdentifier = "goalGallery"
self.searchBar.accessibilityIdentifier = "gallerySearchBar"

// SwiftUI
LazyVGrid(...) {
    ...
}
.accessibilityIdentifier("goalGallery")

TextField("Search", text: $searchText)
    .accessibilityIdentifier("gallerySearchBar")
```

### UI Test Examples

```swift
final class GalleryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    // MARK: - Gallery Tests

    func testGalleryDisplaysGoals() {
        // Wait for gallery to load
        let gallery = app.collectionViews["goalGallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))

        // Verify goals are displayed
        XCTAssertGreaterThan(gallery.cells.count, 0)
    }

    func testSearchFiltersGoals() {
        // Open search
        app.buttons["searchButton"].tap()

        let searchBar = app.searchFields["gallerySearchBar"]
        XCTAssertTrue(searchBar.waitForExistence(timeout: 2))

        // Type search query
        searchBar.tap()
        searchBar.typeText("weight")

        // Verify filtering works
        let gallery = app.collectionViews["goalGallery"]
        // Assert filtered results
    }

    func testNavigationToGoalDetail() {
        let gallery = app.collectionViews["goalGallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))

        // Tap first goal
        gallery.cells.firstMatch.tap()

        // Verify navigation to detail
        let goalTitle = app.staticTexts["goalDetailTitle"]
        XCTAssertTrue(goalTitle.waitForExistence(timeout: 2))
    }

    func testPullToRefresh() {
        let gallery = app.collectionViews["goalGallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))

        // Pull to refresh
        gallery.swipeDown()

        // Verify refresh indicator appeared (or goals updated)
        // This may need adjustment based on actual behavior
    }

    // MARK: - Goal Detail Tests

    func testDatapointSubmission() {
        // Navigate to goal
        navigateToFirstGoal()

        // Find and fill form
        let valueField = app.textFields["datapointValueField"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))

        valueField.tap()
        valueField.typeText("5")

        // Submit
        app.buttons["submitDatapointButton"].tap()

        // Verify success (no error alert, form cleared, etc.)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    // MARK: - Settings Tests

    func testSettingsNavigation() {
        app.buttons["settingsButton"].tap()

        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2))
    }

    // MARK: - Helpers

    private func navigateToFirstGoal() {
        let gallery = app.collectionViews["goalGallery"]
        _ = gallery.waitForExistence(timeout: 5)
        gallery.cells.firstMatch.tap()
    }
}
```

### Feature Parity Test Matrix

```swift
/// Tests that verify feature parity between UIKit and SwiftUI versions
final class FeatureParityTests: XCTestCase {

    /// Document all features that must work identically
    func testFeatureParityMatrix() {
        let features: [(String, () -> Bool)] = [
            ("Gallery loads goals", testGalleryLoadsGoals),
            ("Gallery search filters", testGallerySearchFilters),
            ("Gallery sort options", testGallerySortOptions),
            ("Goal detail shows graph", testGoalDetailShowsGraph),
            ("Goal detail shows datapoints", testGoalDetailShowsDatapoints),
            ("Datapoint submission works", testDatapointSubmission),
            ("Timer starts and stops", testTimerStartsAndStops),
            ("Settings persist", testSettingsPersist),
            ("Deep links open goals", testDeepLinksOpenGoals),
            ("Pull to refresh works", testPullToRefresh),
        ]

        for (name, test) in features {
            XCTAssertTrue(test(), "Feature failed: \(name)")
        }
    }
}
```

---

## 4. Performance Testing

### Measure Key Metrics

```swift
final class PerformanceTests: XCTestCase {

    func testGalleryScrollPerformance() {
        let app = XCUIApplication()
        app.launch()

        let gallery = app.collectionViews["goalGallery"]
        _ = gallery.waitForExistence(timeout: 5)

        measure(metrics: [XCTOSSignpostMetric.scrollDraggingMetric]) {
            gallery.swipeUp(velocity: .fast)
            gallery.swipeDown(velocity: .fast)
        }
    }

    func testGoalDetailLoadTime() {
        let app = XCUIApplication()
        app.launch()

        measure(metrics: [XCTClockMetric()]) {
            let gallery = app.collectionViews["goalGallery"]
            _ = gallery.waitForExistence(timeout: 5)
            gallery.cells.firstMatch.tap()

            let detail = app.scrollViews["goalDetailScrollView"]
            _ = detail.waitForExistence(timeout: 5)

            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    func testAppLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    func testMemoryUsage() {
        let app = XCUIApplication()
        app.launch()

        measure(metrics: [XCTMemoryMetric()]) {
            // Navigate through app
            let gallery = app.collectionViews["goalGallery"]
            _ = gallery.waitForExistence(timeout: 5)

            // Open and close multiple goals
            for _ in 0..<5 {
                gallery.cells.firstMatch.tap()
                sleep(1)
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
        }
    }
}
```

### Set Performance Baselines

```swift
func testGalleryScrollPerformance() {
    measure(
        metrics: [XCTOSSignpostMetric.scrollDraggingMetric],
        options: XCTMeasureOptions.default
    ) {
        // test code
    }

    // In CI, compare against baseline:
    // If scroll hitches increase by >10%, fail the build
}
```

---

## 5. Accessibility Testing

### Automated Accessibility Audits

```swift
final class AccessibilityTests: XCTestCase {

    func testGalleryAccessibility() throws {
        let app = XCUIApplication()
        app.launch()

        let gallery = app.collectionViews["goalGallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))

        // Verify VoiceOver labels exist
        for cell in gallery.cells.allElementsBoundByIndex {
            XCTAssertFalse(cell.label.isEmpty, "Cell should have accessibility label")
        }
    }

    func testGoalDetailAccessibility() throws {
        let app = XCUIApplication()
        app.launch()

        navigateToFirstGoal()

        // Audit for accessibility issues (iOS 17+)
        try app.performAccessibilityAudit()
    }

    func testDynamicTypeSupport() {
        // Test with largest accessibility size
        let app = XCUIApplication()
        app.launchArguments.append("-UIPreferredContentSizeCategoryName")
        app.launchArguments.append("UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        app.launch()

        // Verify text is readable (no truncation)
        let gallery = app.collectionViews["goalGallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))

        // Check that labels are visible
        let cell = gallery.cells.firstMatch
        XCTAssertTrue(cell.staticTexts.firstMatch.isHittable)
    }
}
```

### SwiftUI Preview Accessibility

```swift
struct GoalCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GoalCardView(goal: .preview)
                .previewDisplayName("Default")

            GoalCardView(goal: .preview)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .previewDisplayName("XXXL Text")

            GoalCardView(goal: .preview)
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode")

            GoalCardView(goal: .preview)
                .environment(\.accessibilityReduceMotion, true)
                .previewDisplayName("Reduce Motion")
        }
        .previewLayout(.sizeThatFits)
    }
}
```

---

## 6. CI/CD Pipeline Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/swiftui-migration-validation.yml
name: SwiftUI Migration Validation

on:
  pull_request:
    paths:
      - '**/*.swift'
      - 'BeeSwift.xcodeproj/**'

jobs:
  unit-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project BeeSwift.xcodeproj \
            -scheme BeeSwift \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:BeeSwiftTests \
            -only-testing:BeeKitTests \
            | xcpretty

  snapshot-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true  # For snapshot images

      - name: Run Snapshot Tests
        run: |
          xcodebuild test \
            -project BeeSwift.xcodeproj \
            -scheme BeeSwift \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:BeeSwiftSnapshotTests \
            | xcpretty

      - name: Upload Failed Snapshots
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: failed-snapshots
          path: '**/Failures/**'

  ui-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Run UI Tests
        run: |
          xcodebuild test \
            -project BeeSwift.xcodeproj \
            -scheme BeeSwift \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:BeeSwiftUITests \
            | xcpretty

  performance-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Run Performance Tests
        run: |
          xcodebuild test \
            -project BeeSwift.xcodeproj \
            -scheme BeeSwift \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:BeeSwiftPerformanceTests \
            | xcpretty

      - name: Check Performance Baselines
        run: |
          # Compare against stored baselines
          # Fail if performance regresses >10%
```

### Pre-commit Hooks

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run SwiftLint
swiftlint lint --strict

# Run quick unit tests
xcodebuild test \
  -project BeeSwift.xcodeproj \
  -scheme BeeSwift \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:BeeSwiftTests \
  -quiet

# Check for accessibility identifiers in new views
grep -r "accessibilityIdentifier" BeeSwift/*.swift || {
  echo "Warning: Consider adding accessibility identifiers to new views"
}
```

---

## 7. Migration Checklist Tests

Create explicit tests that verify migration is complete:

```swift
final class MigrationChecklistTests: XCTestCase {

    /// Verify no UIKit view controllers remain (when migration is complete)
    func testNoUIKitViewControllersRemain() throws {
        // This test should be enabled at the end of migration
        // throw XCTSkip("Enable when migration is complete")

        let sourceFiles = try FileManager.default
            .contentsOfDirectory(atPath: "BeeSwift")
            .filter { $0.hasSuffix(".swift") }

        for file in sourceFiles {
            let content = try String(contentsOfFile: "BeeSwift/\(file)")
            XCTAssertFalse(
                content.contains(": UIViewController"),
                "\(file) still contains UIViewController"
            )
        }
    }

    /// Verify all screens have SwiftUI equivalents
    func testAllScreensMigrated() {
        let expectedViews = [
            "GalleryView",
            "GoalDetailView",
            "SignInView",
            "TimerView",
            "SettingsView",
            "HealthKitConfigView",
            // ... add all views
        ]

        for viewName in expectedViews {
            // Verify type exists at runtime
            let viewType = NSClassFromString("BeeSwift.\(viewName)")
            XCTAssertNotNil(viewType, "\(viewName) not found")
        }
    }

    /// Verify no SnapKit usage remains
    func testNoSnapKitRemains() throws {
        // throw XCTSkip("Enable when migration is complete")

        let sourceFiles = try findAllSwiftFiles(in: "BeeSwift")
        for file in sourceFiles {
            let content = try String(contentsOfFile: file)
            XCTAssertFalse(
                content.contains("snp.makeConstraints"),
                "\(file) still uses SnapKit"
            )
        }
    }
}
```

---

## 8. Automated Test Coverage Goals

### Coverage Targets by Phase

| Phase | Unit Test Coverage | UI Test Coverage | Snapshot Coverage |
|-------|-------------------|------------------|-------------------|
| Foundation | 80% ViewModels | N/A | N/A |
| Simple Screens | 70% | 50% flows | 100% states |
| Gallery | 80% | 80% flows | 100% states |
| Goal Detail | 80% | 90% flows | 100% states |
| Complete | 80% overall | 90% flows | All screens |

### Enforcing Coverage in CI

```yaml
- name: Check Test Coverage
  run: |
    xcrun llvm-cov report \
      --instr-profile=coverage.profdata \
      BeeSwift.app/BeeSwift \
      --ignore-filename-regex='.*Tests.*' \
      | tee coverage.txt

    # Extract coverage percentage
    COVERAGE=$(grep 'TOTAL' coverage.txt | awk '{print $4}' | tr -d '%')

    if (( $(echo "$COVERAGE < 70" | bc -l) )); then
      echo "Coverage $COVERAGE% is below 70% threshold"
      exit 1
    fi
```

---

## Summary: Validation Automation Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Unit | XCTest | ViewModel logic, business rules |
| Snapshot | swift-snapshot-testing | Visual regression |
| UI | XCUITest | End-to-end flows |
| Performance | XCTMetric | Scroll, launch, memory |
| Accessibility | performAccessibilityAudit | A11y compliance |
| CI | GitHub Actions | Automated pipeline |
| Coverage | llvm-cov | Test coverage enforcement |

By implementing this validation strategy, you can confidently migrate views knowing that regressions will be caught automatically.
