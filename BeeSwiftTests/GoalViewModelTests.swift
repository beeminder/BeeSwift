
import XCTest
@testable import BeeSwift
@testable import BeeKit

final class GoalViewModelTests: XCTestCase {
    private enum DayStep: Double {
        case previousDay = -1
        case sameDay = 0
        case nextDay = 1
    }
    
    func testInitialStepperIsYesterdayWhenSubmissionDateIsAfterMidnightAndBeforeDeadline() async throws {
        let goalWithAfterMidnightDeadline = Self.makeGoalWithDeadline(3600 * 3)
        let viewModel = GoalViewModel(goal: goalWithAfterMidnightDeadline)
        let submissionDateBeforeGoalsDeadline = Calendar.current.date(bySettingHour: 1, minute: 30, second: 0, of: Date())!
        let actual = viewModel.initialDateStepperValue(submissionDate: submissionDateBeforeGoalsDeadline)
        XCTAssertEqual(actual,
                        DayStep.previousDay.rawValue)
    }
    
    func testInitialStepperIsTodayWhenSubmissionDateIsBeforeMidnightAndBeforeDeadline() async throws {
        let goalWithMidnightDeadline = Self.makeGoalWithDeadline(0)
        let viewModel = GoalViewModel(goal: goalWithMidnightDeadline)
        let submissionDateBeforeMidnight = Calendar.current.date(bySettingHour: 20, minute: 30, second: 0, of: Date())!
        let actual = viewModel.initialDateStepperValue(submissionDate: submissionDateBeforeMidnight)
        XCTAssertEqual(actual,
                       DayStep.sameDay.rawValue)
    }
    
    func testInitialStepperIsTomorrowWhenSubmissionDateIsAfterDeadline() async throws {
        let goalWithBeforeMidnightDeadline = Self.makeGoalWithDeadline(3600 * -3)
        let viewModel = GoalViewModel(goal: goalWithBeforeMidnightDeadline)
        let submissionDateBetweenDeadlineAndMidnight = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
        let actual = viewModel.initialDateStepperValue(submissionDate: submissionDateBetweenDeadlineAndMidnight)
        XCTAssertEqual(actual,
                       DayStep.nextDay.rawValue)
    }
}

private extension GoalViewModelTests {
    static func makeGoalWithDeadline(_ deadline: Int) -> Goal {
        let context = BeeminderPersistentContainer.createMemoryBackedForTests().newBackgroundContext()
    
        let user = User(context: context,
                        username: "user123",
                        deadbeat: false,
                        timezone: "",
                        defaultAlertStart: 0,
                        defaultDeadline: 0,
                        defaultLeadTime: 0)
        
        let goal = Goal(context: context,
                    owner: user,
                    id: "goalid",
                    slug: "goalname",
                    alertStart: 0,
                    autodata: nil,
                    deadline: deadline,
                    graphUrl: "",
                    healthKitMetric: "",
                    hhmmFormat: false,
                    initDay: 0,
                    lastTouch: "",
                    limSum: "",
                    leadTime: 0,
                    pledge: 801,
                    queued: false,
                    safeBuf: 0,
                    safeSum: "",
                    thumbUrl: "",
                    title: "goaldescription",
                    todayta: false,
                    urgencyKey: "urgencyKey",
                    useDefaults: false,
                    won: false,
                    yAxis: "units")
        
        context.perform {
            try! context.save()
        }

        return goal
    }
}
