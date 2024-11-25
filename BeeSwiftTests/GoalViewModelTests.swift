//
//  GoalViewModelTests.swift
//  BeeSwiftTests
//
//  Created by krugerk on 2024-11-25.
//

import Testing

@testable import BeeSwift
@testable import BeeKit

struct GoalViewModelTests {
    
    @Test func initialStepperIsMinusOneWhenSubmissionDateIsAfterMidnightAndBeforeDeadline() async throws {
        let goal = Self.makeGoalWithDeadline(3600 * 3)
        let viewModel = GoalViewModel(goal: goal)
        let submissionDate = Calendar.current.date(bySettingHour: 1, minute: 30, second: 0, of: Date())!
        let actual = viewModel.initialDateStepperValue(date: submissionDate)
        #expect(actual == -1)
    }
    
    @Test func initialStepperIsZeroWhenSubmissionDateIsBeforeMidnightAndBeforeDeadline() async throws {
        let goal = Self.makeGoalWithDeadline(0)
        let viewModel = GoalViewModel(goal: goal)
        let submissionDate = Calendar.current.date(bySettingHour: 20, minute: 30, second: 0, of: Date())!
        let actual = viewModel.initialDateStepperValue(date: submissionDate)
        #expect(actual == 0)
    }

    @Test func initialStepperIsPlusOneWhenSubmissionDateIsAfterDeadline() async throws {
        let goal = Self.makeGoalWithDeadline(3600 * -3)
        let viewModel = GoalViewModel(goal: goal)
        let submissionDate = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
        let actual = viewModel.initialDateStepperValue(date: submissionDate)
        #expect(actual == 1)
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
